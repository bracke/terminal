# Ada Terminal

Linux-first Ada 2022 terminal emulator.

The repository root is the Alire application crate:

```sh
alr build
./bin/terminal
```

The root manifest pins the current `gnat_native` package at 15.2.1; invoke
compiler and project tools through `alr exec` so ignored local Alire state cannot
silently select a different toolchain.

System build/runtime prerequisites include GLFW, Vulkan loader/driver support,
HarfBuzz (`libharfbuzz.so`) for app-layer text shaping, and FriBidi
(`libfribidi.so`) for Unicode bidirectional paragraph layout.
Native Linux primary-selection interoperability is enabled when `wl-copy` and
`wl-paste` are available on Wayland, or `xsel` is available on X11.

Crates:

- `c_string_ownership`: neutral cancellation-safe temporary C-string owner.
- `glfw_vulkan`: reusable GLFW window/event/surface helper crate for Vulkan apps.
- `terminal_common`: platform-neutral byte and status types.
- `terminal_core`: deterministic byte-oriented terminal emulator core.
- `terminal_pty`: platform-selected POSIX PTY or Windows ConPTY session backend.
- `terminal_glfw_vulkan_app`: GLFW/Vulkan terminal application wiring crate.

The app currently creates a GLFW window, creates a `df_vulkan` Vulkan instance
with GLFW-required extensions, creates a Vulkan window surface, spawns the host
shell through the selected PTY backend, runs the queue-driven main loop, and
initializes the local `textrender` glyph rasterizer/atlas layer. `Ctrl+Shift+V`
and `Super+V` paste the GLFW
clipboard into the PTY, using bracketed paste mode when the terminal core says
it is enabled. Runtime visible-shell validation is tracked in
`docs/m1_runtime_validation.md`. `Shift+Page_Up` and `Shift+Page_Down` page
through bounded primary-screen scrollback. `Ctrl+Shift+F` searches retained
text; `Alt+R`, `Alt+C`, and `Alt+W` toggle regex, case, and whole-word modes,
while `Ctrl+Up`/`Ctrl+Down` browse search history. All visible matches are
underlined and the overlay reports the current/total match count.

Named persistent sessions and layouts use the same atomic versioned workspace
format as crash recovery:

```sh
./bin/terminal --session=project
./bin/terminal --layout=three-pane
```

Session names live under the XDG state directory; layout names live under the
XDG config directory. Names are portable and traversal-safe.
`Ctrl+Shift+Space` enters keyboard copy mode, and
`Ctrl+Shift+O` enters keyboard link mode for detected URLs and absolute paths.
Use arrows or Tab to choose a target, Enter to open it, and Escape to cancel.
`Ctrl+Shift+P` opens the searchable command/profile palette.
`Ctrl+Shift+Up` and `Ctrl+Shift+Down` jump between OSC 133 shell marks, while
the in-window scrollbar shows the current retained-history position. Tabs can
be clicked, closed with their `x` or middle click, and reordered by dragging;
split borders and the scrollbar are draggable. `Ctrl+Shift+U` opens a bounded
Unicode `U+` pre-edit overlay, with Enter/Space committing the scalar and
Escape cancelling it. Native XIM on X11 and IMM on Windows provide bounded
platform pre-edit text, committed Unicode, focus handling, and cursor-relative
candidate positioning. `Ctrl+Shift+B`, `Ctrl+Shift+Y`, and `Ctrl+Shift+R`
select, copy, or rerun the latest OSC 133 command block.
`Ctrl+Shift+Equal`/`Ctrl+Shift+Minus`/`Ctrl+Shift+0` adjust or reset font zoom.
`Ctrl+Shift+N` opens a process-backed window and `Ctrl+Shift+D` detaches the
active tab to a new window by handing off its working directory, label, and
startup command. `Ctrl+Comma` opens the settings/profile-line editor;
`Ctrl+Shift+Comma` transactionally reloads the configuration.
The settings editor also imports or exports a complete canonical configuration,
including custom colors, profiles, bindings, policy, and resource limits.
Headless equivalents are available for migration and backup:

