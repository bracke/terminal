/* Portable read of the current thread's errno.

   The Ada side used to import the glibc accessor "__errno_location" directly,
   which does not exist on macOS/BSD (they expose "__error"). The <errno.h>
   errno macro resolves to the correct per-platform thread-local, so a tiny C
   shim keeps the PTY layer building on every POSIX host. */

#include <errno.h>

int terminal_pty_posix_last_errno (void)
{
   return errno;
}
