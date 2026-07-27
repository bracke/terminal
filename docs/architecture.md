# Architecture

## Crate Graph

`glfw_vulkan` depends on `df_vulkan` and system/Alire `libglfw3`.

`terminal_common` has no external dependencies.

`terminal_core` depends only on `terminal_common`.

`terminal_pty_posix` depends only on `terminal_common` and local POSIX/C
bindings.

`terminal_glfw_vulkan_app` depends on `terminal_common`, `terminal_core`,
`terminal_pty_posix`, `glfw_vulkan`, `textrender`, and `df_vulkan`.

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
initialization and consumes only terminal render snapshots after that. Context
init outcomes expose bounded labels for startup/status UI.

The app render pipeline is staged:

1. `Terminal.Core.Render_Snapshot` is copied out of the terminal core.
2. `Terminal.App.Renderer` loads `textrender`, rasterizes glyphs, and builds
   renderer-neutral `Terminal.App.Render_Model.Frame_Commands`. The frame
   contains fallback glyph quads plus bounded text-run commands prepared for
   the app-layer HarfBuzz shaping backend.
3. `Terminal.App.Vulkan_Submit` converts frame commands into normalized
   rectangle/glyph/image-placeholder triangle vertices, carries text-run
   commands by value, and carries text-atlas upload metadata. Build outcomes
   expose bounded labels for diagnostics.
4. `Terminal.App.Vulkan_Presenter` owns the presentation boundary. It currently
   selects a physical device with a queue family that supports graphics and the
   GLFW surface, creates a logical device with `VK_KHR_swapchain`, creates the
   initial swapchain, image views, render pass, framebuffers, command buffers,
   per-frame sync objects, and a shader-backed color graphics pipeline using
   shader bytecode load outcomes with bounded labels,
   validates accepted batches, uploads packed vertices into a host-visible
   Vulkan vertex buffer, uploads the `textrender` R8 glyph atlas into a sampled
   Vulkan image, records a render pass, submits, presents through the swapchain,
   detects stale swapchains, and records presentation diagnostics.

The Vulkan device creates a descriptor-backed 1x1 fallback atlas during
initialization so the shader sampler binding is always valid. Dirty
`textrender` atlas batches replace that image through a bounded staging upload.

The visible Vulkan draw path renders glyph quads generated from `textrender`.
`Terminal.App.Text_Shaper` classifies each text run and uses a HarfBuzz-backed
app-layer shaping adapter against the selected font file. Text-run commands are
carried through renderer, submit, presenter, and device diagnostics without
moving terminal parsing or terminal state into the renderer.
Each `Text_Run_Command` carries the run kind, shape status, direction, script,
raw codepoints, and a bounded shaped-glyph output buffer. The renderer
coalesces compatible adjacent cells in a row up to the text-run codepoint
bound, while splitting at style changes, inferred script/direction changes,
wide/cluster cells, cursor-inverted cells, and other boundaries that would make
fallback rendering ambiguous. The HarfBuzz adapter sets direction, script, and
stable script-derived language tags, then returns real font glyph IDs, source
clusters, advances, offsets, and the selected shaping font index for simple
text, ligature candidates, combining clusters, emoji ZWJ clusters, RTL runs,
and complex-script runs when a configured font face can shape the run without
`.notdef` glyphs. Font discovery order is exposed through bounded discovery
status labels. The terminal renderer draws successful shaped runs through
`textrender`'s glyph-index rasterization API, using the primary/fallback
font-index order and placing RTL runs from the run's right edge and LTR runs
from the left edge. RTL placement uses the full coalesced run width and steps
the pen according to the HarfBuzz advance sign. If every configured face
shapes a run to `.notdef`, the shaper rejects that as a shaped result. Complex
runs remain explicitly marked as `Needs_Shaping_Backend`; simple runs stay
renderable through the existing codepoint fallback path. Submit batches,
presenter diagnostics, and device upload diagnostics also carry aggregate
shaped-glyph counts so the shaped-text path remains observable across the whole
render path.
Cells covered by a successfully shaped run are suppressed from the per-cell
fallback draw path for the full run span.
`Text_Run_Command.Cell_Width` is one terminal grid cell; `Cell_Span` carries the
number of covered cells. HarfBuzz scaling and renderer placement derive the full
run width from those two fields.
Renderer diagnostics distinguish shaped glyph count, backend-needed shaping
fallbacks, and text runs that used the renderer codepoint fallback.

