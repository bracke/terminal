#ifndef TERMINAL_PTY_TESTING
#error "Windows PTY tests require -XTERMINAL_PTY_BUILD=testing"
#else

#include "terminal_pty_windows_internal.h"

int terminal_pty_test_posix_deferred_cleanup(void)
{
   return 1;
}

#define TERMINAL_PTY_TEST_QUARANTINE_BATCH 8

static HANDLE terminal_pty_test_quarantine_releases
  [TERMINAL_PTY_TEST_QUARANTINE_BATCH];
static unsigned int terminal_pty_test_quarantine_release_count = 0;

static DWORD WINAPI terminal_pty_test_signal_later(void *context)
{
   HANDLE event = (HANDLE) context;

   Sleep(250);
   SetEvent(event);
   CloseHandle(event);
   return 0;
}

int terminal_pty_test_close_failure(void)
{
   HANDLE event = CreateEventW(NULL, TRUE, FALSE, NULL);
   HANDLE fixture_owner;
   int result;
   int cleaned;

   if (event == NULL) {
      return 0;
   }
   fixture_owner = event;
   if (!SetHandleInformation
         (event, HANDLE_FLAG_PROTECT_FROM_CLOSE,
          HANDLE_FLAG_PROTECT_FROM_CLOSE)) {
      CloseHandle(event);
      return 0;
   }
   result = terminal_pty_close_handle_owned(&event);
   SetHandleInformation
     (fixture_owner, HANDLE_FLAG_PROTECT_FROM_CLOSE, 0);
   cleaned = CloseHandle(fixture_owner) != 0;
   return result == 0 && event == NULL && cleaned;
}

int terminal_pty_test_failed_reaper(void)
{
   HANDLE event = CreateEventW(NULL, TRUE, FALSE, NULL);
   HANDLE signal_event = NULL;
   int result;

   if (event == NULL) {
      return 0;
   }
   if (!DuplicateHandle
         (GetCurrentProcess(), event,
          GetCurrentProcess(), &signal_event,
          0, FALSE, DUPLICATE_SAME_ACCESS)) {
      CloseHandle(event);
      return 0;
   }
   if (!QueueUserWorkItem
         (terminal_pty_test_signal_later,
          signal_event,
          WT_EXECUTELONGFUNCTION)) {
      CloseHandle(signal_event);
      CloseHandle(event);
      return 0;
   }
   result = terminal_pty_handoff_process_owned(&event);
   if (!result) {
      CloseHandle(event);
   }
   return result;
}

int terminal_pty_test_reader_handoff(void)
{
   HANDLE read_handle = NULL;
   HANDLE write_handle = NULL;
   void *reader = NULL;
   int result;

   if (!terminal_pty_create_overlapped_output_pipe
         (&read_handle, &write_handle)) {
      return 0;
   }
   if (!terminal_pty_create_windows_reader_owned(read_handle, &reader)) {
      CloseHandle(read_handle);
      CloseHandle(write_handle);
      return 0;
   }
   result = terminal_pty_handoff_reader_owned(&reader, &read_handle);
   if (!result) {
      terminal_pty_free_windows_reader_owned(&reader);
      CloseHandle(read_handle);
   }
   CloseHandle(write_handle);
   return result && reader == NULL && read_handle == NULL;
}

static int terminal_pty_test_release_quarantine_owners(void)
{
   unsigned int index;
   int complete = terminal_pty_test_quarantine_release_count > 0;

   for (index = 0;
        index < terminal_pty_test_quarantine_release_count;
        ++index) {
      HANDLE event = terminal_pty_test_quarantine_releases[index];
      terminal_pty_test_quarantine_releases[index] = NULL;
      if (event != NULL) {
         if (!SetEvent(event)) {
            complete = 0;
         }
         if (!CloseHandle(event)) {
            complete = 0;
         }
      }
   }
   terminal_pty_test_quarantine_release_count = 0;
   return complete;
}

static int terminal_pty_test_enter_quarantine_count(unsigned int count)
{
   unsigned int index;
   unsigned int attempt;

   if (count == 0
       || count > TERMINAL_PTY_TEST_QUARANTINE_BATCH
       || terminal_pty_test_quarantine_release_count != 0) {
      return 0;
   }
   for (index = 0; index < count; ++index) {
      HANDLE event = CreateEventW(NULL, TRUE, FALSE, NULL);
      HANDLE release = NULL;

      if (event == NULL
          || !DuplicateHandle
                (GetCurrentProcess(), event,
                 GetCurrentProcess(), &release,
                 0, FALSE, DUPLICATE_SAME_ACCESS)
          || !terminal_pty_handoff_process_owned(&event)) {
         if (event != NULL) {
            CloseHandle(event);
         }
         if (release != NULL) {
            CloseHandle(release);
         }
         terminal_pty_test_release_quarantine_owners();
         return 0;
      }
      terminal_pty_test_quarantine_releases[index] = release;
      terminal_pty_test_quarantine_release_count = index + 1;
   }
   for (attempt = 0; attempt < 700U; ++attempt) {
      if (terminal_pty_cleanup_quarantined_count() >= (LONG) count) {
         return 1;
      }
      Sleep(10);
   }
   terminal_pty_test_release_quarantine_owners();
   return 0;
}

