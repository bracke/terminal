/* Small POSIX wrappers for errno classification, descriptor ownership, and
   child-process observation. Platform headers provide the native constants. */

#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int terminal_pty_error_is_interrupted (void)
{
   return errno == EINTR;
}

int terminal_pty_error_is_would_block (void)
{
   return errno == EAGAIN || errno == EWOULDBLOCK;
}

int terminal_pty_error_is_io (void)
{
   return errno == EIO;
}

int terminal_pty_path_is_executable (const char *path)
{
   return access (path, X_OK) == 0;
}

int terminal_pty_wait_nohang (pid_t pid, int *status)
{
   int result;
   do {
      result = (int) waitpid (pid, status, WNOHANG);
   } while (result < 0 && errno == EINTR);
   return result;
}

/* A nonzero wait result means this owner can no longer reap PID.  Clear the
   marker before returning to cancellable Ada code so cleanup cannot target a
   recycled process identifier. */
int terminal_pty_wait_nohang_owned (int *pid, int *status)
{
   int result = terminal_pty_wait_nohang ((pid_t) *pid, status);
   if (result != 0) {
      *pid = -1;
   }
   return result;
}

int terminal_pty_close_owned (int *fd)
{
   int owned = *fd;

   /* Disarm before close: POSIX permits an interrupted close to leave the
      descriptor state unspecified, so retrying can close a descriptor already
      reused by another task.  Linux consumes the descriptor on every result;
      on macOS the safe at-most-once policy may trade an indeterminate close for
      a leak, but never for corruption of an unrelated descriptor. */
   *fd = -1;
   return owned >= 0 ? close (owned) : 0;
}

int terminal_pty_hangup_process_group (pid_t pid)
{
   return kill (-pid, SIGHUP);
}

int terminal_pty_kill_process_group (pid_t pid)
{
   int result = kill (-pid, SIGKILL);
   if (result < 0) {
      /* A child can move itself out of the process group created for the PTY.
         Still terminate the direct child so close cannot block indefinitely on
         a live process after the bounded SIGHUP grace period. */
      result = kill (pid, SIGKILL);
   }
   return result;
}

/* Present one platform-neutral child status: a normal exit code is
   nonnegative, while signal termination is the negated signal number. */
int terminal_pty_normalize_wait_status (int status)
{
   if (WIFEXITED (status)) {
      return WEXITSTATUS (status);
   }
   if (WIFSIGNALED (status)) {
      return -WTERMSIG (status);
   }
   return 0;
}