```sh
./bin/terminal --export-config=/tmp/bracke-terminal.conf
./bin/terminal --import-config=/tmp/bracke-terminal.conf
```
`Ctrl+Shift+Z` zooms the active pane, `Ctrl+Shift+M` moves it to the next pane
position, and `Ctrl+Shift+I` broadcasts keyboard and paste input to every pane.
`Ctrl+Shift+G` starts or stops bounded output recording, `Ctrl+Shift+J` replays
the recording into matching live sessions, and `Ctrl+Shift+S` exports the
active session's retained transcript. The Vulkan content surface publishes the
active pane, cursor row, and interaction status through the sibling `a11y`
crate, using native AT-SPI when available and its validating fallback otherwise.
Font path, font size, and every app-owned shortcut are configurable.
`content-padding` controls the terminal inset; `tab-bar = auto|always|never`
and the three tab background color keys style tab chrome. Setting
`follow-system-theme = true` follows light/dark desktop changes at runtime
using GTK/KDE preferences (with `BRACKE_TERMINAL_COLOR_SCHEME` as an explicit
override). `background-blur = true` requests native compositor blur on
supported X11/KWin and Windows DWM desktops.
`background-image = PATH` decodes a bounded PNG, JPEG, GIF, or PICT through
the normal image pipeline and places its first frame below cell backgrounds;
`background-image-opacity = 0..100` controls its tint alpha.

The app restores and saves its tab/pane workspace under
`$XDG_STATE_HOME/ada-terminal/workspace` (or the corresponding home-state
path), including active session, labels, OSC 7 working directories, and bounded
startup commands. Desktop notifications accept OSC 9 and the title/body subset
of OSC 99. Bell and OSC 133 command-completion notifications are separately
opt-in with `bell-notifications` and `command-completion-notifications`.
Delivery uses `notify-send` on Linux, Notification Center through `osascript`
on macOS, and a native Windows toast launched by an encoded PowerShell command.
Recordings and transcript exports use the configured workspace path with
`.recording` and `.txt` suffixes, respectively.

Session profiles use bounded `profile.NAME.FIELD` keys. Fields are `shell`,
`command`, `cwd`, `environment` (comma-separated assignments), `theme`, `ssh`,
`serial`, `baud`, `socket`, `container`, `wsl`, and `tls`; `default-profile =
NAME` applies one to new sessions. SSH profiles launch
through the same palette and PTY lifecycle as local profiles.
Local profiles may set `persistent=true` to create or reconnect to a named tmux
daemon session. SSH profiles additionally support `ssh-identity`, `ssh-port`,
`ssh-jump`, and `ssh-setup`; the latter installs the bundled terminal identity
through the remote `tic` when available and exports a remote-integration marker.

`protected-input = true` confines keyboard and paste input to the active pane,
disables broadcast and remote-control injection, and prevents terminal-driven
OSC 52 reads or writes. Bounded `output-trigger.NAME = PATTERN` rules match
literal output across PTY read boundaries, isolate reused session streams, and
raise desktop notifications with a five-second per-rule cooldown.

Dropped files are inserted as safely single-quoted shell paths. SSH profiles
also drive `--upload=PROFILE LOCAL REMOTE`, `--download=PROFILE REMOTE LOCAL`,
`--remote-edit=PROFILE REMOTE`, and `--remote-open=PROFILE REMOTE`; these invoke
`scp`/`ssh` with direct argument vectors and inherit the profile's key, port,
and jump-host settings.

`global-hotkey = ctrl+alt+t` registers an OS-level X11/Windows shortcut that
toggles window visibility. `focus-mode = true` removes native window chrome;
both settings are applied by live config reload, and focus mode is also exposed
in the in-app settings panel.

Typography accepts `font-bold-path`, `font-italic-path`, and
`font-bold-italic-path` for real style faces. `font-features` takes comma-
separated HarfBuzz feature expressions such as `liga=0,kern=1`, while
`font-variations` takes axis coordinates such as `wght=625,wdth=90`; configured
faces share the existing bounded atlas and fall back to synthetic styling only
for styles without a dedicated path.

Release tooling emits minisign-protected stable, beta, and nightly manifests
with pinned size and SHA-256. Feed templates cover Debian `Signed-By` sources,
Homebrew, WinGet/MSIX, and macOS bundles; see
[`docs/update_channels.md`](docs/update_channels.md).

