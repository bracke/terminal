# terminal_glfw_vulkan_app

Application crate that wires `terminal_core`, the platform-selected
`terminal_pty` backend, `glfw_vulkan`, and the Vulkan text-rendering adaptation
point together. `TERMINAL_PTY_OS=windows` selects ConPTY; the default selects
the POSIX backend used on Linux and macOS.

This crate links against system HarfBuzz (`libharfbuzz.so`) for shaped text-run
metadata. The current visible glyph path still uses `textrender` rasterization.

The renderer package is deliberately an adapter boundary: it consumes
`Terminal.Core.Render_Snapshot` plus complete staged graphics events and never
mutates terminal state. Protocol framing and encoded-source allocation are
delegated to `Terminal.App.Image_Ingestion`, which also performs bounded Kitty
query validation. `Terminal.App.Graphics` owns protocol adaptation and the
controlled preview value. `Media_Decoders` and `Decoding` form the public
format-decoder boundaries; the private `Transport_Decoders` child implements
the transport details. Their codec implementations live in dedicated subunits,
so the protocol parent does not repeat or forward decoder profiles.
The application loop reaches that owner through focused
`Renderer.Graphics`, `Renderer.Layout`, and `Renderer.Presentation` child
interfaces. Heap-backed snapshots, decoded media, and graphics previews are
limited controlled values, so their buffers cannot be shallow-copied and are
released automatically; explicit move and release operations remain available
where ownership changes before scope exit.
Snapshot storage is consumed through value-returning indexed accessors, and
decoded media exposes bounded byte reads and explicit frame copies rather than
exporting pointers into controlled objects. Complete graphics-event staging
reports allocation failure to the frame/session loop before decoding begins;
stale events and payload-length mismatches are reported separately and never
fall back to the bounded preview.

`Terminal.App.Graphics_Profile` is the single runtime source for core protocol
capability replies, renderer transfer-media access, and iTerm2 download
admission. Requested media are intersected with the selected platform backend
before sessions receive the profile.

Graphics helpers keep protocol-independent responsibilities out of the main
renderer body. `Terminal.App.Image_Decode` supplies the canonical decode status
type, `Terminal.App.Image_Ingestion` owns payload boundaries, encoded-source
copies, and iTerm2 size resolution, while `Terminal.App.Image_Store` owns
private image-object linkage, content
release, replacement-aware object counts, allocation-backed frame/byte accounting,
serial allocation, atomic root/indexed-buffer ownership transfer, controlled
rollback guards, and per-operation allocation controls (including index-update
failure injection without persistent test state in each store);
its `Frames` child directly owns frame-list construction, traversal, conversion,
mutation, and rollback, while `Themes` isolates replay transactions.
Store bytes are exposed through controlled `Data_Borrow` values that pin their
image object until explicit release or scope finalization; raw root/indexed
accessors are private to the store, animation and theme data are array
parameters scoped to a visitor call, and mutation cannot invalidate an active
visit.
`Terminal.App.Owned_Image_Data` gives emitters a controlled single-owner guard
with allocation, move, bounded element operations, and scoped callbacks. Raw
adoption/extraction needed by legacy codec and store representations is isolated
in `Terminal.App.Owned_Image_Data.Unsafe`; normal callers cannot accidentally
select it through the owner API. `Terminal.App.Renderer.Image_Buffers` centralizes decoded row
assembly and bounded previews, and
`Terminal.App.Renderer.Frame_Commands` centralizes frame ownership and overflow;
the private `Terminal.App.Image_Placements` child resolves crop and cell
geometry and owns placement lifetime, while the private
`Terminal.App.Placeholder_Index` child owns derived lookup state;
`Terminal.App.Image_Rendering` owns media admission and bounded
structured decoder diagnostics. `Terminal.App.Image_Colors` owns xterm/Kitty
palette expansion, while `Terminal.App.Image_Staging` converts encoded render
commands into renderer-neutral row and RGBA byte sinks, keeping protocol decode
logic out of the Vulkan resource manager. Store totals are cached from actual
owned allocations; synchronization and allocation release are private store
operations. `Terminal.App.Image_Upload_Layout` validates overflow-safe source,
staging, and Vulkan row-pitch extents independently of Vulkan handles.
Transactional replacements name the exact prior object, and
`Terminal.App.Image_Animation` owns bounded playback timing,
protocol-neutral control state transitions, and loop semantics; the renderer
maps Kitty wire fields and response codes at its boundary. Image commands contain copy-safe
borrowed byte views. The
renderer delegates command/owner synchronization, alias-safe release, and
rollback truncation to the private `Terminal.App.Frame_Image_Storage`; its
move-only controlled store-borrow tokens survive capacity growth without being
copied, and every frame reset
also invalidates Vulkan submission descriptors before their borrowed storage
can be replaced. Store-owned bytes enter commands through frame storage's
object-and-frame selection API, which resolves the internal view while acquiring
an opaque frame-borrow token; deletion is deferred
until the final pin is released and in-place replacement rejects a live pin.
Theme changes reserve their complete backup and
worst-case replay working set against a configurable scratch quota and return
an explicit update status. GIF and PICT decoding independently bound
decoder workspace, retained result, and adapter canvas to a documented
combined peak of three times the configured decoded-image quota.
The media facade's decoded-byte limit is itself constrained to the shared hard
image-byte ceiling; format adapters cannot be configured above it.
The private `Terminal.App.Zlib_Inflation` child is the single bounded inflater
used by direct and Base64 graphics transports, with filter and output lifetime
owned by controlled values. PNG chunk semantics, streaming IDAT inflation,
pixel conversion, and byte-order/filter/pass arithmetic are isolated in the
`Graphics.PNG_Chunks`, `Graphics.PNG_Inflation`, `Graphics.PNG_Pixels`, and
`Graphics.PNG_Support` components.
Graphics diagnostic labels are isolated in `Graphics.Status_Reporting`, so
formatting does not add dependencies to the decode and transport paths.
Kitty control indexing, syntax, ranges, and typed-header construction are
isolated in `Graphics.Kitty_Validation`; the outer parser handles framing only.
The private `Terminal.App.JPEG_Decoder`, `Terminal.App.GIF_Adapter`, and
`Terminal.App.PICT_Adapter` packages isolate codec-specific ownership,
borrowed-stream, and diagnostic translation from the shared graphics and media
facades. GIF and PICT share a validated private borrowed-stream bridge and
diagnostic identifier initializer, while
JPEG uses the same cursor and independently bounds output, metadata, and
decoder workspace. Its workspace is capped by the shared hard image-byte
ceiling; codec output is copied through explicit byte conversion,
without unchecked access conversion between the codec and renderer array
types. GIF frame acceptance follows the configured animation-frame quota up to
the shared hard limit rather than imposing a smaller codec-specific ceiling.
The large graphics-event adapter, PNG row-filter/Adam7 coordinator, animation
frame/composition transactions, theme history/replay operations, and Vulkan staging
resource transaction are separate Ada subunits. This keeps the primary
graphics, renderer, and device bodies navigable while preserving private-state
access and crate boundaries. The single-pane/multi-pane renderer entry points
and the main-loop runtime controller are subunits for the same reason; backend
polling and framebuffer resize are separate frame phases. Text, inline-image,
and colour-glyph textures use the same parameterized Vulkan staging pipeline.
Frame reset, capacity growth, release, and immutable frame
view publication are likewise isolated as renderer subunits; image command
ownership remains centralized in the private `Terminal.App.Frame_Image_Storage` through an
atomic command-and-buffer append API.

