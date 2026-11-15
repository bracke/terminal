# Architecture

## Crate Graph

`c_string_ownership` has no external dependencies and provides the neutral,
cancellation-safe temporary C-string owner used at foreign call boundaries.

`glfw_vulkan` depends on `c_string_ownership`, `df_vulkan`, and system/Alire
`libglfw3`.

`terminal_common` depends only on `c_string_ownership`.

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

`Terminal.Core` keeps terminal lifecycle and protocol types in the parent
package. Focused child interfaces own snapshot mutation and status formatting,
so the ordinary snapshot surface remains read-only.
Complete parser transitions remain named Ada subunits with explicit state,
status, payload-owner, and quota parameters. `Feed` coordinates input blocking
and final status selection; byte-state transitions and iterative tmux
passthrough draining are separate units. Ignored-string completion delegates
tmux decoding, Sixel cursor policy, and DECRQSS generation to protocol-specific
units. State domains with reusable invariants have private child-package
interfaces. In particular,
`Terminal.Core.Screen_Rows` owns backing-cell indexing and selection, blank
cell construction, dirty-row updates, wide-cell overlap repair, normalization,
and row shifts; these invariants have no duplicate implementation in the
parent. Lifecycle/reset, byte feeding, Kitty APC and ignored-string graphics
handling, OSC and CSI
completion, mode/SGR application, Unicode cell updates, resizing, and snapshot
construction each remain independently buildable units.
`Terminal.Core.Character_Properties` owns reusable Unicode width, emoji, and
renderable-attachment classification. Width, standardized emoji-variation
bases, combining marks, and format characters all come from the same generated
Unicode 15.1 interval tables, so behavior does not depend on the GNAT runtime's
Unicode version. Regenerate the checked-in table with the Ada tool:

```sh
alr exec -- gprbuild -P tools/graphics_tools.gpr
tools/bin/generate_unicode_character_properties \
  UnicodeData.txt EastAsianWidth.txt emoji-variation-sequences.txt \
  terminal_core/src/terminal-core-character_properties_data.ads
```

Pass `--check` as the final argument to compare regenerated output without
modifying the checked-in table; Linux CI installs the Unicode 15.1 data package
and performs this check on every change.

App-layer script, bidi-direction, and emoji classification likewise comes from
checked-in Unicode 15.1 tables rather than hand-maintained block ranges. Build
the same Ada tool project, then regenerate or check that table with:

```sh
tools/bin/generate_text_properties \
  Scripts.txt DerivedBidiClass.txt emoji-data.txt \
  terminal_glfw_vulkan_app/src/terminal-app-text_properties_data.ads [--check]
```

The Linux workflow pins both its Ubuntu release and `unicode-data` package
revision so the two generators cannot silently consume a newer dataset.
Both generators use `Unicode_Generator_Support` for checked range parsing,
hexadecimal formatting, interval emission, and generated-file comparison, so
their accepted input and emitted interval syntax cannot drift independently.
Every script value in `Scripts.txt` maps to an explicit renderer script; an
unknown future script makes the generated unit fail to compile instead of
silently falling back to the Common shaping tag.
The generator also records the complex-shaping policy on each script interval,
so script classification and shaping dispatch cannot drift in separate source
files. Every Unicode 15.1 script is explicitly classified as complex or
simple/bidi-routed, and the reviewed mapped-script count is an additional
generation invariant. A Unicode update that introduces a script must update
the shaping policy explicitly before a new table can be emitted.

`Terminal.Core.Snapshot_Access` owns private snapshot validation, checked
indexing, damage/scroll-event access, and the image/blink and wide-cell
violation accounting maintained by snapshot mutation.
`Terminal.Core.Snapshot_Editing` is the explicit public mutation boundary used
by selection, blink, scrollback, graphics staging, and white-box tests; backing
array access types remain private. Validation therefore remains constant-time
and malformed edits are rejected before rendering.
`Terminal.Core.Graphics_Runtime` owns graphics-transfer buffers, complete
queued-event allocation and destruction, input barriers, and multipart cleanup;
event insertion receives an immutable screen/stream context and returns a
result instead of depending on the complete terminal record. The parent retains
parser orchestration and diagnostic policy. The compatibility `Last_Event`
snapshot is published only after queue insertion commits and is cleared when
the FIFO becomes empty, so rejected or consumed commands cannot remain visible;
nonqueued diagnostics build it directly without copying the maximum-size event
record for rollback. Lowering resource limits repacks or
discards every retained transfer, chunk, multipart, and deferred-input buffer,
and trims the event FIFO to its oldest conforming prefix before returning. Chunk assembly,
transfer growth, deferred-input detachment, and every matching deallocator stay
behind that single runtime owner.
`Terminal.Core.Graphics_Events` owns queue inspection, payload reads, discard,
backpressure release, and deferred-input resumption; `Graphics_Scrolling` owns the bounded per-screen
scroll-event rings. `State_Access` owns side-effect-free state queries plus
bounded response and damage consumption. `Lifecycle` coordinates teardown,
while `Storage` is the single owner of shared screen and snapshot deallocation
instances. These children keep queue, storage, and lifecycle invariants out of
the parser-orchestration body without widening the public core API.
Kitty placeholder diacritic lookup is a named core subunit with binary search
over the sorted protocol-authoritative table, keeping both the table and its
lookup policy out of the terminal coordination body while preserving the
existing private decode interface.

`Terminal.App.Graphics_Types` owns protocol headers and capability value types.
`Terminal.App.Graphics` owns protocol parsing and the controlled preview value;
`Media_Decoders` and `Decoding` are the focused public codec boundaries, while
the private `Transport_Decoders` child implements transport decoding. The
decoder packages directly own their implementations in dedicated subunits,
avoiding duplicate parent declarations and forwarding bodies.
Protocol header parsing is likewise split into Sixel, Kitty, and iTerm2
subunits. Kitty validation constructs its typed header behind one private
boundary, and iTerm2 control fields are indexed once for both rendering and
file-transfer policy. Decoder length checks
remain at the owning implementation entry points. PNG container validation,
bounded streaming inflation, and color conversion are isolated in the private
`PNG_Chunks`, `PNG_Inflation`, and `PNG_Pixels` children; row filtering and
Adam7 pass coordination remain in the decoder subunit. Shared raw layout
arithmetic, Sixel color conversion, PNG metadata types, and Base64 length
validation are respectively owned by the focused private `Pixel_Layout`,
`Sixel_Support`, `PNG_Types`, and `Base64_Sizing` children rather than a decoder
grab-bag package. Protocol-neutral Sixel extent, aspect, and background analysis
lives in `Terminal.Common.Sixel`, so core cursor movement and application
decoding consume the same result. The protocol package also coordinates
preview ownership through its preview-storage,
capability-reporting, Kitty-validation, PNG-support, and
status-reporting child packages. `Terminal.App.Vulkan_Submit.Validation`
performs all frame count, geometry, atlas, and overflow checks before the
submission builder mutates a retained batch. The builder, text-run copying,
atlas preparation, and image-command conversion are named subunits, while the
low-level backend-only `Batch_Views` child and private `Diagnostics` child
respectively own borrowed batch projection and human-readable batch status
formatting. Lifetime-sensitive vertex and pixel views are absent from the
stable parent facade; the test project supplies its own white-box child.
Image-atlas source
bytes are consumed through a scoped row callback: the public submission facade
exposes scalar format and dimension metadata, but never returns a command that
contains pointers into retained batch storage. Decoder-only inspection remains
a test-source facade and is not compiled into the production library.
Vertex append overflow is latched into an explicit failed build outcome instead
of producing a successful partial batch. The reusable bounded-append primitive
is independently failure-testable and keeps test capacity controls out of the
production submission record.
`Terminal.Core.Response_Writer` owns bounded response transactions and their
rollback, while `Response_Facade` adapts those operations to terminal state so
the parent body does not duplicate response-buffer plumbing or bypass the
facade during exception rollback. `Response_Queries` owns device-status,
mode-status, and window-operation query semantics behind one private interface;
the parser coordinator only dispatches to that boundary. `Parser_Primitives`
owns CSI reset/default lookup and string-control state classification without
exposing the mutable parser record. The private child `Parser_Execution`
boundary owns UTF-8 decoding, CSI execution, byte dispatch, and feed-byte
control flow. It can inspect the parent's private terminal state, but the Ada
compilation boundary prevents it from reaching body-local declarations; the
parent private specification lists its permitted state-changing actions
explicitly.
The public
`Terminal.Core.Status_Labels` child owns bounded status formatting
and overflow-safe diagnostic aggregation. Natural-valued telemetry updates use
the shared saturating operations in `Terminal.Common.Counters`.
`Terminal.Core.Hyperlink_Store` interns OSC 8 values behind compact cell
references. An ordered index gives logarithmic lookup in the retained-link
population, including deliberately colliding or repetitive application input;
periodic mark-sweep removes index entries no longer referenced by either
screen, scrollback, or the active link. Public cells still materialize a
self-contained hyperlink value when a caller needs it. `Cell` and the link-free
`Cell_Content` view are constrained variants of one shared record definition,
so their display fields cannot drift while rendering avoids expanding the
bounded OSC 8 payload for every visited cell. Snapshot hyperlink pools use
explicit reference counts instead of scanning the complete grid. Snapshot
refresh interns all hyperlinks needed by dirty rows before changing any
retained cell and retains those prepared references
in reusable snapshot scratch storage for the update pass, so allocation failure
leaves the prior snapshot intact without repeating ordered-index lookups or
allocating scratch on every refresh. Consumed and abandoned scratch entries are
released explicitly, so the reusable array never retains stale access values.
`Terminal.Core.Snapshot_Cell_Storage` is the single owner of active and recycled
cell-array hyperlink references; acquisition, abandonment, commit, and final
release all cross that boundary. Failure injection exercises both the full and
dirty-row refresh paths through the real snapshot routine by substituting the
interning operation, without retaining a test-only branch in production state.
The tests fail after a successful intern as well as before publication, proving
that partially prepared hyperlink references are released. Explicit release
still propagates cleanup failures; controlled finalization records suppressed
failures in `Snapshot_Finalizer_Diagnostics`, retaining a saturating count and
the most recent exception identity. Tests and diagnostic consumers can reset
that state explicitly; `Snapshot_Finalizer_Failure_Count` remains the compact
compatibility view.
Cell replacement calculates image, blink, and wide-cell accounting before
committing the new cell and counters; failure-injection tests
verify that all three counters and the prior cell remain unchanged.
`Terminal.Core.Scrollback_Storage` grows the
bounded scrollback ring geometrically from an empty initial allocation instead
of reserving the configured maximum for every session. Erasing scrollback
scrubs retained ring capacity as well as resetting logical bounds, so interned
hyperlink references cannot survive outside the mark-sweep root set.
The private terminal record groups parser machinery and
graphics transport/queue state into separate runtime records, leaving screen
state distinct without changing the public core interface. Supporting
invariants remain private to the parent and its private children,
so this split does not add dependencies or expose mutable parser state.

