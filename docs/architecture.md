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
initialization and consumes only terminal render snapshots after that.

The app render pipeline is staged:

1. `Terminal.Core.Render_Snapshot` is copied out of the terminal core.
2. `Terminal.App.Renderer` loads `textrender`, rasterizes glyphs, and builds
   renderer-neutral `Terminal.App.Render_Model.Frame_Commands`. The frame
   contains the current fallback glyph quads plus bounded text-run commands
   that preserve complete cell clusters for a later shaping backend.
3. `Terminal.App.Vulkan_Submit` converts frame commands into normalized
   rectangle/glyph triangle vertices, carries text-run commands by value, and
   carries text-atlas upload metadata.
4. `Terminal.App.Vulkan_Presenter` owns the presentation boundary. It currently
   selects a physical device with a queue family that supports graphics and the
   GLFW surface, creates a logical device with `VK_KHR_swapchain`, creates the
   initial swapchain, image views, render pass, framebuffers, command buffers,
   per-frame sync objects, and a shader-backed color graphics pipeline,
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
fallback rendering ambiguous. The HarfBuzz adapter returns real font glyph IDs,
source clusters, advances, offsets, and the selected shaping font index for
simple text, ligature candidates, combining clusters, emoji ZWJ clusters, RTL
runs, and complex-script runs when a configured font face can shape the run
without `.notdef` glyphs. The terminal renderer draws successful shaped runs
through `textrender`'s glyph-index rasterization API, using the same primary and
fallback font-index order and placing RTL runs from the run's right edge and
LTR runs from the left edge. If HarfBuzz cannot load or shape a run, the run
remains explicitly marked as `Needs_Shaping_Backend` and is represented by the
existing codepoint fallback path. Submit batches, presenter diagnostics, and
device upload diagnostics also carry aggregate shaped-glyph counts so the
shaped-text path remains observable across the whole render path.

Resize handling stays in the app layer. The main loop converts framebuffer
pixels to terminal rows/columns, resizes the core and PTY when cell dimensions
change, and keeps terminal damage pending until a frame presents successfully.
If acquire or present reports a stale swapchain, the presenter is finalized and
reinitialized on the main thread with the current framebuffer size. When a
window is minimized and GLFW reports a zero-sized framebuffer, the app skips
swapchain recreation and presentation, keeps damage pending, and retries once a
nonzero framebuffer size returns.

Diagnostics remain app-owned. The core exposes counters without taking a
logging dependency; the app collects core, queue, renderer, and presenter
snapshots and writes compact stderr diagnostics only when status or counters
change. Renderer diagnostics include the last frame-build status so visible
window failures distinguish initialization, invalid snapshot, allocation,
glyph, and batch-conversion problems.

Mouse selection is also app-owned. `glfw_vulkan` exposes generic mouse events,
the main loop converts event coordinates to visible grid cells, and
`Terminal.App.Selection` extracts UTF-8 text from render snapshots and marks
selected cells with inverse style before rendering. The core does not know
about selection or clipboards.

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
writes PTY input through a bounded write-all helper, handles resize, snapshots,
and renders.

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
