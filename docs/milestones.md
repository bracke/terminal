# Milestones

## M1 Visible Shell

- Open a GLFW Vulkan window through `glfw_vulkan`.
- Create a Vulkan instance and a window surface through the direct Ada
  `glfwCreateWindowSurface` binding in the
  `glfw_vulkan` surface API, with bounded context init status labels.
- Initialize `textrender`, build terminal frame commands, and prepare
  Vulkan-style vertex batches, with bounded submit-build status labels.
- Select a Vulkan physical device and graphics/present queue family for the
  GLFW surface.
- Create a `VK_KHR_swapchain` logical device for that queue family.
- Create the initial swapchain from the selected surface format, present mode,
  image count, and framebuffer extent.
- Retrieve swapchain images and create 2D color image views.
- Create a simple color render pass and one framebuffer per swapchain image.
- Create command buffers and per-frame semaphore/fence resources.
- Create shader modules, a pipeline layout, and a shader-backed color graphics
  pipeline from the checked-in GLSL/SPIR-V assets, with bounded shader-load
  status labels.
- Upload packed rectangle/glyph vertices into a host-visible Vulkan vertex
  buffer.
- Record command buffers, submit frames, and present through the swapchain while
  preserving the batch submission API.
- Upload and sample the `textrender` glyph atlas through a descriptor-backed
  Vulkan image. Text, inline-image, and colour-glyph textures use one bounded,
  format-parameterized staging/copy/fence pipeline with slot-specific commits.
- Detect stale swapchains during acquire/present and recreate the presenter from
  the main loop without clearing terminal damage.
- Keep damage pending and skip swapchain recreation/presentation while the
  framebuffer is zero-sized, as happens when the window is minimized.
- Spawn `$SHELL` in a Linux PTY.
- Validate child PTY terminal identity with `TERM=xterm-256color` and
  `COLORTERM=truecolor`.
- Expose selected PTY backend capabilities: the POSIX build reports ConPTY as
  unavailable, while the Windows build reports and exercises ConPTY support.
- Expose the app terminal profile used for xterm-compatible multiplexer-facing
  behavior.
- Tie the app terminal profile smoke to real bracketed paste, focus, mouse,
  synchronized-update, OSC 52 target capabilities, OSC 8, and truecolor
  behavior.
- Expose render-policy status labels for synchronized-update deferral and
  app-owned local redraw bypasses.
- Cover app-owned cursor blink phases and bounded cursor status labels with a
  non-GUI smoke test.
- Cover app-owned SGR text blink phases and bounded text blink status labels
  with a non-GUI smoke test.
- Cover font discovery fallback bounds and bounded font discovery status labels
  with a non-GUI smoke test.
- Cover text shaping backend and shape outcome status labels with a non-GUI
  smoke test.
- Validate PTY output can be fed into `Terminal.Core` in a non-GUI integration
  smoke and converted into renderer glyph vertices plus atlas metadata.
- Validate real GLFW/Vulkan presentation in `gui_present_smoke` when a display
  and Vulkan device are available. Local headless runs may skip; Linux CI sets
  `TERMINAL_REQUIRE_GUI_PRESENT=1` under Xvfb so a missing presentation path is
  fatal. Vulkan context/shader/submit/device/presenter status labels are
  covered in non-GUI smoke.
- Validate real shell `echo`, `cat`, `ls --color`, SGR color, and
  clear-sequence behavior through a non-GUI PTY/core command smoke.
- Validate broader program progression through a non-GUI PTY/core smoke:
  deterministic `git status --short` output plus installed `less`, `nano`,
  `vim`, and `top` command output markers.
- Cover app-owned key, character, cursor-mode, control-key, Alt-key,
  bracketed-paste byte mappings, key-mode/paste/keyboard status labels, and
  combined input-mode status labels with a non-GUI smoke test.
- Cover app-owned visible-grid mouse selection, render highlighting, and UTF-8
  clipboard text extraction with a non-GUI smoke test.
- Cover app-owned xterm mouse reporting byte mappings for button, release, and
  drag events with a non-GUI smoke test.
- Cover app-owned xterm focus reporting mode, focus-in/focus-out byte
  mappings, and focus status labels with non-GUI smoke tests.
- Preserve input byte ordering across partial PTY writes with a bounded
  write-all helper, runtime-owned retry suffix, and bounded write outcome labels
  used by the main loop and integration smoke.
- Cover bounded PTY/input queue ordering, lossless PTY backpressure and
  shutdown, input-event drop-newest overflow, diagnostic counters, and bounded
  queue pressure labels with a non-GUI smoke test.
- Cover core initialization/feed outcome labels and aggregate diagnostic
  status labels with a non-GUI core smoke test.
- Compose retained feed/write outcomes, core, queue, geometry, redraw-policy,
  scrollback, selection, hyperlink, clipboard, tabs, splits, config/profile,
  input-mode, mouse-routing, cursor blink, text blink, theme, fonts, graphics,
  PTY backend, ConPTY capability, multiplexer capability/diagnostics, renderer,
  graphics header, graphics data preview, and presenter status labels into a
  tested runtime diagnostics line.
- Cover app-owned scrollback view offsets, clamping, and bounded scrollback
  status labels with a non-GUI smoke test.
- Cover framebuffer-to-cell resize conversion, minimized-framebuffer clamping,
  and bounded resize/grid status labels with a non-GUI smoke test.
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
- Keep failed session teardown owned in a visible `Cleanup_Pending` state;
  restart, table removal, and finalization must not silently overwrite it.
- Roll back provisional image installation and theme-history appends through
  controlled Ada guards unless the mutation is explicitly committed.

## Program Progression

1. `echo`, `cat`, `ls --color`
2. Shell prompt and line editing
3. `clear`
4. `git status` - covered non-interactively through PTY/core smoke
5. `less` - covered as installed command output through PTY/core smoke
6. `nano` - covered as installed command output through PTY/core smoke
7. `vim` - covered as installed command output through PTY/core smoke
8. `top` - covered as installed command output through PTY/core smoke
9. `htop`, `tig`, `lazygit` - covered when installed through PTY/core smoke
10. `tmux`, `screen` - covered when installed through PTY/core smoke

## Postponed

Platform-native primary/selection clipboards beyond GLFW's portable clipboard
API. The normal OSC 52 `c` target uses GLFW's native clipboard and is mirrored
into the bounded app target store; OSC 52 `p` and `s` targets remain app-local
because GLFW exposes no portable primary/selection clipboard API.

## Recent Additions

Completed in the current milestone set: startup config/theme selection, OSC 8
hover and activation status, rectangular and shifted local selection, extended
mouse reporting including UTF-8/SGR/urxvt coordinate encodings, tab and split
runtime tables with independent terminal/PTY sessions, kitty/iTerm2/sixel image
handling with PNG/JPEG decode and Vulkan texture upload, color emoji glyph
rendering with fallback diagnostics, tmux DCS passthrough, renderer-level mixed
direction row reordering, and the Windows-selected ConPTY backend.
