# terminal_glfw_vulkan_app

Linux application crate that wires `terminal_core`, `terminal_pty_posix`,
`glfw_vulkan`, and the Vulkan text-rendering adaptation point together.

This crate links against system HarfBuzz (`libharfbuzz.so`) for shaped text-run
metadata. The current visible glyph path still uses `textrender` rasterization.

The renderer package is deliberately an adapter boundary: it consumes
`Terminal.Core.Render_Snapshot` and must not parse bytes or mutate terminal
state.
