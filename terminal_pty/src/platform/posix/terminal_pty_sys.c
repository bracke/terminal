/* Thin C shims over POSIX facilities whose Ada bindings would otherwise have to
   hardcode per-platform magic that differs across Linux and macOS/BSD:

     - errno's accessor symbol (__errno_location on glibc, __error on macOS)
     - the ioctl request numbers TIOCSWINSZ / TIOCSCTTY (e.g. 0x5414 on Linux
       but 0x80087467 on Darwin)

   Letting the C headers resolve these keeps the PTY layer correct on every
   POSIX host without the Ada side guessing numbers it cannot verify. */

#include <errno.h>
#include <stddef.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

int terminal_pty_last_errno (void)
{
   return errno;
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

/* Make FD the controlling terminal of the calling (session-leader) process.
   Returns 0 on success. */
int terminal_pty_set_controlling_tty (int fd)
{
   return ioctl (fd, TIOCSCTTY, (void *) NULL);
}