Session runtimes and the runtime table are controlled owners. Cleanup failures
remain visible as `Cleanup_Pending`, prevent restart or deallocation from
overwriting live resources, and are reported by finalization rather than being
silently converted to a closed state. Runtime diagnostic labels are grouped in
one bounded `Runtime_Statuses` value at the collection boundary.
The runtime table also owns the tab and split models, committing their active
indices together with session activation so the main loop cannot maintain a
second, divergent layout state.

`Terminal.App.Workspace` persists a bounded, versioned tab/pane description,
active session, labels, OSC 7 working directories, and per-session startup
commands. Restore reconstructs sessions before the first frame and submits
quoted directory changes plus explicitly configured/saved commands through the
normal bounded PTY writer. The notification path similarly remains bounded:
the core produces BEL, OSC 9/99, and OSC 133 completion requests, while the app
applies independent policy switches before the POSIX launcher invokes
`notify-send`. Link activation also recognizes plain `http`, `https`, `mailto`,
and absolute-path tokens; `Ctrl+Shift+O` exposes deterministic keyboard
selection without sending navigation keys to the PTY.

`Terminal.App.Command_Palette` keeps a bounded searchable index of app actions
and configured session profiles. `Terminal.App.Session_Profiles` validates
bounded shell, command, CWD, environment, built-in theme, and SSH fields and
constructs shell-quoted launch input. A chosen profile creates a normal runtime
table entry, so cleanup, graphics identity, workspace capture, and PTY
backpressure behavior remain shared with ordinary tabs.

OSC 133 prompt/command markers are retained in a 128-entry core ring using
monotonic history-row coordinates. The scrollback adapter maps those marks to
previous/next offsets, including bounded-history clamping. Render snapshots
carry retained-row totals and offsets; the renderer derives a proportional
track/thumb without introducing a second scroll-position state.

Application chrome routes tab-bar, pane-border, and scrollbar pointer input
before terminal mouse reporting. Tabs support activation, close, and runtime-
preserving drag reorder; split weights change through draggable dividers. The
bounded `Ctrl+Shift+U` composition state renders Unicode hexadecimal pre-edit
text, while GLFW character callbacks carry committed platform-IME Unicode.
OSC 133 `A/B/C/D` phases retain bounded command blocks, including exit status
and optional `D;status;duration_ms` timing, for select/copy/rerun actions.

`Terminal.App.Accessibility` converts the active render snapshot into a stable
semantic row tree and publishes it through the sibling `a11y` provider while
pumping host queries and focus changes from the main loop. Pane zoom, pane
movement, and broadcast input remain main-loop policies over the runtime table;
they do not duplicate PTY or core ownership. `Terminal.App.Session_Recording`
owns the versioned output-recording parser/writer and UTF-8 transcript export;
the runtime-table poll observer supplies output without coupling recording to
the PTY reader task.
