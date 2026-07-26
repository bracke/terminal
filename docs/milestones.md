# Milestones

## M1 Visible Shell

- Open a GLFW Vulkan window through `glfw_vulkan`.
- Create a Vulkan instance and a window surface through the shim-backed
  `glfw_vulkan` surface API.
- Initialize `textrender`, build terminal frame commands, and prepare
  Vulkan-style vertex batches.
- Select a Vulkan physical device and graphics/present queue family for the
  GLFW surface.
- Create a `VK_KHR_swapchain` logical device for that queue family.
- Create the initial swapchain from the selected surface format, present mode,
  image count, and framebuffer extent.
- Retrieve swapchain images and create 2D color image views.
- Create a simple color render pass and one framebuffer per swapchain image.
- Create command buffers and per-frame semaphore/fence resources.
- Create shader modules, a pipeline layout, and a shader-backed color graphics
  pipeline from the checked-in GLSL/SPIR-V assets.
- Upload packed rectangle/glyph vertices into a host-visible Vulkan vertex
  buffer.
- Record command buffers, submit frames, and present through the swapchain while
  preserving the batch submission API.
- Upload and sample the `textrender` glyph atlas through a descriptor-backed
  Vulkan image.
- Detect stale swapchains during acquire/present and recreate the presenter from
  the main loop without clearing terminal damage.
- Keep damage pending and skip swapchain recreation/presentation while the
  framebuffer is zero-sized, as happens when the window is minimized.
- Spawn `$SHELL` in a Linux PTY.
- Validate PTY output can be fed into `Terminal.Core` in a non-GUI integration
  smoke and converted into renderer glyph vertices plus atlas metadata.
- Validate real GLFW/Vulkan presentation in `gui_present_smoke` when a display
  and Vulkan device are available; the smoke skips cleanly in headless runs.
- Validate real shell `echo`, `cat`, `ls --color`, SGR color, and
  clear-sequence behavior through a non-GUI PTY/core command smoke.
- Validate broader program progression through a non-GUI PTY/core smoke:
  deterministic `git status --short` output plus installed `less`, `nano`,
  `vim`, and `top` command output markers.
- Cover app-owned key, character, cursor-mode, control-key, Alt-key, and
  bracketed-paste byte mappings with a non-GUI smoke test.
- Cover app-owned visible-grid mouse selection, render highlighting, and UTF-8
  clipboard text extraction with a non-GUI smoke test.
- Cover app-owned xterm mouse reporting byte mappings for button, release, and
  drag events with a non-GUI smoke test.
- Cover app-owned xterm focus reporting mode and focus-in/focus-out byte
  mappings with non-GUI smoke tests.
- Preserve input byte ordering across partial PTY writes with a bounded
  write-all helper used by the main loop and integration smoke.
- Cover bounded PTY/input queue ordering, drop-newest overflow, and diagnostic
  counters with a non-GUI smoke test.
- Cover framebuffer-to-cell resize conversion and minimized-framebuffer
  clamping with a non-GUI smoke test.
- Cover POSIX PTY `TIOCSWINSZ` propagation with a non-GUI smoke test that
  resizes an active shell and verifies `stty size`.
- Cover POSIX PTY close behavior with a non-GUI smoke test that verifies the
  spawned child is no longer alive after `Close`.
- Show the shell prompt.
- Send printable keyboard input and Enter to the PTY.
- Validate `echo`, `cat`, `ls --color`, and `clear`; record the interactive
  GUI result in `docs/m1_runtime_validation.md`.
- Propagate row/column resize to the core and PTY via `TIOCSWINSZ`.
- Close the window cleanly.

## Program Progression

1. `echo`, `cat`, `ls --color`
2. Shell prompt and line editing
3. `clear`
4. `git status` - covered non-interactively through PTY/core smoke
5. `less` - covered as installed command output through PTY/core smoke
6. `nano` - covered as installed command output through PTY/core smoke
7. `vim` - covered as installed command output through PTY/core smoke
8. `top` - covered as installed command output through PTY/core smoke
9. Later: `htop`, `tig`, `lazygit`
10. Much later: `tmux`, `screen`

## Postponed

Sixel, kitty graphics, iTerm2 images, richer OSC 8 hover/tooltip UI,
platform-native primary/selection clipboards, full color emoji rendering,
paragraph BiDi, advanced mouse/selection behavior, tabs, splits, themes, config,
Windows ConPTY, and terminal multiplexer behavior.
