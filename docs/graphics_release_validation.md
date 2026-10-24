# Graphics release validation

Validation date: 2026-10-24.

This record separates deterministic protocol evidence from checks that require
a graphical login session. A skipped graphical check is not reported as a
pass.

## Target and environment

- Target: the current Kitty 0.50.0 graphics protocol, including indexed
  formats, Unicode and relative placements, animation, deletion, transfer
  media, and responses.
- Host: Linux 7.0.0-111030-tuxedo, x86-64.
- Ada tools through Alire: GNAT 15.2.0 and GPRbuild 25.0.0.
- Window/graphics packages: GLFW 3.3.10, Vulkan loader 1.4.315, and Vulkan
  tools 1.3.275.
- Available headless Vulkan device: llvmpipe, Mesa 26.1.6, Vulkan API 1.4.354.
- Interoperability tools: tmux 3.4, Chafa 1.14.0, and libsixel 1.10.3.

The repository's Alire-selected compiler was used unchanged.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Alire application build | Pass | `alr build` completes with the pinned toolchain. |
| Core graphics suites | Pass | Streaming, responses, placeholders, screen lifetime, limits, and deterministic malformed-input suites complete without failure. |
| Renderer/application suites | Pass | Image objects, placement identity, animation, resource quotas, atlas generation, recovery logic, and auxiliary protocols complete without failure. |
| POSIX PTY suites | Pass | Environment, resize, close, and status tests complete without failure. |
| External Kitty client | Pass | The Ada `tools/bin/external_graphics_clients_probe` feeds Chafa-generated Kitty APC through the public core and headless renderer, then requires a successfully decoded retained image. This also covers Chafa's metadata-only first chunk and empty final chunk. |
| External tmux-wrapped Kitty client | Pass | The same probe unwraps Chafa's tmux stream, resolves its Unicode-placeholder placement, and requires a successfully decoded retained image. |
| External Sixel client | Pass | The same probe feeds libsixel-generated DCS through the core and renderer and requires a successfully decoded retained image. |
| Released tmux passthrough | Pass | The Ada `tools/bin/tmux_graphics_passthrough_probe` uses a dedicated tmux 3.4 socket, enables passthrough, verifies `TERM`/`TERM_PROGRAM` updating, and observes the unwrapped Kitty APC at the outer pseudo-terminal. No persistent tmux server is touched. |
| Released tmux to Vulkan presentation | Pass | `tools/bin/tmux_graphics_passthrough_probe --present` incrementally feeds the actual outer tmux capture and requires its decoded image frame to reach the live GLFW/Vulkan presenter before tmux exit cleanup. |
| Kitty indexed formats | Pass | `renderer_kitty_object_smoke` covers `f=8`, `f=16`, special palette entries, alpha, byte quotas, and theme-change texture regeneration. |
| iTerm2 runtime media | Pass | `image_media_smoke` covers GIF87a stills, interlacing, transparency, sub-frame composition, disposal, frame limits, animated GIF, PDF, and PICT fixtures; `iterm2_media_smoke` verifies finite/infinite/single-play GIF timing, frame storage, playback, and stream teardown through the renderer. |
| Deterministic graphics parser soak | Pass | 1,000,000 randomized inputs across four seeds completed without invalid parser state, crash, or failed recovery. |
| Replacement/resource soak | Pass | 50,000 same-ID decoded-image replacements completed in 2.787659586 seconds (17,936 updates/s), ending with exactly one four-byte object and one placement. This is an observation, not a timing gate. |
| Vulkan loader/device enumeration | Pass | `vulkaninfo --summary` enumerates llvmpipe through the selected Vulkan ICD without surface creation. |
| GLFW/Vulkan surface presentation | Pass | `gui_present_smoke` created the window/surface/swapchain, submitted and presented a frame, rebuilt the presenter, and presented retained state again. |
| Vulkan framebuffer pixel comparison | Pass | `gui_present_smoke` enables transfer-source swapchain usage, copies the completed image to bounded host-visible memory, converts BGRA/RGBA ordering, and compares the center of a known image against its expected opaque-red pixel. The `--present` tmux path uses the same oracle. |

## Reproduction

Build and run the deterministic suites with Alire, then run:

```sh
alr exec -- gprbuild -p -P tools/graphics_tools.gpr
tools/bin/tmux_graphics_passthrough_probe
tools/bin/tmux_graphics_passthrough_probe --present
tools/bin/external_graphics_clients_probe
tools/bin/graphics_fuzz_runner 300 fuzz/findings core
tools/bin/graphics_fuzz_runner 300 fuzz/findings pipeline

terminal_glfw_vulkan_app/tests/bin/kitty_control_matrix_smoke

TERMINAL_GRAPHICS_FUZZ_ROUNDS=250000 \
TERMINAL_GRAPHICS_FUZZ_SEED=3221344269 \
terminal_core/tests/bin/core_graphics_fuzz_smoke

TERMINAL_GRAPHICS_REPLACEMENT_ITERATIONS=50000 \
terminal_glfw_vulkan_app/tests/bin/graphics_replacement_benchmark_smoke
```

The parser soak was repeated with seeds `305419896`, `3735928559`, and
`2654435769`. The tmux probe creates a process-specific server and always
destroys that server on exit.

`graphics_fuzz_runner` is the Ada AFL++ orchestrator used by the scheduled CI
campaign. It builds each instrumented target through pinned Alire, verifies an
input-sensitive coverage map, enforces the campaign deadline, terminates the
process tree, and fails when AFL++ records a crash or hang.

`--present` must be run inside a real X11 or Wayland session. It exercises the
released tmux server, terminal parser, image store, renderer, window creation,
swapchain creation, image upload/presentation, teardown, and reconstruction
from retained CPU state.

## Runtime boundary

- Inline GIF support is built in through the path-pinned Ada `giflib` crate,
  alongside built-in PNG and JPEG decoding. PDF/PICT support is available only
  when a compatible MagickWand runtime and the required coder/delegate policy
  are present. Diagnostics report that optional runtime-media surface only when
  the library can be loaded.
- Framebuffer readback is enabled only by the validation API; normal terminal
  presentation does not allocate or copy the readback buffer.

No known deviation exists for the advertised Kitty 0.50.0 capability surface.
The detailed feature matrix is in
[`graphics_protocol_conformance.md`](graphics_protocol_conformance.md).