Graphics support includes Kitty image objects and indexed/direct formats,
Unicode placeholders, animations, local transfer media under explicit policy,
persistent Sixel, iTerm2 inline PNG/JPEG/native GIF/PICT, and policy-gated
arbitrary-file downloads. Native PICT rendering reports compatibility
approximations instead of silently claiming exact QuickDraw output. The exact
advertised surface, security defaults, quota
keys, and test evidence are recorded in
[`docs/graphics_protocol_conformance.md`](docs/graphics_protocol_conformance.md).
Executed release evidence and environment-specific blockers are recorded in
[`docs/graphics_release_validation.md`](docs/graphics_release_validation.md).

Build individual project targets through the root crate's pinned Alire
environment:

```sh
alr exec -- gprbuild -p -P c_string_ownership/c_string_ownership.gpr
alr exec -- gprbuild -p -P terminal_common/terminal_common.gpr
alr exec -- gprbuild -p -P terminal_core/terminal_core.gpr
alr exec -- gprbuild -p -P terminal_pty/terminal_pty.gpr
alr exec -- gprbuild -p -P glfw_vulkan/glfw_vulkan.gpr
alr exec -- gprbuild -p -P terminal_glfw_vulkan_app/terminal_glfw_vulkan_app.gpr
```

Core smoke tests:

```sh
alr exec -- gprbuild -p -P c_string_ownership/tests/c_string_ownership_tests.gpr
c_string_ownership/tests/bin/c_string_ownership_smoke
alr exec -- gprbuild -p -P terminal_core/tests/core_tests.gpr
for test in terminal_core/tests/bin/*_smoke; do "$test" || exit 1; done
```

PTY smoke tests:

```sh
alr exec -- gprbuild -p -P terminal_pty/tests/pty_tests.gpr
terminal_pty/tests/bin/pty_status_smoke
terminal_pty/tests/bin/pty_env_smoke
terminal_pty/tests/bin/pty_resize_smoke
terminal_pty/tests/bin/pty_close_smoke
terminal_pty/tests/bin/pty_spawn_failure_smoke
```

App smoke tests:

```sh
alr exec -- gprbuild -p -P terminal_glfw_vulkan_app/tests/app_tests.gpr
for test in terminal_glfw_vulkan_app/tests/bin/*_smoke; do "$test" || exit 1; done
```

Each smoke test runs in its own process so GLFW, Vulkan, renderer, and session
global state cannot leak between cases. Individual probes remain directly
executable for focused diagnostics:

```sh
terminal_glfw_vulkan_app/tests/bin/click_debounce_smoke
terminal_glfw_vulkan_app/tests/bin/gui_present_smoke
terminal_glfw_vulkan_app/tests/bin/graphics_replacement_benchmark_smoke
terminal_glfw_vulkan_app/tests/bin/external_graphics_stream_probe /path/to/client-output.bin
terminal_glfw_vulkan_app/tests/bin/pty_core_integration_smoke
terminal_glfw_vulkan_app/tests/bin/pty_m1_commands_smoke
terminal_glfw_vulkan_app/tests/bin/pty_program_progression_smoke
terminal_glfw_vulkan_app/tests/bin/image_pipeline_units_smoke
terminal_glfw_vulkan_app/tests/bin/image_store_smoke
```

`gui_present_smoke` includes a bounded Vulkan swapchain readback and pixel
oracle when a real display is available. Without a display it skips by default;
setting `TERMINAL_REQUIRE_GUI_PRESENT=1` makes that condition fatal, as in Linux
CI under Xvfb. The released-tmux version is
`tools/bin/tmux_graphics_passthrough_probe --present`. Build the Ada graphics
tools with:

```sh
alr exec -- gprbuild -p -P tools/graphics_tools.gpr
```

After editing either GLSL source, regenerate the committed SPIR-V files with
the Ada shader tool. It requires `glslangValidator` from `glslang-tools`:

```sh
tools/bin/compile_shaders
```

Coverage-guided graphics fuzzing keeps the pinned GNAT compiler and maps GCC
sanitizer-coverage edges into AFL++. The first target isolates the streaming
core parser; the second continues through decoding, image storage, placement,
and retained rendering:

```sh
alr exec -- gprbuild -p -P tools/graphics_tools.gpr
tools/bin/graphics_fuzz_runner 300 fuzz/findings core
tools/bin/graphics_fuzz_runner 300 fuzz/findings pipeline
```

The checked-in seed corpora can be run without AFL++ as described in
[`terminal_core/fuzz/README.md`](terminal_core/fuzz/README.md) and
[`terminal_glfw_vulkan_app/fuzz/README.md`](terminal_glfw_vulkan_app/fuzz/README.md).
