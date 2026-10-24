# terminal_pty

Platform PTY/session backend. On POSIX hosts, file descriptors, process IDs,
`ioctl`, open/fcntl flags, errno values, and other POSIX details do not leave
this crate; a thin C shim resolves host constants from system headers. On Windows builds,
the `TERMINAL_PTY_OS=windows` scenario selects the ConPTY backend. The public
capability snapshot reports the selected backend, resize, terminal environment,
and nonblocking read support through bounded status labels.
