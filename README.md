# Ada Terminal

Linux-first Ada 2022 terminal emulator.

The repository root is the Alire application crate:

```sh
alr build
./bin/terminal
```

Crates:

- `glfw_vulkan`: reusable GLFW window/event/surface helper crate for Vulkan apps.
- `terminal_common`: platform-neutral byte and status types.
- `terminal_core`: deterministic byte-oriented terminal emulator core.
- `terminal_pty_posix`: Linux POSIX PTY/session backend.
- `terminal_glfw_vulkan_app`: GLFW/Vulkan terminal application wiring crate.

The app currently creates a GLFW window, creates a `df_vulkan` Vulkan instance
with GLFW-required extensions, creates a Vulkan window surface, spawns the POSIX
PTY, runs the queue-driven main loop, and initializes the local `textrender`
glyph rasterizer/atlas layer. `Ctrl+Shift+V` and `Super+V` paste the GLFW
clipboard into the PTY, using bracketed paste mode when the terminal core says
it is enabled. Runtime visible-shell validation remains.

Build individual crates:

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
tests/bin/pty_resize_smoke
tests/bin/pty_close_smoke
```

App smoke tests:

```sh
cd terminal_glfw_vulkan_app
alr exec -- gprbuild -P tests/app_tests.gpr
tests/bin/vulkan_submit_smoke
tests/bin/vulkan_presenter_smoke
tests/bin/vulkan_device_smoke
tests/bin/shader_loader_smoke
tests/bin/pty_core_integration_smoke
tests/bin/input_map_smoke
tests/bin/queue_smoke
tests/bin/resize_smoke
```
