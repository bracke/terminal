# M1 Runtime Validation

This checklist records user-facing validation for the real GLFW/Vulkan terminal
binary. Automated non-GUI smokes cover PTY/core/render-model behavior, but M1
also requires running the actual `terminal` window on a Linux desktop with a
working Vulkan driver.

## Environment

- Platform: Linux.
- Build command: `alr build`.
- Binary: `./bin/terminal`.
- Required runtime: `DISPLAY` or `WAYLAND_DISPLAY`, GLFW, Vulkan loader, and a
  Vulkan-capable graphics device.
- Optional automated display smoke:

```sh
cd terminal_glfw_vulkan_app
alr exec -- gprbuild -P tests/app_tests.gpr
tests/bin/gui_present_smoke
```

`gui_present_smoke` skips cleanly when no display or Vulkan path is available.

## Current Recorded Status

- Window opens: observed.
- Shell prompt visible: observed.
- Printable text input appears: observed.
- Text orientation: fixed after earlier upside-down-rendering pass.
- Cursor vertical placement: adjusted after earlier cursor alignment passes.
- Terminal content margin: implemented.
- `echo`: not yet recorded from an interactive GUI run.
- `cat`: not yet recorded from an interactive GUI run.
- `ls --color`: not yet recorded from an interactive GUI run.
- `clear`: not yet recorded from an interactive GUI run.
- Window resize updates terminal rows/cols: not yet recorded from an
  interactive GUI run.
- Resize propagates to PTY with `TIOCSWINSZ`: covered by non-GUI PTY smoke;
  not yet recorded through the interactive GUI.
- Window close exits cleanly: not yet recorded from an interactive GUI run.

## Manual M1 Checklist

Run from the repository root:

```sh
alr build
./bin/terminal
```

Validate these items in order:

1. A window opens with the title `Ada Terminal`.
2. The shell prompt is visible and upright.
3. Typed printable characters appear upright at the prompt.
4. Press `Enter`; the shell accepts the command line.
5. Run:

```sh
echo ADA_GUI_ECHO_OK
```

Expected: `ADA_GUI_ECHO_OK` appears once in the terminal output.

6. Run:

```sh
cat
ADA_GUI_CAT_OK
```

Then press `Ctrl+D`.

Expected: `ADA_GUI_CAT_OK` is echoed by `cat` and the shell prompt returns.

7. Run:

```sh
mkdir -p /tmp/ADA_GUI_LS_COLOR_DIR
LS_COLORS='di=01;34' ls --color=always -d /tmp/ADA_GUI_LS_COLOR_DIR
rm -rf /tmp/ADA_GUI_LS_COLOR_DIR
```

Expected: the directory name is visible with SGR color/style applied.

8. Run:

```sh
clear
```

Expected: the visible screen clears and the prompt returns at the top.

9. Resize the window.

Expected: the terminal grid changes size without corrupting text.

10. Run:

```sh
stty size
```

Expected: reported rows and columns match the resized visible grid.

11. Close the window.

Expected: the process exits without hanging and the child shell is closed.

## Recording A Pass

When the full GUI run passes, update `Current Recorded Status` above from
`not yet recorded` to `passed`, and add the date, compositor/session type, GPU
or Vulkan driver, and shell used here.