`glfw_vulkan` is reusable for non-terminal Vulkan applications and contains no
terminal emulation, text rendering, or input semantics.
Its process-wide initialization lease is serialized by a protected state
machine, including startup and final termination transitions. Controlled
transition guards recover cancelled startup and shutdown operations; startup
generations prevent a blocked acquirer from cancelling another task's active
transition. Window teardown
normally removes callbacks transactionally; the controlled-finalizer fallback
forcibly retires the native window identity so address reuse cannot expose
callbacks from a destroyed window, while outstanding dispatch tokens keep the
retired registry node alive until quiescence. A dispatch waiting on a callback
mutation retains that generation and discards its event if the generation is
retired, even when a new window immediately reuses the native address.

`terminal_pty` selects one backend with `TERMINAL_PTY_OS`: POSIX PTYs on Linux
and macOS, or ConPTY on Windows. Native handles, file descriptors, ioctl
values, and platform API types do not leak into common, core, or
renderer-facing interfaces. POSIX and Windows scenarios use separate object,
library, and test-executable directories, preventing a scenario switch from
reusing incompatible build artifacts.
An early POSIX C constructor captures an immutable environment before Ada
elaboration can activate library tasks. Each spawn derives its environment and `SHELL`
from that snapshot and allocates all child strings before `fork`; later
process-environment mutations are intentionally not observed. A leaf C helper
owns the complete fork-to-exec branch, so the child
never re-enters the Ada runtime; it uses allocation-free descriptor operations
and the target kernel's PTY-control ioctl before calling `execve`. A
close-on-exec status pipe makes child setup and shell execution failures
synchronous, and the master is accepted only after nonblocking mode has been
installed successfully.
POSIX ABI declarations live in a platform-private binding unit rather than the
session implementation. Child finalization performs only a bounded terminate
and wait; unresolved PIDs move to a process-wide quarantine that bounded drain
and shutdown calls can retry without blocking a controlled finalizer. Cleanup
shutdown also rejects later POSIX spawns before they acquire native resources.
The Windows path builds a sorted child-specific environment block before
`CreateProcessA`, so per-session terminal features do not mutate process-global
environment state. ConPTY output uses a host-side overlapped named pipe and a
retained read context; each backend read only polls completion and therefore
preserves the common nonblocking contract. Teardown cancels that context and
closes the host output endpoint before `ClosePseudoConsole`, preventing its
final presentation frame from blocking shutdown when output is no longer being
consumed. A child that outlives bounded finalizer teardown is transferred with
its process handle to a Windows worker for bounded termination and wait
attempts before the handle is closed. Persistent termination or native-release
failures increment cleanup diagnostics and emit a debugger-visible message;
live children remain owned in a quarantine after bounded exponential-backoff
attempts. A retained overlapped reader always moves with its output-pipe handle,
and resources surviving the finalizer's bounded retry transfer to type-specific
cleanup jobs. Pending and quarantined owner counters plus an explicit bounded
drain operation expose current cleanup progress. After successfully closing its
session table, the application atomically closes cleanup admission and drains
all previously accepted owners; if session closure fails, it leaves admission
open and records that live producers prevented the shutdown barrier. Retry
attempts stay out of the terminal-failure counter; only quarantine, exhausted
allocation, rejected post-shutdown handoff, or a non-retryable release failure
increments cleanup diagnostics. Handoff failure leaves ownership with the Ada
resource record; finalization then invokes a bounded type-specific terminal
fallback. Only timeouts retain retryable ownership. Failed waits, closes, and
`LocalFree` calls consume their marker once so a later native-value reuse cannot
redirect cleanup to an unrelated resource. All Windows bridge translation units
share one internal C header, including the deterministic allocation and queue
fault controls used by the lifecycle smoke test. Those controls exist only in
the dedicated testing scenario and are absent from production objects. A
separate cumulative abandoned-owner counter records consumed markers whose
native release could not be confirmed; both drain and shutdown report
incomplete whenever it is nonzero, even after all queued jobs have finished.
Cleanup shutdown is a one-way backend transition, and later Windows spawn
requests return `Cleanup_Shutdown`. Quarantine draining admits at most four
retry workers concurrently so a large retained set cannot flood the Windows
thread pool.
The application routes this result through a dedicated PTY-cleanup lifecycle
package; its test child verifies that an incomplete backend result increments
the application cleanup diagnostics.

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
External URI activation has a separate, descriptor-free
`Terminal.App.Platform_Launcher` boundary. Its POSIX body locates a desktop
opener, starts it with `posix_spawnp`, and registers the exact child PID in a
bounded table. The frame loop polls that table with `waitpid(..., WNOHANG)`
through a local POSIX shim, so no library task can block application shutdown;
completed and already-reaped entries are retired explicitly, while unexpected
host errors retain ownership in a bounded quarantine and enter cleanup
diagnostics. Quarantined entries continue to be polled without consuming the
normal 64-child admission quota; a successful poll returns them to normal
accounting. The larger hard tracking ceiling prevents an unbounded leak if the
host wait API remains broken, and no error path discards a PID that may still
need reaping.
Its Windows body uses the platform-neutral, directly tested
`Terminal.Common.UTF8` converter before calling `ShellExecuteW`.
A test child injects the final executor after exercising the same selection and
status mapping and exposes the real spawn/poll path to the platform smoke test.
Hyperlink policy and labels remain platform neutral and never construct a shell
command.
The same launcher owner provides bounded desktop notification delivery on
POSIX by locating `notify-send`; notification children share the existing PID
tracking, admission limit, and nonblocking reaping path. The core only records
bounded BEL, OSC 9/99, and OSC 133 completion requests, leaving delivery policy
and platform behavior in the application layer.

`Terminal.App.Workspace` is a versioned bounded text-state boundary. The main
loop reconstructs the runtime table from it before first presentation and
captures layout, labels, OSC 7 directories, and startup commands before session
teardown. Restored shell input is submitted through `Session_Table.Write`, so
it uses the same bounded queue and write-status path as interactive input.

