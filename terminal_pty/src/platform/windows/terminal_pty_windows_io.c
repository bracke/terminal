#include "terminal_pty_windows_internal.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define TERMINAL_PTY_READ_BUFFER_SIZE 4096

struct terminal_pty_windows_reader {
   HANDLE pipe;
   HANDLE event;
   OVERLAPPED operation;
   unsigned char buffer[TERMINAL_PTY_READ_BUFFER_SIZE];
   DWORD ready_offset;
   DWORD ready_length;
   int pending;
   int eof;
};

static volatile LONG terminal_pty_pipe_serial = 0;

static int terminal_pty_pipe_closed(DWORD error)
{
   return error == ERROR_BROKEN_PIPE
       || error == ERROR_PIPE_NOT_CONNECTED
       || error == ERROR_NO_DATA;
}

/* Create the host read end as an overlapped named-pipe handle. CreatePipe
   cannot request FILE_FLAG_OVERLAPPED. */
int terminal_pty_create_overlapped_output_pipe
  (HANDLE *read_handle, HANDLE *write_handle)
{
   WCHAR name[128];
   HANDLE read_pipe;
   HANDLE write_pipe;
   DWORD error;
   LONG serial;

   if (read_handle == NULL || write_handle == NULL) {
      SetLastError(ERROR_INVALID_PARAMETER);
      return 0;
   }
   *read_handle = NULL;
   *write_handle = NULL;
   serial = InterlockedIncrement(&terminal_pty_pipe_serial);
   if (swprintf(name,
                sizeof name / sizeof name[0],
                L"\\\\.\\pipe\\terminal-pty-%lu-%ld",
                (unsigned long) GetCurrentProcessId(),
                (long) serial) < 0) {
      SetLastError(ERROR_INVALID_NAME);
      return 0;
   }

   read_pipe = CreateNamedPipeW
     (name,
      PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
      1,
      0,
      64 * 1024,
      0,
      NULL);
   if (read_pipe == INVALID_HANDLE_VALUE) {
      return 0;
   }

   write_pipe = CreateFileW
     (name,
      GENERIC_WRITE,
      0,
      NULL,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      NULL);
   if (write_pipe == INVALID_HANDLE_VALUE) {
      error = GetLastError();
      CloseHandle(read_pipe);
      SetLastError(error);
      return 0;
   }

   *read_handle = read_pipe;
   *write_handle = write_pipe;
   return 1;
}

void *terminal_pty_create_windows_reader(HANDLE pipe)
{
   struct terminal_pty_windows_reader *reader;
   DWORD error;

   reader = (struct terminal_pty_windows_reader *) calloc(1, sizeof *reader);
   if (reader == NULL) {
      SetLastError(ERROR_OUTOFMEMORY);
      return NULL;
   }
   reader->event = CreateEventW(NULL, TRUE, FALSE, NULL);
   if (reader->event == NULL) {
      error = GetLastError();
      free(reader);
      SetLastError(error);
      return NULL;
   }
   reader->pipe = pipe;
   return reader;
}

int terminal_pty_create_windows_reader_owned(HANDLE pipe, void **target)
{
   void *result = terminal_pty_create_windows_reader(pipe);
   *target = result;
   return result != NULL;
}

int terminal_pty_allocate_attribute_list(void **target, SIZE_T bytes)
{
   void *result = LocalAlloc(LPTR, bytes);
   *target = result;
   return result != NULL;
}

enum terminal_pty_reader_cleanup_result
terminal_pty_free_windows_reader(void *context)
{
   struct terminal_pty_windows_reader *reader =
     (struct terminal_pty_windows_reader *) context;
   DWORD ignored;

   if (reader == NULL) {
      return TERMINAL_PTY_READER_COMPLETE;
   }
   if (reader->pending) {
      CancelIoEx(reader->pipe, &reader->operation);
      DWORD waited;

#ifdef TERMINAL_PTY_TESTING
      waited = terminal_pty_cleanup_test_take_wait_failure()
        ? WAIT_FAILED : WaitForSingleObject(reader->event, 1000);
#else
      waited = WaitForSingleObject(reader->event, 1000);
#endif

      if (waited == WAIT_TIMEOUT) {
         return TERMINAL_PTY_READER_RETRY;
      }
      if (waited != WAIT_OBJECT_0) {
         /* The event marker is no longer safe to retry. Keep the reader
            allocation alive because an overlapped operation may still refer
            to it, but consume the public owner and report a terminal leak. */
         terminal_pty_note_cleanup_abandoned();
         return TERMINAL_PTY_READER_ABANDONED;
      }
      GetOverlappedResult
        (reader->pipe, &reader->operation, &ignored, FALSE);
      reader->pending = 0;
   }
   if (reader->event != NULL) {
      HANDLE event = reader->event;

      /* A close attempt consumes the numeric handle. Retrying a failed
         CloseHandle later could close an unrelated handle after reuse. */
      reader->event = NULL;
      if (!CloseHandle(event)) {
         terminal_pty_note_cleanup_abandoned();
      }
   }
   free(reader);
   return TERMINAL_PTY_READER_COMPLETE;
}

int terminal_pty_free_windows_reader_owned(void **target)
{
   void *owned = *target;
   enum terminal_pty_reader_cleanup_result result =
     terminal_pty_free_windows_reader(owned);

   if (result == TERMINAL_PTY_READER_RETRY) {
      return 0;
   }
   *target = NULL;
   return result == TERMINAL_PTY_READER_COMPLETE;
}

