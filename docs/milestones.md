# Milestones

## M1 Visible Shell

- Open a GLFW Vulkan window through `glfw_vulkan`.
- Create a Vulkan instance and a window surface through the shim-backed
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
  Vulkan image.
- Detect stale swapchains during acquire/present and recreate the presenter from
  the main loop without clearing terminal damage.
- Keep damage pending and skip swapchain recreation/presentation while the
  framebuffer is zero-sized, as happens when the window is minimized.
- Spawn `$SHELL` in a Linux PTY.
- Validate child PTY terminal identity with `TERM=xterm-256color` and
  `COLORTERM=truecolor`.
- Expose POSIX PTY backend capabilities, including explicit unsupported
  Windows ConPTY status for this backend.
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
  and Vulkan device are available; the smoke skips cleanly in headless runs,
  and Vulkan context/shader/submit/device/presenter status labels are covered
  in non-GUI smoke.
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
  write-all helper and bounded write outcome labels used by the main loop and
  integration smoke.
- Cover bounded PTY/input queue ordering, drop-newest overflow, diagnostic
  counters, and bounded queue pressure labels with a non-GUI smoke test.
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

Complete payload decoding and textured rendering for sixel, kitty graphics, and
iTerm2 images, in-content OSC 8 tooltips/previews, platform-native
primary/selection clipboards, full color emoji rendering, paragraph BiDi,
additional advanced mouse behavior,
multi-session tab rendering, split-pane rendering, Windows ConPTY, and full
terminal multiplexer behavior. Built-in theme selection is available through startup
config and `ADA_TERMINAL_THEME`, and startup config can set a bounded scrollback
limit, wheel-scroll lines, window size, and startup fallback grid, with a
stable effective-config image plus bounded config/theme status labels for
diagnostics and bounded config line-status labels; OSC 8 hover state now underlines
supported
links, switches to a hand cursor, and exposes the target URI in the window
title plus bounded open/unsupported and activation outcome status labels;
activation outcomes are retained in the refreshed title/status surface;
`Alt+Left` drag supports
rectangular selection; `Shift+Left` can force a
local selection while terminal mouse reporting is enabled, and selection state
exposes active/range/mode/anchor/focus snapshots for future mouse UI routing;
selection and mouse routing expose bounded status labels; mouse wheel reporting
now includes horizontal wheel packets;
the clipboard module
exposes that the normal clipboard is native while primary/selection targets are
app-local, with bounded status labels for each OSC 52 target and a bounded
terminal profile status label; the POSIX PTY backend now reports Windows ConPTY as an explicit
unsupported capability with bounded backend and ConPTY status labels; bounded tab state and
app-owned tab shortcuts are in place, with tab count reflected in the window title and bounded per-tab labels
available for future tab UI, including active-label updates from OSC terminal
titles plus tab-strip layout, hit-testing, activate-by-column, and
close-by-column behavior, with active layout flags and public tab snapshots for
future rendering plus display-ready tab label fitting and bounded tab model
status labels;
bounded split state and app-owned
split shortcuts are in place, with pane count reflected in the window title and
deterministic pane rectangles
plus pane hit-testing, activate-by-cell, and close-by-cell behavior available
from the split model, with active layout flags and public split snapshots for
future rendering plus display-ready pane label fitting and bounded split model
status labels; sixel,
kitty graphics, and iTerm2 image payloads are explicitly
recognized and safely ignored with aggregate, per-protocol, and last-protocol
diagnostics plus last-payload length and bounded ignored-payload status labels
that include byte counts; core snapshots expose the last graphics event with
protocol, cursor cell, payload length, and a 128 KiB bounded payload preview; and the
app graphics layer parses bounded kitty/iTerm2 header previews, including
explicit cell-span/size metadata, for placeholder sizing, splits bounded data
previews, counts encoded preview bytes, and decodes capped Base64 byte previews
for kitty/iTerm2 data with runtime data-preview status labels and short hex
preview-byte fingerprints plus decoded/partial markers with bounded
partial-decode reasons; the renderer accumulates bounded kitty `m=1`
raw or PNG continuation chunks as app-owned encoded segments beyond the core
preview cap until the final chunk arrives, decodes raw `f=24`/`f=32` chunks
directly across those segments, decodes chunked kitty PNG Base64 directly
across those segments into an exact upper-bound PNG byte staging buffer for the
current PNG decoder API, sizes raw kitty, PNG, and sixel decoded output buffers
to the actual decoded byte count, and keeps a heap-backed kitty `i=` image
object table by transferring decoded `i=` payloads into the store, supports later
placement-only commands without per-frame pixel copies plus kitty delete
actions, and retains per-image upload caps;
renderer plus Vulkan
submit now carry protocol-tinted image placeholder quads for all three
protocols, with image commands retaining total payload length and bounded
encoded/decoded preview metadata, payload-completeness markers that distinguish
complete bounded payloads from preview-only samples, plus 1 MiB capped decoded
upload data and 4 KiB decoded diagnostics preview bytes; complete bounded kitty raw RGB/RGBA payloads with explicit pixel
dimensions, bounded kitty `f=100` PNG payloads, bounded sixel rasters, and
bounded iTerm2 PNG payloads decoded with the local zlib crate now become real
texture-backed image quads through submit, presenter, the Vulkan device,
descriptor binding 1, and a shader image sampler, with PNG grayscale, RGB,
indexed, grayscale-alpha, and RGBA images covered across valid bit depths,
simple transparency, 16-bit downconversion, and Adam7 interlace, while JPEG
remains placeholder-rendered plus renderer
diagnostics and submit batches exposing bounded
last-image metadata/status labels, with renderer diagnostics, submit batches,
and presenter plus Vulkan device diagnostics retaining exact RGB upload staging
bytes while decoded RGBA upload uses the source buffer directly, plus the decoded preview byte
buffer plus the image metadata, computed placeholder dimensions, and image
vertex counts that reached their boundaries plus the last image texture source
and texture-backed image vertex counts, and exposing bounded image status labels
with size markers, image vertex-count markers at presenter/device boundaries,
texture-source markers, placeholder/textured markers, explicit downgrade markers
when texture-requested commands are forced through the placeholder path,
reserved submit texture-source labels, a shader-facing image texture id for the
raw kitty upload path, compact image texture readiness labels for
unavailable/downgraded/ready states with texture-backed vertex counts,
and a Vulkan device image texture resource-status label that reports inactive,
pending, and descriptor-ready image texture resources through device and presenter helpers,
including descriptor bound/capacity counts with runtime refresh tracking,
bounded-label coverage, and an app-level image texture pipeline status that
summarizes renderer, presenter, device, texture-vertex, and descriptor readiness
in the runtime diagnostics line while reporting whether image payload data is
complete or preview-only,
decode-status reasons, and short hex
preview-byte fingerprints that are included in runtime diagnostics; emoji
runs expose color-emoji fallback diagnostics and app capabilities report
monochrome fallback plus bounded status labels until color glyph rendering is
implemented; tmux DCS
passthrough unwraps escaped inner sequences through the existing parser and
reports a multiplexer diagnostic plus bounded profile and diagnostic-count
status labels emitted by runtime diagnostics;
mixed-direction
rows expose paragraph-BiDi fallback diagnostics plus bounded status labels until
full reordering is implemented.