The command palette is a bounded application state machine over key-binding
actions and the validated session-profile registry. Profile execution creates
a regular session-table tab and then submits quoted CWD, environment, local
shell/command, or SSH startup input; it does not introduce another process
owner. Built-in profile themes pass through the renderer's transactional theme
update before becoming active configuration state.

Shell marks remain core-owned because OSC 133 parsing and scroll production are
core concerns. Each mark records a monotonic history-row coordinate in a
bounded ring. `Scrollback_View` alone converts those coordinates into clamped
presentation offsets. The renderer consumes snapshot `Scrollback_Rows` and
`Scrollback_Offset` to draw the scrollbar, preserving the existing one-way
core-to-snapshot-to-renderer state flow.

Pointer chrome is resolved before terminal mouse routing. Tab reorder moves the
borrow-registry entry and tab label as one owner-task transaction; active
borrows remain valid because releases locate entries by runtime identity.
Split dividers update bounded model weights, and subsequent layout/PTY resize
uses the same deterministic pane geometry. Scrollbar dragging only changes the
app-owned scroll offset.

Text composition is a small app-owned state machine: its pre-edit buffer is six
hex digits and is rendered through the existing interaction overlay. Committed
platform IME scalars and committed built-in composition scalars converge on the
same UTF-8 input mapper. Command blocks remain core-owned alongside OSC 133
state because their absolute history coordinates must advance atomically with
scroll production; app helpers map retained blocks to visible selections and
extract bounded command text for copy/rerun.

`Terminal.App.Graphics_Profile` constructs the core capability response,
renderer transfer-access policy, and iTerm2 download admission together after
intersecting requested media with platform availability. The main loop and new
sessions retain that immutable runtime profile, so protocol replies cannot
advertise access that the renderer will reject or vice versa.

`Terminal.App.Vulkan_Context` owns the Vulkan instance and window surface. It
uses GLFW-provided instance extensions, `df_vulkan` handle types, and
`glfw_vulkan` surface creation. The renderer receives this context during
initialization and consumes only terminal render snapshots after that. Context
init outcomes expose bounded labels for startup/status UI. Context, presenter,
and logical-device objects are limited controlled resource owners, so exception
unwinding invokes their idempotent teardown even when the main loop does not
reach its explicit orderly-shutdown path.

Session runtimes and the runtime table are also limited controlled owners. A
runtime closes its queue, PTY, reader task, and terminal core independently so
one failed cleanup step cannot prevent the remaining releases. Table teardown
continues across every live session and is safe to invoke explicitly before the
automatic finalization performed during scope unwinding. A failed release leaves
the runtime in `Cleanup_Pending`; restart and table removal refuse to overwrite
the retained owner, and finalization reports incomplete cleanup instead of
silently marking leaked resources closed.
Public core and PTY-queue access uses limited controlled borrow objects rather
than naked resource pointers. Closing a runtime atomically blocks new borrows
and leaves it in `Cleanup_Pending` while an existing borrow is alive; a retry
performs the final deallocation after the borrow guard releases its lease. Each
borrow has an access discriminant tied to its runtime owner, so Ada accessibility
rules prevent the lease guard from outliving that owner. Runtime-table lookup
uses the same owner-tied controlled-borrow model. Tab and pane removal returns
`Runtime_In_Use` while the selected runtime is borrowed, and whole-table cleanup
refuses to deallocate any runtime until all lookup borrows have ended.
The runtime table owns session, tab, and split activation state. Mutations are
prepared on copied state and committed only after every participating model
accepts the operation; a rejected layout or activation therefore cannot leave
their counts or active indices divergent. The main loop consumes read-only tab
and split snapshots and cannot independently mutate an active index.
The table is explicitly task-confined: initialization records the owning Ada
task and every public lookup, borrow operation, and mutation rejects a different
caller. The protected borrow registry controls nested object lifetimes within
that owner task rather than pretending to provide partial cross-task safety.
The registry is the sole owner of runtime pointers: registration transfers
ownership into it, removal atomically detaches the reserved pointer, and whole-
table cleanup detaches every pointer before deallocation begins.
Orderly shutdown records snapshot, session-table, GLFW-window, and GLFW-context
cleanup failures and leaves failed owners armed for controlled-finalization
retry. Cleanup diagnostics retain the most recent operation and exception name
in addition to saturating component counters, making suppressed finalizer
failures attributable without allowing one failed release to stop the rest.

The app render pipeline is staged:

1. A limited controlled `Terminal.Core.Render_Snapshot` is constructed from
   the terminal core. Its backing arrays cannot be shallow-copied; refresh uses
   the explicit snapshot procedure, while controlled finalization guarantees
   release at scope exit. Backing ownership exists only in private storage;
   explicit cell replacement supports frame-local overlays by copying into
   snapshot-owned storage. Dimensions, screen context, cursor state, and the
   graphics event are read through accessors and changed only by validated
   setters, so callers cannot desynchronize logical metadata from backing
   counters. `Terminal.Core.Is_Valid` checks cursor bounds and graphics-preview
   bounds against private storage before either renderer entry point allocates
   a frame. The exact placeholder-cell
   count is maintained inside the private storage while cells are copied or
   replaced, so validation does not rescan the grid; indexed accessors and
   mutators reject
   indices outside the logical
   cell, dirty-row, or graphics-scroll counts instead of returning stale
   defaults. Graphics adopt and take operations make lifetime
   changes visible at call sites and reject aliases that overlap storage about
   to be released.
   Graphics previews and decoded-media results use the same single-source
   ownership model, so no independently writable pointer can diverge from the
   pointer released by finalization.
   Reusing a same-sized snapshot refreshes terminal rows marked dirty by either
   the core or the preceding presentation pass; dimension changes and composed
   scrollback views rebuild the complete visible-cell copy. Scrollback
   composition prepares a complete replacement in reusable scratch storage and
   swaps it into place only after every cell and hyperlink succeeds.
   Selection and text
   blink mark each row they decorate, so the next refresh restores those rows
   from the core before applying the next frame's transient effects. Cursor
   metadata is refreshed unconditionally. This retains incremental damage
   behavior without allocating and copying a second full grid on every frame.
   Placeholder counts are adjusted as rows are replaced, avoiding a second
   grid scan.
2. `Terminal.App.Renderer` loads `textrender`, rasterizes glyphs, and builds
   renderer-neutral `Terminal.App.Render_Model.Frame_Commands`. The frame
   contains fallback glyph quads plus bounded text-run commands prepared for
   the app-layer HarfBuzz shaping backend. Single-pane and composite frames
   use the same snapshot-draw routine and advance animations before drawing,
   so text, image, and overlay ordering cannot drift between entry points.
   `Terminal.App.Renderer.Frame_Lifecycle` owns frame reset, capacity growth,
   release, damage accounting, atlas-dirty propagation, and submission-batch
   publication. `Renderer.Drawing_Commands` is the checked append boundary for
   rectangle and glyph commands.
3. `Terminal.App.Vulkan_Submit` converts frame commands into normalized
   rectangle/glyph/image-placeholder triangle vertices, carries text-run
   commands by value, and carries text-atlas upload metadata. Build outcomes
   expose bounded labels for diagnostics. The submission builder, validation,
   atlas construction, and diagnostic formatting have separate compilation
   boundaries.
