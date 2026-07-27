# terminal_pty_posix

Linux-only POSIX PTY/session backend. File descriptors, process IDs, `ioctl`,
and other POSIX details do not leave this crate. The public capability snapshot
reports POSIX PTY, resize, terminal environment, and nonblocking read support;
Windows ConPTY is explicitly reported as unsupported by this backend.
