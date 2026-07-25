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
  (`ESC # 8`), keypad mode toggles, and G-set charset designation for ASCII
  and DEC special graphics. Coding-system designations `ESC % G` and `ESC % @`
  are consumed safely.
- SO/SI select G1/G0 for 7-bit GL text. SS2/SS3 single-shift one printable
  byte through G2/G3. DEC special graphics maps the common VT100 line-drawing
  range to Unicode box-drawing and symbol code points across G0 through G3.
- Saved cursor state includes row, column, and current SGR style.
- Saved cursor state also preserves the active G-set and G0 through G3 charset
  designations.
- CSI: cursor movement, CUP/CHA/HPA/HPR/VPA/VPR, CHT/CBT, TBC, ED, EL,
  ICH, DCH, ECH, IL, DL, REP, SU, SD, SGR, DECSET/DECRST known modes,
  SM/RM insert mode including bounded parameter lists, DECSTBM margins with at
  least two rows, and DECSTR soft reset (`CSI ! p`).
- DEC origin mode constrains vertical cursor movement to the active scrolling
  region for CUP/HVP, CUU/CUD, CNL/CPL, VPA, and VPR.
- DECSCUSR cursor-shape requests (`CSI Ps SP q`) select block, underline, or
  bar cursor shapes in the render snapshot.
- Xterm synchronized-update private mode (`DECSET`/`DECRST ?2026`) is tracked
  in mode state and queryable. The GLFW app defers live terminal redraws while
  it is active, while app-owned local redraws such as selection and scrollback
  remain immediate.
- DSR status (`CSI 5 n`), cursor-position report (`CSI 6 n`), DEC private
  cursor-position report (`CSI ? 6 n`), primary DA (`CSI c`), and secondary DA
  (`CSI > c`) responses.
- DECRQM mode reports (`CSI Ps $ p` and `CSI ? Ps $ p`) for insert mode,
  line-feed/new-line mode, known DEC private modes, and stateless `?1048`
  save/restore cursor mode.
- XTWINOPS window-state report (`CSI 11 t`) returns normal state as
  `CSI 1 t`, and window-position report (`CSI 13 t`) returns unknown position
  as `CSI 3 ; 0 ; 0 t`. Window pixel-size report (`CSI 14 t`) returns the
  app-provided framebuffer height and width as `CSI 4 ; height ; width t`.
  Character-cell size report (`CSI 16 t`) returns the app-provided renderer
  cell height and width as `CSI 6 ; height ; width t`. Text-area size report
  (`CSI 18 t`) returns current rows and columns as `CSI 8 ; rows ; cols t`.
  Window-title report (`CSI 21 t`) returns the bounded OSC title as
  `OSC l title ST`.
- Bounded OSC 0/1/2 window-title capture, applied by the GLFW app.
- Bounded DCS, SOS, PM, and APC payload consumption with BEL, ST, and C1 ST
  termination; payloads are ignored.
- Default tab stops every eight columns, plus `ESC H` tab-set and `CSI g`
  tab-clear handling.
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
`4:2`, `4:3`, `4:4`, and `4:5` are recognized and collapsed to the v1 boolean
underline style. Font selectors `10` through `19` are recognized and ignored.
Underline color selectors `58;5;n`, `58;2;r;g;b`, and reset `59` are recognized
and ignored because underline color is not stored in the v1 style model.
The GLFW app renders blink text with app-owned half-second phases; the
platform-independent core only stores the blink style state.
The GLFW app renders bold base 8-color foregrounds with the corresponding
bright foreground color and also overdraws the glyph by one pixel for weight.
Colon-separated SGR forms such as `38:5:n` and `48:2:r:g:b` are accepted as
aliases for the semicolon forms.

## Unsupported or Ignored

OSC payloads are bounded. BEL and ST (`ESC \`) termination are recognized.
OSC 0/1/2 update the app window title. OSC 8 hyperlinks and OSC 52 clipboard
are not implemented. Unknown OSC, escape, and CSI sequences are consumed safely
and recorded in diagnostics where applicable.

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
direction inference instead of treating every bidi control as RTL.
The app-layer HarfBuzz adapter shapes those runs against the selected font file
with direction, script, and script-derived language tags, and returns real font
glyph IDs, source clusters, advances, and offsets in the bounded shaped-glyph
output. Script tags are specific for Latin, Hebrew, Arabic, Devanagari,
Bengali, Gurmukhi, Gujarati, Oriya/Odia, Tamil, Telugu, Kannada, Malayalam,
Sinhala, Thai, Lao, Myanmar, Khmer, Javanese, Cham, CJK/Han, and emoji/common
runs. The shaping adapter also tries configured fallback font faces in the same
order as `textrender` when the primary face shapes a run with `.notdef` glyphs.
The default fallback list includes generic sans/symbol fonts plus script-specific
Noto fonts for Arabic, Hebrew, Indic, Southeast Asian, and CJK/Han coverage when
those files are installed and loadable by `textrender`. Each shaped glyph stores
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
not mutate terminal core state.

Mouse-aware terminal programs can enable basic xterm mouse reporting through
DEC private modes `?1000`, `?1002`, `?1003`, and SGR extended coordinates
through `?1006`. When reporting is enabled, the app sends mouse press, release,
and configured motion events to the PTY instead of starting local selection.
Button, drag, and any-event tracking are treated as exclusive xterm tracking
modes; enabling one clears the other two. SGR coordinates are an independent
encoding mode. Mouse wheel events are encoded as xterm wheel button packets
when reporting is enabled; otherwise the GLFW app uses the wheel for app-owned
scrollback viewing.
Advanced selection behavior and OSC 52 clipboard escape handling are postponed.

Focus reporting via DEC private mode `?1004` is supported. When enabled, the
app sends xterm focus-in and focus-out reports to the PTY as window focus
changes arrive from GLFW.

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
GLFW character events are encoded as UTF-8 only when they are valid Unicode
scalar values; surrogate code points and values above `U+10FFFF` are dropped at
the app boundary.
