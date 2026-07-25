# Terminal MVP Scope

## Supported Core Behavior

- Byte-oriented feed API.
- UTF-8 decoding with replacement for malformed input.
- C0: BEL, BS, HT, LF, CR, ESC.
- ESC: reset, save/restore cursor, index, next line, reverse index, CSI, OSC,
  keypad mode toggles, and G-set charset-designation consume/ignore.
- Saved cursor state includes row, column, and current SGR style.
- CSI: cursor movement, CUP/CHA/HPA/HPR/VPA/VPR, CHT/CBT, TBC, ED, EL,
  ICH, DCH, ECH, IL, DL, REP, SU, SD, SGR, DECSET/DECRST known modes,
  SM/RM insert mode, DECSTBM margins, and DECSTR soft reset (`CSI ! p`).
- DECSCUSR cursor-shape requests (`CSI Ps SP q`) are consumed as no-ops; v0.1
  renders one cursor shape.
- DSR status (`CSI 5 n`), cursor-position report (`CSI 6 n`), primary DA
  (`CSI c`), and secondary DA (`CSI > c`) responses.
- Bounded OSC 0/1/2 window-title capture, applied by the GLFW app.
- Default tab stops every eight columns, plus `ESC H` tab-set and `CSI g`
  tab-clear handling.
- Autowrap with pending-wrap behavior.
- Primary and alternate screen buffers.
- Dirty row tracking.
- Renderer-neutral snapshots.

## SGR

Supported: reset, bold, italic, underline, inverse, normal intensity, style-off
codes including `21` as bold-off, 8-color foreground/background, bright
16-color variants, indexed `38;5;n` and `48;5;n`, truecolor `38;2;r;g;b` and
`48;2;r;g;b`, default foreground/background. Common unsupported style toggles
for dim, blink, conceal, strikethrough, and overline are consumed as no-ops.
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

## Scrollback

Primary-screen scrollback is bounded by the initialize-time limit. The alternate
screen has no scrollback. Full terminal reset (`ESC c`) clears the visible
buffers and scrollback.

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