Graphics protocol payloads are first consumed by `Terminal.Core` as bounded
events with a 128 KiB inline graphics preview cap. The app graphics layer parses
kitty/iTerm2 headers, decodes bounded kitty base64 payloads, rasterizes bounded
sixel payloads to RGBA pixels, and decodes bounded kitty `f=100` plus iTerm2
PNG payloads with the local zlib crate. The renderer accumulates bounded kitty
`m=1` raw or PNG continuation chunks as app-owned encoded segments beyond the
core preview cap, decodes raw `f=24`/`f=32` kitty chunks directly across those
segments, and decodes chunked kitty PNG Base64 directly across those segments
into an exact upper-bound PNG byte staging buffer used by the current PNG
decoder API. Complete decoded pixel data is stored separately from the shorter
diagnostics preview, with raw kitty, PNG, and sixel decoded output buffers
sized to the actual decoded byte count instead of the maximum cap. It also
keeps a
heap-backed kitty image object table keyed by `i=` so later placement-only
kitty commands can reuse already decoded pixel data without resending the
payload. Initial `i=` transmissions transfer the decoded buffer into that table
instead of duplicating pixels, placements borrow stored pixels without copying
them into each frame, kitty delete actions release individual IDs or the whole
table, and individual image payloads still use the app decode/upload caps.
Complete bounded kitty raw RGB/RGBA payloads with explicit pixel
dimensions, supported kitty/iTerm2 PNGs, and bounded sixel rasters become
texture-backed image commands; valid bounded PNG bit depths, transparency, and
Adam7 interlace are expanded to RGBA, while JPEG remains placeholder-rendered
with decode diagnostics, and payloads beyond the cap remain preview-only.
Submit batches mark textured image vertices with the image texture source, the
Vulkan device uploads an RGBA image to descriptor binding 1, using decoded RGBA
buffers directly and only allocating exact RGBA staging when raw RGB input needs
alpha expansion; the fragment shader samples either binding 0 (`text_atlas`) or
binding 1 (`image_texture`) from the vertex texture id.

Resize handling stays in the app layer. The main loop converts framebuffer
pixels to terminal rows/columns, resizes the core and PTY when cell dimensions
change, and keeps terminal damage pending until a frame presents successfully.
If acquire or present reports a stale swapchain, the presenter is finalized and
reinitialized on the main thread with the current framebuffer size. When a
window is minimized and GLFW reports a zero-sized framebuffer, the app skips
swapchain recreation and presentation, keeps damage pending, and retries once a
nonzero framebuffer size returns.

Diagnostics remain app-owned. The core exposes counters and bounded labels for
initialization, feed outcomes, and diagnostic summaries without taking a
logging dependency; the app collects core, queue, renderer, and presenter
snapshots and writes compact stderr diagnostics only when status or counters
change. The main loop retains the last core feed outcome and PTY write outcome
for those diagnostics. The composed runtime diagnostic line is exposed as a
testable helper so status UI/logging formatting stays deterministic. Queue
snapshots include bounded occupancy/overflow labels for PTY output and app
input pressure, and the current framebuffer-to-grid label is included with the
same diagnostics surface. Runtime diagnostics also carry the redraw-policy
label that explains synchronized-update deferral or local redraw bypasses, plus
local scrollback, selection, hyperlink, clipboard, tab, split, config, and
profile labels. Cursor and SGR text blink status labels are collected from the
render snapshot before diagnostics are emitted. The runtime line also includes
the active theme label and startup font-discovery label, so appearance/fallback
state is visible without parsing config files or renderer internals. PTY backend,
ConPTY capability, and terminal multiplexer capability labels are retained at
startup and emitted with the same diagnostics.
Renderer diagnostics include the last frame-build
status so visible window failures distinguish initialization, invalid snapshot,
allocation, glyph, and batch-conversion problems. Vulkan device selection,
logical-device creation, device rendering, and presenter statuses expose
bounded labels for status/help UI and diagnostics.

Mouse selection is also app-owned. `glfw_vulkan` exposes generic mouse events,
the main loop converts event coordinates to visible grid cells, and
`Terminal.App.Selection` extracts UTF-8 text from render snapshots and marks
selected cells with inverse style before rendering. OSC 52 target policy is
app-owned as well: `c` uses the GLFW system clipboard, while `p` and `s` use
bounded app-owned target slots. The diagnostics line reports bounded input-mode
and mouse-routing labels from the same mapper used to encode keyboard, paste,
focus, and mouse events. The core does not know about selection or platform
clipboard ownership.

`textrender` is used directly rather than through the existing toolkit layer,
because that layer currently pulls in a GLFW/OpenGL binding outside this
terminal's locked Vulkan-only dependency rules.

The app Vulkan presenter follows the high-quality color-target policy used by
the Guikit/Files Vulkan backend: it prefers the highest supported framebuffer
color sample count from 8x, 4x, and 2x, falls back to 1x, and resolves an MSAA
color attachment into the swapchain when multisampling is available.

## Threading Model

GLFW and Vulkan run on the main thread. Terminal state is mutated only on the
main thread.

A background Ada task reads PTY bytes and pushes bounded chunks into a
protected queue. The POSIX parent master is nonblocking, so the task can stop
explicitly before the main thread closes the session. GLFW callbacks enqueue
compact input/window events. The main loop drains queues, feeds the core,
writes PTY input through a bounded write-all helper with status labels for
complete, incomplete, failed, and closed-session outcomes, handles resize,
snapshots, and renders.

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
