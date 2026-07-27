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
  designations. CSI save/restore is supported as `CSI s` and `CSI u`; private
  or parameterized variants are diagnosed.
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
- Terminal-generated response bytes are held in a bounded core queue. If the
  queue is full, newest response bytes are dropped, already-queued byte
  ordering is preserved, and parser-overflow diagnostics are incremented.
  Core initialization, feed outcomes, and aggregate diagnostic counters also
  expose bounded status labels for app UI and logging surfaces.
  App PTY and input queues expose bounded pressure labels with occupancy and
  overflow counts for diagnostics/status surfaces. The GLFW app retains the
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
Core snapshots expose the last recognized graphics event with protocol, cursor
cell, payload length, and a 128 KiB bounded payload preview for protocol header
parsing and inline image rendering.
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
mapping from parser decode status to render-model image decode status for
renderer-owned image commands. The renderer accumulates bounded kitty `m=1`
raw or PNG continuation chunks as app-owned encoded segments beyond the core
128 KiB preview cap, decodes raw `f=24`/`f=32` chunks directly across those
segments, and decodes chunked kitty PNG Base64 directly across those segments
into an exact upper-bound PNG byte staging buffer used by the current PNG
decoder API. Raw kitty, PNG, and sixel decoded output buffers are sized to the
actual decoded byte count rather than the maximum cap. It renders the combined
payload when the final chunk arrives. It
also retains a heap-backed kitty `i=` image object table for later
placement-only kitty commands that reuse decoded pixels without resending image
data. Initial `i=` transmissions transfer decoded pixels into that table
without a second pixel copy, placements borrow stored pixels without copying
them into each frame, kitty delete actions can release individual IDs or the
full table, and the existing per-image decode/upload caps remain in place.
General file-format image decoding remains limited to PNG in the current draw
path, but the renderer model now has image commands for sixel, kitty, and iTerm2
placeholders plus a real textured path for complete bounded kitty raw RGB/RGBA
payloads with explicit `f=24` or `f=32` format and `s`/`v` pixel dimensions,
bounded kitty `f=100` PNG payloads, bounded sixel rasters decoded to RGBA
pixels, and bounded iTerm2 PNG payloads inflated through the local zlib crate.
The PNG path supports grayscale, RGB, indexed, grayscale-alpha, and RGBA images
across valid PNG bit depths, including palette, simple transparency chunks,
16-bit downconversion, and Adam7 interlace.
Image commands include total payload length, raw pixel format/dimensions,
2 MiB bounded encoded/app-accumulated payload metadata, an explicit payload-completeness
marker for complete bounded payload previews versus preview-only samples,
1 MiB capped decoded/upload data, plus a separate 4 KiB decoded diagnostics
preview byte buffer. The app renderer maps the snapshot
graphics event into either a protocol-tinted placeholder image command or a
texture-backed decoded image command, and the Vulkan submit path turns those
image commands into quads, so the draw pipeline can carry visible image
placeholders and real kitty/sixel/iTerm2 PNG image textures while retaining the last image
command's payload, preview counts, decoded diagnostics preview bytes, computed placeholder
dimensions, pixel dimensions, and image vertex counts in renderer diagnostics,
the submit batch, presenter diagnostics, and Vulkan device upload diagnostics.
The same
path carries an explicit placeholder flag so diagnostics distinguish current
placeholder quads from
texture-backed image commands. The submit/presenter/device boundary also marks
texture-requested image commands as downgraded when they are emitted through the
current placeholder-only path. The submit vertex model reserves a distinct
image texture source, retains the last image texture source through
submit/presenter/device diagnostics, tracks how many image vertices are
texture-backed, and the Vulkan device maps image texture vertices to a
shader-facing texture id for the raw kitty texture-upload path. Device upload
uses decoded RGBA buffers directly and only allocates exact RGBA staging when
raw RGB input needs alpha expansion. Current image
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
Full paragraph BiDi reordering and color emoji glyph rendering are still outside
the current draw path. Mixed-direction rows are detected and counted as
paragraph-BiDi fallbacks so that this missing reordering path is visible in
diagnostics. Emoji clusters are preserved and classified as emoji text runs, but
the renderer currently draws them through monochrome/font fallback paths rather
than layered color glyph/image glyph paths. Renderer diagnostics expose
paragraph-BiDi and color-emoji fallback counts along with aggregate shaped-glyph
counts, fallback-run counts, and bounded fallback status labels for those paths.
The app graphics capability surface reports emoji clusters as preserved with
monochrome fallback and no color glyph rendering.

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
primary scrollback; ED 2 clears only the visible screen. The GLFW app supports
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
anchor, and focus positions for future mouse UI routing without exposing the
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
through `?1006`. When reporting is enabled, the app sends mouse press, release,
and configured motion events to the PTY instead of starting local selection.
`Shift+Left` overrides reporting and starts/extends a local selection, matching
the common terminal escape hatch for copying text from mouse-aware programs.
The input mapper exposes a bounded mouse status label that distinguishes local
selection routing from terminal mouse-reporting routing, plus a combined
bounded input-mode status label that summarizes keyboard lock, paste, focus,
and mouse routing.
Button, drag, and any-event tracking are treated as exclusive xterm tracking
modes; enabling one clears the other two. SGR coordinates are an independent
encoding mode. Mouse wheel events are encoded as xterm wheel button packets,
including horizontal wheel packets, when reporting is enabled; otherwise the
GLFW app uses the wheel for app-owned scrollback viewing.
OSC 52 clipboard set and query requests are supported for bounded text
payloads, and `c`/`p`/`s` targets are recognized. Query responses are capped so
their OSC framing and base64 payload fit in one bounded app byte chunk.
The normal `c` target is backed by the native GLFW clipboard. Distinct
platform-native primary and selection clipboards remain postponed; the clipboard
module exposes this capability split with bounded status labels, and app-owned
bounded target slots are used for `p` and `s`.

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
target URI as a link hint. `Ctrl+Left Click` activation results are retained as
bounded activation outcome labels and included in the refreshed title/status
surface. The hyperlink helper exposes a bounded sanitized URI-only label and
bounded open/unsupported status label for future status/tooltip surfaces.
In-content tooltips and richer link previews remain postponed.

