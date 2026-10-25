# Architecture

## Crate Graph

`glfw_vulkan` depends on `df_vulkan` and system/Alire `libglfw3`.

`terminal_common` has no external dependencies.

`terminal_core` depends only on `terminal_common`.

`terminal_pty` depends only on `terminal_common`. Its selected POSIX backend
uses a thin local C shim so host headers resolve ioctl requests, open/fcntl
flags, and errno values; its Windows backend uses direct Ada ConPTY imports.

`terminal_glfw_vulkan_app` depends on `terminal_common`, `terminal_core`,
`terminal_pty`, `glfw_vulkan`, `textrender`, `df_vulkan`, `zlib`, `jpeglib`,
`giflib`, and `pictlib`.

## Dependency Rules

The terminal core has no GLFW, Vulkan, POSIX, Windows, file descriptor, window,
surface, or renderer types in its public API. It consumes byte arrays and
produces renderer-neutral snapshots.

`glfw_vulkan` is reusable for non-terminal Vulkan applications and contains no
terminal emulation, text rendering, or input semantics.

`terminal_pty` selects one backend with `TERMINAL_PTY_OS`: POSIX PTYs on Linux
and macOS, or ConPTY on Windows. Native handles, file descriptors, ioctl
values, and platform API types do not leak into common, core, or
renderer-facing interfaces.

The application uses the same scenario variable to select the body of
`Terminal.App.Platform_Media`. The POSIX body owns local-file, shared-memory,
safe-download, and dynamic-library primitives. The Windows body reports those
optional facilities unavailable without importing Unix symbols, so capability
profiles never advertise a backend that cannot execute there. This internal
package is the application layer's sole platform-media boundary and therefore
the only app package whose interface carries native descriptors and addresses.
The POSIX implementation likewise delegates host-varying file flags,
descriptor-path discovery (`/proc/self/fd` on Linux and `F_GETPATH` on macOS),
and dynamic-loader flags to a local C shim instead of embedding Linux constants
in Ada.

`Terminal.App.Vulkan_Context` owns the Vulkan instance and window surface. It
uses GLFW-provided instance extensions, `df_vulkan` handle types, and
`glfw_vulkan` surface creation. The renderer receives this context during
initialization and consumes only terminal render snapshots after that. Context
init outcomes expose bounded labels for startup/status UI. Context, presenter,
and logical-device objects are limited controlled resource owners, so exception
unwinding invokes their idempotent teardown even when the main loop does not
reach its explicit orderly-shutdown path.

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

`Terminal.App.Renderer` keeps one private state owner, but its implementation is
partitioned into Ada subunits by responsibility. Frame orchestration remains in
the parent body; protocol-event application, placement lifecycle, retained-image
emission, text shaping and glyph drawing, diagnostics, and teardown live in
named subunits. This preserves direct access to the renderer's invariants without
introducing another crate or exposing backend types, while keeping each state
transition independently reviewable.

Renderer command arrays and Vulkan submission arrays retain their capacity
between frames and grow geometrically when the grid requires more space. Image
commands borrow a bounded diagnostic-preview source rather than embedding a
4 KiB copy in every command; placeholder tiles for the same image therefore
share the decoded source. `Terminal.App.Frame_Image_Storage` is the frame-local
ownership boundary: it keeps image commands and their decoded, encoded, and
preview owners in synchronized slots, recognizes aliased owners, and releases
removed slots on truncation as well as full reset. This makes failed graphics
event rollbacks reclaim ownership instead of merely reducing a visible count.
`Frame_Commands` exposes command arrays through access-to-constant views. These
views borrow renderer and text-atlas storage and are valid only until the next
render, theme update, graphics-limit update, graphics-stream release, or
renderer finalization. Submission copies compact borrowed descriptors for the
synchronous upload path; every renderer frame reset invalidates those
descriptors before releasing or replacing their backing storage. The
renderer does not publish those borrowed views as a production query API.
White-box tests access them through `Terminal.App.Renderer.Testing`, whose spec
and body live only in the test project's source directory.

