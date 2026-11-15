#include "terminal_pty_windows_internal.h"

#include <limits.h>
#include <stdlib.h>

#define TERMINAL_PTY_CLEANUP_ATTEMPTS 8
#define TERMINAL_PTY_MAX_BACKOFF_MS 800
#define TERMINAL_PTY_MAX_DRAIN_WORKERS 4

enum terminal_pty_cleanup_kind {
   TERMINAL_PTY_CLEANUP_PROCESS,
   TERMINAL_PTY_CLEANUP_READER
};

struct terminal_pty_cleanup_job {
   enum terminal_pty_cleanup_kind kind;
   void *primary;
   HANDLE secondary;
   struct terminal_pty_cleanup_job *next;
};

static SRWLOCK terminal_pty_cleanup_lock = SRWLOCK_INIT;
static struct terminal_pty_cleanup_job *terminal_pty_quarantine = NULL;
static volatile LONG terminal_pty_cleanup_failures = 0;
static volatile LONG terminal_pty_cleanup_pending = 0;
static volatile LONG terminal_pty_cleanup_quarantined = 0;
static volatile LONG terminal_pty_cleanup_abandoned = 0;
static volatile LONG terminal_pty_cleanup_active = 0;
static LONG terminal_pty_cleanup_accepting = 1;
#ifdef TERMINAL_PTY_TESTING
static volatile LONG terminal_pty_test_allocation_failures = 0;
static volatile LONG terminal_pty_test_queue_failures = 0;
static volatile LONG terminal_pty_test_wait_failures = 0;
static volatile LONG terminal_pty_test_local_free_failures = 0;
static volatile LONG terminal_pty_test_drain_worker_high_water = 0;
#endif

static void terminal_pty_saturating_increment(volatile LONG *value)
{
   LONG previous;
   LONG replacement;

   do {
      previous = InterlockedCompareExchange(value, 0, 0);
      if (previous == LONG_MAX) {
         return;
      }
      replacement = previous + 1;
   } while (InterlockedCompareExchange(value, replacement, previous) != previous);
}

static void terminal_pty_nonnegative_decrement(volatile LONG *value)
{
   LONG previous;

   do {
      previous = InterlockedCompareExchange(value, 0, 0);
      if (previous <= 0) {
         return;
      }
   } while (InterlockedCompareExchange(value, previous - 1, previous)
            != previous);
}

#ifdef TERMINAL_PTY_TESTING
static int terminal_pty_consume_test_failure(volatile LONG *value)
{
   LONG previous;

   do {
      previous = InterlockedCompareExchange(value, 0, 0);
      if (previous <= 0) {
         return 0;
      }
   } while (InterlockedCompareExchange(value, previous - 1, previous)
            != previous);
   return 1;
}

void terminal_pty_cleanup_test_fail_allocations(LONG count)
{
   InterlockedExchange
     (&terminal_pty_test_allocation_failures, count > 0 ? count : 0);
}

void terminal_pty_cleanup_test_fail_queue_submissions(LONG count)
{
   InterlockedExchange
     (&terminal_pty_test_queue_failures, count > 0 ? count : 0);
}

void terminal_pty_cleanup_test_fail_waits(LONG count)
{
   InterlockedExchange
     (&terminal_pty_test_wait_failures, count > 0 ? count : 0);
}

void terminal_pty_cleanup_test_fail_local_frees(LONG count)
{
   InterlockedExchange
     (&terminal_pty_test_local_free_failures, count > 0 ? count : 0);
}

int terminal_pty_cleanup_test_take_wait_failure(void)
{
   return terminal_pty_consume_test_failure
     (&terminal_pty_test_wait_failures);
}

int terminal_pty_cleanup_test_take_local_free_failure(void)
{
   return terminal_pty_consume_test_failure
     (&terminal_pty_test_local_free_failures);
}

void terminal_pty_cleanup_test_reset_drain_worker_high_water(void)
{
   InterlockedExchange(&terminal_pty_test_drain_worker_high_water, 0);
}

