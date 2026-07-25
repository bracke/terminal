# Ada Terminal

Linux-first Ada 2022 terminal emulator.

The repository root is the convenient Alire application crate:

```sh
alr build
./bin/terminal
```

The implementation remains split under `terminal_workspace/` so the reusable
crates can later move to separate repositories:

- `glfw_vulkan`
- `terminal_common`
- `terminal_core`
- `terminal_pty_posix`
- `terminal_glfw_vulkan_app`
