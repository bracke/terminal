#ifndef TERMINAL_PTY_POSIX_INTERNAL_H
#define TERMINAL_PTY_POSIX_INTERNAL_H

int terminal_pty_exec_with_environment
  (const char *path, char *const argv[], void *storage);

#endif