LONG terminal_pty_cleanup_test_drain_worker_high_water(void)
{
   return InterlockedCompareExchange
     (&terminal_pty_test_drain_worker_high_water, 0, 0);
}

LONG terminal_pty_cleanup_test_active_workers(void)
{
   return InterlockedCompareExchange(&terminal_pty_cleanup_active, 0, 0);
}
#endif

void terminal_pty_note_cleanup_failure(void)
{
   terminal_pty_saturating_increment(&terminal_pty_cleanup_failures);
   OutputDebugStringA("terminal_pty: native cleanup remained incomplete\n");
}

void terminal_pty_note_cleanup_abandoned(void)
{
   terminal_pty_note_cleanup_failure();
   terminal_pty_saturating_increment(&terminal_pty_cleanup_abandoned);
}

LONG terminal_pty_cleanup_failure_count(void)
{
   return InterlockedCompareExchange(&terminal_pty_cleanup_failures, 0, 0);
}

LONG terminal_pty_cleanup_pending_count(void)
{
   return InterlockedCompareExchange(&terminal_pty_cleanup_pending, 0, 0);
}

LONG terminal_pty_cleanup_quarantined_count(void)
{
   return InterlockedCompareExchange(&terminal_pty_cleanup_quarantined, 0, 0);
}

LONG terminal_pty_cleanup_abandoned_count(void)
{
   return InterlockedCompareExchange(&terminal_pty_cleanup_abandoned, 0, 0);
}

int terminal_pty_cleanup_is_accepting(void)
{
   int accepting;

   AcquireSRWLockShared(&terminal_pty_cleanup_lock);
   accepting = terminal_pty_cleanup_accepting != 0;
   ReleaseSRWLockShared(&terminal_pty_cleanup_lock);
   return accepting;
}

static DWORD terminal_pty_cleanup_backoff(unsigned int attempt)
{
   DWORD delay = 25U << (attempt < 5U ? attempt : 5U);
   return delay < TERMINAL_PTY_MAX_BACKOFF_MS
     ? delay : TERMINAL_PTY_MAX_BACKOFF_MS;
}

static int terminal_pty_try_cleanup(struct terminal_pty_cleanup_job *job)
{
   DWORD waited;
   enum terminal_pty_reader_cleanup_result reader_result;

   switch (job->kind) {
      case TERMINAL_PTY_CLEANUP_PROCESS:
         TerminateProcess((HANDLE) job->primary, 1);
         waited = WaitForSingleObject((HANDLE) job->primary, 100);
         if (waited == WAIT_TIMEOUT) {
            return 0;
         }
         if (waited != WAIT_OBJECT_0) {
            /* WAIT_FAILED and unexpected states are permanent. Consume the
               marker once instead of risking a retry after handle reuse. */
            terminal_pty_note_cleanup_abandoned();
            job->primary = NULL;
            return 1;
         }
         if (!CloseHandle((HANDLE) job->primary)) {
            terminal_pty_note_cleanup_abandoned();
         }
         job->primary = NULL;
         return 1;

      case TERMINAL_PTY_CLEANUP_READER:
         reader_result = terminal_pty_free_windows_reader(job->primary);
         if (reader_result == TERMINAL_PTY_READER_RETRY) {
            return 0;
         }
         /* A negative result deliberately abandons storage that may still be
            referenced by an unobservable overlapped operation. */
         job->primary = NULL;
         if (job->secondary != NULL && !CloseHandle(job->secondary)) {
            terminal_pty_note_cleanup_abandoned();
         }
         job->secondary = NULL;
         return 1;

   }
   return 0;
}

static void terminal_pty_quarantine_job(struct terminal_pty_cleanup_job *job)
{
   AcquireSRWLockExclusive(&terminal_pty_cleanup_lock);
   job->next = terminal_pty_quarantine;
   terminal_pty_quarantine = job;
   terminal_pty_saturating_increment(&terminal_pty_cleanup_quarantined);
   ReleaseSRWLockExclusive(&terminal_pty_cleanup_lock);
}

