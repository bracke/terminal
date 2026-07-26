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
  remain immediate.
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
- DECRQM mode reports (`CSI Ps $ p` and `CSI ? Ps $ p`) for insert mode,
  line-feed/new-line mode, known DEC private modes including application keypad
  mode `?66`, and stateless `?1048` save/restore cursor mode. Missing, extra,
  and unsupported-private DECRQM parameters are diagnosed.
- Terminal-generated response bytes are held in a bounded core queue. If the
  queue is full, newest response bytes are dropped, already-queued byte
  ordering is preserved, and parser-overflow diagnostics are incremented.
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
  VT, and FF preserve the current column or first return to column one.
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
platform-independent core only stores the blink style state.
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
`textrender`. Each shaped glyph stores
the selected font index so the renderer can rasterize it from the matching
primary or fallback face. If HarfBuzz cannot load or shape the selected font or
run, the command remains explicitly marked as
`Needs_Shaping_Backend`. The renderer draws successful shaped runs through
`textrender` glyph-index rasterization; RTL shaped runs are placed from the
full coalesced run's right edge with HarfBuzz advance-aware pen movement, while
LTR runs are placed from the left edge. Fallback runs use the existing codepoint
glyph path and do not fabricate font glyph indexes from Unicode codepoints.
Runs shaped only to `.notdef` glyphs are rejected as shaped output: simple runs
fall back to codepoint rendering, while complex runs remain backend-needed. The
submit/presenter/device layers carry those runs without parsing terminal data.
Full paragraph BiDi reordering and color emoji glyph rendering are still outside
the current draw path. Renderer, submit, presenter, and device diagnostics
expose aggregate shaped-glyph counts and renderer fallback-run counts for that
path.

## Cursor

The core tracks cursor visibility, cursor blink state, and DECSCUSR cursor
shape. Supported shapes are block (`0`, `1`, `2`), underline (`3`, `4`), and
bar (`5`, `6`). DECSCUSR blinking variants and DEC private cursor blink mode
`?12` update the render snapshot state. The GLFW app renders cursor blinking
with app-owned half-second phases; the platform-independent core only exposes
the cursor blink state. Soft reset, full reset, and initialization return the
cursor shape to a steady block.

## Scrollback

Primary-screen scrollback is bounded by the initialize-time limit. The alternate
screen has no scrollback. Full terminal reset (`ESC c`) clears the visible
buffers and scrollback. Xterm ED 3 (`CSI 3 J`) clears the visible screen and
primary scrollback; ED 2 clears only the visible screen. The GLFW app supports
page-based scrollback viewing
with `Shift+Page_Up` and `Shift+Page_Down`; normal typing returns to the live
bottom.

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
Double-clicking selects the token under the pointer, where token characters
are letters, digits,
underscore, common shell path/URI characters, and non-ASCII letter-like cells.
Wide-character token runs can be selected across continuation cells.
Double-clicking punctuation outside that set selects that single cell.
Triple-clicking selects the visible row. Middle-click pastes the app-owned
primary selection slot when terminal mouse reporting is disabled.

Mouse-aware terminal programs can enable basic xterm mouse reporting through
DEC private modes `?1000`, `?1002`, `?1003`, and SGR extended coordinates
through `?1006`. When reporting is enabled, the app sends mouse press, release,
and configured motion events to the PTY instead of starting local selection.
Button, drag, and any-event tracking are treated as exclusive xterm tracking
modes; enabling one clears the other two. SGR coordinates are an independent
encoding mode. Mouse wheel events are encoded as xterm wheel button packets
when reporting is enabled; otherwise the GLFW app uses the wheel for app-owned
scrollback viewing.
OSC 52 clipboard set and query requests are supported for bounded text
payloads, and `c`/`p`/`s` targets are recognized. Query responses are capped so
their OSC framing and base64 payload fit in one bounded app byte chunk.
Distinct platform-native primary and selection clipboards remain postponed;
app-owned bounded target slots are used for `p` and `s`.

Focus reporting via DEC private mode `?1004` is supported. When enabled, the
app sends xterm focus-in and focus-out reports to the PTY as window focus
changes arrive from GLFW.

## Hyperlinks

OSC 8 hyperlink ranges are preserved by the platform-independent core as
bounded URI/id metadata on rendered cells. Starting `OSC 8 ; params ; uri ST`
applies the current hyperlink to subsequently printed cells; `OSC 8 ;; ST`
clears it. The GLFW app resolves links under the pointer from snapshots and
opens `http`, `https`, and `mailto` links with `Ctrl+Left Click` through the
desktop opener. Supported URI scheme matching is case-insensitive, and URIs
with bare schemes, spaces, or control bytes are rejected before launcher command
construction. Supported links under the pointer are underlined and use a hand
cursor. Tooltips and richer link UI remain postponed.

## TERM and Environment

The POSIX backend inherits the parent environment, sets `TERM=xterm-256color`,
and sets `COLORTERM=truecolor`. `$SHELL` is used when present and executable,
otherwise `/bin/sh`. The child creates a new session, opens the PTY slave as
the controlling terminal, duplicates it to standard input/output/error, and
execs the shell with `execv`.

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
primary-selection paste when mouse reporting is disabled.
GLFW character events are encoded as UTF-8 only when they are valid Unicode
scalar values; surrogate code points and values above `U+10FFFF` are dropped at
the app boundary. Plain printable space is sent through the character callback;
modified Space is handled by the key callback for `Ctrl+Space` (`NUL`) and
`Alt+Space` (`ESC SP`); `Ctrl+Alt+Space` sends `ESC NUL`. Ctrl-letter keys
send C0 control bytes, and adding Alt prefixes the control byte with `ESC`.
Plain Backspace sends `DEL`; `Ctrl+Backspace` sends `BS`, `Alt+Backspace`
sends `ESC DEL`, and `Ctrl+Alt+Backspace` sends `ESC BS`.
