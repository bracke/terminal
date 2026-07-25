# Ada Terminal Workspace

Initial Linux-first Ada 2022 terminal emulator workspace.

Crates:

- `glfw_vulkan`: reusable GLFW window/event/surface helper crate for Vulkan apps.
- `terminal_common`: platform-neutral byte and status types.
- `terminal_core`: deterministic byte-oriented terminal emulator core.
- `terminal_pty_posix`: Linux POSIX PTY/session backend.
- `terminal_glfw_vulkan_app`: GLFW/Vulkan terminal application wiring crate.

The app currently creates a GLFW window, creates a `df_vulkan` Vulkan instance
with GLFW-required extensions, creates a Vulkan window surface, spawns the POSIX
PTY, and runs the queue-driven main loop. The text renderer remains the adapter
point for the existing Vulkan text-rendering layer.

Build examples:

```sh
cd terminal_common && alr build
cd ../terminal_core && alr build
cd ../terminal_pty_posix && alr build
cd ../glfw_vulkan && alr build
cd ../terminal_glfw_vulkan_app && alr build
```

Core smoke tests:

```sh
cd terminal_core
alr update
alr exec -- gprbuild -P tests/core_tests.gpr
tests/bin/core_smoke
tests/bin/core_sgr_smoke
tests/bin/core_modes_smoke
tests/bin/core_osc_smoke
tests/bin/core_utf8_smoke
tests/bin/core_alternate_smoke
tests/bin/core_scrollback_smoke
```

PTY status smoke test:

```sh
cd terminal_pty_posix
alr update
alr exec -- gprbuild -P tests/pty_tests.gpr
tests/bin/pty_status_smoke
```
