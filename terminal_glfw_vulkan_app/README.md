# terminal_glfw_vulkan_app

Application crate that wires `terminal_core`, the platform-selected
`terminal_pty` backend, `glfw_vulkan`, and the Vulkan text-rendering adaptation
point together. `TERMINAL_PTY_OS=windows` selects ConPTY; the default selects
the POSIX backend used on Linux and macOS.

This crate links against system HarfBuzz (`libharfbuzz.so`) for shaped text-run
metadata. The current visible glyph path still uses `textrender` rasterization.

The renderer package is deliberately an adapter boundary: it consumes
`Terminal.Core.Render_Snapshot` plus complete staged graphics events and never
mutates terminal state. Protocol framing and encoded-source allocation are
delegated to `Terminal.App.Image_Ingestion`; format decoders remain separate
application-layer packages.

Graphics helpers keep protocol-independent responsibilities out of the main
renderer body. `Terminal.App.Image_Decode` supplies the canonical decode status
type, `Terminal.App.Image_Ingestion` owns payload boundaries and encoded-source
copies, `Terminal.App.Image_Store` owns install transactions and allocation
controls, `Terminal.App.Image_Placements` resolves crop and cell
geometry, and `Terminal.App.Image_Rendering` owns media admission and bounded
structured decoder diagnostics. `Terminal.App.Render_Model` owns final cleanup
of image-command buffers, including aliased decoded, encoded, and preview
views.
