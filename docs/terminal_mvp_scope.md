# Terminal MVP Scope

## Supported Core Behavior

- Byte-oriented feed API.
- UTF-8 decoding with replacement for malformed input.
- C0: BEL, BS, HT, LF, CR, ESC.
- C1: IND (`0x84`), NEL (`0x85`), HTS (`0x88`), RIS (`0x8C`), RI (`0x8D`),
  DCS (`0x90`), SOS (`0x98`), CSI (`0x9B`), OSC (`0x9D`), PM (`0x9E`), APC
  (`0x9F`), and ST (`0x9C`) are recognized as byte-oriented controls.
- ESC: reset, save/restore cursor, index, next line, reverse index, CSI, OSC,
  DEC screen alignment test (`ESC # 8`), keypad mode toggles, and G-set
  charset-designation consume/ignore.
- Saved cursor state includes row, column, and current SGR style.
- CSI: cursor movement, CUP/CHA/HPA/HPR/VPA/VPR, CHT/CBT, TBC, ED, EL,
  ICH, DCH, ECH, IL, DL, REP, SU, SD, SGR, DECSET/DECRST known modes,
  SM/RM insert mode, DECSTBM margins, and DECSTR soft reset (`CSI ! p`).
- DECSCUSR cursor-shape requests (`CSI Ps SP q`) select block, underline, or
  bar cursor shapes in the render snapshot.
- DSR status (`CSI 5 n`), cursor-position report (`CSI 6 n`), DEC private
  cursor-position report (`CSI ? 6 n`), primary DA (`CSI c`), and secondary DA
  (`CSI > c`) responses.
- DECRQM mode reports (`CSI Ps $ p` and `CSI ? Ps $ p`) for insert mode and
  known DEC private modes.
- Bounded OSC 0/1/2 window-title capture, applied by the GLFW app.
- Bounded DCS, SOS, PM, and APC payload consumption with BEL, ST, and C1 ST
  termination; payloads are ignored.
- Default tab stops every eight columns, plus `ESC H` tab-set and `CSI g`
  tab-clear handling.
- Autowrap with pending-wrap behavior.
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
overline `53`/`55`. Blink timing is not implemented yet; blink text currently
renders steadily.
Colon-separated SGR forms such as `38:5:n` and `48:2:r:g:b` are accepted as
aliases for the semicolon forms.

## Unsupported or Ignored

OSC payloads are bounded. BEL and ST (`ESC \`) termination are recognized.
OSC 0/1/2 update the app window title. OSC 8 hyperlinks and OSC 52 clipboard
are not implemented. Unknown OSC, escape, and CSI sequences are consumed safely
and recorded in diagnostics where applicable.

## Unicode Limitations

One decoded scalar value maps to one simplified character cell initially. Common
CJK ranges are treated as width two, with continuation cells cleared when either
half is overwritten, erased, or shifted apart. Combining marks are ignored.
Full grapheme clusters, emoji ZWJ sequences, shaping, and BiDi are postponed.

## Cursor

The core tracks cursor visibility and DECSCUSR cursor shape. Supported shapes
are block (`0`, `1`, `2`), underline (`3`, `4`), and bar (`5`, `6`). Blink
timing is not modeled in the core yet; blinking and steady variants currently
select the same shape. Soft reset, full reset, and initialization return the
cursor shape to block.

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
Selection is app-owned and does not mutate terminal core state.

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
Mouse reporting is app-owned and encoded from GLFW mouse events using xterm
legacy `CSI M` packets or SGR `CSI < ... M/m` packets according to the current
core mode snapshot.