4. `Terminal.App.Vulkan_Presenter` owns the presentation boundary. It selects a
   physical device with graphics and GLFW-surface presentation support, using
   one queue family when available and distinct graphics/presentation families
   otherwise, creates a logical device with `VK_KHR_swapchain`, creates the
   initial swapchain, image views, render pass, framebuffers, command buffers,
   per-frame sync objects, and a shader-backed color graphics pipeline using
   shader bytecode load outcomes with bounded labels,
   validates accepted batches, uploads packed vertices into a host-visible
   Vulkan vertex buffer, uploads the `textrender` R8 glyph atlas into a sampled
   Vulkan image, records a render pass, submits, presents through the swapchain,
   detects stale swapchains, and records presentation diagnostics. Upload and
   presentation failures retain their precise bounded status through the
   presenter boundary. `Terminal.App.Frame_Completion` is the single policy
   point that decides whether graphics events are committed, a frame is
   retried, backend recovery is awaited, or the window is closed; graphics
   events are committed only after successful presentation. A presentation
   that was never attempted has its own status, so a retryable renderer
   allocation failure cannot mask structurally invalid presenter input.
   Physical-device enumeration and queue/surface suitability are isolated in
   `Terminal.App.Vulkan_Device.Selection_Logic`. Dynamic Vulkan enumerations use
   `Terminal.App.Vulkan_Enumeration`, which validates counts and performs a
   bounded retry after `VK_INCOMPLETE`. Every enumeration also has a practical
   item ceiling, independent of the host `Natural` range. Queue preference is
   isolated in `Terminal.App.Vulkan_Queue_Selection` so changing result sets and split
   families have deterministic tests. `Terminal.App.Vulkan_Creation_Plan` is
   shared by production creation and tests; it fixes logical-device queue-info
   counts, swapchain sharing mode, family-index counts, and rejects unbounded or
   unrepresentable extents before a swapchain handle is created. Logical-device
   ownership, uploads,
   rendering, and teardown do not share the selection implementation.
   Snapshot comparison and human-readable image diagnostics are owned by
   `Terminal.App.Vulkan_Device_Diagnostics`, leaving logical-device resource
   management independent of presentation formatting. The private
   `Terminal.App.Vulkan_Device.Snapshots` child captures device state, keeping
   the large diagnostic aggregate out of the device orchestration body.
   `Terminal.App.Vulkan_Device.Resource_Lifecycle` owns destruction, deferred
   upload retirement, and upload-fence restoration, so handle cleanup policy
   is not duplicated by the logical-device facade. The generic
   `Terminal.App.Vulkan_Destroy_Once` clears Ada ownership before entering a
   foreign destructor; an exception can therefore be diagnosed but can never
   make an indeterminately consumed handle eligible for a second destroy call.
   The pair and triple cleanup chains additionally quarantine dependent handles
   when destruction of their parent resource is ambiguous, so teardown never
   invokes a child destructor after a failed parent step. The same policy is
   used by context teardown, normal replacement, initial logical-device
   rollback, staging-image rollback, deferred retirement, and upload-fence
   recovery. Creation publishes each persistent handle to the controlled device
   immediately; local shader modules use destroy-once cleanup. A failed local
   cleanup quarantines the logical device, preventing its parent handle from
   being destroyed beneath an ambiguously live child.
   It covers the text atlas, inline-image atlas, colour-glyph sheet, MSAA image,
   vertex buffer, and optional readback buffer; readback replacement destroys
   the old buffer/memory pair before publishing the new pair. Framebuffer and
   swapchain-view teardown applies the same rule to their render-pass,
   attachment, and swapchain parents. If any child destructor has an ambiguous
   outcome, the remaining parent handles and logical device are quarantined
   instead of being passed to further foreign destructors.

`Terminal.App.Renderer` partitions its private state into lifecycle, text,
frame, view, and controlled graphics components. Text, frame, shaped-run, and
view storage types live in the private `Terminal.App.Renderer_State` package
instead of the renderer facade. Frame buffers and submission state therefore
do not share a flat namespace with text-engine metrics or UI state. The graphics component is further partitioned into cohesive resource,
policy, transaction, and telemetry records.
Together they coordinate graphics resources, limits, protocol staging,
counters, and media diagnostics, and provide an independent finalization
fallback if ordinary renderer teardown is interrupted. These state types and
the renderer's remaining controlled graphics state are private, so callers
cannot bypass the domain stores selected by the renderer.
The private child packages `Terminal.App.Image_Placements` and
`Terminal.App.Placeholder_Index` are renderer implementation details; ordinary
application clients cannot obtain their mutable placement access values or
bypass renderer cache invalidation. `Terminal.App.Image_Placements.Store` owns
virtual and conventional placement
list heads, their shared quota count, unlinking, release, and finalization.
Renderer protocol code traverses and looks up placements through read-only
views and requests checked prepend/remove operations. Mutations run through
cursor- or identity-scoped callbacks which invalidate the derived index before
returning, so callers cannot retain a writable placement pointer. A callback
first edits an unlinked candidate copy; only successful callbacks are committed
to the live placement and all internal lookup maps. Relative descendant moves
use the same bulk transaction, preparing the complete replacement index before
publishing any placement state. Placement
linkage is a private limited component: a placement
cannot be copied with its list membership or inserted twice, and failed
insertion leaves the store count unchanged.
Virtual and conventional placements instantiate the same generic index,
single-update, bulk-update, and removal machinery. Only their identity and
addressability rules remain specialized. Those generic implementations are
children of the private placement package, so they do not enlarge the ordinary
`Terminal.App` client surface. Removal preflights the key, address, and
per-image indexes before unlinking or changing any map; renderer-wide deletion
preflights every matching placement before releasing the first one.
Renderer placement queries compose each canonical state record with a presence
flag. Mutable store state remains an ordinary untagged value, so query metadata
cannot enter the placement hierarchy or be written back into the store, and no
second field-for-field state schema is maintained.
Relative screen-association propagation first discovers reachable placement
identities in a bounded hash map and then applies the update in one list pass.
Its work is bounded by configured depth times placement count and does not
rescan the full list recursively for each descendant.
Renderer-owned placement and image mutation wrappers also invalidate the
derived placeholder index before destructive mutation. Eviction, replacement,
stream release, relative-placement movement, and ordinary insertion/removal
therefore cannot leave cached access values referring to released objects.
The implementation is partitioned into Ada subunits by responsibility. Frame
orchestration remains in the parent body; decoded-image extent validation,
preview capture, and row assembly live in the private
`Terminal.App.Renderer.Image_Buffers` child;
protocol-event application, placement lifecycle, and retained-image emission
live in named subunits. Focused private renderer children provide smaller semantic
boundaries inside that implementation:
`Terminal.App.Renderer.Image_Objects` owns lookup, automatic-ID allocation,
stored-data presence/length queries, coordinated image/placement release, and
unplaced-object eviction;
`Terminal.App.Renderer.Frame_Planning` owns protocol-aware frame-command
capacity planning without adding parsing or placement dependencies to the
image-object store;
`Terminal.App.Renderer.Placement_State` owns traversal, mutation, index
invalidation, relative-descendant movement, and geometry resolution;
`Terminal.App.Renderer.Graphics_Synchronization` owns screen-generation,
scroll-journal, and orphan-relative-placement reconciliation;
`Terminal.App.Renderer.Animations` owns frame transmission, composition,
storage, playback control, and deadline calculation; the renderer parent keeps
only protocol-facing renames for those mutation entry points;
`Terminal.App.Renderer.Animation_Frame_Decoding` owns bounded transport decode,
row capture, and decode/quota failure classification before store mutation,
while `Animation_Frame_Canvas` initializes base/background canvases;
`Terminal.App.Renderer.Theme_State` owns theme snapshots, operation replay, and
side-effect-free staging validation, while
`Terminal.App.Renderer.Visual_Style` owns palette resolution, indexed-pixel
expansion, cell colors, cursor geometry, and link-hover styling.
`Terminal.App.Renderer.Frame_Commands` owns frame-image publication and
rollback, while `Terminal.App.Renderer.Event_Tracking` owns staged-payload
allocation, lookup, borrowed consumption, cleanup, accounting, and selective
retirement.
`Terminal.App.Renderer.Visible_Views` owns visible-screen identity changes and
animation-schedule invalidation, while
`Terminal.App.Renderer.Graphics_State_Lifecycle` owns graphics-resource
teardown and renderer finalization independent of frame orchestration.
`Terminal.App.Renderer.Diagnostics_State` captures immutable diagnostic
snapshots and compares their operational fields. `Terminal.App.Renderer.Frame_Geometry`
is the shared source for draw origins and bounded overlay capacity.
`Terminal.App.Renderer.Text_Pipeline`
owns text-run construction, bidirectional reordering, shaping maps, glyph
drawing, and text overlays behind the parent renderer's stable operations.
`Terminal.App.Renderer.Text_Media`
owns font-cell measurement, emoji scalar classification, and bounded color-PNG
header validation without depending on placement or frame lifecycle state. Transaction-list ownership is
not duplicated across rendering paths.

Production callers use the narrow `Terminal.App.Renderer.Graphics`,
`Terminal.App.Renderer.Layout`, and `Terminal.App.Renderer.Presentation` child
interfaces. Graphics policy, event staging, and result lookup live in the
graphics child; layout owns request validation before invoking the shared draw
engine, including agreement between the supplied pane array and the split
snapshot's count and active index, canonical one-based pane bounds, and tab
snapshot invariants; and presentation owns the Vulkan presenter calls. Tests and the
application loop use these focused interfaces and cannot bypass the graphics,
layout, and presentation boundaries.

