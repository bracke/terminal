#if defined(__linux__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE
#endif

#include "terminal_pty_posix_internal.h"

#include <stddef.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

/* Publish the master descriptor before returning to cancellable Ada code. */
int terminal_pty_open_master(int *master_fd, int flags)
{
   int result = posix_openpt(flags);
   *master_fd = result;
   return result < 0 ? -1 : 0;
}

/* Copy the slave path into caller-owned storage. ptsname may return shared
   storage and is therefore unsuitable when multiple sessions are created
   concurrently. */
int terminal_pty_slave_path_owned(int master_fd, char **target)
{
   size_t capacity = 128;

   *target = NULL;
   while (capacity <= 65536) {
      char *value = (char *) malloc(capacity);
      int result;
      int error;

      if (value == NULL) {
         return -1;
      }
      result = ptsname_r(master_fd, value, capacity);
      if (result == 0) {
         *target = value;
         return 0;
      }
      error = result > 0 ? result : errno;
      free(value);
      if (error != ERANGE) {
         errno = error;
         return -1;
      }
      capacity *= 2;
   }
   errno = ERANGE;
   return -1;
}

/* Consume the public marker before releasing the allocation so cancellation
   cannot leave Ada holding a pointer that has already been freed. */
void terminal_pty_free_string_owned(char **target)
{
   char *owned = *target;

   *target = NULL;
   free(owned);
}

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

/* Give a new PTY its first size. Linux takes it on the master; macOS
   refuses TIOCSWINSZ on a master whose slave was never opened, so open the
   slave (without making it a controlling terminal), size it there, and close
   it again. Returns 0 on success. */
int terminal_pty_set_initial_winsize (int master_fd, const char *slave_path,
                                      unsigned short rows,
                                      unsigned short cols)
{
   int slave;
   int result;
   int saved;

   if (terminal_pty_set_winsize (master_fd, rows, cols) == 0) {
      return 0;
   }
   slave = open (slave_path, O_RDWR | O_NOCTTY);
   if (slave < 0) {
      return -1;
   }
   result = terminal_pty_set_winsize (slave, rows, cols);
   saved = errno;
   close (slave);
   errno = saved;
   return result;
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

static int terminal_pty_set_close_on_exec (int fd)
{
   int flags = fcntl (fd, F_GETFD, 0);
   if (flags < 0) {
      return -1;
   }
   return fcntl (fd, F_SETFD, flags | FD_CLOEXEC);
}

/* Build a parent/child status channel whose write end closes automatically on
   a successful exec. Keep both descriptors above stderr so the child's dup2
   calls cannot overwrite the channel when the parent was started with a closed
   standard descriptor. */
int terminal_pty_create_spawn_pipe (int *read_fd, int *write_fd)
{
   int fds[2];
   int duplicate;

#if defined(__linux__)
   if (pipe2 (fds, O_CLOEXEC) < 0) {
      return -1;
   }
#else
   if (pipe (fds) < 0) {
      return -1;
   }
#endif
   if (fds[0] <= STDERR_FILENO) {
      duplicate = fcntl (fds[0], F_DUPFD_CLOEXEC, STDERR_FILENO + 1);
      if (duplicate < 0) {
         close (fds[0]);
         close (fds[1]);
         return -1;
      }
      close (fds[0]);
      fds[0] = duplicate;
   }
   if (fds[1] <= STDERR_FILENO) {
      duplicate = fcntl (fds[1], F_DUPFD_CLOEXEC, STDERR_FILENO + 1);
      if (duplicate < 0) {
         close (fds[0]);
         close (fds[1]);
         return -1;
      }
      close (fds[1]);
      fds[1] = duplicate;
   }
   if (terminal_pty_set_close_on_exec (fds[0]) < 0
       || terminal_pty_set_close_on_exec (fds[1]) < 0) {
      close (fds[0]);
      close (fds[1]);
      return -1;
   }
   *read_fd = fds[0];
   *write_fd = fds[1];
   return 0;
}

/* EOF means exec closed the status descriptor and therefore succeeded. A
   child-reported failure is a step byte then the low byte of its errno,
   returned as step + 256 * errno; -1 is a pipe failure. */
int terminal_pty_wait_for_child_exec (int fd)
{
   unsigned char report[2] = { 0U, 0U };
   size_t have = 0U;
   ssize_t count;

   while (have < sizeof report) {
      do {
         count = read (fd, report + have, sizeof report - have);
      } while (count < 0 && errno == EINTR);
      if (count <= 0) {
         break;
      }
      have += (size_t) count;
   }
   if (have == 0U) {
      return count == 0 ? 0 : -1;
   }
   return (int) report[0] + 256 * (int) report[1];
}

/* Only async-signal-safe operations are permitted between fork and exec in the
   multithreaded application. Report the failed step and errno best-effort,
   then terminate. */
void terminal_pty_child_spawn_failed (int fd, int code)
{
   unsigned char report[2];
   ssize_t count;

   report[0] = (unsigned char) code;
   report[1] = (unsigned char) errno;
   do {
      count = write (fd, report, sizeof report);
   } while (count < 0 && errno == EINTR);
   _exit (127);
}

/* Fork and complete the child-side PTY setup without ever returning through
   the Ada runtime in the child.  The target kernels implement the terminal
   ioctls below as allocation-free system calls; all other child operations are
   required async-signal-safe operations. */
int terminal_pty_spawn_child
  (int *child_pid,
   int master_fd,
   int spawn_read_fd,
   int spawn_write_fd,
   const char *slave_path,
   const char *path,
   char *const argv[],
   void *storage)
{
   pid_t result = fork();

   *child_pid = (int) result;
   if (result < 0) {
      return -1;
   }
   if (result > 0) {
      return 0;
   }

   /* Step codes: 1 setsid, 3 open slave, 4 controlling tty, 5 dup2;
      2 is exec (below). */
   close (spawn_read_fd);
   if (setsid () < 0) {
      terminal_pty_child_spawn_failed (spawn_write_fd, 1);
   }

   {
      int slave = terminal_pty_open_slave (slave_path);
      if (slave < 0) {
         terminal_pty_child_spawn_failed (spawn_write_fd, 3);
      }
      if (terminal_pty_set_controlling_tty (slave) != 0) {
         terminal_pty_child_spawn_failed (spawn_write_fd, 4);
      }
      if (dup2 (slave, STDIN_FILENO) < 0
          || dup2 (slave, STDOUT_FILENO) < 0
          || dup2 (slave, STDERR_FILENO) < 0) {
         terminal_pty_child_spawn_failed (spawn_write_fd, 5);
      }
      close (master_fd);
      if (slave > STDERR_FILENO) {
         close (slave);
      }
   }

   terminal_pty_exec_with_environment (path, argv, storage);
   terminal_pty_child_spawn_failed (spawn_write_fd, 2);
   return -1;
}
