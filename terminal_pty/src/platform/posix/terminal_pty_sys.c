/* Thin C shims over POSIX facilities whose Ada bindings would otherwise have to
   hardcode per-platform magic that differs across Linux and macOS/BSD:

     - the ioctl request numbers TIOCSWINSZ / TIOCSCTTY (e.g. 0x5414 on Linux
       but 0x80087467 on Darwin)
     - open/fcntl flags and errno values, which also differ across hosts

   Letting the C headers resolve these keeps the PTY layer correct on every
   POSIX host without the Ada side guessing numbers it cannot verify. */

#include <stddef.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

/* Set the window size on the tty behind FD. Returns 0 on success. */
int terminal_pty_set_winsize (int fd, unsigned short rows,
                                    unsigned short cols)
{
   struct winsize ws;
   ws.ws_row = rows;
   ws.ws_col = cols;
   ws.ws_xpixel = 0;
   ws.ws_ypixel = 0;
   return ioctl (fd, TIOCSWINSZ, &ws);
}

/* Make FD the controlling terminal of the calling (session-leader) process.
   Returns 0 on success. */
int terminal_pty_set_controlling_tty (int fd)
{
   return ioctl (fd, TIOCSCTTY, (void *) NULL);
}

int terminal_pty_open_flags (void)
{
   return O_RDWR | O_NOCTTY;
}

int terminal_pty_open_slave (const char *path)
{
   return open (path, O_RDWR);
}

int terminal_pty_set_nonblocking (int fd)
{
   int flags = fcntl (fd, F_GETFL, 0);
   if (flags < 0) {
      return -1;
   }
   return fcntl (fd, F_SETFL, flags | O_NONBLOCK);
}

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
   return (int) waitpid (pid, status, WNOHANG);
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

int terminal_pty_wait (pid_t pid, int *status)
{
   int result;
   do {
      result = (int) waitpid (pid, status, 0);
   } while (result < 0 && errno == EINTR);
   return result;
}