The presenter also exposes an opt-in validation-only framebuffer readback. If
the surface supports transfer-source swapchain images, enabling it allocates a
bounded host-visible transfer buffer, copies the resolved image after the render
pass, restores the presentation layout, waits on the submitted frame fence, and
returns format-normalized RGBA pixels. Normal application presentation leaves
this path disabled and allocates no readback resources.

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
the pen according to the HarfBuzz advance sign. Mixed-direction rows are
visually reordered at the text-run level before drawing. Emoji runs first try
`textrender` color glyph output, including layered COLR/CPAL glyphs and bitmap
PNG strikes decoded by the app, then fall back to shaped monochrome text when a
color glyph is unavailable. If every configured face shapes a run to `.notdef`,
the shaper rejects that as a shaped result. Complex runs remain explicitly
marked as `Needs_Shaping_Backend`; simple runs stay renderable through the
existing codepoint fallback path. Submit batches, presenter diagnostics, and
device upload diagnostics also carry aggregate shaped-glyph and color-glyph
counts so the shaped-text path remains observable across the whole render path.
Cells covered by a successfully shaped run are suppressed from the per-cell
fallback draw path for the full run span.
`Text_Run_Command.Cell_Width` is one terminal grid cell; `Cell_Span` carries the
number of covered cells. HarfBuzz scaling and renderer placement derive the full
run width from those two fields.
Renderer diagnostics distinguish shaped glyph count, backend-needed shaping
fallbacks, and text runs that used the renderer codepoint fallback.

