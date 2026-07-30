# Agent instructions — terminal

Linux GLFW/Vulkan terminal emulator application.

This crate pins its GNAT toolchain via Alire. Build and test with `alr`, not
system GNAT / GPRBuild / GNATprove / GNATdoc tools on `PATH` — `alr exec -- gnatls --version` must report the pinned GNAT.

```sh
alr build
```
