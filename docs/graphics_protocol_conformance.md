# Graphics protocol conformance

This document records the graphics capabilities implemented by this repository.
It is capability-first: a protocol name is not treated as a promise that every
feature of another terminal is present. The implementation advertises only the
surface that the core, decoder, resource store, and Vulkan backend can provide.

Baseline date: 2026-10-24. The target is the current Kitty 0.50.0
[graphics protocol specification](https://sw.kovidgoyal.net/kitty/graphics-protocol/),
including its indexed-color formats.
The auxiliary protocol references are the
[iTerm2 inline-image protocol](https://iterm2.com/documentation-images.html),
[iTerm2 feature-reporting specification](https://iterm2.com/feature-reporting/),
and the Sixel controls documented by xterm/DEC.

Status meanings:

- **Supported** means deterministic automated coverage exercises the behavior.
- **Policy-gated** means the implementation exists but is disabled unless the
  application explicitly grants access.
- **Not advertised** means input is rejected or ignored without claiming the
  corresponding capability.
- **Manual validation** identifies hardware/window-system behavior that cannot
  be established by the headless suite.

## Milestone status (M1-M10)

| Milestone | Status | Implemented capability |
| --- | --- | --- |
| M1 — inventory and baseline | Supported | This matrix names the implemented Kitty, Sixel, and iTerm2 surfaces and links each area to regression suites. |
| M2 — streaming parser | Supported | Graphics framing survives arbitrary PTY boundaries. Complete commands enter a bounded ordered FIFO, complete Kitty chunk transactions are assembled in the core, and CAN/SUB, malformed controls, allocation failure, overflow, and terminator recovery preserve later terminal input. |
| M3 — Kitty object model | Supported | Image IDs, image numbers, implicit IDs, multiple placements, virtual placements, relative placements, crops, scaling, deletion, animation frames, composition, and playback are retained with stream and screen ownership. |
| M4 — Unicode placeholders | Supported | U+10EEEE identity, row/column/high-ID diacritics, color-carried image and placement IDs, omission inheritance, and cell metadata survive the terminal's editing and screen lifecycle. |
| M5 — rendering | Supported | Renderer-neutral commands preserve crops, opacity, source geometry, clipping, z-index, placeholder tiles, multiple simultaneous sources, and persistent conventional/Sixel/iTerm2 placements. |
| M6 — resource management | Supported | Configurable CPU/GPU limits, transient-first eviction, reference-aware image lifetime, content-versioned GPU atlas reuse, fence-gated replacement, allocation failure, and automatic device-loss reconstruction with bounded retry backoff are implemented. |
| M7 — capability and tmux interoperability | Supported | Kitty queries and iTerm2 feature reports are truthful. tmux DCS passthrough, fragmentation, response ordering, placeholder cells, PTY identity, and environment propagation have automated coverage. A dedicated released-tmux stream has also reached a live GLFW/Vulkan presenter. |
| M8 — auxiliary protocols | Supported for the advertised/runtime-available subsets | Sixel raster/palette/aspect/cursor semantics and iTerm2 inline PNG/JPEG/native GIF/PICT, optional runtime PDF and extended media, arbitrary-file downloads, sizing, aspect ratio, cursor policy, and multipart delivery are implemented. FILE reporting is policy-gated. |
| M9 — security, performance, diagnostics | Supported | Bounded parsing/decoding, overflow-safe arithmetic, strict PNG structure/CRC validation, heap-backed large row buffers, deterministic malformed-input tests, scheduled AFL++ edge-coverage fuzzing, transfer-media policy, counters, cache diagnostics, and a deterministic rapid-replacement benchmark are present. |
| M10 — end-to-end validation | Automated and host-level validation complete | Chafa, libsixel, and a dedicated released-tmux server have been exercised. The released-tmux image stream is decoded, submitted through the live GLFW/Vulkan path, copied back from the swapchain, and checked against a deterministic RGBA pixel oracle. A million-input parser soak and 50,000-update replacement soak pass. |

## Kitty graphics protocol

| Area | Status | Behavior |
| --- | --- | --- |
| APC framing | Supported | 7-bit APC/ST and C1 forms are incremental across `Feed` calls. The compatibility BEL terminator remains accepted. Cancellation and oversized-command discard recover at the next terminator. |
| Ordered delivery | Supported | Events carry stable stream, sequence, transaction, screen-generation, and scroll-sequence identities. Presentation retries are idempotent; a command is acknowledged and removed only after a committed frame. |
| Chunking (`m`) | Supported | The core validates the 4096-byte limit, non-final Base64 alignment, legal continuation controls, cancellation, interleaving, and total transaction quota, then emits one complete transaction to the app. Metadata-only initial chunks and empty final chunks emitted by Chafa are accepted. Static and animation-frame transmissions use the same architecture. |
| Formats | Supported | Indexed RGB (`f=8`), indexed RGBA (`f=16`), direct RGB (`f=24`), direct RGBA (`f=32`), and PNG (`f=100`) are decoded. Indices 0–247 use the terminal palette and 248–254 resolve the specification's dynamic default/selection/cursor/URL colors; indexed textures are regenerated after theme changes. `f=100` is strictly PNG. Strict RFC 1950 zlib (`o=z`) is bounded before output allocation. |
| Transfer media | Supported / Policy-gated | Direct (`t=d`), regular file (`t=f`), temporary file (`t=t`), and POSIX shared memory (`t=s`) are implemented. Regular-file access is disabled by default; temporary-file and shared-memory access are separately configurable and reported by queries. |
| Local-media security | Supported | Locations are bounded and Base64-decoded, files must be regular files, offsets/sizes are checked, sensitive pseudo-filesystems are rejected, temporary deletion requires the protocol marker under an approved temporary directory, and shared-memory names are unlinked according to protocol lifetime. Access failures use a uniform error surface. |
| Actions | Supported | Transmit (`a=t`), transmit-and-place (`a=T`), put (`a=p`), query (`a=q`), delete (`a=d`), frame (`a=f`), animation control (`a=a`), and frame composition (`a=c`) are validated independently. Omitted `a` means transmit-only. |
| Image identity | Supported | Explicit unsigned 32-bit IDs, collision-free implicit IDs, non-unique image numbers, newest-number lookup, replacement, and per-stream isolation are implemented. Successful numbered transmissions report the allocated ID. |
| Placement identity | Supported | Explicit and implicit placement IDs, multiple placements per image, and conventional and virtual placements are implemented. A nonzero `(image ID, placement ID)` pair is unique per terminal stream even across primary/alternate screens; screen generation controls visibility and lifetime rather than changing protocol identity. |
| Relative placement | Supported | Full-width parent image/placement IDs, signed offsets, virtual or conventional parents, cycle rejection, missing-parent rejection, depth limits, dynamic resolution, and descendant cleanup are implemented. |
| Geometry | Supported | Natural size is derived when spans are omitted. One-axis sizing preserves aspect ratio; two-axis sizing letterboxes without distortion. Source crop, pixel offsets, cell spans, viewport clipping, and invalid/empty rectangle rejection are covered. |
| Cursor policy | Supported | Successful absolute placement advances according to the Kitty policy unless `C=1`; virtual, relative, and failed placements do not. Input following a cursor-moving placement is bounded and deferred until the renderer result commits. |
| Z-index and opacity | Supported | Signed 32-bit z values are sorted deterministically. Values below `INT32_MIN / 2` render below explicit cell backgrounds; other negative images render below text and non-negative images above text. RGBA alpha is preserved. |
| Unicode placeholders | Supported | Foreground color supplies the low image-ID bits, underline color supplies placement ID, and the complete 297-entry combining-diacritic table supplies row, column, and optional high image-ID byte. Placeholder glyphs are never submitted as missing text glyphs. |
| Deletion | Supported | Lower/uppercase image, number, placement, visible/location, row, column, z-index, ID-range, and animation-frame selectors are implemented with the required distinction between placement removal and unreferenced-data cleanup. Parent deletion cascades to relative descendants. |
| Animation | Supported | Frames are quota-accounted; direct, chunked, raw, zlib, and PNG paths use bounded decoding. Frame replacement/editing, gap updates, replace/alpha composition, region composition, running/loading/stopped states, loop counts, automatic scheduling, and frame deletion are implemented. |
| Responses and quiet mode | Supported | Immediate queries are side-effect free and ordered before later replies. Deferred renderer outcomes return `OK` or precise `EINVAL`, `ENOENT`, `ENOMEM`, `ENOSPC`, `EBADF`, `ENOTSUP`, `ENOPARENT`, `ECYCLE`, or `ETOODEEP` results. `q=1` suppresses success and `q=2` suppresses errors. |
| Scrolling and screen lifetime | Supported | Conventional anchors follow full-screen and margin scrolling, including scrollback offsets. Placeholder metadata follows ordinary cells through scroll, resize, insert/delete, erase, and alternate-screen switching. Primary placements restore after alternate-screen use; clearing/resetting a screen retires that screen's placements. |
| Multi-image rendering | Supported | Distinct image sources share a packed RGBA atlas with one-pixel gutters. Cropped placements remap UVs to their slots, so simultaneous objects cannot alias a shared texture slot. Stable content signatures skip redundant uploads. |

## Resource limits and recovery

The following configuration keys are validated and applied to both the core and
application layers:

- `graphics-transaction-bytes`
- `graphics-pending-events`
- `graphics-pending-bytes`
- `graphics-deferred-input-bytes`
- `graphics-image-objects`
- `graphics-image-bytes`
- `graphics-per-image-bytes`
- `graphics-placements`
- `graphics-animation-frames`
- `graphics-pixel-dimension`
- `graphics-gpu-atlas-bytes`
- `graphics-gpu-atlas-dimension`
- `iterm2-file-downloads`

The store evicts unplaced/transient objects before reusable or placed objects.
Encoded input, decoded pixels, animation frames, placements, and atlas data all
participate in explicit bounds. An upload first polls all frame fences and is
deferred without blocking while shared descriptors or buffers are still in
use. Atlas/image copies use a dedicated command buffer and transfer fence;
replacement destroys the old resources only after those fences prove they are
unused. Queue/device-idle synchronization is reserved for final device
teardown. Device loss is propagated to the main loop, which
preserves the window, PTYs, terminal state, and CPU-side image store while
rebuilding the logical device and its dependent resources. Failed reconstruction
attempts remain pending with exponential retry delays bounded at 128 loop ticks
instead of terminating the application or spinning.

Diagnostics expose live object/byte/placement/frame counts; command, success,
error, install, eviction, placement, animation, transport, decode, allocation,
and chunk-cancellation counters; and GPU image-texture upload/cache-hit counts.
`graphics_replacement_benchmark_smoke` performs 1000 same-ID replacements by
default and accepts `TERMINAL_GRAPHICS_REPLACEMENT_ITERATIONS` for longer soak
runs. It asserts bounded lifetime while reporting throughput without a flaky
timing gate.

## Sixel

Sixel support includes DCS framing; DCS pixel-aspect selectors; `Pa`, `Pb`, and
`Ph` interpretation; raster attributes; repeat introducers; graphics carriage
return and newline; RGB and HLS palette definitions; transparent/background
modes; private and shared palette registers; vertical aspect expansion; DECSDM
page-origin behavior; Sixel scrolling/right-scroll modes; cursor advancement;
persistent placement; and the same decoded-byte/pixel-dimension limits as
other images.

The iTerm2 feature report advertises `Sx` only when this decoder is enabled.

## iTerm2 FILE transfers and inline images

The implemented and tested subset is:

- `OSC 1337;File=...` and the `MultipartFile`/`FilePart`/`FileEnd` form;
- inline images (`inline=1`) and non-inline arbitrary-file downloads
  (`inline=0`, also the default);
- built-in PNG and JPEG decoding to RGBA;
- native bounded animated GIF playback through the path-pinned Ada `giflib`;
- native bounded QuickDraw PICT rendering through the path-pinned Ada
  `pictlib`, including vector drawing, QuickDraw text with classic font-family
  mappings, and embedded QuickTime JPEG pictures; plus PDF and other extended
  decoding when a compatible MagickWand runtime and its format delegates or
  policies are available;
- `width` and `height` in cells, pixels, percentages, or `auto`;
- aspect-preserving fit by default and explicit stretching with
  `preserveAspectRatio=0`;
- default next-line cursor movement and `doNotMoveCursor=1`, committed only
  after the rendered image height is known;
- `size` as a non-binding progress hint, as required by the protocol;
- bounded metadata, Base64 input, decoded bytes, and pixel dimensions;
- borrowed native PICT input without a full encoded copy, direct rendering into
  the retained RGBA buffer,
  and structured Pictlib failure diagnostics;
- persistent placement and coexistence with Kitty and Sixel images.

Downloads are disabled by default and enabled with
`iterm2-file-downloads=allow`. The destination is the configured Downloads
directory; the implementation rejects traversal/control names and symlinked
targets, creates files with mode 0600, never overwrites an existing name, and
enforces the per-image byte limit. The optional `size` field remains a
non-binding progress hint as specified. Downloaded
content is format-agnostic, so GIF, PDF, PICT, archives, and other files are
preserved byte-for-byte. Inline PNG/JPEG/GIF/PICT decoding has no external
runtime dependency. Other media uses a dynamically discovered MagickWand
runtime, without adding a crate or link-time dependency, and remains bounded
by the same byte, dimension, frame-count, memory, map, disk, and time limits. Animated
GIF frames and delays enter the existing quota-accounted image object playback
model. Normal FILE commands have no success reply.

The feature report includes `F` only when both inline FILE display and the
policy-gated download path are enabled. This follows the feature definition's
combined transfer/display requirement without treating iTerm2's macOS decoder
formats as portable protocol requirements.

## Capability negotiation and identity

- Kitty `a=q` reports only media, formats, and compression enabled by the app's
  configured profile and access policy.
- `OSC 1337;Capabilities` responds with `Sx` when Sixel is available and adds
  `F` only when FILE downloads are explicitly enabled; byte-exact regressions
  prevent accidental over-advertising.
- Each spawned PTY receives the same launch-time `TERM_FEATURES` value (`Sx` or
  `FSx`) as that configured profile, including newly created tabs and panes.
- Graphics commands in non-visible tabs continue through protocol validation,
  object-store updates, replies, and input-order barriers. Off-screen processing
  does not claim an atlas upload has presented; the next visible frame performs
  that upload before its graphics events are committed.
- The PTY uses `TERM=xterm-256color`, `COLORTERM=truecolor`,
  `TERM_PROGRAM=bracke-terminal`, and the project version. It does not claim to
  be Kitty, iTerm2, or another emulator.
- tmux DCS passthrough is decoded recursively with escape unquoting and bounded
  nesting/input. Automated tests cover fragmented wrapped Kitty queries and raw
  response ordering without modifying persistent tmux sessions.

## Automated evidence

- `terminal_core/tests/core_graphics_stream_smoke.adb`: FIFO ordering,
  arbitrary fragmentation, complete core-owned chunks, cancellation, limits,
  and cursor-order barriers.
- `terminal_core/tests/core_graphics_fuzz_smoke.adb`: deterministic malformed
  and fragmented graphics corpus with bounded output/state.
- `terminal_core/fuzz/core_graphics_fuzz_target.adb`: process-per-testcase raw,
  Kitty, Sixel, iTerm2, and tmux target used by the scheduled AFL++ edge-coverage
  campaign, with a checked-in seed corpus and protocol dictionary.
- `terminal_glfw_vulkan_app/fuzz/graphics_pipeline_fuzz_target.adb`: bounded
  end-to-end AFL++ target that continues from core framing through the image
  decoders, object/placement store, quota enforcement, and retained renderer.
- `tools/bin/graphics_fuzz_runner`: Ada orchestration for both scheduled AFL++
  profiles, including pinned-Alire builds, coverage-map verification, bounded
  execution, process-tree shutdown, and crash/hang finding checks.
- `terminal_core/tests/core_image_cells_smoke.adb`: placeholder decoding and
  lifetime through text/screen operations.
- `terminal_core/tests/core_osc_smoke.adb` and `core_scrollback_smoke.adb`:
  Sixel modes, capability reporting, tmux passthrough, scrolling, and scrollback.
- `terminal_glfw_vulkan_app/tests/graphics_capabilities_smoke.adb`: raw, PNG,
  JPEG, zlib, Sixel, iTerm2, malformed-data, and pre-allocation limit coverage.
- `graphics_transport_smoke.adb`: regular/temp/shared-memory policy, offsets,
  limits, cleanup, and indistinguishable access failures.
- `renderer_metrics_smoke.adb` and `renderer_kitty_object_smoke.adb`: IDs,
  placements, geometry, deletion, relative placement, animation, quotas,
  eviction, screen lifetime, auxiliary persistence, and exact result codes.
- `kitty_control_matrix_smoke.adb`: table-driven coverage of all eight Kitty
  actions, all transmission/display/frame/composition/animation controls and
  their value domains, every lower/uppercase deletion selector, and invalid
  action/control combinations.
- `renderer_large_payload_smoke.adb`: transactions beyond the compatibility
  preview and multipart iTerm2 delivery.
- `image_media_smoke.adb` and `iterm2_media_smoke.adb`: native bounded GIF87a
  and GIF89a decoding, interlacing, transparency, sub-frame disposal and
  composition, frame-limit boundaries, finite/infinite/single-play animation,
  resource teardown, native PICT and optional PDF decoding, and animated-GIF
  storage/playback
  through the iTerm2 renderer.
- `vulkan_submit_smoke.adb`, `vulkan_device_smoke.adb`, and
  `diagnostics_smoke.adb`: atlas packing, content cache signatures, GPU resource
  lifecycle, and observability.
- `vulkan_recovery_smoke.adb`: immediate reconstruction, bounded exponential
  retry scheduling, incident accounting, and successful recovery reset.
- `tools/bin/external_graphics_clients_probe`: the Ada probe drives
  Chafa-generated direct/tmux Kitty
  streams and libsixel output pass through the public core and headless renderer
  and must produce successfully decoded retained images. The Chafa path covers
  metadata-only initial chunks, empty final chunks, and tmux Unicode
  placeholders.
- `tools/bin/tmux_graphics_passthrough_probe`: the Ada probe validates
  released-tmux passthrough on an
  isolated socket, including environment-update configuration, decoded image
  installation, and optional live presentation with `--present`.

The Linux CI installs and executes the external Chafa/libsixel and released-tmux
probes. It also makes `gui_present_smoke` mandatory under Xvfb, so unavailable
window-system or Vulkan presentation is a failure rather than a skip. The
headless suites validate semantics and command generation. The live probe
validates the installed tmux, Vulkan driver, compositor, swapchain transfer,
and framebuffer pixels using a deterministic color oracle. The latest executed
evidence is recorded in
[`graphics_release_validation.md`](graphics_release_validation.md).
