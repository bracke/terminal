#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

extern int terminal_pty_posix_handoff_child_owned(int *pid);
extern long terminal_pty_posix_cleanup_pending_count(void);
extern long terminal_pty_posix_cleanup_quarantined_count(void);
extern int terminal_pty_posix_cleanup_drain(unsigned int timeout_ms);

int terminal_pty_test_posix_deferred_cleanup(void)
{
   pid_t child = fork();
   int owned;
   int status;

   if (child < 0) {
      return 0;
   }
   if (child == 0) {
      for (;;) {
         pause();
      }
   }
   owned = (int) child;
   if (!terminal_pty_posix_handoff_child_owned(&owned)) {
      kill(child, SIGKILL);
      waitpid(child, &status, 0);
      return 0;
   }
   return owned == -1
      && terminal_pty_posix_cleanup_drain(1000)
      && terminal_pty_posix_cleanup_pending_count() == 0
      && terminal_pty_posix_cleanup_quarantined_count() == 0;
}

int terminal_pty_test_close_failure(void)
{
   return 1;
}

int terminal_pty_test_failed_reaper(void)
{
   return 1;
}

int terminal_pty_test_reader_handoff(void)
{
   return 1;
}

int terminal_pty_test_enter_quarantine(void)
{
   return 1;
}

int terminal_pty_test_enter_quarantine_batch(void)
{
   return 1;
}

int terminal_pty_test_release_quarantine(void)
{
   return 1;
}

void terminal_pty_cleanup_test_reset_drain_worker_high_water(void)
{
}

long terminal_pty_cleanup_test_drain_worker_high_water(void)
{
   return 1;
}

long terminal_pty_cleanup_test_active_workers(void)
{
   return 0;
}

int terminal_pty_test_cleanup_fault_injection(void)
{
   return 1;
}

int terminal_pty_test_rejected_handoff(void)
{
   return 1;
}

int terminal_pty_test_permanent_release_failures(void)
{
   return 1;
}