Kitty Unicode placeholders are represented directly in each core `Cell` by
renderer-neutral image metadata. `U+10EEEE` remains in the text cluster for
terminal editing semantics, while its foreground color, underline color, and
official row/column combining diacritics are decoded into image ID, placement
ID, source row, and source column. Because the metadata is part of the cell, it
follows scrolling, scrollback, resize, insert/delete, erase, and alternate
screen operations. The text renderer never submits the placeholder itself as a
glyph. The app retains decoded `U=1` prototypes by image and placement ID and
resolves matching cells into one renderer-neutral image tile per visible cell.
Each tile carries UV coordinates derived from its placeholder row/column and
the placement's clamped source crop. The placement store is renderer-owned but
isolated by terminal stream. A nonzero placement ID is unique for its image
across that stream, as required by the protocol, while each placement also
carries its owning screen generation for visibility and lifetime. Reusing an
addressed image/placement pair on another screen therefore moves/replaces that
placement instead of creating a duplicate identity. Relative descendants move
with such a replacement so the parent group remains intact.
Conventional Kitty placements are retained separately from virtual prototypes.
They preserve their cursor-cell anchor, placement ID, crop, cell span, pixel
offset, and z-index after the APC event is consumed. Explicit transmit-only
commands, including the protocol default when `a` is omitted, install image
data without becoming visible, while `a=p` and `a=T` create persistent
placements. Conventional placements can be relative to another conventional
placement or to a virtual prototype. Parent references are validated before
mutation, cycles and chains deeper than 32 are rejected, signed cell offsets
are accumulated at render time, and a virtual parent's origin is the minimum
row and column of its matching visible placeholder cells. Parent deletion
cascades through descendants and releases an unplaced descendant's image data.
The core publishes a bounded, monotonically sequenced stream of full-screen and
margin scroll operations. Conventional anchors consume that stream before each
frame, move with their originating rows, and remain associated with the correct
scrollback offset. Falling behind retained scroll history causes a
generation-safe resynchronization rather than ambiguous movement.
Pure crop, aspect-ratio, cell-span, and pixel-offset calculation lives in
`Terminal.App.Image_Placements`; renderer-owned lists remain responsible only
for placement identity, lifetime, references, and screen association.
`Terminal.App.Image_Ingestion` owns protocol payload-boundary discovery,
encoded-source copies, iTerm2 unit/aspect-ratio resolution, local-medium query
loading, and bounded Kitty query validation. Local query data is decoded
directly from the loaded byte buffer; it is not expanded into a temporary
Base64 command first.
`Terminal.App.Image_Store` owns private object-list
linkage, replacement-aware object counts, allocation-backed byte/frame accounting,
storage/content serial allocation, object lookup and release, allocation
controls, install transaction state, and atomic ownership transfer for root and
indexed buffers. Renderer code can inspect image content through an object
handle and access-to-constant byte views, but cannot splice owned lists, mutate
or release store-owned content, or directly synchronize accounting. Frame,
theme-history, and image metadata are private and change only through checked
store operations. Accounting totals are cached from the actual owned buffers
and cached frame/theme-history totals, and therefore
remain constant-time for quota checks; replacement transactions retain an exact
pointer to the object being superseded. `Terminal.App.Image_Animation` owns
bounded playback timing, protocol-neutral control-state transitions, and loop
semantics, and builds decoded animation frames before transferring the complete
list to the store atomically. The renderer translates Kitty headers and result
codes at the protocol boundary; the animation engine does not depend on parser
or core response types.
`Terminal.App.Image_Colors` owns xterm/Kitty palette
resolution and indexed-pixel expansion. `Terminal.App.Image_Staging` decodes
encoded render commands into bounded row or RGBA byte sinks; Vulkan owns only
mapping or packing the destination and uploading it.
Native GIF and PICT decode transactions independently bound decoder workspace,
retained output, and the adapter canvas. Their combined transient peak is at
most three times the configured decoded-image quota.
Theme replay and indexed recoloring build private working buffers and publish
them through store replacement operations only after replay succeeds. A theme
switch snapshots every affected root and animation frame before changing the
active theme, then restores the complete set if any object cannot be rebuilt;
failed theme changes therefore cannot leave mixed-theme live image storage.
Before allocating, the transaction reserves its complete backup plus the exact
per-object replay working set against the configurable theme scratch limit.
That set contains two work canvases and one canvas for each distinct retained
operation target or source/base reference, rather than each operation or only
the current live frames. Deleted but replayable animation dependencies therefore
remain quota-accounted without penalizing long edit histories of the same
frames. Rollback consumes each
backup node exactly once and releases the unconsumed tail if restoration itself
raises. Callers receive an explicit update status for resource or replay
failures; invariant exceptions are not converted into silent theme failures.
Palette-sensitive animation edits append their replay operation provisionally
before publishing changed pixels or frames. The store transaction rolls that
append back if the subsequent mutation fails, so an allocation failure cannot
leave live image data and replay history out of sync.
Theme-history
archiving uses a heap-backed operation vector and a hashed frame dependency
set, making pruning linear in retained history rather than quadratic and
avoiding a maximum-sized stack allocation.
`Terminal.App.Image_Upload_Layout` computes and validates source, staging,
upload, and Vulkan row-pitch extents without Vulkan handles.
Renderer frame-capacity and pane-dimension products use the shared checked
operations in `Terminal.App.Size_Arithmetic`; overflow is reported as an
invalid snapshot before any frame allocation or coordinate calculation.
`Terminal.App.Vulkan_Retirement` independently classifies fence and deferred
cleanup outcomes. A destructor exception during live upload retirement is
therefore surfaced as a copy failure instead of being reported as success;
device loss remains the primary status when both conditions occur.
The graphics-event adapter, theme baseline/preparation/replay operations, and
the Vulkan creation, upload, readback, render, and staging transactions are Ada
subunits of their owning packages. Logical-device construction is divided into
named acquisition stages and every failed stage enters the controlled device's
single reverse-order finalization path. The renderer's single-pane/multi-pane
frame entry points and the main-loop runtime controller are likewise separated.
The main loop groups native owners in one runtime record, centralizes shutdown,
and keeps lifecycle, per-frame orchestration, and input-event dispatch in named
subunits. This preserves private-state boundaries while making each transition
independently navigable. Every
fallible placement allocation is completed
before a combined
Kitty transmission replaces an object. The prior object remains owned until its
new placement commits; a rejected placement rolls the new object back without
consuming image or placement quota.

