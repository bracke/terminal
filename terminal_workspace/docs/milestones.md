# Milestones

## M1 Visible Shell

- Open a GLFW Vulkan window through `glfw_vulkan`.
- Create a Vulkan instance and a window surface through the shim-backed
  `glfw_vulkan` surface API.
- Initialize the Vulkan text renderer adapter.
- Spawn `$SHELL` in a Linux PTY.
- Show the shell prompt.
- Send printable keyboard input and Enter to the PTY.
- Validate `echo`, `cat`, `ls --color`, and `clear`.
- Propagate row/column resize to the core and PTY via `TIOCSWINSZ`.
- Close the window cleanly.

## Program Progression

1. `echo`, `cat`, `ls --color`
2. Shell prompt and line editing
3. `clear`
4. `git status`
5. `less`
6. `nano`
7. `vim`
8. `top`
9. Later: `htop`, `tig`, `lazygit`
10. Much later: `tmux`, `screen`

## Postponed

Mouse reporting, sixel, kitty graphics, iTerm2 images, OSC 8 hyperlinks, OSC 52
clipboard, ligatures, full emoji shaping, BiDi, advanced selection, tabs,
splits, themes, config, Windows ConPTY, and terminal multiplexer behavior.