The corresponding large smoke coverage is partitioned into Ada subunits and
nested subunits: renderer baseline, protocol transaction, quota/failure, and
composition/lifetime cases are independently navigable, while the media decode
matrix separates fixture state, helper callbacks, core decode cases, and format
cases into focused Ada packages and subunits. Its fixture package is generic and
instantiated inside each matrix invocation; each partition also resets callback
observations before use, eliminating elaboration-order and prior-run coupling.
The four renderer groups each receive fresh renderer and core owners and report
their own failure before the first occurrence is re-raised, so a group cannot
depend on resources or terminal state left by its predecessor.
The streaming-graphics and Vulkan-submission integration procedures are also
split into named Ada subunits. Each streaming group owns a fresh terminal, and
each Vulkan submission group restores an explicit baseline fixture before it
runs. Their labeled case boundary re-raises the first failure immediately
instead of accumulating failures while shared fixture state continues to
change.

Renderer command arrays and Vulkan submission arrays retain their capacity
between frames and grow geometrically when the grid requires more space. Image
commands borrow a bounded diagnostic-preview source rather than embedding a
4 KiB copy in every command; placeholder tiles for the same image therefore
share the decoded source. The private `Terminal.App.Frame_Image_Storage` is the frame-local
ownership boundary: it keeps image commands and their decoded, encoded, and
preview owners in synchronized slots, recognizes aliased owners, and releases
removed slots on truncation as well as full reset. This makes failed graphics
event rollbacks reclaim ownership instead of merely reducing a visible count.
Store-backed frames are selected by object and frame number, then pinned in the
same slot through an opaque, move-only controlled borrow token; capacity growth
transfers tokens explicitly, and finalization releases any token that does not reach the normal
frame reset path. Frame storage cannot directly manipulate the store's raw
borrow counters. `Terminal.App.Image_Store.Data_Borrow` exposes bounded length
and copy operations for root or indexed store bytes: acquiring it pins the
object and its controlled finalizer releases that pin. Raw accessors remain
private to the store implementation, while animation frame bytes are exposed as
an array parameter only for the dynamic extent of a scoped visitor. Frame
storage resolves and installs its own object pin before publishing a command;
renderer protocol code never captures the store's access value. Renderer
ingestion returns a retained image-object identity instead of a separable
borrowed byte pointer.
Mutations that would replace pinned bytes are rejected, while deletion unlinks
the object immediately but defers byte reclamation until the final frame pin is
released.
`Terminal.App.Renderer.Frame_Commands` owns append, overflow, owner-transfer,
and rollback mechanics outside the renderer body.
`Frame_Commands` exposes command arrays through access-to-constant views. These
views borrow renderer and text-atlas storage and are valid only until the next
render, theme update, graphics-limit update, graphics-stream release, or
renderer finalization. Submission copies compact borrowed descriptors for the
synchronous upload path; every renderer frame reset invalidates those
descriptors before releasing or replacing their backing storage. The
renderer does not publish those borrowed views as a production query API.
Composite rendering rejects panes that repeat any graphics stream, including
the unassigned zero stream: a
later pane therefore cannot replace image-store bytes borrowed by an earlier
pane's commands.
Submission source validation is shared outside `Build`, while bounded image
atlas admission, scaling, layout, and content-signature construction live in a
dedicated `Prepare_Image_Atlas` Ada subunit.
Both the text and RGBA colour-glyph atlas views carry explicit byte extents;
validation checks those extents and backend dimension/byte limits before the
submission layer copies caller-owned storage. Inline-image cache signatures
cover every source-layout field used by CPU cache invalidation, so a metadata
change cannot accidentally retain a stale GPU texture.
Submission allocation failures retain their distinct renderer status so the
application schedules a retry; structurally invalid batches remain non-retryable
build failures.
White-box tests access small renderer controls through
`Terminal.App.Renderer.Testing`. Frame-storage ownership, event-payload
lifetime, image/placement transactions, and placement invariants live in
focused test-only child packages, so unrelated checks do not share one broad
private-state facade. All of these units live only in the test project's source
directory.

The presenter also exposes an opt-in validation-only framebuffer readback. If
the surface supports transfer-source swapchain images, enabling it allocates a
bounded host-visible transfer buffer, copies the resolved image after the render
pass, restores the presentation layout, waits on the submitted frame fence, and
returns format-normalized RGBA pixels. Normal application presentation leaves
this path disabled and allocates no readback resources.

The Vulkan device creates a descriptor-backed 1x1 fallback atlas during
initialization so the shader sampler binding is always valid. Dirty
`textrender` atlas batches replace that image through a bounded staging upload.
Atlas-resource upload and per-frame image-atlas construction are separate Ada
subunits, keeping their staging and rollback transactions out of the device
orchestration body. Text-atlas, inline-image, and colour-glyph uploads share one
format-parameterized staging, copy, fence-retirement, and descriptor-update
pipeline; slot-specific commit logic owns only the final device fields.

The main-loop frame controller delegates backend polling and framebuffer/grid
resize transitions to nested Ada subunits and centralizes presenter recovery in
one status handler. The input dispatcher delegates key, character, mouse-button,
cursor-motion, and scroll events to nested Ada subunits. The dispatcher owns
only event routing and the final PTY write, while each handler owns the state
transitions specific to its event kind.