static void terminal_pty_run_cleanup_job(struct terminal_pty_cleanup_job *job)
{
   unsigned int attempt;

   for (attempt = 0; attempt < TERMINAL_PTY_CLEANUP_ATTEMPTS; ++attempt) {
      if (terminal_pty_try_cleanup(job)) {
         free(job);
         terminal_pty_nonnegative_decrement(&terminal_pty_cleanup_pending);
         return;
      }
      if (attempt + 1U < TERMINAL_PTY_CLEANUP_ATTEMPTS) {
         Sleep(terminal_pty_cleanup_backoff(attempt));
      }
   }
   terminal_pty_note_cleanup_failure();
   terminal_pty_quarantine_job(job);
}

static DWORD WINAPI terminal_pty_cleanup_worker(void *context)
{
   terminal_pty_run_cleanup_job((struct terminal_pty_cleanup_job *) context);
   terminal_pty_nonnegative_decrement(&terminal_pty_cleanup_active);
   return 0;
}

static int terminal_pty_reserve_cleanup_worker(int enforce_drain_limit)
{
   LONG previous;

   do {
      previous = InterlockedCompareExchange
        (&terminal_pty_cleanup_active, 0, 0);
      if (previous == LONG_MAX
          || (enforce_drain_limit
              && previous >= TERMINAL_PTY_MAX_DRAIN_WORKERS)) {
         return 0;
      }
   } while (InterlockedCompareExchange
              (&terminal_pty_cleanup_active, previous + 1, previous)
            != previous);
#ifdef TERMINAL_PTY_TESTING
   if (enforce_drain_limit) {
      LONG observed = InterlockedCompareExchange
        (&terminal_pty_test_drain_worker_high_water, 0, 0);
      while (observed < previous + 1
             && InterlockedCompareExchange
                  (&terminal_pty_test_drain_worker_high_water,
                   previous + 1,
                   observed) != observed) {
         observed = InterlockedCompareExchange
           (&terminal_pty_test_drain_worker_high_water, 0, 0);
      }
   }
#endif
   return 1;
}

static int terminal_pty_queue_cleanup_job
  (struct terminal_pty_cleanup_job *job, int enforce_drain_limit)
{
   if (!terminal_pty_reserve_cleanup_worker(enforce_drain_limit)) {
      return 0;
   }
#ifdef TERMINAL_PTY_TESTING
   if (terminal_pty_consume_test_failure
         (&terminal_pty_test_queue_failures)) {
      terminal_pty_nonnegative_decrement(&terminal_pty_cleanup_active);
      return 0;
   }
#endif
   if (!QueueUserWorkItem
         (terminal_pty_cleanup_worker, job, WT_EXECUTELONGFUNCTION)) {
      terminal_pty_nonnegative_decrement(&terminal_pty_cleanup_active);
      return 0;
   }
   return 1;
}

static struct terminal_pty_cleanup_job *terminal_pty_new_cleanup_job
  (enum terminal_pty_cleanup_kind kind, void *primary, HANDLE secondary)
{
   struct terminal_pty_cleanup_job *job;
#ifdef TERMINAL_PTY_TESTING
   job = terminal_pty_consume_test_failure
     (&terminal_pty_test_allocation_failures)
     ? NULL : (struct terminal_pty_cleanup_job *) calloc(1, sizeof *job);
#else
   job = (struct terminal_pty_cleanup_job *) calloc(1, sizeof *job);
#endif
   if (job != NULL) {
      job->kind = kind;
      job->primary = primary;
      job->secondary = secondary;
      return job;
   }
   terminal_pty_note_cleanup_failure();
   return NULL;
}

