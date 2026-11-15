#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>

struct terminal_pty_cleanup_job {
   pid_t pid;
   struct terminal_pty_cleanup_job *next;
};

static pthread_mutex_t terminal_pty_cleanup_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t terminal_pty_cleanup_changed = PTHREAD_COND_INITIALIZER;
static struct terminal_pty_cleanup_job *terminal_pty_quarantine;
static struct terminal_pty_cleanup_job *terminal_pty_quarantine_tail;
static long terminal_pty_cleanup_failures;
static long terminal_pty_cleanup_pending;
static long terminal_pty_cleanup_quarantined;
static long terminal_pty_cleanup_abandoned;
static int terminal_pty_cleanup_accepting = 1;
static int terminal_pty_cleanup_worker_started;
/* 0 = no join required, 1 = joinable, 2 = another shutdown is joining. */
static int terminal_pty_cleanup_worker_join_state;
static pthread_t terminal_pty_cleanup_worker_thread;

extern int terminal_pty_kill_process_group(pid_t pid);

static void terminal_pty_increment(long *value)
{
   if (*value < LONG_MAX) {
      ++*value;
   }
}

static void terminal_pty_decrement(long *value)
{
   if (*value > 0) {
      --*value;
   }
}

static void terminal_pty_pause(void)
{
   const struct timespec interval = {0, 10000000L};
   (void) nanosleep(&interval, NULL);
}

void terminal_pty_posix_note_cleanup_failure(void)
{
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   terminal_pty_increment(&terminal_pty_cleanup_failures);
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
}

void terminal_pty_posix_note_cleanup_abandoned(void)
{
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   terminal_pty_increment(&terminal_pty_cleanup_failures);
   terminal_pty_increment(&terminal_pty_cleanup_abandoned);
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
}

static void terminal_pty_note_wait_failure(void)
{
   terminal_pty_posix_note_cleanup_abandoned();
}

/* Return 1 when reaped, 0 when the bounded wait expires, and -1 when this
   process can no longer safely own the PID.  Only a terminal result consumes
   the marker. */
int terminal_pty_posix_terminate_child_owned
  (int *pid, int *status, unsigned int timeout_ms)
{
   unsigned int attempt;
   unsigned int attempts = timeout_ms / 10U + 1U;
   int result;

   if (*pid <= 0) {
      *pid = -1;
      return 1;
   }
   (void) terminal_pty_kill_process_group((pid_t) *pid);
   for (attempt = 0; attempt < attempts; ++attempt) {
      result = (int) waitpid((pid_t) *pid, status, WNOHANG);
      if (result > 0) {
         *pid = -1;
         return 1;
      }
      if (result < 0 && errno == EINTR) {
         if (attempt + 1U >= attempts) {
            return 0;
         }
         terminal_pty_pause();
         continue;
      }
      if (result < 0) {
         *pid = -1;
         terminal_pty_note_wait_failure();
         return -1;
      }
      if (attempt + 1U >= attempts) {
         return 0;
      }
      terminal_pty_pause();
   }
   return 0;
}

static void *terminal_pty_cleanup_worker(void *unused);

int terminal_pty_posix_handoff_child_owned(int *pid)
{
   struct terminal_pty_cleanup_job *job;

   if (*pid <= 0) {
      *pid = -1;
      return 1;
   }
   job = (struct terminal_pty_cleanup_job *) malloc(sizeof *job);
   if (job == NULL) {
      terminal_pty_posix_note_cleanup_failure();
      return 0;
   }
   job->pid = (pid_t) *pid;
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   if (!terminal_pty_cleanup_accepting) {
      pthread_mutex_unlock(&terminal_pty_cleanup_lock);
      free(job);
      terminal_pty_posix_note_cleanup_failure();
      return 0;
   }
   if (!terminal_pty_cleanup_worker_started) {
      int create_result = pthread_create
        (&terminal_pty_cleanup_worker_thread, NULL,
         terminal_pty_cleanup_worker, NULL);
      if (create_result != 0) {
         pthread_mutex_unlock(&terminal_pty_cleanup_lock);
         free(job);
         terminal_pty_posix_note_cleanup_failure();
         return 0;
      }
      terminal_pty_cleanup_worker_started = 1;
      terminal_pty_cleanup_worker_join_state = 1;
   }
   job->next = NULL;
   if (terminal_pty_quarantine_tail == NULL) {
      terminal_pty_quarantine = job;
   } else {
      terminal_pty_quarantine_tail->next = job;
   }
   terminal_pty_quarantine_tail = job;
   terminal_pty_increment(&terminal_pty_cleanup_pending);
   terminal_pty_increment(&terminal_pty_cleanup_quarantined);
   *pid = -1;
   pthread_cond_signal(&terminal_pty_cleanup_changed);
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   return 1;
}

void terminal_pty_posix_abandon_child_owned(int *pid)
{
   *pid = -1;
   terminal_pty_posix_note_cleanup_abandoned();
}

long terminal_pty_posix_cleanup_failure_count(void)
{
   long result;
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   result = terminal_pty_cleanup_failures;
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   return result;
}

long terminal_pty_posix_cleanup_pending_count(void)
{
   long result;
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   result = terminal_pty_cleanup_pending;
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   return result;
}

long terminal_pty_posix_cleanup_quarantined_count(void)
{
   long result;
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   result = terminal_pty_cleanup_quarantined;
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   return result;
}

long terminal_pty_posix_cleanup_abandoned_count(void)
{
   long result;
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   result = terminal_pty_cleanup_abandoned;
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   return result;
}