The visible Vulkan draw path renders glyph quads generated from `textrender`.
`Terminal.App.Text_Shaper` classifies each text run and uses a HarfBuzz-backed
app-layer shaping adapter against the selected font file. Text-run commands are
carried through renderer, submit, presenter, and device diagnostics without
moving terminal parsing or terminal state into the renderer.
Its public specification exposes only shaping operations and renderer-model
types; font faces and the bounded result cache live in the private
`Text_Shaper_State` package. HarfBuzz ownership and FFI calls remain in the
adapter, while script, direction, and language-tag policy is isolated in
`Text_Shaping_Tags`. Explicit renderer teardown resets the shaper as well as
the glyph atlas so cached results and font handles do not outlive the renderer.
Each `Text_Run_Command` carries the run kind, shape status, direction, script,
raw codepoints, and a bounded shaped-glyph output buffer. The renderer
coalesces compatible adjacent cells in a row up to the text-run codepoint
bound, while splitting at style changes, inferred script/direction changes,
wide/cluster cells, cursor-inverted cells, and other boundaries that would make
fallback rendering ambiguous. The HarfBuzz adapter sets direction and script;
until run metadata carries a real language, it uses the neutral `und` language
instead of guessing from scripts shared by multiple languages. It returns real font glyph IDs, source
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
`Terminal.App.Image_Placements`; its controlled store also owns placement-list
lifetime and shared count invariants. Renderer protocol code remains
responsible for identity, references, and screen-association decisions without
owning the list mechanics.
`Terminal.App.Image_Ingestion` owns protocol payload-boundary discovery,
encoded-source copies, iTerm2 unit/aspect-ratio resolution, local-medium query
loading, and bounded Kitty query validation. Local query data is decoded
directly from the loaded byte buffer; it is not expanded into a temporary
Base64 command first. Local and inline queries use the renderer's configured
byte, pixel-dimension, and animation-frame limits, matching the admission path
that would handle the corresponding transmission. Query validation lives in a
dedicated Ada subunit, and its local and inline paths share one uncompressed
format dispatcher and one result classifier.
The private package `Terminal.App.Image_Store` owns private object-list
linkage, replacement-aware object counts, allocation-backed byte/frame accounting,
storage/content serial allocation, object lookup and release, allocation
controls and atomic ownership transfer for root and
indexed buffers. Renderer code can inspect image content through an object
handle and access-to-constant byte views, but cannot splice owned lists, mutate
or release store-owned content, or directly synchronize accounting. Frame,
theme-history, and image metadata are private and change only through checked
store operations. Accounting totals are cached from the actual owned buffers
and cached frame/theme-history totals, and therefore
remain constant-time for quota checks; replacement transactions retain an exact
pointer in both directions, and the doubly linked ownership list permits direct
removal after a storage-order lookup. `Image_Store.Indexes` owns identity and
image-number map installation; installation reserves capacity and rolls back as
one transaction, while per-key collision chains let deletion replace or remove
existing keys without allocating, rebuilding, or rescanning the object list.
Removal first validates the complete bidirectional collision chain against its
map head, including every successor back-link and cycle detection, before
changing any link or map entry. A successful renderer preflight is passed into
the non-allocating removal step, so each deletion validates the chain once
rather than repeating the same traversal after placements have been checked.
Renderer deletion validates store state before releasing any placements, so a
theme transaction or pending replacement cannot cause a partial delete. Its
allocation-failure control is an explicit
optional input to a root installation, rather than mutable test state retained
by every image store. Renderer-level regression coverage injects failure after
a partial index update and verifies that the prior object and all placements
survive. Retransmission installs a pending replacement
before deleting the superseded image or any of its placements, so an allocation
failure preserves the complete old image. Its mutation and ownership operations
are visible only to `Terminal.App` implementation descendants; white-box store
tests are private descendants too, so ordinary application clients cannot
bypass renderer policy. Theme-list adoption and append
validation are separate store subunits, keeping alias checks and accounting
rollback isolated from unrelated lookup and frame operations.
`Image_Store.Object_Lifecycle`, `Image_Store.Data_Borrows`, and
`Image_Store.Accounting` are the private mutation boundaries for object linking,
borrow tokens, and cached quota totals respectively; the parent remains the
stable facade used by renderer code. All three boundaries advance the store's
mutation epoch through one parent-owned operation, including wraparound
normalization, so iterator invalidation cannot diverge by mutation path.
The `Image_Store.Frames` child owns frame creation, unowned-list cleanup,
traversal, format conversion, checked mutation, adoption, and rollback. Frame
linkage routines do not pass through a forwarding surface in the parent.
Once a frame is adopted, callers address it by object and frame number and
receive immutable descriptors; store-owned frame-node pointers are not exposed.
Each image keeps a private number-to-frame index, built transactionally during
append or bulk adoption, so random frame lookup and animation playback do not
scan the linked ownership list. Metadata setters require the owning store and
reject handles belonging to another store.
Frame and theme traversal use constant-time private cursors carrying the unique
token of the controlled data borrow that created them; a cursor cannot be used
with another object, another simultaneous borrow, or a later borrow of the same
object.
Frame append, bulk adoption, replacement, and clearing all reject an active
data borrow, so no cursor or visitor array can be invalidated by structural frame
mutation. A null object has zero frames and yields an empty, inactive borrow.
`Image_Store.Themes` groups replay-history operations behind the same private
child boundary. Owned history is traversed only through a cursor tied to an
active controlled data borrow; list-node pointers are opaque construction
handles and are never returned by iteration. The child restores list linkage,
address indexes, counts, and byte accounting if a clear cannot be synchronized.
`Image_Store.Playback_State`
owns the animation cursor, loop, deadline, and playback state. Mutations replace
one validated state value atomically instead of exposing independent setters
that can publish inconsistent cross-field combinations.
`Terminal.App.Image_Animation` owns
bounded playback timing, protocol-neutral control-state transitions, and loop
semantics, and builds decoded animation frames before transferring the complete
list to the store atomically. The renderer translates Kitty headers and result
codes at the protocol boundary; the animation engine does not depend on parser
or core response types. Only animations referenced by a currently visible
stream/screen-generation placement are scheduled or advanced; restoring a view
invalidates the schedule and makes an unscheduled running animation due again.
`Terminal.App.Image_Colors` owns xterm/Kitty palette
resolution and indexed-pixel expansion. `Terminal.App.Image_Staging` decodes
encoded render commands into bounded row or RGBA byte sinks; Vulkan owns only
mapping or packing the destination and uploading it.
Native GIF and PICT decode transactions independently bound decoder workspace,
retained output, and the adapter canvas. Their combined transient peak is at
most three times the configured decoded-image quota.
Decoded-media frame timing is allocated to the exact decoded frame count and
uses the same logical bounds as frame-copy access, so still images carry no
fixed animation-delay table and callers cannot observe timing entries outside
the decoded animation.
Theme replay and indexed recoloring build private working buffers and publish
them through store replacement operations only after replay succeeds. A theme
replay workspace is a controlled owner of its frame-number index and archived
canvas list, so every early return and exception releases the whole working set.
The transaction passes one explicit limited replay context containing both work
canvases, the data borrow, archived canvases, and frame indexes to its operation
handlers; replay subunits do not depend on parallel ambient locals.
Pixel fill and composition arithmetic lives in the separate `Theme_Pixels`
child, including extent validation, rather than in the replay transaction.
A theme
switch snapshots every affected root and animation frame before changing the
active theme, then restores the complete set if any object cannot be rebuilt;
failed theme changes therefore cannot leave mixed-theme live image storage.
Before allocating, the transaction reserves its complete backup plus the exact
per-object replay working set against the configurable theme scratch limit.
That set contains two work canvases and one canvas for each distinct retained
operation target or source/base reference, rather than each operation or only
the current live frames. Deleted but replayable animation dependencies therefore
remain quota-accounted without penalizing long edit histories of the same
frames. Replay indexes both borrowed frame sources and archived working canvases
by frame number, so neither distinct frames nor repeated operations rescan a
linked list. Rollback consumes each
backup node exactly once and releases the unconsumed tail if restoration itself
raises. Callers receive an explicit update status for resource or replay
failures. Non-composition history is accepted only when its format, dimensions,
row stride, and retained byte extent are mutually consistent; replay repeats
the extent check before indexing bytes and reports a rejected replay rather than
allowing malformed retained data to escape as a bounds exception.
Palette-sensitive animation edits append their complete prepared replay suffix
provisionally before publishing changed pixels or frames. The suffix includes
the baseline when history is first created. The store transaction rolls the
whole suffix back if the subsequent mutation fails, so an allocation failure
cannot leave live image data and replay history out of sync. An active suffix
locks theme mutation and object deletion; a rollback invariant failure keeps
the object quarantined instead of converting provisional history into a commit.
Quarantine still permits explicit deletion of the affected object, providing a
bounded recovery path while ordinary live transactions remain deletion-locked.
Theme append transactions
and renderer image-install guards are controlled owners: scope exit performs
rollback automatically unless commit explicitly disarms the guard.
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
Graphics event staging exchanges results through the shared
`Renderer.Event_Stage_Types` package; the event tracker does not depend on the
public graphics facade. The graphics-event adapter, theme baseline/preparation/replay operations, and
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
`Graphics_Event_Payload` or drain it incrementally with `Read_Graphics_Event`.
Incremental reads retain the FIFO head after the final byte so the consumer can
acknowledge it with `Complete_Graphics_Event` (or explicitly discard it);
queue pressure preserves older events, drops the newest completed event, and
increments `Queue_Overflow`.
Complete payloads copied into the renderer's retry transaction are bounded by
both a pane-count quota and an aggregate byte quota. Permanent staging errors
are completed with a protocol error and retired; transient allocation or frame
allocation failures keep the core event and successfully staged siblings for a
later frame retry.
The app main loop peeks the oldest event for each visible session, renders that
event, and discards it only after a successful presentation; another frame is
scheduled while events remain. A separate app-layer consumer also advances one
event per non-visible session on each iteration. The renderer reserves one
event-tracking slot beyond the maximum visible pane count, so hidden work can
progress alongside a retained visible presentation retry. Its off-screen commit
removes only its own `(stream ID, sequence)` staging and result entries, retains
atlas dirty state, routes replies through the event's owning PTY, and forces the
visible batch to be rebuilt before presentation. Thus presentation retries
remain isolated while queries, chunk barriers, and deferred terminal input
cannot stall merely because a tab is hidden.
The snapshot graphics event remains a 128 KiB compatibility carrier between
that FIFO and the existing renderer, exposed through a value accessor and a
validated replacement operation. Each runtime
assigns its core a stable nonzero graphics stream ID, and the core assigns every
queued event a monotonic nonzero sequence number. The renderer retains processed
`(stream ID, sequence)` guards until the presenter accepts the frame. A failed
render or stale swapchain can therefore retry the same event without repeating
image-number allocation, chunk assembly, replacement, placement, or deletion;
the guards are cleared at the same commit boundary where the core events are
discarded. The app
configures a renderer-backed Kitty capability profile on each core session.
Terminal reset clears both the FIFO and its compatibility carrier, preventing a
pre-reset event from remaining visible after parser and screen state restart.
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
Generation changes that affect many retained placements are committed through
one bulk placement transaction, so both virtual and conventional indexes are
rebuilt at most once per screen transition.

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
Its private `Preview_Storage` child is the sole owner of decoded-preview
allocation, publication, and transfer invariants, while the private
`Capability_Reporting` child owns protocol and emoji capability descriptions.
Decoder support is a build fact, but renderer and color-font availability are
false unless a caller with initialized runtime state confirms them explicitly.
Protocol decoders therefore do not
manipulate controlled preview storage or duplicate capability claims.
Direct-byte and Base64 transports feed the same private
`Terminal.App.Zlib_Inflation` state machine, so output limits, trailing bytes,
termination, exact-length checks, and allocation failures have one status
mapping.
All Base64 consumers use `Terminal.Common.Base64.Decoder_State`, which owns
quantum assembly, padding, whitespace, unpadded-final-group, completion, and
trailing-data state. Protocol adapters only supply output sinks and their
protocol-specific size policy. Encoded image uploads decode complete sources
once as a row stream; random-access diagnostics expose only the already
validated decoded-preview prefix and never restart decoding for each byte.
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
Giflib diagnostics retain distinct canvas, frame, compressed-input, extension,
work, warning, and snapshot limit categories rather than mapping them onto
PICT concepts. Adapter-side dimension, byte, frame-count, allocation, and
cross-pass consistency failures populate the same structured diagnostic.
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
The public media facade constrains its decoded-byte argument to the shared hard
image-byte ceiling, so a caller cannot request a decoder budget larger than the
terminal's global graphics policy even before format-specific admission runs.
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
Header parsing, Sixel analysis/decoding, Base64 decoding, zlib expansion, and
status formatting are separated from protocol coordination. The large raw-row
state machines are decoder subunits; PNG chunk parsing, inflation, filtering,
pixel conversion, and Adam7 coordination have explicit stage boundaries. JPEG
ownership and jpeglib
lifetime handling live in the private `Terminal.App.JPEG_Decoder`; the graphics
package is the public result-mapping facade.
`Terminal.App.Number_Parsing` provides the single overflow-checked scanner used
for natural, signed-integer, and graphics-ID validation and conversion, so
headers are not scanned once for validity and again for their value. Preview
`Take` delegates to the same move operation used by explicit transfers.
JPEG output remains constrained by
the decoded-image quota, while codec workspace and metadata have independent
bounded limits so a valid small output is not rejected solely because decoding
needs more working memory. JPEG workspace is additionally capped by the shared
hard image-byte ceiling, so codec workspace plus codec output plus the retained
renderer output cannot grow to the former eight-quota workspace peak. The
codec and renderer array types are bridged by
explicit byte conversion after a successful decode, never by unchecked access
conversion. GIF and PICT borrowed-stream and diagnostic
translation live in private `Terminal.App.GIF_Adapter` and
`Terminal.App.PICT_Adapter` packages, so their third-party dependencies do not
enter the shared media body. Both adapters use the private
`Terminal.App.Borrowed_Stream` generic bridge over the
`Terminal.App.Borrowed_Bytes` cursor for validated address arithmetic and
bounded source reads. Shared identifier initialization lives in
`Image_Media_Diagnostics`, leaving only codec-specific context mapping in each
adapter. The parent facade owns only shared checked arithmetic and
storage helpers. Graphics previews and decoded-media results are
limited controlled private types: callers use read-only metadata accessors and
constant pixel views plus explicit adopt, take, move, and release operations.
Graphics previews report whether pixels are owned, external/streamed, detached,
or absent, so successful streamed metadata is not confused with buffer
ownership. Format decode transactions remain separate Ada subunits behind the
shared media facade.
Regular/temp-file and shared-memory reads are isolated in
`Terminal.App.Graphics_Transport`, which enforces explicit policy, regular-file
type, offset/size bounds, sensitive-path rejection, temporary-name/directory
rules, and shared-memory unlink lifetime.
The transfer implementation accepts its unlink operation through a private
callback seam, allowing deterministic failure coverage without mutable
test-only state in the production package.