Graphics protocol payloads are first consumed by `Terminal.Core`. Its limits
are configured from the app, up to compiled safety ceilings of 8 MiB per
transaction, 4096 queued events, and 16 MiB of queued payload. Kitty continuation
chunks are validated and assembled into one complete transaction in the core;
the app never owns partial protocol state. Complete transactions enter an
ordered FIFO. Consumers can copy a stable complete payload with
`Graphics_Event_Payload` or drain it incrementally with `Read_Graphics_Event`;
queue pressure preserves older events, drops the newest completed event, and
increments `Queue_Overflow`.
The app main loop peeks the oldest event for each visible session, renders that
event, and discards it only after a successful presentation; another frame is
scheduled while events remain. A separate app-layer consumer also advances one
event per non-visible session on each iteration. Its off-screen commit retains
atlas dirty state, routes replies through the event's owning PTY, and forces the
visible batch to be rebuilt before presentation. Thus queries, chunk barriers,
and deferred terminal input cannot stall merely because a tab is hidden.
`Render_Snapshot.Graphics` remains a 128 KiB
compatibility carrier between that FIFO and the existing renderer. Each runtime
assigns its core a stable nonzero graphics stream ID, and the core assigns every
queued event a monotonic nonzero sequence number. The renderer retains processed
`(stream ID, sequence)` guards until the presenter accepts the frame. A failed
render or stale swapchain can therefore retry the same event without repeating
image-number allocation, chunk assembly, replacement, placement, or deletion;
the guards are cleared at the same commit boundary where the core events are
discarded. The app
configures a renderer-backed Kitty capability profile on each core session.
Processed retained commands also keep a bounded protocol result alongside the
retry guard. Once presentation succeeds, the main loop gives that result to
the owning core before clearing the guard. The core verifies the stream and
sequence against its FIFO head, applies Kitty quiet mode, formats the response
with resolved image/image-number/placement identity, and atomically releases
the event. A stale completion therefore cannot acknowledge or discard another
session's command. Absolute placement commands that can move the cursor form
an input-ordering barrier: the core retains subsequent PTY bytes in a bounded
16 MiB buffer until the renderer reports the committed placement outcome. A
successful placement then advances the cursor by its cell span before those
bytes are parsed; a failed, `C=1`, virtual, or relative placement resumes input
without movement. The core carries the first chunk's movement policy through
`m=1` continuations while the final chunk supplies the placement anchor.
Each FIFO node captures its stream identity when it is enqueued; changing the
terminal's stream assignment cannot relabel already queued work.
The same stream ID is copied into renderer snapshots and forms part of every
Kitty image-object and placement key. Object lookup, image-number lookup,
relative-parent resolution, placeholder resolution, rendering, replacement,
and deletion therefore cannot cross PTY session boundaries even when two
applications choose identical image and placement IDs. Core chunk transactions
are likewise per stream, so sessions may interleave uploads without combining
payloads. Each transaction validates Kitty's encoded-chunk size, Base64
alignment, legal continuation fields, total-length limit, and cancellation
rules before enqueueing static-image or animation-frame work.
Graphics events and snapshots also carry a primary/alternate screen
generation. Entering the alternate buffer, clearing the full active screen,
or resetting the terminal advances the relevant generation. Renderer
placements are filtered by that identity, preserving primary-screen placements
while the alternate buffer is active and retiring placements when the
corresponding text screen is cleared without discarding reusable image objects.
The generation is not part of an explicit placement's protocol key.

Rectangle commands carry a renderer-neutral stacking class. Vulkan submission
draws base backgrounds first, Kitty images with z-index below
`INT32_MIN / 2`, explicit non-default cell backgrounds, remaining negative
images, foreground decorations and text, and finally non-negative images. This
keeps protocol ordering out of the Vulkan device layer while preserving the
special below-cell-background range.
The core handles direct `a=q` probes synchronously so their reply precedes later
input responses and the dummy query image never reaches the renderer. Local
file/shared-memory probes are validated through the renderer's security policy
without retaining objects. Direct RGB, RGBA, PNG, and zlib are reported only
when enabled. Regular-file, temporary-file, and POSIX shared-memory media are
independent capability bits; regular files are disabled by default. Unsupported
media, formats, and compression methods return protocol errors with quiet mode
applied.

`Terminal.App.Image_Decode` defines the single decode outcome vocabulary used
by protocol parsing, general media decoding, render commands, and diagnostics.
Compatibility constants in those packages name the canonical values; there is
no conversion table whose ordering can drift. Allocation exhaustion remains
distinct from malformed, oversized, and unsupported input throughout the
pipeline.

