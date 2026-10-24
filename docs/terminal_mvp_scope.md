# Terminal MVP Scope

## Supported Core Behavior

- Byte-oriented feed API.
- UTF-8 decoding with replacement for malformed input.
- C0: BEL, BS, HT, LF, VT, FF, CR, CAN, SUB, ESC.
- DEL (`0x7F`) is ignored outside string-control payloads.
- C1: IND (`0x84`), NEL (`0x85`), HTS (`0x88`), RIS (`0x8C`), RI (`0x8D`),
  SS2 (`0x8E`), SS3 (`0x8F`), DCS (`0x90`), SOS (`0x98`), CSI (`0x9B`),
  OSC (`0x9D`), PM (`0x9E`), APC (`0x9F`), and ST (`0x9C`) are recognized
  as byte-oriented controls.
- ESC: reset, save/restore cursor, index, next line, reverse index, DECID
  device attributes (`ESC Z`), CSI, OSC, DEC screen alignment test
  (`ESC # 8`), with unsupported screen-alignment selectors diagnosed and
  ignored, application/numeric keypad mode toggles, and G-set charset
  designation for ASCII
  (`B`/`@`) and DEC special graphics (`0`). Unsupported G-set charset
  selectors are diagnosed without changing the previous designation.
  Coding-system designations `ESC % G` and `ESC % @` are consumed safely;
  unsupported coding-system selectors are diagnosed and ignored.
- SO/SI select G1/G0 for 7-bit GL text. SS2/SS3 single-shift one printable
  byte through G2/G3. DEC special graphics maps the common VT100 line-drawing
  range to Unicode box-drawing and symbol code points across G0 through G3.
- Saved cursor state includes row, column, and current SGR style.
- The app exposes keypad Enter as CR in numeric keypad mode and `ESC O M` in
  application keypad mode. Printable keypad digits and operators use the
  character callback path in numeric mode and xterm-style `ESC O` application
  keypad sequences in application mode.
- DEC backarrow-key mode (`DECSET`/`DECRST ?67`) is tracked and queryable.
  Backspace sends DEL by default and BS while backarrow-key mode is enabled.
  Application cursor, application keypad, backarrow-key, and line-feed/new-line
  input translations expose a bounded key-mode status label for status/help UI.
- Saved cursor state also preserves the active G-set and G0 through G3 charset
  designations. CSI save/restore is supported as `CSI s` and `CSI u`;
  parameterized variants are diagnosed, and `CSI u` with a private marker is
  the progressive keyboard enhancement protocol below.
- CSI: cursor movement, CUP/CHA/HPA/HPR/VPA/VPR, CHT/CBT, TBC, ED, EL,
  ICH, DCH, ECH, IL, DL, REP, SU, SD, SGR, DECSET/DECRST known modes,
  SM/RM insert mode including bounded parameter lists, DECSTBM margins with at
  least two rows, media-copy/printer-control requests (`CSI Ps i` and
  `CSI ? Ps i`) as no-ops across bounded parameter lists, and DECSTR soft
  reset (`CSI ! p`) with no parameters.
- DEC origin mode constrains vertical cursor movement to the active scrolling
  region for CUP/HVP, CUU/CUD, CNL/CPL, VPA, and VPR.
- DECSCUSR cursor-shape requests (`CSI Ps SP q`) select block, underline, or
  bar cursor shapes in the render snapshot. Extra DECSCUSR parameters are
  diagnosed.
- Xterm synchronized-update private mode (`DECSET`/`DECRST ?2026`) is tracked
  in mode state and queryable. The GLFW app defers live terminal redraws while
  it is active, while app-owned local redraws such as selection and scrollback
  remain immediate. The render policy exposes bounded status labels for live,
  deferred, and local-redraw-bypass states.
- In-band resize reports (`DECSET`/`DECRST ?2048`): while the mode is set,
  every change of the grid, and of the cell size in pixels, is reported as
  `CSI 48 ; rows ; columns ; height ; width t`, the last two the text area in
  pixels. Setting the mode reports the current size at once; an unchanged
  resize request reports nothing. The mode is queryable with DECRQM.
