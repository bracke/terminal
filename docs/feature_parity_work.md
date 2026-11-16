# Feature parity work

This checklist tracks the broad parity program requested on 2026-11-16. An
item is complete only when its public behavior, failure handling, documentation,
and deterministic regression coverage are present.

## Protocol and compatibility

- [x] Complete Kitty progressive keyboard protocol flags 1 through 16.
- [x] Native `bracke-terminal` terminfo source and resource installer.
- [x] Select native terminfo safely at runtime with an xterm fallback.
- [x] Complete paragraph-level Unicode bidirectional layout through FriBidi,
      including isolates, weak/neutral resolution, bracket pairing, mirroring,
      embedding levels, and pure-RTL right-edge placement.
- [x] Native platform primary/selection clipboards where available, using
      Wayland `wl-clipboard` with X11 `xsel` fallback and a bounded app mirror.
- [x] Native XIM/Windows IMM composition, bounded pre-edit presentation,
      committed Unicode delivery, and cursor-relative candidate positioning.

## Automation and sessions

- [x] Owner-only local control socket and command-line client.
- [x] Version-one scripting command schema and state inspection.
- [x] Persistent local multiplexer daemon and reconnectable frontend through
      named tmux-backed profiles (`persistent=true`, create-or-attach).
- [x] Profile-driven SSH connection reuse/keepalive and TLS domains with safe
      remote TERM fallback.
- [x] Nested mixed-orientation pane tree with draggable dividers and exact
      crash/workspace restoration.
- [x] Named layouts and named sessions with portable validated names, separate
      XDG config/state namespaces, exact tree persistence, and CLI selection.
- [x] Atomic periodic workspace autosave and crash layout/command recovery.
- [x] Session recording/replay and transcript export archive.
- [x] Process-aware pane/tab/window close confirmation (foreground process
      groups on POSIX; conservative live-process protection on ConPTY).

## Shells, connections, and files

- [x] Bash, Zsh, Fish, and Nushell OSC 7/133 integration scripts.
- [x] Automatic, configurable shell-integration injection.
- [x] Integrated SSH connection reuse, agent/key authentication, port/jump-host
      routing, remote terminfo bootstrap, and remote integration marker setup.
- [x] Serial, local-socket, container, and WSL profile domains.
- [x] Native file drag/drop with safe shell quoting, plus profile-aware SCP
      upload/download and SSH remote edit/open workflows.

## Interface and appearance

- [x] Complete settings/profile/binding UI with transactional import and atomic
      canonical export, plus equivalent command-line import/export workflows.
- [x] User-defined RGB/RGBA terminal colors, complete ANSI palette overrides,
      and bundled Solarized, Dracula, Gruvbox, Nord, and One Dark catalog.
- [x] OS theme following, opacity, blur, background images, padding, and tab
      styling.
- [x] Configurable OpenType feature strings, variable-font axes, and real
      bold/italic/bold-italic faces with synthetic fallback per missing style.
- [x] Quick/drop-down window mode, runtime visibility toggle, opacity,
      decorations, and always-on-top support.
- [x] In-app X11/Windows global-hotkey registration and focus-mode chrome
      suppression, including live config reload.
- [x] Runtime read-only mode with local selection and complete PTY-input blocking.
- [x] OSC 9;4 task progress and iTerm2 badge decoding with live overlay/title
      presentation.
- [x] Protected input and configurable output triggers, including blocked remote
      input/broadcast/OSC 52 access, per-session-stream matching, and cooldowns.
- [x] Bounded dynamic SSH profile discovery plus OSC progress/badge background
      task indicators.
- [x] Staged POSIX installer, reproducible release archive, desktop entry,
      AppStream metadata, and atomic local crash reports.
- [x] Minisign-enforced stable/beta/nightly update manifests plus generated
      Homebrew, Debian, WinGet, MSIX, and macOS package-feed metadata.
- [x] Broader native macOS and Windows desktop integration: native file drop,
      platform IME, global shortcuts, accessibility/window handles, DWM blur,
      ConPTY, Windows toast delivery, macOS Notification Center fallback, and
      signed bundle/package metadata.