The app graphics layer parses Kitty and iTerm2 headers, performs strict bounded
Base64 and RFC 1950 decoding, rasterizes Sixel rows, expands PNG to RGBA with
the local zlib crate, decodes iTerm2 JPEG through the local jpeglib crate, and
decodes/composites iTerm2 GIF animations through the local giflib crate.
Direct-byte and Base64 transports feed the same
`Terminal.App.Zlib_Inflation` state machine, so output limits, trailing bytes,
termination, exact-length checks, and allocation failures have one status
mapping.
QuickDraw PICT input is rendered to bounded RGBA through the local pictlib
crate. The adapter borrows encoded bytes through the same checked cursor model
used for GIF input, renders into a pictlib-owned bounded buffer, and copies the
validated result into renderer-owned storage. This avoids unchecked access-type
conversion across crate boundaries. Classic Macintosh font IDs and family names
are mapped to discovered mono, sans-serif, serif, and symbol fonts, with
exact-family and semantic environment overrides for installed classic fonts.
Pictlib runs in compatible mode: drawing constructs it cannot reproduce exactly
yield bounded, deterministic output plus a retained warning. Pictlib failures and warnings
retain their stable identifier, source/opcode/row coordinates, expected and
actual values, limit kind, and underlying-code fields in renderer diagnostics.
`Terminal.App.Image_Rendering` owns decoder admission checks and the structured
media-diagnostic snapshot. An iTerm2 payload is offered to the full decoder
once; a rejected payload cannot fall through into the bounded preview decoder
or create a generic fallback image. Every iTerm2 command clears the previous
media snapshot before validation, including commands rejected before decode.
Media diagnostics separately expose explicit adapter buffer bytes and the
format-specific configured decoder storage limits. Container allocations and
font-library state are deliberately excluded from that buffer metric. Pictlib
enforces both a per-allocation limit and a monotonic aggregate admission quota
for every decode session; releasing or replacing a decoder buffer does not
replenish that quota.
The figures intentionally exclude allocator/runtime bookkeeping and GPU storage;
Policy-gated non-inline iTerm2 FILE transfers decode arbitrary file bytes into
an explicitly selected Downloads directory using no-follow, exclusive creation
and per-file quotas.
Kitty `f=100` accepts PNG only. Raw and compressed paths validate dimensions,
integer products, declared sizes, per-image byte limits, and decoded extent
before output allocation; PNG validates chunk bounds, CRCs, ordering, critical
chunks, IEND termination, and trailing data. PNG and Sixel decode through
bounded row sinks whose potentially large working rows are heap-backed and
automatically released.
Header parsing, Sixel decoding, Base64 decoding, zlib expansion, and the large
streaming PNG and raw-row state machines are separate Ada subunits of the
graphics package. The parent remains the public protocol/codec facade while the
individual parser and decoder invariants stay independently reviewable.
Regular/temp-file and shared-memory reads are isolated in
`Terminal.App.Graphics_Transport`, which enforces explicit policy, regular-file
type, offset/size bounds, sensitive-path rejection, temporary-name/directory
rules, and shared-memory unlink lifetime.

The renderer owns a unified bounded image-object store used by Kitty, Sixel,
and iTerm2. Kitty objects retain explicit IDs, non-unique image numbers,
animation frames, playback state, composition state, content versions, and
usage hints. Collision-free implicit IDs and placement IDs are allocated only
after validation. Placements borrow decoded pixels without frame-by-frame
copies; deletion and screen/session teardown release references deterministically.
Inline iTerm2 placements preserve their documented cursor policy: unless
`doNotMoveCursor=1` is present, later PTY input is held until decoding determines
the rendered cell height and then resumes at the first column below the image.
Animation actions support bounded direct/chunked frame decoding, frame edits,
replace and alpha composition, region composition, per-frame gaps, looping,
running/loading/stopped control, scheduling, and frame deletion.