The renderer owns a unified bounded image-object store used by Kitty, Sixel,
and iTerm2. Kitty objects retain explicit IDs, non-unique image numbers,
animation frames, playback state, composition state, content versions, and
usage hints. Store-owned hashed maps resolve stream-scoped image IDs, image
numbers, and storage-order identities without rescanning the ownership list;
install, replacement, deletion, and release update those maps with the owned
objects. Collision-free implicit IDs and placement IDs are allocated only
after validation. Placements borrow decoded pixels without frame-by-frame
copies. Frame storage pins each source object, deletion defers reclamation when
a completed command still borrows it, and in-place replacement is guarded while
pinned. Resource release no longer depends solely on reset call ordering.
Inline iTerm2 placements preserve their documented cursor policy: unless
`doNotMoveCursor=1` is present, later PTY input is held until decoding determines
the rendered cell height and then resumes at the first column below the image.
Animation actions support bounded direct/chunked frame decoding, frame edits,
replace and alpha composition, region composition, per-frame gaps, looping,
running/loading/stopped control, scheduling, and frame deletion.

Core and renderer limits are supplied from validated config values for
transaction bytes, queued events/bytes, deferred input, image objects, total
and per-image bytes, placements, animation frames, decoded and scaled-placement
pixel dimensions, and GPU atlas bytes/dimensions. Kitty cursor completion
follows exact in-bounds movement but performs at most one implementation-defined
boundary scroll, so untrusted placement geometry cannot flood the retained
scroll journal. Unplaced/transient objects are preferred eviction
candidates; if all retained objects are referenced, installation returns a
quota error rather than violating lifetime. Diagnostics expose both live
resource use and cumulative command, install, eviction, transport, decode,
allocation, placement, animation, and cancellation counters.
Applying lower renderer limits first evicts only unplaced objects that violate
per-image byte or dimension limits, then evicts other unplaced objects only for
aggregate pressure. Referenced retained state that still exceeds the new policy
returns an explicit overcommitted status without sacrificing unrelated valid
objects; subsequent mutations remain subject to the new limits.
Protocol and image-resource compile-time ceilings have one protocol-neutral
authority in `Terminal.Common.Graphics_Limits`; compatibility constants in
core, config, render-model, and renderer specs are aliases of that source.
Vulkan atlas ceilings and defaults live in `Terminal.App.Vulkan_Limits`, keeping
backend policy out of the common crate while deriving safe resource maxima from
the shared image limits.
Animation wakeup checks build a bounded sorted set of due image identities and
scan each placement list once, avoiding an image-by-placement nested search on
every 16 ms main-loop tick.

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
no-op, avoiding redundant PTY resize calls. Changed core resizes reconstruct
soft-wrapped primary logical lines from history and the live grid, then stream
them into the resized history and viewport at the new width. Wide cells and
placeholder metadata remain atomic during reflow; the alternate screen uses
overlap preservation because full-screen applications normally repaint after
resize. Input
grace frames reuse the last completed submission batch and its resident GPU
buffers when terminal state is unchanged, so compositor pacing neither rebuilds
snapshots and vertices nor remaps vertex memory or reuploads texture atlases.
Dirty frames refresh per-pane terminal snapshots in retained backing arrays;
the immutable damage cache updates only dirty rows, while its reusable
presentation peer receives a full value copy before frame-local overlays.
Steady-state rendering therefore performs no cell, dirty-row, or
scroll-journal allocation/free cycle on each frame.
Text and colour-glyph atlases carry independent dirty state through submission.
The Vulkan backend keeps unchanged colour sheets resident, and atlas dirty bits
are cleared only after the frame containing them is accepted for presentation.
Per-frame throughput counters remain available in diagnostics but do not trigger
status logging by themselves. Image-preview propagation copies only the declared
valid prefix, avoiding repeated 4 KiB clears for short or absent previews.
Runtime change detection requests snapshots with renderer, presenter, and
device preview payloads omitted. Each producer compares its own explicitly
defined operational fields, excluding cumulative counters and preview arrays,
so polling neither copies large previews nor logs an old rejection.
Text-run construction classifies each cell's scalar direction and script through
a compact scalar API. It does not create and initialize full shaped-run records
for every coalescing candidate; full records are built only for emitted runs.
After shaping, the renderer builds a retained cell-to-run map once per pane.
Glyph emission uses constant-time map lookups instead of scanning every shaped
run twice for each drawable cell, keeping the pass linear in cells plus runs.
`Terminal.App.Placeholder_Index` retains renderer-wide hashed indexes for image
objects plus virtual and conventional placements across streams and screens.
It also retains the set of `(stream, storage order)` pairs referenced by any
placement, so quota eviction tests image liveness in constant time rather than
rescanning all placements for every object.
Only successful object or placement topology mutations invalidate the index;
animation playback, composition, rejected commands, and other content-only
changes retain it. The renderer rebuilds a dirty index once before the next
retained-image pass rather than once per pane. A per-snapshot origin
epoch indexes placeholder anchors in one cell scan. Placeholder resolution,
object lookup, and every step of a relative-placement chain are then constant
time, so the pass remains linear in placements, objects, cells, and parent-chain
length rather than multiplying those dimensions.
The same topology invalidation clears the visible-animation schedule cache.
The cache records the exact stream, screen, and generation identities rendered
by the current single- or multi-pane frame, so hidden streams and inactive
screens do not schedule wakeups. Rebuild indexes image objects once and resolves
placements through that index, keeping the scan linear in objects plus
placements. Animation polling reuses its cached immediate state or earliest
visible frame deadline and rescans only after topology/control changes, a view
identity change, or an elapsed deadline.
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
`Runtime_Statuses` record instead of a long positional parameter list. Change
detection retains one complete prior snapshot. Renderer, presenter, and
logical-device diagnostic snapshots structurally extend tagged operational
records. Their equivalence policies compare the operational slices, so adding a
transient counter cannot silently change redraw decisions and adding operational
state requires an explicit schema choice.
The main loop retains the last core
feed outcome and PTY write outcome
for those diagnostics. The composed runtime diagnostic line is exposed as a
testable helper so status UI/logging formatting stays deterministic. Queue
snapshots include bounded occupancy/overflow labels for PTY output and app
input pressure, and the current framebuffer-to-grid label is included with the
same diagnostics surface. Runtime diagnostics also carry the redraw-policy
label that explains synchronized-update deferral or local redraw bypasses, plus
local scrollback, selection, hyperlink, clipboard, tab, split, config, and
profile labels. Cursor and SGR text blink status labels are collected from the
render snapshot before diagnostics are emitted. Pane-wide blink activity is
aggregated by a testable scheduler helper, so a secondary visible pane requests
the shared redraw when its tick changes; a core-hidden cursor does not keep the
blink scheduler active. The runtime line also includes
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