static int terminal_pty_accept_cleanup_job
  (struct terminal_pty_cleanup_job *job)
{
   int accepted = 0;

   AcquireSRWLockExclusive(&terminal_pty_cleanup_lock);
   if (terminal_pty_cleanup_accepting) {
      terminal_pty_saturating_increment(&terminal_pty_cleanup_pending);
      accepted = 1;
   }
   ReleaseSRWLockExclusive(&terminal_pty_cleanup_lock);
   if (!accepted) {
      free(job);
      terminal_pty_note_cleanup_failure();
   }
   return accepted;
}

static void terminal_pty_submit_cleanup_job
  (struct terminal_pty_cleanup_job *job)
{
   if (!terminal_pty_queue_cleanup_job(job, 0)) {
      /* Handoff must never inherit the worker's waits. Keep accepted
         ownership in quarantine for a later bounded drain instead. */
      terminal_pty_quarantine_job(job);
   }
}

int terminal_pty_handoff_process_owned(HANDLE *target)
{
   HANDLE owned = *target;
   struct terminal_pty_cleanup_job *job;

   if (owned == NULL || owned == INVALID_HANDLE_VALUE) {
      *target = NULL;
      return 1;
   }
   job = terminal_pty_new_cleanup_job
     (TERMINAL_PTY_CLEANUP_PROCESS, owned, NULL);
   if (job == NULL || !terminal_pty_accept_cleanup_job(job)) {
      return 0;
   }
   *target = NULL;
   terminal_pty_submit_cleanup_job(job);
   return 1;
}

int terminal_pty_handoff_reader_owned(void **target, HANDLE *pipe)
{
   void *owned = *target;
   struct terminal_pty_cleanup_job *job;

   if (owned == NULL) {
      return 0;
   }
   job = terminal_pty_new_cleanup_job
     (TERMINAL_PTY_CLEANUP_READER, owned, *pipe);
   if (job == NULL || !terminal_pty_accept_cleanup_job(job)) {
      return 0;
   }
   *target = NULL;
   *pipe = NULL;
   terminal_pty_submit_cleanup_job(job);
   return 1;
}

static struct terminal_pty_cleanup_job *terminal_pty_pop_quarantine(void)
{
   struct terminal_pty_cleanup_job *job;

   AcquireSRWLockExclusive(&terminal_pty_cleanup_lock);
   job = terminal_pty_quarantine;
   if (job != NULL) {
      terminal_pty_quarantine = job->next;
      job->next = NULL;
      terminal_pty_nonnegative_decrement
        (&terminal_pty_cleanup_quarantined);
   }
   ReleaseSRWLockExclusive(&terminal_pty_cleanup_lock);
   return job;
}

int terminal_pty_cleanup_drain(DWORD timeout_ms)
{
   ULONGLONG started = GetTickCount64();
   struct terminal_pty_cleanup_job *job;

   for (;;) {
      while ((job = terminal_pty_pop_quarantine()) != NULL) {
         if (!terminal_pty_queue_cleanup_job(job, 1)) {
            terminal_pty_quarantine_job(job);
            break;
         }
      }
      if (terminal_pty_cleanup_pending_count() == 0
          && InterlockedCompareExchange
               (&terminal_pty_cleanup_active, 0, 0) == 0) {
         return terminal_pty_cleanup_abandoned_count() == 0;
      }
      if (GetTickCount64() - started >= (ULONGLONG) timeout_ms) {
         return 0;
      }
      Sleep(10);
   }
}

void terminal_pty_cleanup_stop_accepting(void)
{
   AcquireSRWLockExclusive(&terminal_pty_cleanup_lock);
   terminal_pty_cleanup_accepting = 0;
   ReleaseSRWLockExclusive(&terminal_pty_cleanup_lock);
}

int terminal_pty_cleanup_drain_closed(DWORD timeout_ms)
{
   if (terminal_pty_cleanup_is_accepting()) {
      return 0;
   }
   return terminal_pty_cleanup_drain(timeout_ms);
}

int terminal_pty_cleanup_shutdown(DWORD timeout_ms)
{
   terminal_pty_cleanup_stop_accepting();
   return terminal_pty_cleanup_drain_closed(timeout_ms);
}
