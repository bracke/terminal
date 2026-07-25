# terminal_glfw_vulkan_app

Linux application crate that wires `terminal_core`, `terminal_pty_posix`,
`glfw_vulkan`, and the Vulkan text-rendering adaptation point together.

The renderer package is deliberately an adapter boundary: it consumes
`Terminal.Core.Render_Snapshot` and must not parse bytes or mutate terminal
state.

