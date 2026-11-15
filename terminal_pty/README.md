# terminal_pty

Platform PTY/session backend. On POSIX hosts, file descriptors, process IDs,
`ioctl`, open/fcntl flags, errno values, and other POSIX details do not leave
this crate; a thin C shim resolves host constants from system headers. On Windows builds,
the `TERMINAL_PTY_OS=windows` scenario selects the ConPTY backend. The public
capability snapshot reports the selected backend, resize, terminal environment,
and nonblocking read support through bounded status labels.

The POSIX backend validates nonblocking mode before spawning. An early C
constructor captures the process environment before Ada elaboration can
activate library tasks. Every child environment and the selected
`SHELL` derive from that immutable snapshot; later environment mutations are
intentionally not observed. Its leaf C spawn
helper keeps the complete fork-to-exec branch out of the Ada runtime and uses
only allocation-free descriptor/session setup in the child. A close-on-exec
status pipe distinguishes child setup and shell `exec` failures from a
successful spawn, so callers never activate a session whose shell did not
start. POSIX finalizers use bounded child termination; a child that does not
exit in that interval transfers to a process-wide quarantine retained by the
deferred-cleanup API, whose drain and shutdown operations are also bounded.
The shutdown barrier rejects later POSIX spawns with `Cleanup_Shutdown`.
The Windows backend likewise builds a sorted child-specific environment block
for `CreateProcessA`; it does not publish terminal variables into the parent
process. Its host output endpoint is an overlapped named pipe, so a read poll
never waits for ConPTY output. Teardown cancels that read context and closes the
host output endpoint before `ClosePseudoConsole`, avoiding the documented
final-frame shutdown deadlock on older Windows releases. If bounded finalizer
shutdown cannot confirm that a child exited, ownership of its process handle is
handed to a Windows worker for bounded termination and wait attempts before the
handle is closed. A child that still resists termination increments cleanup
diagnostics and emits a debugger message, then remains owned in a quarantine
after bounded exponential-backoff attempts. Reader contexts move with their
output pipe, and other resources that survive finalizer retries transfer to
typed cleanup jobs. Callers can inspect pending and quarantined owner counts and
explicitly drain accepted work. The application uses the shutdown barrier only
after session producers are closed; the barrier rejects later handoffs before
draining all previously accepted owners. If a handoff cannot allocate or is
rejected after shutdown, finalization consumes the retained native owner through
a bounded type-specific fallback instead of silently discarding it. Permanent
wait, close, or `LocalFree` failures are never retried against reusable native
values. Such terminal release failures increment a cumulative abandoned-owner
counter, so a drain cannot report complete merely because its queue is empty.
After cleanup shutdown, subsequent Windows spawn requests fail explicitly with
`Cleanup_Shutdown` rather than running without deferred-cleanup support.
Windows fault controls are compiled only for the `TERMINAL_PTY_BUILD=testing`
scenario used by CI; production binaries contain no mutable fault hooks. A
Windows test build must therefore use both
`-XTERMINAL_PTY_OS=windows -XTERMINAL_PTY_BUILD=testing`; the test C unit fails
at compile time if the testing scenario is omitted.
