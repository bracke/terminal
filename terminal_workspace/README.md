# Ada Terminal Workspace

Initial Linux-first Ada 2022 terminal emulator workspace.

For normal app builds, use the repository-root Alire crate:

```sh
cd ..
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
glyph rasterizer/atlas layer. The app renderer now builds Vulkan-style batches
and hands them to a narrow presenter boundary that selects a graphics/present
queue candidate, creates a `VK_KHR_swapchain` logical device, and creates the
initial swapchain image views, render pass, framebuffers, command buffers, and
per-frame sync objects, plus a shader-backed color graphics pipeline;
accepted frame batches are packed into a host-visible Vulkan vertex buffer.
The presenter records a render pass, binds the graphics pipeline and vertex
buffer, uploads the `textrender` R8 glyph atlas into a sampled Vulkan image,
submits the frame, and presents through the swapchain. Runtime visible-shell
validation remains; a 1x1 fallback atlas keeps descriptor state valid before
the real glyph atlas is uploaded. Stale swapchains from resize/out-of-date
acquire or present results are detected and cause presenter recreation on the
main thread. Startup failures and changed runtime diagnostics are written to
stderr with explicit status/counter values.

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

`pty_core_integration_smoke` is non-GUI: it spawns the shell through the POSIX
PTY backend, feeds output into `Terminal.Core`, then renders the resulting
snapshot through the headless renderer path and checks glyph vertices plus atlas
metadata.

`input_map_smoke` checks the app-owned key/character/paste byte mappings,
including control keys, UTF-8 character input, cursor-key mode differences, and
bracketed paste.

`queue_smoke` checks bounded PTY and input queue ordering, drop-newest overflow
behavior, and overflow counters.

`resize_smoke` checks framebuffer-to-cell conversion, minimum cell clamping, and
zero-sized/minimized framebuffer handling without opening a window.