int terminal_pty_posix_cleanup_is_accepting(void)
{
   int result;
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   result = terminal_pty_cleanup_accepting;
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   return result;
}

static void terminal_pty_requeue_quarantine
  (struct terminal_pty_cleanup_job *job)
{
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   job->next = NULL;
   if (terminal_pty_quarantine_tail == NULL) {
      terminal_pty_quarantine = job;
   } else {
      terminal_pty_quarantine_tail->next = job;
   }
   terminal_pty_quarantine_tail = job;
   terminal_pty_increment(&terminal_pty_cleanup_quarantined);
   pthread_cond_signal(&terminal_pty_cleanup_changed);
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
}

static void terminal_pty_complete_job
  (struct terminal_pty_cleanup_job *job)
{
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   terminal_pty_decrement(&terminal_pty_cleanup_pending);
   pthread_cond_broadcast(&terminal_pty_cleanup_changed);
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
   free(job);
}

static void *terminal_pty_cleanup_worker(void *unused)
{
   (void) unused;
   for (;;) {
      struct terminal_pty_cleanup_job *job;
      int pid;
      int status = 0;
      int result;

      pthread_mutex_lock(&terminal_pty_cleanup_lock);
      while (terminal_pty_quarantine == NULL) {
         if (!terminal_pty_cleanup_accepting
             && terminal_pty_cleanup_pending == 0) {
            terminal_pty_cleanup_worker_started = 0;
            pthread_cond_broadcast(&terminal_pty_cleanup_changed);
            pthread_mutex_unlock(&terminal_pty_cleanup_lock);
            return NULL;
         }
         (void) pthread_cond_wait
           (&terminal_pty_cleanup_changed, &terminal_pty_cleanup_lock);
      }
      job = terminal_pty_quarantine;
      terminal_pty_quarantine = job->next;
      if (terminal_pty_quarantine == NULL) {
         terminal_pty_quarantine_tail = NULL;
      }
      job->next = NULL;
      terminal_pty_decrement(&terminal_pty_cleanup_quarantined);
      pthread_mutex_unlock(&terminal_pty_cleanup_lock);

      pid = (int) job->pid;
      result = terminal_pty_posix_terminate_child_owned(&pid, &status, 100U);
      if (result == 0) {
         job->pid = (pid_t) pid;
         terminal_pty_requeue_quarantine(job);
         terminal_pty_pause();
      } else {
         terminal_pty_complete_job(job);
      }
   }
}

int terminal_pty_posix_cleanup_drain(unsigned int timeout_ms)
{
   unsigned int attempt;
   unsigned int attempts = timeout_ms / 10U + 1U;

   for (attempt = 0; attempt < attempts; ++attempt) {
      if (terminal_pty_posix_cleanup_pending_count() == 0) {
         return terminal_pty_posix_cleanup_pending_count() == 0
            && terminal_pty_posix_cleanup_abandoned_count() == 0;
      }
      if (attempt + 1U >= attempts) {
         return 0;
      }
      terminal_pty_pause();
   }
   return 0;
}

void terminal_pty_posix_cleanup_stop_accepting(void)
{
   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   terminal_pty_cleanup_accepting = 0;
   pthread_cond_broadcast(&terminal_pty_cleanup_changed);
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);
}

int terminal_pty_posix_cleanup_drain_closed(unsigned int timeout_ms)
{
   unsigned int attempt;
   unsigned int attempts = timeout_ms / 10U + 1U;

   pthread_mutex_lock(&terminal_pty_cleanup_lock);
   if (terminal_pty_cleanup_accepting) {
      pthread_mutex_unlock(&terminal_pty_cleanup_lock);
      return 0;
   }
   pthread_mutex_unlock(&terminal_pty_cleanup_lock);

   for (attempt = 0; attempt < attempts; ++attempt) {
      int stopped;
      int complete;
      int join_worker = 0;
      pthread_t worker;
      pthread_mutex_lock(&terminal_pty_cleanup_lock);
      stopped = terminal_pty_cleanup_pending == 0
        && !terminal_pty_cleanup_worker_started;
      complete = stopped && terminal_pty_cleanup_abandoned == 0;
      if (stopped && terminal_pty_cleanup_worker_join_state == 1) {
         worker = terminal_pty_cleanup_worker_thread;
         terminal_pty_cleanup_worker_join_state = 2;
         join_worker = 1;
      } else if (stopped && terminal_pty_cleanup_worker_join_state == 2) {
         stopped = 0;
      }
      pthread_mutex_unlock(&terminal_pty_cleanup_lock);
      if (stopped) {
         if (join_worker) {
            int join_result = pthread_join(worker, NULL);
            pthread_mutex_lock(&terminal_pty_cleanup_lock);
            terminal_pty_cleanup_worker_join_state =
              join_result == 0 ? 0 : 1;
            pthread_cond_broadcast(&terminal_pty_cleanup_changed);
            pthread_mutex_unlock(&terminal_pty_cleanup_lock);
            if (join_result != 0) {
               terminal_pty_posix_note_cleanup_failure();
               return 0;
            }
         }
         return complete;
      }
      if (attempt + 1U >= attempts) {
         return 0;
      }
      terminal_pty_pause();
   }
   return 0;
}

int terminal_pty_posix_cleanup_shutdown(unsigned int timeout_ms)
{
   terminal_pty_posix_cleanup_stop_accepting();
   return terminal_pty_posix_cleanup_drain_closed(timeout_ms);
}