Core and renderer limits are supplied from validated config values for
transaction bytes, queued events/bytes, deferred input, image objects, total
and per-image bytes, placements, animation frames, pixel dimensions, and GPU
atlas bytes/dimensions. Unplaced/transient objects are preferred eviction
candidates; if all retained objects are referenced, installation returns a
quota error rather than violating lifetime. Diagnostics expose both live
resource use and cumulative command, install, eviction, transport, decode,
allocation, placement, animation, and cancellation counters.

Complete bounded Kitty raw RGB/RGBA/PNG images, iTerm2 PNG/JPEG/GIF images, and
Sixel rasters become texture-backed image commands. Valid PNG bit depths,
transparency, and Adam7 interlace are expanded to RGBA. Native GIF frames are
composited to RGBA with their delays and loop policy retained; data outside
configured limits is rejected before full decoded-image allocation.
Image commands carry signed z-index values. Submission emits values below
`INT32_MIN / 2` beneath explicit cell backgrounds, other negative images below
text, and non-negative images above text, sorting each layer by ascending
z-index and then ascending image ID.
Submit batches deduplicate visible image sources by backing storage, pack every
distinct source into a bounded RGBA atlas with duplicated one-pixel edge
gutters, and remap each image quad's crop UVs to its atlas slot. The Vulkan
device fills and uploads that atlas to descriptor binding 1, so distinct image
objects and repeated placements coexist without a descriptor-layout change or
last-image texture aliasing. Atlas limits are configurable within compiled
safety ceilings. A deterministic signature includes each source's content
serial and geometry; an unchanged visible set reuses the resident image texture
without another upload. Replacement polls the per-frame fences and defers the
upload while shared resources remain in flight. Copies use a dedicated command
buffer and upload fence, so replaced GPU objects are destroyed only after their
last use without a queue-wide idle stall. Device loss propagates through the
renderer/presenter status path to a
main-loop recovery controller; CPU-side terminal and image state stays alive
while the logical device and all dependent Vulkan resources are reconstructed.
Failed reconstruction is retried with exponential backoff capped at 128 loop
ticks, so a transient driver failure neither closes the terminal nor causes a
busy loop.
The fragment shader samples either binding 0 (`text_atlas`) or binding 1
(`image_texture`) from the vertex texture id.

Resize handling stays in the app layer. The main loop converts framebuffer
pixels to terminal rows/columns, resizes the core and PTY when cell dimensions
change, and keeps terminal damage pending until a frame presents successfully.
Both the session runtime and core reject unchanged dimensions as a successful
no-op, avoiding redundant PTY resize calls. Changed core resizes preserve the
logical order and retained columns of the bounded scrollback ring, padding new
columns with blank cells. Input
grace frames reuse the last completed submission batch and its resident GPU
buffers when terminal state is unchanged, so compositor pacing neither rebuilds
snapshots and vertices nor remaps vertex memory or reuploads texture atlases.
Dirty frames refresh per-pane terminal snapshots in retained backing arrays;
steady-state rendering therefore copies current cells without allocating and
freeing cell, dirty-row, or scroll-journal arrays on every frame.
Text and colour-glyph atlases carry independent dirty state through submission.
The Vulkan backend keeps unchanged colour sheets resident, and atlas dirty bits
are cleared only after the frame containing them is accepted for presentation.
Per-frame throughput counters remain available in diagnostics but do not trigger
status logging by themselves. Image-preview propagation copies only the declared
valid prefix, avoiding repeated 4 KiB clears for short or absent previews.
Text-run construction classifies each cell's scalar direction and script through
a compact scalar API. It does not create and initialize full shaped-run records
for every coalescing candidate; full records are built only for emitted runs.
After shaping, the renderer builds a retained cell-to-run map once per pane.
Glyph emission uses constant-time map lookups instead of scanning every shaped
run twice for each drawable cell, keeping the pass linear in cells plus runs.
`Terminal.App.Placeholder_Index` retains renderer-wide hashed indexes for image
objects plus virtual and conventional placements across streams and screens.
Only successful object or placement topology mutations invalidate the index;
animation playback, composition, rejected commands, and other content-only
changes retain it. The renderer rebuilds a dirty index once before the next
retained-image pass rather than once per pane. A per-snapshot origin
epoch indexes placeholder anchors in one cell scan. Placeholder resolution,
object lookup, and every step of a relative-placement chain are then constant
time, so the pass remains linear in placements, objects, cells, and parent-chain
length rather than multiplying those dimensions.
Core snapshots count placeholder cells while copying their retained cell array.
Frames without placeholders therefore skip the renderer's additional image-cell
scan, while scrollback views refresh the count during their existing row copy.
Vulkan submission keeps a retained image-index array and sorts it once by
z-index, image ID, and source order. The three image layers then traverse that
order linearly instead of independently selection-sorting every image tile.
Frame-command capacities are computed with overflow-checked arithmetic from
the number of cells, retained placements, panes, and the maximum segmented
underline cost. Exhausting any command array fails the frame explicitly instead
of publishing a partially rendered frame.
If acquire or present reports a stale swapchain or device loss, the presenter is
finalized and reconstructed on the main thread with the current framebuffer
size. Reconstruction includes physical-device selection and every logical
device child resource. Failure leaves recovery pending rather than closing the
window. When a window is minimized and GLFW reports a zero-sized framebuffer,
the app skips reconstruction and presentation, keeps damage pending, and
retries once a nonzero framebuffer size returns.

