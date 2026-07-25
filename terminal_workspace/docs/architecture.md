# Architecture

## Crate Graph

`glfw_vulkan` depends on `df_vulkan` and system/Alire `libglfw3`.

`terminal_common` has no external dependencies.

`terminal_core` depends only on `terminal_common`.

`terminal_pty_posix` depends only on `terminal_common` and local POSIX/C
bindings.

`terminal_glfw_vulkan_app` depends on `terminal_common`, `terminal_core`,
`terminal_pty_posix`, `glfw_vulkan`, and `df_vulkan`.

## Dependency Rules

The terminal core has no GLFW, Vulkan, POSIX, Windows, file descriptor, window,
surface, or renderer types in its public API. It consumes byte arrays and
produces renderer-neutral snapshots.

`glfw_vulkan` is reusable for non-terminal Vulkan applications and contains no
terminal emulation, text rendering, or input semantics.

`terminal_pty_posix` owns Linux PTY/session details. POSIX types do not leak
into common or core packages.

`Terminal.App.Vulkan_Context` owns the Vulkan instance and window surface. It
uses GLFW-provided instance extensions, `df_vulkan` handle types, and
`glfw_vulkan` surface creation. The renderer receives this context during
initialization and consumes only terminal render snapshots after that.

## Threading Model

GLFW and Vulkan run on the main thread. Terminal state is mutated only on the
main thread.

A background Ada task reads PTY bytes and pushes bounded chunks into a
protected queue. The POSIX parent master is nonblocking, so the task can stop
explicitly before the main thread closes the session. GLFW callbacks enqueue
compact input/window events. The main loop drains queues, feeds the core,
writes PTY input, handles resize, snapshots, and renders.

Queue overflow is explicit: newest items are dropped, existing ordering is
preserved, and overflow counters are exposed.

## Ownership

`Terminal.Core.Terminal` owns heap-backed primary and alternate screen buffers.
Snapshots are deep copies of visible cells plus cursor and dirty-row state.
Renderers must not retain references into mutable terminal storage.

## Platform Independence

The core models terminal behavior only: UTF-8 decoding, parser state, screen
buffers, modes, cursor, styles, damage, and diagnostics. Platform I/O and
rendering are adapters around that deterministic state machine.
