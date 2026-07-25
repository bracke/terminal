# Terminal MVP Scope

## Supported Core Behavior

- Byte-oriented feed API.
- UTF-8 decoding with replacement for malformed input.
- C0: BEL, BS, HT, LF, CR, ESC.
- ESC: reset, save/restore cursor, index, next line, reverse index, CSI, OSC,
  and charset-selection consume/ignore.
- CSI: cursor movement, CUP/CHA, default-tab CHT/CBT, ED, EL, ICH, DCH, ECH,
  IL, DL, SU, SD, SGR, DECSET/DECRST known modes, SM/RM insert mode, and
  DECSTBM margins.
- DSR status (`CSI 5 n`) and cursor-position report (`CSI 6 n`) responses.
- Bounded OSC 0/1/2 window-title capture, applied by the GLFW app.
- Autowrap with pending-wrap behavior.
- Primary and alternate screen buffers.
- Dirty row tracking.
- Renderer-neutral snapshots.

## SGR

Supported: reset, bold, italic, underline, inverse, normal intensity, style-off
codes, 8-color foreground/background, bright 16-color variants, indexed
`38;5;n` and `48;5;n`, truecolor `38;2;r;g;b` and `48;2;r;g;b`, default
foreground/background.

## Unsupported or Ignored

OSC payloads are bounded. BEL and ST (`ESC \`) termination are recognized.
OSC 0/1/2 update the app window title. OSC 8 hyperlinks and OSC 52 clipboard
are not implemented. Unknown OSC, escape, and CSI sequences are consumed safely
and recorded in diagnostics where applicable.

## Unicode Limitations

One decoded scalar value maps to one simplified character cell initially. Common
CJK ranges are treated as width two. Combining marks are ignored. Full grapheme
clusters, emoji ZWJ sequences, shaping, and BiDi are postponed.

## Scrollback

Primary-screen scrollback is bounded by the initialize-time limit. The alternate
screen has no scrollback.

## TERM and Environment

The POSIX backend inherits the parent environment, sets `TERM=xterm-256color`,
and sets `COLORTERM=truecolor`. `$SHELL` is used when present and executable,
otherwise `/bin/sh`. The child creates a new session, opens the PTY slave as
the controlling terminal, duplicates it to standard input/output/error, and
execs the shell with `execv`.