Diagnostics remain app-owned. The core exposes counters and bounded labels for
initialization, feed outcomes, and diagnostic summaries without taking a
logging dependency; the app collects core, queue, renderer, and presenter
snapshots and writes compact stderr diagnostics only when status or counters
change. Runtime labels cross the collection boundary as one bounded
`Runtime_Statuses` record, and change detection retains one complete prior
snapshot instead of manually mirrored field storage. It compares the complete
renderer and core diagnostic snapshots, so adding one of those fields cannot
silently omit it from refresh decisions. The main loop retains the last core
feed outcome and PTY write outcome
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
bounded labels for status/help UI and diagnostics. `Terminal.App.Status_Labels`
centralizes enum-image humanization and truncation so Vulkan, font, resize,
scrollback, and shader labels use identical formatting. The same line reports
live
graphics objects/bytes/placements/frames, cumulative protocol and failure
counters, image texture uploads, and content-cache hits, so replacement and
resource pressure are observable without instrumenting the renderer. Media
decode errors and compatibility warnings are rendered as human-readable status
text while preserving their structured fields for programmatic inspection.

Mouse selection is also app-owned. `glfw_vulkan` exposes generic mouse events,
the main loop converts event coordinates to visible grid cells, and
`Terminal.App.Selection` extracts UTF-8 text from render snapshots and marks
selected cells with inverse style before rendering. OSC 52 target policy is
app-owned as well: `c` uses the GLFW system clipboard with a bounded app
mirror, while `p` and `s` use bounded app-owned target slots. The diagnostics line reports bounded input-mode
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
protected queue. When that queue is full, the producer blocks rather than
discarding terminal bytes; shutdown opens the entry and rejects the pending
push so teardown cannot deadlock. The POSIX parent master is nonblocking, so
the task can stop explicitly before the main thread closes the session. GLFW callbacks enqueue
compact input/window events. The main loop drains queues, feeds the core,
writes PTY input through a bounded write-all helper with status labels for
complete, incomplete, failed, and closed-session outcomes, retains an unwritten
suffix across iterations, handles resize, snapshots, and renders.

Input-event overflow is explicit: newest events are dropped, existing ordering
is preserved, and overflow counters are exposed. PTY output instead applies
lossless backpressure.

Tabs and split panes share one runtime table but are mutually exclusive layout
modes: creating a tab while split and splitting while multiple tabs exist are
rejected before a PTY is spawned. Split creation also rejects grids too small
to give every pane at least one cell; layout remains total for transient tiny
framebuffer sizes.

## Ownership

`Terminal.Core.Terminal` owns heap-backed primary and alternate screen buffers.
Snapshots are deep copies of visible cells plus cursor and dirty-row state.
Renderers must not retain references into mutable terminal storage.

## Platform Independence

The core models terminal behavior only: UTF-8 decoding, parser state, screen
buffers, modes, cursor, styles, damage, and diagnostics. Platform I/O and
rendering are adapters around that deterministic state machine.