## TERM and Environment

The POSIX backend inherits the parent environment, sets `TERM=xterm-256color`,
and sets `COLORTERM=truecolor`. `$SHELL` is used when present and executable,
otherwise `/bin/sh`. The child creates a new session, opens the PTY slave as
the controlling terminal, duplicates it to standard input/output/error, and
execs the shell with `execv`. The PTY backend exposes these identity strings as
constants, and a PTY smoke verifies the exported terminal identity seen by the
child shell. The core unwraps tmux DCS passthrough payloads by collapsing
doubled ESC bytes and feeding the inner control sequence back through the normal
parser, with a diagnostic count; full tmux/screen session behavior remains
postponed. The app profile exposes a bounded multiplexer status label for this
distinction and a bounded diagnostic label for the handled passthrough count,
which is included in runtime diagnostics when passthrough has occurred.
The POSIX PTY package exposes a backend capability snapshot that marks POSIX
PTY, resize, terminal environment, and nonblocking reads as supported, and
Windows ConPTY as unsupported, with bounded backend and ConPTY status labels.
The app PTY write-all helper exposes bounded labels for complete, incomplete,
failed, and closed-session write outcomes. The app
package exposes the terminal profile advertised by the frontend:
`TERM=xterm-256color`, `COLORTERM=truecolor`,
bracketed paste, focus reporting, xterm mouse reporting with SGR coordinates,
DEC synchronized update, OSC 52 clipboard, OSC 8 hyperlinks, and truecolor
support. The profile also records tmux DCS passthrough and that OSC 52
primary/selection targets are app-local rather than platform-native, with a
bounded profile status label summarizing the advertised terminal identity.

## Config and Themes

The GLFW app reads app-owned configuration at startup. It first reads
`ADA_TERMINAL_CONFIG` when set, otherwise
`$XDG_CONFIG_HOME/ada-terminal/config`, otherwise
`$HOME/.config/ada-terminal/config`. The supported file keys are `theme`,
`color-theme`, `scrollback-limit`, `scrollback-rows`, `wheel-scroll-lines`, and
`scroll-lines`, `window-width`, `window-height`, `startup-rows`, and
`startup-cols`.
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
future help/status surfaces, plus bounded status labels for the selected theme,
window size, and startup grid.

## Tabs

The app has a bounded tab state model with up to eight tabs and app-owned
shortcut classification for `Ctrl+Shift+T`, `Ctrl+Shift+W`,
`Ctrl+Page_Down`, and `Ctrl+Page_Up`. These shortcuts are reserved by the app
instead of being sent to the PTY. When more than one tab exists, the window
title includes the active/count suffix, such as `[2/3]`. Full multi-session tab
rendering is still in progress; the current visible app owns one live
PTY/session. The tab model exposes bounded per-tab labels so a future tab bar
can render stable UI metadata before tabs own independent sessions. The active
tab label is updated from the bounded terminal title when OSC title changes are
processed. A public tab snapshot exposes count, active index, and bounded
labels for renderers, with helpers to extract and fit label text for a target
cell width. It also computes a deterministic tab-strip layout and column
hit-testing with a fixed minimum tab width and active-tab flags, plus
activate-by-column and close-by-column behavior for future mouse activation.
The tab model exposes a bounded status label that distinguishes the current
single live session from the postponed multi-session tab renderer.

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
for future mouse/input routing. Full split-pane rendering is still in progress;
the current visible app owns one live PTY/session. The split model exposes a
bounded status label that distinguishes the current single live pane from the
postponed split-pane renderer.

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
lock, paste, focus, and mouse routing for future status/help surfaces.
GLFW character events are encoded as UTF-8 only when they are valid Unicode
scalar values; surrogate code points and values above `U+10FFFF` are dropped at
the app boundary. Plain printable space is sent through the character callback;
modified Space is handled by the key callback for `Ctrl+Space` (`NUL`) and
`Alt+Space` (`ESC SP`); `Ctrl+Alt+Space` sends `ESC NUL`. Ctrl-letter keys
send C0 control bytes, and adding Alt prefixes the control byte with `ESC`.
Plain Backspace sends `DEL`; `Ctrl+Backspace` sends `BS`, `Alt+Backspace`
sends `ESC DEL`, and `Ctrl+Alt+Backspace` sends `ESC BS`.
