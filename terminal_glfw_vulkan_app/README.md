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
query validation; format decoders remain separate application-layer packages.

Graphics helpers keep protocol-independent responsibilities out of the main
renderer body. `Terminal.App.Image_Decode` supplies the canonical decode status
type, `Terminal.App.Image_Ingestion` owns payload boundaries, encoded-source
copies, and iTerm2 size resolution, while `Terminal.App.Image_Store` owns
private image-object linkage, content
release, replacement-aware object counts, allocation-backed frame/byte accounting,
serial allocation, atomic root/indexed-buffer ownership transfer, install
transactions, and allocation controls,
`Terminal.App.Image_Placements` resolves crop and cell
geometry, and `Terminal.App.Image_Rendering` owns media admission and bounded
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
rollback truncation to `Terminal.App.Frame_Image_Storage`; every frame reset
also invalidates Vulkan submission descriptors before their borrowed storage
can be replaced. Store-owned bytes likewise enter commands only through
access-to-constant views. Theme changes reserve their complete backup and
worst-case replay working set against a configurable scratch quota and return
an explicit update status. GIF and PICT decoding independently bound
decoder workspace, retained result, and adapter canvas to a documented
combined peak of three times the configured decoded-image quota.
`Terminal.App.Zlib_Inflation` is the single bounded inflater used by direct and
Base64 graphics transports.
The large graphics-event adapter, animation frame/composition transactions,
streaming PNG row decoder, theme history/replay operations, and Vulkan staging
resource transaction are separate Ada subunits. This keeps the primary
graphics, renderer, and device bodies navigable while preserving private-state
access and crate boundaries. The single-pane/multi-pane renderer entry points
and the main-loop runtime controller are subunits for the same reason. Frame
reset, capacity growth, release, and immutable frame
view publication are likewise isolated as renderer subunits; image command
ownership remains centralized in `Terminal.App.Frame_Image_Storage` through an
atomic command-and-buffer append API.