- Progressive keyboard enhancement (kitty's keyboard protocol), flag 1 only
  (disambiguate escape codes): `CSI > flags u` pushes, `CSI < n u` pops, `CSI =
  flags ; mode u` sets, adds, or removes flags, and `CSI ? u` answers `CSI ?
  flags u`. Flags the terminal does not implement are dropped. The main and
  the alternate screen keep separate stacks of at most eight entries; a full
  stack loses its oldest entry, a full reset clears both, and a soft reset
  leaves them. The active flags are part of the mode snapshot.
- XTVERSION (`CSI > q`) answers `DCS > | bracke-terminal <version> ST`.
- The private identity query `OSC 7701 ; q ST` answers
  `OSC 7701 ; v=1 ; caps=<name>,... ST`, telling a program that it runs in
  this terminal and what it may use: `kgfx` (Kitty graphics), `kgfx-shm`
  (shared-memory transfer, when enabled), `kgfx-jpeg` and `kgfx-gif` (the
  private Kitty transmit formats below), `kbd` (keyboard enhancement),
  `resize2048` (in-band resize), and `osc52` (clipboard). Readers ignore names
  and keys they do not know, so the list can grow. `explore` in posix_tools
  uses it to refuse other terminals.
- Kitty graphics accepts two private transmit formats besides Kitty's own:
  `f=1001`, whose payload is a JPEG file, and `f=1002`, a GIF file, sent
  directly and uncompressed. They are decoded as iTerm2 inline images are,
  and a payload that is not what its code says is rejected as an unsupported
  format. Kitty's `f=100` remains PNG only.
- Keyboard action mode (`CSI 2 h`/`CSI 2 l`) is tracked in mode state and
  queryable. While locked, the GLFW app drops keyboard-generated input bytes
  such as key presses, character callbacks, and paste requests. The input
  mapper exposes bounded keyboard and combined input-mode status labels so this
  lock state can be shown without parsing modes directly.
- DSR status (`CSI 5 n`), DEC private operating status (`CSI ? 5 n`),
  cursor-position report (`CSI 6 n`), DEC private cursor-position report
  (`CSI ? 6 n`), primary DA (`CSI c`/`CSI 0 c`), and secondary DA
  (`CSI > c`/`CSI > 0 c`) responses. Extra DSR and DA parameters are
  diagnosed.
- DEC-specific DSR hardware/status probes return deterministic emulator
  defaults: printer not ready (`CSI ? 15 n` -> `CSI ? 11 n`), UDK unlocked
  (`CSI ? 25 n` -> `CSI ? 20 n`), North American keyboard
  (`CSI ? 26 n` -> `CSI ? 27 ; 1 ; 0 ; 0 n`), no locator
  (`CSI ? 53 n`/`CSI ? 55 n` -> `CSI ? 50 n`), and unknown locator type
  (`CSI ? 56 n` -> `CSI ? 57 ; 0 n`).
- DECRQM mode reports (`CSI Ps $ p` and `CSI ? Ps $ p`) for keyboard action
  mode, insert mode, line-feed/new-line mode, known DEC private modes including
  application keypad mode `?66` and backarrow-key mode `?67`, and stateless
  `?1048` save/restore cursor mode. Missing, extra, and unsupported-private
  DECRQM parameters are diagnosed.
- Terminal-generated responses are held in a bounded core queue. Each framed
  response is committed atomically; if it cannot fit, the complete newest
  response is dropped, already-queued framing and byte ordering are preserved,
  and parser-overflow diagnostics are incremented once for that response.
  Core initialization, feed outcomes, and aggregate diagnostic counters also
  expose bounded status labels for app UI and logging surfaces.
  App PTY and input queues expose bounded pressure labels with occupancy and
  overflow counts for diagnostics/status surfaces. PTY output applies lossless
  producer backpressure and has an explicit shutdown wakeup; input events retain
  drop-newest behavior. The GLFW app retains the
  last core feed outcome and PTY write outcome, then composes feed, write,
  core, queue, geometry, redraw-policy, scrollback, selection, hyperlink,
  clipboard, tabs, splits, config/profile, input-mode, mouse-routing, cursor
  blink, text blink, theme, font discovery, graphics, multiplexer, renderer,
  PTY backend, ConPTY capability, multiplexer capability/diagnostics, renderer,
  graphics header, graphics data preview, and presenter status labels into one
  deterministic runtime diagnostics line.
- DECRQSS status-string reports (`DCS $ q m ST`, `DCS $ q r ST`, and
  `DCS $ q SP q ST`) return current SGR state, scrolling margins, and
  DECSCUSR cursor style using 7-bit DCS/ST framing, BEL termination, or C1
  DCS/ST bytes; unsupported DECRQSS queries receive a negative
  `DCS 0 $ r ST` response. Malformed longer variants of otherwise supported
  DECRQSS payloads and missing status-string designators are rejected with the
  same negative response.
- XTWINOPS window-state report (`CSI 11 t`) returns normal state as
  `CSI 1 t`. XTWINOPS window action requests (`CSI 1 t` through `CSI 10 t`,
  including move and resize parameters) are recognized and ignored by the core
  because platform window control belongs outside terminal state. Window-position
  report (`CSI 13 t`) returns unknown position as `CSI 3 ; 0 ; 0 t`. Window
  pixel-size report (`CSI 14 t`) returns the app-provided framebuffer height
  and width as `CSI 4 ; height ; width t`, or `0 ; 0` before the app has
  provided dimensions.
  Screen pixel-size report (`CSI 15 t`) returns the same app-provided
  framebuffer size as `CSI 5 ; height ; width t`, or `0 ; 0` before the app
  has provided dimensions. Character-cell size report
  (`CSI 16 t`) returns the app-provided renderer cell height and width as
  `CSI 6 ; height ; width t`, or `0 ; 0` before the app has provided metrics.
  Text-area size report
  (`CSI 18 t`) returns current rows and columns as `CSI 8 ; rows ; cols t`.
  Screen-size report (`CSI 19 t`) returns the same grid size as
  `CSI 9 ; rows ; cols t`. Icon-label report (`CSI 20 t`) and window-title
  report (`CSI 21 t`) return the bounded OSC title as `OSC L title ST` and
  `OSC l title ST`; the current app has no separate icon label. Title stack
  operations (`CSI 22 t`, `CSI 23 t`, and their `;0`, `;1`, `;2` variants)
  save and restore one bounded title. Extra XTWINOPS report parameters and
  overlong title-stack parameter lists are diagnosed.
- Bounded OSC 0/1/2 window-title capture, clipped to 256 bytes and applied by
  the GLFW app.
- Bounded DCS, SOS, PM, and APC payload consumption with BEL, ST, and C1 ST
  termination; payloads are ignored.
- Default tab stops every eight columns, plus `ESC H` tab-set and `CSI g`
  tab-clear handling across bounded parameter lists.
- Autowrap with pending-wrap behavior.
- ANSI line-feed/new-line mode (`CSI 20 h`/`CSI 20 l`) controls whether LF,
  VT, and FF preserve the current column or first return to column one. The
  GLFW app also uses this mode for Return-key input, sending CR LF while it is
  enabled and CR while it is disabled. The app key mapper includes this
  translation in its bounded key-mode status label.
- Primary and alternate screen buffers.
- Dirty row tracking.
- Renderer-neutral snapshots.

## SGR

Supported: reset, bold, faint/dim, blink style state, italic, underline,
overline, inverse,
conceal, normal intensity, style-off codes including `21` as bold-off, 8-color
foreground/background, bright
16-color variants, indexed `38;5;n` and `48;5;n`, truecolor `38;2;r;g;b` and
`48;2;r;g;b`, default foreground/background, strikethrough `9`/`29`, and
overline `53`/`55`. Underline substyle selectors such as `4:0`, `4:1`,
`4:2`, `4:3`, `4:4`, and `4:5` are stored in snapshots; the renderer draws
single, double, curly, dotted, and dashed underline approximations. Font
selectors `10` through `19` are recognized and ignored.
Underline color selectors `58;5;n`, `58;2;r;g;b`, and reset `59` are recognized
and stored separately from foreground/background color.
The GLFW app renders blink text with app-owned half-second phases; the
platform-independent core only stores the blink style state. The text blink
helper exposes a bounded status label for inactive, visible, and hidden phases.
The GLFW app renders bold base 8-color foregrounds with the corresponding
bright foreground color and also overdraws the glyph by one pixel for weight.
Colon-separated SGR forms such as `38:5:n` and `48:2:r:g:b` are accepted as
aliases for the semicolon forms.

## Unsupported or Ignored

OSC payloads are bounded. BEL and ST (`ESC \`) termination are recognized.
OSC 0/1/2 update the app window title. OSC 52 clipboard set requests are
decoded from bounded base64 payloads by the core and applied to the system
clipboard by the GLFW app. OSC 52 clipboard query requests use a lone `?`
payload; they are detected by the core and answered by the app with a bounded
base64 OSC 52 response generated from GLFW clipboard text. OSC 52 targets `c`,
`p`, and `s` are recognized and exposed on the core request snapshot; `c` uses
the GLFW system clipboard, while
`p` and `s` use bounded app-owned target slots so they can round-trip
independently. Query responses preserve the requested `c`/`p`/`s` target
designator in the OSC 52 response. Unsupported OSC 52 target bytes are
diagnosed and the request is ignored. OSC 8 hyperlinks are parsed into bounded
per-cell snapshot metadata.
Unknown OSC, escape, and CSI sequences are consumed safely and recorded in
diagnostics where applicable. Unsupported private CSI markers such as `<`, `=`,
`?`, and `>` are recognized as private prefixes so their payloads do not leak
into the screen or execute unrelated public CSI finals.
Sixel DCS payloads, kitty graphics APC payloads, and iTerm2 `OSC 1337;File=`
payloads are recognized as graphics protocols, consumed without leaking payload
bytes into the screen, and counted in aggregate, per-protocol, and
last-protocol graphics diagnostics, including the last consumed payload length.
Core graphics commands are retained in arrival order by a configurable FIFO
with compiled ceilings of 4096 events and 16 MiB. Kitty APC accumulation has a
separately configurable 8 MiB ceiling and is independent of the compatibility
preview bound. The core validates and joins complete Kitty chunk transactions;
consumers can copy a stable payload or drain it incrementally.
Core snapshots continue to expose the last recognized graphics event with
protocol, cursor cell, payload length, and a 128 KiB bounded payload preview for
the existing diagnostics path. Queued commands carry a stable runtime stream ID and a
monotonic event sequence. The renderer guards state mutations with that pair
until successful presentation commits the frame and discards the corresponding
core event, so a swapchain retry cannot apply the same Kitty command twice.
The same commit carries the renderer's Kitty result back to the core. The core
verifies event identity, applies `q=1`/`q=2`, emits resolved image-number and
placement identities, and releases the FIFO head as one operation.
The embedding app supplies an explicit Kitty capability profile to the core;
the core never infers renderer support. Kitty `a=q` commands are handled
immediately and do not enter the graphics FIFO. Direct RGB, RGBA, PNG, zlib,
and policy-enabled regular-file, temporary-file, or shared-memory queries are
validated accurately, while unsupported combinations fail without changing
state. `q=1`/`q=2` suppress the corresponding success/error response class.
Query replies also work when the APC arrives through tmux DCS passthrough.
Kitty `U+10EEEE` image placeholders are stored as ordinary movable cells plus
renderer-neutral image metadata. The core decodes the low image-ID bytes from
foreground color, placement ID from underline color, and row, column, and
optional high image-ID byte from Kitty's official 297 combining diacritics.
Compatible preceding cells provide the protocol-defined omitted-coordinate
inheritance. This metadata survives the same scrollback, resize, edit, erase,
and alternate-screen operations as its cell. The renderer suppresses the
placeholder from glyph output. The app retains decoded `U=1` prototypes by
image and placement ID, matches visible cells to them after the graphics event
has been consumed, and emits cropped per-cell UV regions. The placement store
also retains conventional `a=p`/`a=T` placements with cursor anchors, explicit
placement IDs, crop rectangles, cell spans, pixel offsets, and z-index.
Explicit-ID `a=t` transmissions install data without creating a visible
placement. Both kinds persist after their APC events are consumed. The renderer
store is keyed by runtime stream and screen generation. Conventional placements
may be chained relative to conventional or virtual parents with signed cell
offsets. The renderer validates parent existence, cycles, and depth; derives a
virtual parent's origin from matching placeholder cells; and cascades parent
deletion through descendants. Core scroll events keep conventional anchors
aligned with full-screen, margin, and scrollback movement. Submission implements
the extreme-negative background tier, ordinary negative/text/non-negative
layers, deterministic equal-z ordering, and full-width signed z-index values.
Deletion selectors, relative-placement result codes, screen isolation, and
fence-gated GPU resource replacement are implemented.
The app graphics layer parses bounded kitty and iTerm2 preview headers,
including kitty format and `c`/`r` cell-span fields plus iTerm2 inline/name and
numeric width/height metadata, and uses that metadata to choose clamped
placeholder cell spans. It also splits bounded payload previews from headers,
reports encoded preview byte counts, and decodes a capped Base64 byte preview
for kitty and iTerm2 data while treating sixel raster data as non-Base64; the
runtime diagnostics line exposes both graphics header and data-preview status
labels, with short hex preview-byte fingerprints and decoded/partial markers
for decoded kitty/iTerm2 data plus bounded partial-decode reason labels for
invalid bytes, trailing data after padding, and preview truncation through a
public parser status suffix helper. The graphics layer also exposes a tested
shared decode status used by protocol parsing, general media decoding,
render-model image commands, and diagnostics. Allocation failures remain
distinguishable from malformed and oversized input without parallel enum
conversion tables. The core assembles Kitty continuations beyond
the 128 KiB preview cap and emits one complete bounded transaction. Raw
`f=24`/`f=32`, strict PNG `f=100`, and zlib paths decode through prevalidated
row/byte bounds. Raw, PNG, JPEG, and Sixel decoded buffers use exact decoded
lengths rather than maximum-cap allocations.

The unified object store retains Kitty IDs, image numbers, reusable pixels,
placements, usage hints, animation frames, composition, and playback state.
Placements borrow stored pixels; replacement, deletion, eviction, screen reset,
and session release update references deterministically. Limits for object
count, total/per-image bytes, placements, animation frames, pixel dimensions,
and the GPU atlas are configurable within compiled safety ceilings. Transient
unplaced objects are preferred eviction candidates, and current plus cumulative
resource behavior is exposed in diagnostics.
General file-format image decoding supports PNG, JPEG, GIF, and PICT in the
current draw path, and the renderer model has image commands for sixel, kitty, and iTerm2
placeholders plus a real textured path for complete bounded kitty raw RGB/RGBA
payloads with explicit `f=24` or `f=32` format and `s`/`v` pixel dimensions,
bounded Kitty `f=100` PNG payloads, bounded Sixel rasters decoded to RGBA
pixels, and bounded iTerm2 PNG/JPEG/GIF/PICT payloads. The PNG path is inflated through
the local zlib crate; JPEG is decoded through the local jpeglib crate, GIF
frames are decoded and composited through the local giflib crate, and PICT is
rendered through the local pictlib crate. PICT operations outside pictlib's
exact drawing surface use deterministic compatible output with structured
warnings; exact installed classic fonts can be selected through normalized
family or semantic `TERMINAL_PICT_FONT_*` environment overrides. Explicit
adapter buffer bytes and format-specific decoder configuration limits are
retained separately in renderer diagnostics. Container and font-library
allocations are outside the buffer metric. Pictlib decoder allocations share a
monotonic aggregate admission quota; allocator/runtime bookkeeping and GPU
storage remain separate. iTerm2 inline content enters the full media decoder at
most once; rejection does not invoke the preview decoder or emit a fallback
image. Media diagnostics are reset for every iTerm2 command before validation,
so non-inline or malformed commands cannot retain an earlier decoder result.
The PNG
path supports grayscale, RGB, indexed, grayscale-alpha, and RGBA images
across valid PNG bit depths, including palette, simple transparency chunks,
16-bit downconversion, and Adam7 interlace.
Non-inline iTerm2 FILE commands can save arbitrary byte content under an
explicit, disabled-by-default Downloads policy; exclusive no-follow creation,
safe filename validation, declared-size checks, and quotas bound that path.
Image commands include total payload length, raw pixel format/dimensions,
explicit payload-completeness, content serial, borrowed decoded pixels, and a
separate bounded diagnostics preview. The app renderer maps the snapshot
graphics event into either a protocol-tinted placeholder image command or a
texture-backed decoded image command, and the Vulkan submit path turns those
image commands into quads, so the draw pipeline can carry visible image
placeholders and real kitty/sixel/iTerm2 PNG/JPEG/GIF image textures while retaining the last image
command's payload, preview counts, decoded diagnostics preview bytes, computed placeholder
dimensions, pixel dimensions, and image vertex counts in renderer diagnostics,
the submit batch, presenter diagnostics, and Vulkan device upload diagnostics.
Render-model cleanup releases aliased decoded, encoded, and preview buffer views
exactly once and resets all ownership metadata before command reuse.
The same path carries an explicit placeholder flag so diagnostics distinguish
fallback quads from texture-backed image commands. The submit vertex model
reserves a distinct image texture source, retains the last source through
submit/presenter/device diagnostics, and tracks texture-backed image vertices.
Submission deduplicates shared image storage and packs distinct visible sources
into a configurable, padded RGBA atlas; per-command crop UVs are remapped to the
correct atlas slot before the Vulkan device uploads binding 1.
This prevents separate image objects from aliasing the final source uploaded in
a frame while allowing repeated placements to share one atlas entry. Content
serials form a deterministic atlas signature, so an unchanged visible set
reuses the resident GPU image instead of uploading it again. Fallback
placeholders continue to use untextured `texture=none` vertices.
Submit, presenter, and device helpers expose compact image texture readiness
labels for unavailable, downgraded, and ready states with texture-backed vertex
counts, and the Vulkan device exposes a resource-status label that reports
current placeholders as inactive, image texture vertices without a bound image
descriptor as pending, and uploaded raw image textures as ready, including image
texture descriptor bound/capacity counts; the presenter exposes that device resource
boundary through its own diagnostic helper. These compact labels are covered as
bounded status strings, and descriptor-count changes participate in runtime
diagnostic refresh detection. The app diagnostics layer also composes these
renderer, presenter, and device stages into one image texture pipeline status
with payload-completeness, texture-vertex, and descriptor progress, so runtime
diagnostics identify the current placeholder blocker, whether only a payload
sample is available, and texture-ready state without reading every
lower-level label separately. The presenter and device labels plus the composed
pipeline label are included in runtime diagnostics.
The path also carries the preview decode status so partial decode reasons
survive past the parser through a shared render-model status suffix. Renderer
diagnostics retain the last image command protocol, payload length, preview byte
counts, decoded diagnostics preview byte buffer, decode-complete flag, and decode-status
reason with
bounded submit, renderer, presenter, and device image status labels that include
a size marker, image vertex-count marker at presenter/device boundaries,
texture-source marker, texture-backed image vertex-count marker,
placeholder/textured marker, downgrade marker, and short hex preview-byte
fingerprint when decoded preview bytes are available. The renderer,
presenter, and device labels are surfaced in the runtime
diagnostics line when available.
The app
graphics capability surface reports these protocols as recognized and
texture-renderable for supported bounded payloads, with bounded capability
status labels. It also maps
core graphics diagnostic protocol values to display labels and bounded
ignored-payload status labels that include the last payload byte count when
available.

## Unicode And Text

Common CJK ranges, supplementary CJK ideograph planes, and common emoji /
pictograph scalar ranges are treated as width two, with continuation cells
cleared when either half is overwritten, erased, or shifted apart. Cells store a
bounded text cluster: one spacing base scalar plus up to eight attached scalars.
Common combining-mark ranges, zero-width joiner/non-joiner,
format controls, bidi marks, and variation selectors are attached to the
previous cell without advancing the cursor. VS16 promotes common
emoji-presentation base scalars to width two when there is room to add the
continuation cell in the same row. Keycap bases (`0` through `9`, `#`, and `*`)
plus enclosing keycap mark are also promoted to width two. Regional-indicator
pairs are kept as one two-cell flag cluster instead of two separate wide cells.
Emoji skin-tone modifiers attach to non-flag wide emoji clusters, including
clusters that already contain joined scalars. Emoji tag sequence scalars attach
to the preceding cluster for subdivision-flag preservation. When a cluster ends
in ZWJ, the next spacing scalar is attached to that cluster, preserving emoji
ZWJ sequences without consuming more grid cells; overflow is reported through
diagnostics. Selection and clipboard copy preserve stored cluster scalars.
Rendering submits the base scalar and overlays renderable combining-mark
attachments in the same cell, while invisible joiner, format-control, bidi,
variation-selector, tag, and joined emoji attachments remain non-drawing in the
current glyph fallback path. The app renderer also emits bounded text-run
commands that preserve the full stored cluster for each drawable cell, and the
`Terminal.App.Text_Shaper` adapter classifies run kind, direction, and script
directly on each text-run command. Compatible adjacent cells in a row are
coalesced up to the bounded text-run capacity, so ordinary text is available as
a run rather than only as one cell at a time. Coalescing splits at style,
cluster width, cursor, inferred script, and inferred direction boundaries.
Explicit LTR and RTL directional controls are distinguished during run
direction inference instead of treating every bidi control as RTL. ASCII digit
sequences are treated as strong left-to-right runs for renderer segmentation, so
they do not get folded into adjacent RTL shaping runs.
The app-layer HarfBuzz adapter shapes those runs against the selected font file
with direction, script, and script-derived language tags, and returns real font
glyph IDs, source clusters, advances, and offsets in the bounded shaped-glyph
output. Script tags are specific for Latin, Greek, Cyrillic, Glagolitic,
Coptic, Gothic, Old Italic, Old Persian, Ugaritic, Linear B, Cypriot,
Egyptian Hieroglyphs, Anatolian Hieroglyphs, Old Permic, Elbasan,
Caucasian Albanian, Mro, Bassa Vah, Pahawh Hmong, Linear A,
Phaistos Disc, Cuneiform, Lycian, Carian, Old Turkic, Medefaidrin,
Toto, Wancho, Armenian,
Deseret, Shavian, Osmanya, Osage, Bamum, Lisu, Miao, Nushu, Tangut,
Khitan Small Script, Georgian, Ethiopic, Cherokee, Hebrew, Arabic,
Syriac, Thaana, NKo,
Samaritan, Mandaic, Adlam, Hanifi Rohingya, Imperial Aramaic,
Palmyrene, Nabataean, Hatran, Phoenician, Lydian, Avestan,
Inscriptional Parthian, Inscriptional Pahlavi, Psalter Pahlavi,
Old South Arabian, Old North Arabian, Manichaean,
Tibetan, Devanagari, Bengali, Gurmukhi, Gujarati, Oriya/Odia, Tamil, Telugu,
Kannada, Malayalam, Sinhala, Brahmi, Kaithi, Chakma, Mahajani, Sharada,
Khojki, Khudawadi, Grantha, Newa, Tirhuta, Siddham, Modi, Takri, Ahom,
Dogra, Warang Citi, Dives Akuru, Nandinagari, Zanabazar Square, Soyombo,
Thai, Lao, Myanmar, Mongolian, Khmer, Javanese,
Limbu, Tai Le, New Tai Lue, Balinese, Sundanese, Batak, Lepcha, Ol Chiki,
Syloti Nagri, Phags-pa, Saurashtra, Kayah Li, Rejang, Buginese, Tai Tham,
Cham, Tai Viet, Meetei Mayek, Hiragana, Katakana, Bopomofo, Hangul, Yi,
Canadian Aboriginal syllabics, Ogham, Runic, Tifinagh, Vai, CJK/Han, and
emoji/common runs. The shaping adapter also tries configured fallback font
faces in the same order as `textrender` when the primary face shapes a run
with `.notdef` glyphs.
The default fallback list includes generic sans/symbol fonts plus script-specific
Noto fonts for Arabic, Hebrew, Indic and supplemental Indic, Southeast Asian,
Central Asian, RTL historic scripts, other historic scripts, minority scripts,
and CJK/Han coverage when those files are installed and loadable by
`textrender`. Font discovery exposes a bounded status label with primary font
availability, fallback count, and primary basename. Each shaped glyph stores
the selected font index so the renderer can rasterize it from the matching
primary or fallback face. If HarfBuzz cannot load or shape the selected font or
run, the command remains explicitly marked as
`Needs_Shaping_Backend`. The text shaper exposes bounded labels for backend
availability/load failures and shape outcomes. The renderer draws successful shaped runs through
`textrender` glyph-index rasterization; RTL shaped runs are placed from the
full coalesced run's right edge with HarfBuzz advance-aware pen movement, while
LTR runs are placed from the left edge. Fallback runs use the existing codepoint
glyph path and do not fabricate font glyph indexes from Unicode codepoints.
Runs shaped only to `.notdef` glyphs are rejected as shaped output: simple runs
fall back to codepoint rendering, while complex runs remain backend-needed. The
submit/presenter/device layers carry those runs without parsing terminal data.
Mixed-direction rows are visually reordered at the renderer text-run level:
RTL-base rows place logical runs from the right edge, and LTR-base rows reverse
contiguous RTL run groups in place. Paragraph-BiDi fallback diagnostics remain
available for unhandled reorder paths. Emoji clusters are preserved and
classified as emoji text runs, but
the renderer now tries `textrender` color glyph output before shaped monochrome
text. Layered COLR/CPAL emoji and bitmap CBDT/CBLC or sbix PNG strikes render
through a dedicated RGBA color-glyph sheet, separate from inline image textures.
Renderer diagnostics expose emitted color glyph counts, paragraph-BiDi and
color-emoji fallback counts, aggregate shaped-glyph counts, fallback-run counts,
and bounded fallback status labels for those paths.
The app graphics capability surface reports emoji clusters as preserved with
monochrome fallback available and color glyph rendering enabled.

## Cursor

The core tracks cursor visibility, cursor blink state, and DECSCUSR cursor
shape. Supported shapes are block (`0`, `1`, `2`), underline (`3`, `4`), and
bar (`5`, `6`). DECSCUSR blinking variants and DEC private cursor blink mode
`?12` update the render snapshot state. The GLFW app renders cursor blinking
with app-owned half-second phases; the platform-independent core only exposes
the cursor blink state. The cursor blink helper exposes a bounded status label
that summarizes shape, steady/blinking mode, and current visible/hidden phase.
Soft reset, full reset, and initialization return the cursor shape to a steady
block.

## Scrollback

Primary-screen scrollback is bounded by the initialize-time limit. The alternate
screen has no scrollback. Full terminal reset (`ESC c`) clears the visible
buffers and scrollback. Xterm ED 3 (`CSI 3 J`) clears the visible screen and
primary scrollback; ED 2 clears only the visible screen. Grid resize preserves
the scrollback ring in logical oldest-to-newest order, retaining shared columns
and blank-padding newly added columns. The GLFW app supports
page-based scrollback viewing
with `Shift+Page_Up` and `Shift+Page_Down`; normal typing returns to the live
bottom. The scrollback view helper exposes a bounded status label for live,
offset, and clamped-offset states.

## Selection and Clipboard

The GLFW app supports basic left-button drag selection over the currently
visible grid. Selected cells are rendered with inverse video, and releasing the
left button copies the selected visible text to the system clipboard as UTF-8.
Wide-character cells are selected as a pair and copied once even when the drag
range starts or ends on the continuation cell. Selection is app-owned and does
not mutate terminal core state. `Shift+Left Click` extends an existing
selection from its original anchor, or starts a new selection when no range is
active. Releasing a non-empty local selection also updates the app-owned OSC 52
primary and selection target slots. `Ctrl+Shift+C`, `Super+C`, and
`Ctrl+Insert` copy the current selection without sending bytes to the PTY.
Selection state exposes a public snapshot with active/range status, mode,
anchor, and focus positions for mouse UI routing without exposing the
private representation. The selection model exposes a bounded status label for
empty, linear, and rectangular selection states.
Double-clicking selects the token under the pointer, where token characters
are letters, digits,
underscore, common shell path/URI characters, and non-ASCII letter-like cells.
Wide-character token runs can be selected across continuation cells.
Double-clicking punctuation outside that set selects that single cell.
Triple-clicking selects the visible row. Middle-click pastes the app-owned
primary selection slot when terminal mouse reporting is disabled. `Alt+Left`
drag starts a rectangular selection that copies only the selected column range
from each selected visible row.

Mouse-aware terminal programs can enable basic xterm mouse reporting through
DEC private modes `?1000`, `?1002`, `?1003`, and SGR extended coordinates
through `?1006`. Legacy UTF-8 mouse coordinates (`?1005`) and urxvt
coordinates (`?1015`) are also tracked and encoded, with SGR preferred when
multiple coordinate encodings are enabled. When reporting is enabled, the app
sends mouse press, release, and configured motion events to the PTY instead of
starting local selection.
`Shift+Left` overrides reporting and starts/extends a local selection, matching
the common terminal escape hatch for copying text from mouse-aware programs.
The input mapper exposes a bounded mouse status label that distinguishes local
selection routing from terminal mouse-reporting routing, plus a combined
bounded input-mode status label that summarizes keyboard lock, paste, focus,
and mouse routing.
Button, drag, and any-event tracking are treated as exclusive xterm tracking
modes; enabling one clears the other two. UTF-8, SGR, and urxvt coordinates
are independent encoding modes. Mouse wheel events are encoded as xterm wheel
button packets, including horizontal wheel packets, when reporting is enabled;
otherwise the GLFW app uses the wheel for app-owned scrollback viewing.
OSC 52 clipboard set and query requests are supported for bounded text
payloads, and `c`/`p`/`s` targets are recognized. Query responses are capped so
their OSC framing and base64 payload fit in one bounded app byte chunk.
The normal `c` target is backed by the native GLFW clipboard and mirrored into
the bounded app target store. GLFW exposes no portable native primary/selection
clipboard API, so the clipboard module reports that capability split explicitly
with bounded status labels, and app-owned bounded target slots provide `p` and
`s` behavior.

Focus reporting via DEC private mode `?1004` is supported. When enabled, the
app sends xterm focus-in and focus-out reports to the PTY as window focus
changes arrive from GLFW. The input mapper exposes bounded focus status labels
for active and inactive reporting states.

## Hyperlinks

OSC 8 hyperlink ranges are preserved by the platform-independent core as
bounded URI/id metadata on rendered cells. Starting `OSC 8 ; params ; uri ST`
applies the current hyperlink to subsequently printed cells; `OSC 8 ;; ST`
clears it. The GLFW app resolves links under the pointer from snapshots and
opens `http`, `https`, and `mailto` links with `Ctrl+Left Click` through the
desktop opener. Supported URI scheme matching is case-insensitive, and URIs
with bare schemes, spaces, or control bytes are rejected before launcher command
construction. Supported links under the pointer are underlined and use a hand
cursor. While a supported link is hovered, the app window title includes the
target URI as a link hint and the renderer draws an in-content status overlay on
the active terminal row with the bounded open/unsupported link preview.
`Ctrl+Left Click` activation results are retained as bounded activation outcome
labels and included in the refreshed title/status surface. The hyperlink helper
exposes bounded sanitized URI-only and open/unsupported labels for these
surfaces.

## TERM and Environment

The POSIX backend inherits the parent environment, sets `TERM=xterm-256color`
and `COLORTERM=truecolor`, and publishes the truthful
`TERM_PROGRAM=bracke-terminal` plus `TERM_PROGRAM_VERSION=0.1.0-dev` identity,
both taken from `Terminal.Common.Identity`, which XTVERSION and the identity
query answer from too.
`$SHELL` is used when present and executable,
otherwise `/bin/sh`. The child creates a new session, opens the PTY slave as
the controlling terminal, duplicates it to standard input/output/error, and
execs the shell with `execv`. The PTY backend exposes these identity strings as
constants, and a PTY smoke verifies the exported terminal identity seen by the
child shell. The core unwraps tmux DCS passthrough payloads by collapsing
doubled ESC bytes and feeding the inner control sequence back through the normal
parser, with a diagnostic count. The app profile exposes a bounded multiplexer
status label for this passthrough support and a bounded diagnostic label for the
handled passthrough count, which is included in runtime diagnostics when
passthrough has occurred.
The PTY package exposes a backend capability snapshot with bounded backend and
ConPTY status labels. The POSIX-selected backend reports POSIX PTY, resize,
terminal environment, and nonblocking reads; the Windows-selected backend uses
ConPTY with resize, terminal environment publishing, and nonblocking reads via
pipe peeking.
The app PTY write-all helper exposes bounded labels for complete, incomplete,
failed, and closed-session write outcomes. The app
package exposes the terminal profile advertised by the frontend:
`TERM=xterm-256color`, `COLORTERM=truecolor`, the `bracke-terminal` program
identity, direct Kitty RGB/RGBA/PNG queries, Kitty Unicode placeholders,
bracketed paste, focus reporting, xterm mouse reporting with UTF-8, SGR, and
urxvt coordinate encodings, DEC synchronized update, OSC 52 clipboard, OSC 8
hyperlinks, and truecolor support. The profile also records tmux DCS passthrough and that OSC 52
primary/selection targets are app-local rather than platform-native, with a
bounded profile status label summarizing the advertised terminal identity.

## Config and Themes

The GLFW app reads app-owned configuration at startup. It first reads
`ADA_TERMINAL_CONFIG` when set, otherwise
`$XDG_CONFIG_HOME/ada-terminal/config`, otherwise
`$HOME/.config/ada-terminal/config`. The supported file keys include `theme`,
`color-theme`, `scrollback-limit`, `scrollback-rows`, `wheel-scroll-lines`,
`scroll-lines`, `window-width`, `window-height`, `startup-rows`,
`startup-cols`, the Kitty local-media policy keys (`kitty-file-transfer`,
`kitty-temporary-transfer`, and `kitty-shared-memory`), the disabled-by-default
`iterm2-file-downloads` policy, and the validated
`graphics-*` transaction, queue, deferred-input, object, byte, placement,
animation-frame, pixel-dimension, and GPU-atlas limits documented in
`graphics_protocol_conformance.md`.
`ADA_TERMINAL_THEME` can override the file-selected theme.
Supported theme values are `default`, `dark`, `default-dark`, `light`,
`high-contrast`, and `high_contrast`; unknown values fall back to the default
dark theme. The scrollback limit defaults to 10,000 rows, accepts zero, and is
bounded at 100,000 rows. Wheel scrollback movement defaults to three rows per
wheel event and is bounded to 1 through 100 rows. Window dimensions default to
960x600 pixels and are bounded to 1 through 16,384 pixels; startup fallback
grid dimensions default to 24x80 cells and are bounded to 1 through 1,000
cells. Resize helpers expose bounded grid and startup status labels for
framebuffer-derived and fallback cell dimensions. Themes currently control the
base 16-color palette, default
foreground/background, and cursor foreground/background used by renderer frame
commands. The config parser exposes line-level status for accepted entries,
blank/comment lines, malformed lines, unknown keys, and invalid values while the
startup loader continues to tolerate missing or unreadable config files, with
bounded labels for each line status. The config package exposes a stable
effective-config image for diagnostics and
help/status surfaces, plus bounded status labels for the selected theme,
window size, and startup grid.

## Tabs

The app has a bounded tab state model with up to eight tabs and app-owned
shortcut classification for `Ctrl+Shift+T`, `Ctrl+Shift+W`,
`Ctrl+Page_Down`, and `Ctrl+Page_Up`. These shortcuts are reserved by the app
instead of being sent to the PTY. When more than one tab exists, the window
title includes the active/count suffix, such as `[2/3]`. New tabs allocate
independent app-owned terminal cores, PTYs, PTY output queues, and reader tasks
through the bounded runtime table; tab navigation switches the active visible
runtime and routes input, clipboard replies, resize, scrollback, diagnostics,
and rendering through that active session. Every live runtime's PTY queue is
polled continuously, including background tabs, and terminal-generated replies
are written back through the runtime that owns the corresponding core. The
composited renderer draws a
visible tab strip using bounded per-tab labels and active-tab highlighting. The active
tab label is updated from the bounded terminal title when OSC title changes are
processed. A public tab snapshot exposes count, active index, and bounded
labels for renderers, with helpers to extract and fit label text for a target
cell width. It also computes a deterministic tab-strip layout and column
hit-testing with a fixed minimum tab width and active-tab flags, plus
activate-by-column and close-by-column behavior for mouse activation. The tab
model exposes a bounded status label for the live session count and active
index.

## Splits

The app has a bounded split-pane state model with up to four panes and
app-owned shortcut classification for `Ctrl+Shift+H`, `Ctrl+Shift+V`,
`Ctrl+Shift+X`, and `Ctrl+Shift+L`. These shortcuts are reserved by the app
instead of being sent to the PTY. When more than one pane exists, the window
title includes the active/count suffix, such as `pane 2/3`. The split model
also computes deterministic bounded pane rectangles from the available terminal
grid: the first split chooses row-wise or column-wise layout, and panes divide
that axis evenly. A public split snapshot exposes count, active index, and
orientation for renderers, with helpers to generate and fit pane labels for a
target cell width. The layout can also map a terminal row/column back to a pane
index, marks the active pane, activates the hit pane, and closes the hit pane
for mouse/input routing. New panes allocate independent app-owned terminal
cores, PTYs, PTY output queues, and reader tasks through the bounded runtime
table. Pane navigation switches the active runtime for input, clipboard replies,
scrollback, and diagnostics, while the composited renderer draws all visible
pane snapshots with active-pane chrome in one frame. Every pane PTY queue remains
live regardless of which pane owns keyboard focus. Split panes are live
sessions rather than placeholders. The split model exposes a bounded status
label for the live pane count and active index.

## Input Mapping

The app maps modified navigation keys with xterm-style modifier parameters:
Shift is `2`, Alt is `3`, Control is `5`, and combinations add those offsets
through `8`. Modified arrow/Home/End keys use `CSI 1 ; modifier final`;
modified Insert/Delete/Page keys use `CSI number ; modifier ~`.
Modified F1-F4 use `CSI 1 ; modifier P/Q/R/S`; modified F5-F12 use
`CSI number ; modifier ~` with the normal xterm function-key numbers.
Mouse reporting is app-owned and encoded from GLFW mouse events using xterm
legacy `CSI M` packets or SGR `CSI < ... M/m` packets according to the current
core mode snapshot.
`Ctrl+Shift+C`/`Super+C`/`Ctrl+Insert` are app-owned copy shortcuts and
`Ctrl+Shift+V`/`Super+V`/`Shift+Insert` are app-owned paste shortcuts. Plain
`Ctrl+C` remains terminal input. Unmodified middle-click is an app-owned
primary-selection paste when mouse reporting is disabled. Bracketed-paste mode
has a bounded status label so UI surfaces can distinguish bracketed and plain
paste routing. A combined bounded input-mode status label summarizes keyboard
lock, paste, focus, and mouse routing for status/help surfaces.
GLFW character events are encoded as UTF-8 only when they are valid Unicode
scalar values; surrogate code points and values above `U+10FFFF` are dropped at
the app boundary. Plain printable space is sent through the character callback;
modified Space is handled by the key callback for `Ctrl+Space` (`NUL`) and
`Alt+Space` (`ESC SP`); `Ctrl+Alt+Space` sends `ESC NUL`. Ctrl-letter keys
send C0 control bytes, and adding Alt prefixes the control byte with `ESC`.
Plain Backspace sends `DEL`; `Ctrl+Backspace` sends `BS`, `Alt+Backspace`
sends `ESC DEL`, and `Ctrl+Alt+Backspace` sends `ESC BS`.
While keyboard enhancement flag 1 is active, Escape is sent as `CSI 27 u`, and
keys typed with Alt, Control, or Super -- and Shift with Enter, Tab, or
Backspace -- as `CSI code ; modifiers u`, where the code is the character the
key types without Shift (13, 9, and 127 for Enter, Tab, and Backspace) and
the modifiers add Super as 8 to the xterm values. The character event GLFW
sends after such a key is suppressed. Plain keys, the keypad, and the cursor,
editing, and function keys keep their legacy encodings.