int terminal_pty_test_enter_quarantine(void)
{
   return terminal_pty_test_enter_quarantine_count(1);
}

int terminal_pty_test_enter_quarantine_batch(void)
{
   return terminal_pty_test_enter_quarantine_count
     (TERMINAL_PTY_TEST_QUARANTINE_BATCH);
}

int terminal_pty_test_release_quarantine(void)
{
   return terminal_pty_test_release_quarantine_owners();
}

int terminal_pty_test_cleanup_fault_injection(void)
{
   HANDLE allocation_event = CreateEventW(NULL, TRUE, TRUE, NULL);
   HANDLE queue_event = CreateEventW(NULL, TRUE, FALSE, NULL);
   HANDLE queue_release = NULL;
   int allocation_result;
   int queue_result;
   int queue_released;
   ULONGLONG queue_started;
   ULONGLONG queue_elapsed;

   if (allocation_event == NULL || queue_event == NULL
       || !DuplicateHandle
            (GetCurrentProcess(), queue_event,
             GetCurrentProcess(), &queue_release,
             0, FALSE, DUPLICATE_SAME_ACCESS)) {
      if (allocation_event != NULL) {
         CloseHandle(allocation_event);
      }
      if (queue_event != NULL) {
         CloseHandle(queue_event);
      }
      if (queue_release != NULL) {
         CloseHandle(queue_release);
      }
      return 0;
   }
   terminal_pty_cleanup_test_fail_allocations(4);
   allocation_result =
     terminal_pty_handoff_process_owned(&allocation_event);
   terminal_pty_cleanup_test_fail_allocations(0);
   if (allocation_result || allocation_event == NULL) {
      if (allocation_event != NULL) {
         CloseHandle(allocation_event);
      }
      CloseHandle(queue_event);
      CloseHandle(queue_release);
      return 0;
   }
   CloseHandle(allocation_event);

   terminal_pty_cleanup_test_fail_queue_submissions(1);
   queue_started = GetTickCount64();
   queue_result = terminal_pty_handoff_process_owned(&queue_event);
   queue_elapsed = GetTickCount64() - queue_started;
   terminal_pty_cleanup_test_fail_queue_submissions(0);
   queue_released = SetEvent(queue_release) != 0;
   CloseHandle(queue_release);
   if (!queue_result || queue_event != NULL) {
      if (queue_event != NULL) {
         CloseHandle(queue_event);
      }
      return 0;
   }
   return queue_released && queue_elapsed < 500U
     && terminal_pty_cleanup_drain(1000);
}

int terminal_pty_test_rejected_handoff(void)
{
   HANDLE event = CreateEventW(NULL, TRUE, TRUE, NULL);
   int result;

   if (event == NULL) {
      return 0;
   }
   result = terminal_pty_handoff_process_owned(&event);
   if (result || event == NULL) {
      if (event != NULL) {
         CloseHandle(event);
      }
      return 0;
   }
   return CloseHandle(event) != 0;
}

int terminal_pty_test_permanent_release_failures(void)
{
   HANDLE read_handle = NULL;
   HANDLE write_handle = NULL;
   void *reader = NULL;
   void *fixture_reader;
   unsigned char byte = 0;
   DWORD bytes_read = 0;
   DWORD error_code = 0;
   void *allocation = LocalAlloc(LPTR, 64);
   void *fixture_allocation = allocation;
   int initialized = 0;
   int read_result;
   int free_result;
   enum terminal_pty_reader_cleanup_result reader_cleanup;
   int cleaned;

   if (allocation == NULL
       || !terminal_pty_create_overlapped_output_pipe
            (&read_handle, &write_handle)
       || !terminal_pty_create_windows_reader_owned(read_handle, &reader)) {
      if (allocation != NULL) {
         LocalFree(allocation);
      }
      if (read_handle != NULL) {
         CloseHandle(read_handle);
      }
      if (write_handle != NULL) {
         CloseHandle(write_handle);
      }
      return 0;
   }
   read_result = terminal_pty_poll_windows_reader
     (reader, &byte, 1, &bytes_read, &error_code);
   if (read_result != 0) {
      terminal_pty_free_windows_reader_owned(&reader);
      CloseHandle(read_handle);
      CloseHandle(write_handle);
      LocalFree(allocation);
      return 0;
   }
   fixture_reader = reader;

   terminal_pty_cleanup_test_fail_waits(1);
   free_result = terminal_pty_free_windows_reader_owned(&reader);
   terminal_pty_cleanup_test_fail_waits(0);
   reader_cleanup = terminal_pty_free_windows_reader(fixture_reader);
   CloseHandle(read_handle);
   CloseHandle(write_handle);
   if (free_result || reader != NULL
       || reader_cleanup != TERMINAL_PTY_READER_COMPLETE) {
      LocalFree(allocation);
      return 0;
   }

   terminal_pty_cleanup_test_fail_local_frees(1);
   free_result = terminal_pty_free_attribute_list_owned
     (&allocation, 0, &initialized);
   terminal_pty_cleanup_test_fail_local_frees(0);
   cleaned = LocalFree(fixture_allocation) == NULL;
   return !free_result && allocation == NULL && cleaned;
}

#endif