int terminal_pty_abandon_windows_reader_owned
  (void **target, HANDLE *pipe)
{
   struct terminal_pty_windows_reader *reader =
     (struct terminal_pty_windows_reader *) *target;
   HANDLE owned_pipe = *pipe;
   int complete = 1;

   *target = NULL;
   *pipe = NULL;
   if (reader == NULL) {
      if (owned_pipe != NULL && !CloseHandle(owned_pipe)) {
         terminal_pty_note_cleanup_abandoned();
         return 0;
      }
      return 1;
   }
   if (reader->pending) {
      CancelIoEx(reader->pipe, &reader->operation);
   }
   if (owned_pipe != NULL && !CloseHandle(owned_pipe)) {
      terminal_pty_note_cleanup_abandoned();
      complete = 0;
   }
   if (reader->pending) {
      /* This is the allocation-free terminal fallback. The OVERLAPPED storage
         must outlive an operation whose completion cannot be observed, so
         relinquish it without waiting rather than risk a use-after-free. */
      terminal_pty_note_cleanup_abandoned();
      return 0;
   }
   if (reader->event != NULL && !CloseHandle(reader->event)) {
      terminal_pty_note_cleanup_abandoned();
      complete = 0;
   }
   free(reader);
   return complete;
}

int terminal_pty_close_handle_owned(HANDLE *target)
{
   HANDLE owned = *target;

   if (owned == NULL || owned == INVALID_HANDLE_VALUE) {
      *target = NULL;
      return 1;
   }
   /* Consume before closing: a failed CloseHandle does not provide a safe
      marker to retry because Windows may reuse the numeric value. */
   *target = NULL;
   if (!CloseHandle(owned)) {
      terminal_pty_note_cleanup_abandoned();
      return 0;
   }
   return 1;
}

void terminal_pty_close_pseudo_console_owned(HPCON *target)
{
   HPCON owned = *target;
   *target = NULL;
   if (owned != NULL) {
      ClosePseudoConsole(owned);
   }
}

int terminal_pty_free_attribute_list_owned
  (void **target, int initialized, int *still_initialized)
{
   void *owned = *target;
   HLOCAL free_result;
   *still_initialized = initialized;
   if (owned == NULL) {
      *target = NULL;
      *still_initialized = 0;
      return 1;
   }
   if (initialized) {
      DeleteProcThreadAttributeList
        ((LPPROC_THREAD_ATTRIBUTE_LIST) owned);
      *still_initialized = 0;
   }
#ifdef TERMINAL_PTY_TESTING
   free_result = terminal_pty_cleanup_test_take_local_free_failure()
     ? (HLOCAL) owned : LocalFree(owned);
#else
   free_result = LocalFree(owned);
#endif
   if (free_result != NULL) {
      /* LocalFree failures are not transient. Consume the pointer so a later
         allocation at the same address cannot be freed by a retry. */
      *target = NULL;
      terminal_pty_note_cleanup_abandoned();
      return 0;
   }
   *target = NULL;
   return 1;
}

static int terminal_pty_copy_ready
  (struct terminal_pty_windows_reader *reader,
   void *buffer,
   DWORD capacity,
   DWORD *bytes_read)
{
   DWORD available = reader->ready_length - reader->ready_offset;
   DWORD amount = available < capacity ? available : capacity;

   memcpy(buffer, reader->buffer + reader->ready_offset, amount);
   reader->ready_offset += amount;
   if (reader->ready_offset == reader->ready_length) {
      reader->ready_offset = 0;
      reader->ready_length = 0;
   }
   *bytes_read = amount;
   return 1;
}

/* Poll one overlapped read without waiting. Return 1 with bytes, 0 while no
   bytes are ready, 2 at end-of-file, and -1 on a permanent I/O failure. */
int terminal_pty_poll_windows_reader
  (void *context,
   void *buffer,
   DWORD capacity,
   DWORD *bytes_read,
   DWORD *error_code)
{
   struct terminal_pty_windows_reader *reader =
     (struct terminal_pty_windows_reader *) context;
   DWORD completed = 0;
   DWORD error;

   if (reader == NULL || buffer == NULL || capacity == 0
       || bytes_read == NULL || error_code == NULL) {
      if (error_code != NULL) {
         *error_code = ERROR_INVALID_PARAMETER;
      }
      return -1;
   }
   *bytes_read = 0;
   *error_code = ERROR_SUCCESS;

   if (reader->ready_length != 0) {
      return terminal_pty_copy_ready(reader, buffer, capacity, bytes_read);
   }
   if (reader->eof) {
      return 2;
   }

   if (reader->pending) {
      if (!GetOverlappedResult
            (reader->pipe, &reader->operation, &completed, FALSE)) {
         error = GetLastError();
         if (error == ERROR_IO_INCOMPLETE) {
            return 0;
         }
         reader->pending = 0;
         if (terminal_pty_pipe_closed(error)) {
            reader->eof = 1;
            return 2;
         }
         *error_code = error;
         return -1;
      }
      reader->pending = 0;
   } else {
      ResetEvent(reader->event);
      ZeroMemory(&reader->operation, sizeof reader->operation);
      reader->operation.hEvent = reader->event;
      if (!ReadFile
            (reader->pipe,
             reader->buffer,
             TERMINAL_PTY_READ_BUFFER_SIZE,
             &completed,
             &reader->operation)) {
         error = GetLastError();
         if (error == ERROR_IO_PENDING) {
            reader->pending = 1;
            return 0;
         }
         if (terminal_pty_pipe_closed(error)) {
            reader->eof = 1;
            return 2;
         }
         *error_code = error;
         return -1;
      }
   }

   if (completed == 0) {
      reader->eof = 1;
      return 2;
   }
   reader->ready_offset = 0;
   reader->ready_length = completed;
   return terminal_pty_copy_ready(reader, buffer, capacity, bytes_read);
}