Input encoding remains behind the `Terminal.App.Input_Map` facade, with mouse,
paste, and status-label policy split into private child packages. Ordinary key
and mouse sequences remain bounded queue chunks. Clipboard paste text uses the
session runtime's ordered streaming write buffer, which preserves bracketed
paste opening and closing sequences across arbitrary 4 KiB PTY write chunks;
new input is held until that buffer drains. Paste construction uses the same
private operation seam in production and failure tests, so exception-safety
coverage does not add test switches to each runtime object.

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

The process-wide GLFW runtime is reference counted behind a protected
transition barrier. Controlled start/stop guards release a committed lease or
finish its matching generation when asynchronous cancellation interrupts a
transition, and completed stop generations prevent a finalizer from terminating
the same runtime twice. Callback retirement similarly holds its exact registry
node with a controlled token until all in-flight dispatches have left.

A background Ada task reads PTY bytes and pushes bounded chunks into a
protected queue. When that queue is full, the producer blocks rather than
discarding terminal bytes; shutdown opens the entry and rejects the pending
push so teardown cannot deadlock. Runtime teardown shuts down the queue, joins
the reader, and only then closes the PTY, so backend state cannot be mutated
while the reader is polling it. The queue is released after both operations.
Any failed step remains owned as `Cleanup_Pending` and can be retried;
restart and table removal do not overwrite it. GLFW callbacks enqueue
compact input/window events. The main loop drains queues, feeds the core,
writes PTY input through a bounded write-all helper with status labels for
complete, incomplete, failed, and closed-session outcomes, retains an unwritten
suffix across iterations, delegates backend polling and framebuffer/grid resize
to named frame phases, snapshots, and renders. Presenter recovery is handled by
one shared status path for retained and newly built frames. That path pairs the
actual renderer result with the presenter result; renderer allocation failure
requests another frame and cannot be misclassified as a fatal invalid batch.

GLFW callback ownership is keyed by the raw window handle. Each live window has
its own key, character, mouse-button, cursor, scroll, and focus callbacks;
window destruction unregisters the native callbacks and removes its node from a
dynamically sized protected registry. Registry lookup and mutation are
synchronized by one protected registry containing hash buckets; the buckets
bound lookup cost but intentionally share one short-held lock. Dispatch accounting
is per window: while replacement waits for old callbacks on that window,
acquisitions for that window wait on a per-node suspension object rather than
polling, and the wait occurs outside the registry lock. Reentrant replacement permits only the
current task's active stack for the target window, which is owned independently
by `GLFW_Vulkan.Input_Dispatch_Context`; the registry itself owns only callback
storage and mutation synchronization. The protected storage implementation and
the controlled dispatch/lifetime implementation are separate subunits behind a
small coordinator, so their respective invariants can be audited independently.
This avoids self-deadlock without treating callbacks
on other windows as quiescent. A callback that collides with an already active
mutation for the same window fails immediately instead of waiting behind one that may itself
be waiting for that callback. Controlled dispatch and mutation guards restore
registry accounting during exceptions. Native GLFW callback changes are rolled
back if their corresponding registry commit or multi-callback removal fails, so
the C and Ada callback views remain transactional. Exceptions are
contained at the C callback boundary and increment an observable saturating
callback-failure counter instead of disappearing silently. Each failure also
retains a bounded callback-kind and Ada exception-name record. Registry
bookkeeping and guard failures use a separate infrastructure-failure counter
and detail record, so callback quality telemetry is not polluted by registry
defects. Diagnostics obtains both counters and both detail records in one
protected snapshot, so concurrent callbacks cannot produce mismatched pairs;
that coherent snapshot is the only public failure-diagnostics accessor.
There is no fixed
window-count ceiling, and creating a second window cannot redirect events from
the first.
Each dispatch guard retains the exact registry-node generation it acquired.
Reentrant removal retires that node until its final dispatch releases it, so a
new registration reusing the same raw window handle has independent accounting
and cannot be decremented by the older callback's finalizer.
The main-loop callback binding uses an access discriminant tied to its GLFW
window, so Ada accessibility rules require the window to outlive automatic
callback detachment. Its finalizer records infrastructure failures instead of
propagating them, while orderly shutdown isolates explicit detachment so later
session and Vulkan cleanup continues.

Registry test hooks are compiled only by the application test project. The
focused smoke test covers every callback kind, self-replacement, reentrant
removal, nested cross-window dispatch, callback exceptions, and bounded
cross-window mutation completion without requiring a real GLFW window.

Input-event overflow is explicit: newest events are dropped, existing ordering
is preserved, and overflow counters are exposed. PTY output instead applies
lossless backpressure.

Tabs and split panes share one runtime table but are mutually exclusive layout
modes: creating a tab while split and splitting while multiple tabs exist are
rejected before a PTY is spawned. Split creation also rejects grids too small
to give every pane at least one cell; layout remains total for transient tiny
framebuffer sizes.

## Ownership

Heap-owning snapshots, decoded media values, and graphics previews are limited
controlled types. Their buffers are finalized automatically, and ownership
transfer is explicit (`Move` for graphics previews). Graphics-preview bytes
are read through a scoped callback, indexed access, or a snapshot copy; the
preview never publishes a borrowed access value. Detaching or adopting its
buffer requires a controlled `Owned_Image_Data.Owner`, so ownership cannot be
silently duplicated at the graphics API boundary. Root and indexed image-store
installation likewise accept the controlled owner rather than a raw access
value. The raw heap access type exists only in the private representation of
`Owned_Image_Data.Owner`; image objects, frames, theme operations, previews,
media results, ingestion, and zlib output transfer the controlled owner
directly. Borrow-bound frame commands retain only views backed by their active
store token; encoded-source lengths are zero when no encoded view is retained,
and any temporary encoded owner made obsolete by store installation is released
before returning. GIF and PICT adapter
cleanup independently finalizes decoder state and releases temporary buffers
even if either cleanup step raises. Cleanup failures are recorded under the
media-decoder diagnostic component rather than masking the original decode
failure. Snapshot cells, dirty rows, and scroll mutations are exposed through
indexed value accessors rather than pointers into snapshot-owned arrays;
decoded media likewise provides indexed reads and explicit frame copies.
Native GIF failures and warnings retain the decoder identifier, stream
offsets, resource limit, expected/actual values, and underlying error code.

`Terminal.Core.Terminal` owns heap-backed primary and alternate screen buffers
using compact private cells; scrollback storage remains absent until the first
row is retained and then grows only toward its configured limit.
Its graphics queue/transfer state and byte-parser state are cohesive private
components, so lifecycle code can reset or release either domain without
interleaving unrelated screen fields.
Snapshots are self-contained copies of visible cells plus cursor and dirty-row
state. Refresh retains compatible backing arrays and replaces only dirty rows;
the first snapshot and any dimension change copy the full visible grid.
Renderers must not retain references into mutable terminal storage.
Full graphics payload staging is result-bearing: allocation failure aborts the
frame before protocol processing, so a bounded preview is never mistaken for
the complete command.

## Platform Independence

The core models terminal behavior only: UTF-8 decoding, parser state, screen
buffers, modes, cursor, styles, damage, and diagnostics. Platform I/O and
rendering are adapters around that deterministic state machine.
