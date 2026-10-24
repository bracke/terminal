# terminal_glfw_vulkan_app

Application crate that wires `terminal_core`, the platform-selected
`terminal_pty` backend, `glfw_vulkan`, and the Vulkan text-rendering adaptation
point together. `TERMINAL_PTY_OS=windows` selects ConPTY; the default selects
the POSIX backend used on Linux and macOS.

This crate links against system HarfBuzz (`libharfbuzz.so`) for shaped text-run
metadata. The current visible glyph path still uses `textrender` rasterization.

The renderer package is deliberately an adapter boundary: it consumes
`Terminal.Core.Render_Snapshot` and must not parse bytes or mutate terminal
state.
