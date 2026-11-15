#ifndef TERMINAL_PTY_WINDOWS_INTERNAL_H
#define TERMINAL_PTY_WINDOWS_INTERNAL_H

#include <windows.h>

void *terminal_pty_build_windows_environment
  (const char *term,
   const char *color_term,
   const char *term_program,
   const char *term_program_version,
   const char *term_features);
int terminal_pty_build_windows_environment_owned
  (void **target,
   const char *term,
   const char *color_term,
   const char *term_program,
   const char *term_program_version,
   const char *term_features);
void terminal_pty_free_windows_environment(void *environment);
void terminal_pty_free_windows_environment_owned(void **target);

int terminal_pty_create_overlapped_output_pipe
  (HANDLE *read_handle, HANDLE *write_handle);
void *terminal_pty_create_windows_reader(HANDLE pipe);
int terminal_pty_create_windows_reader_owned(HANDLE pipe, void **target);
enum terminal_pty_reader_cleanup_result {
   TERMINAL_PTY_READER_ABANDONED = -1,
   TERMINAL_PTY_READER_RETRY = 0,
   TERMINAL_PTY_READER_COMPLETE = 1
};
enum terminal_pty_reader_cleanup_result
terminal_pty_free_windows_reader(void *context);
int terminal_pty_free_windows_reader_owned(void **target);
int terminal_pty_abandon_windows_reader_owned
  (void **target, HANDLE *pipe);
int terminal_pty_allocate_attribute_list(void **target, SIZE_T bytes);
int terminal_pty_free_attribute_list_owned
  (void **target, int initialized, int *still_initialized);
int terminal_pty_close_handle_owned(HANDLE *target);
void terminal_pty_close_pseudo_console_owned(HPCON *target);
int terminal_pty_poll_windows_reader
  (void *context,
   void *buffer,
   DWORD capacity,
   DWORD *bytes_read,
   DWORD *error_code);

void terminal_pty_note_cleanup_failure(void);
void terminal_pty_note_cleanup_abandoned(void);
LONG terminal_pty_cleanup_failure_count(void);
LONG terminal_pty_cleanup_pending_count(void);
LONG terminal_pty_cleanup_quarantined_count(void);
LONG terminal_pty_cleanup_abandoned_count(void);
int terminal_pty_cleanup_is_accepting(void);
int terminal_pty_handoff_process_owned(HANDLE *target);
int terminal_pty_handoff_reader_owned(void **target, HANDLE *pipe);
int terminal_pty_cleanup_drain(DWORD timeout_ms);
void terminal_pty_cleanup_stop_accepting(void);
int terminal_pty_cleanup_drain_closed(DWORD timeout_ms);
int terminal_pty_cleanup_shutdown(DWORD timeout_ms);
#ifdef TERMINAL_PTY_TESTING
void terminal_pty_cleanup_test_fail_allocations(LONG count);
void terminal_pty_cleanup_test_fail_queue_submissions(LONG count);
void terminal_pty_cleanup_test_fail_waits(LONG count);
void terminal_pty_cleanup_test_fail_local_frees(LONG count);
int terminal_pty_cleanup_test_take_wait_failure(void);
int terminal_pty_cleanup_test_take_local_free_failure(void);
void terminal_pty_cleanup_test_reset_drain_worker_high_water(void);
LONG terminal_pty_cleanup_test_drain_worker_high_water(void);
LONG terminal_pty_cleanup_test_active_workers(void);
#endif

#endif
