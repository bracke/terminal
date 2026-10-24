# Ada Terminal

Linux-first Ada 2022 terminal emulator.

The repository root is the Alire application crate:

```sh
alr build
./bin/terminal
```

System build/runtime prerequisites include GLFW, Vulkan loader/driver support,
and HarfBuzz (`libharfbuzz.so`) for app-layer text shaping.

Crates:

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
through bounded primary-screen scrollback.

Graphics support includes Kitty image objects and indexed/direct formats,
Unicode placeholders, animations, local transfer media under explicit policy,
persistent Sixel, iTerm2 inline PNG/JPEG/native GIF/PICT plus runtime PDF decoding,
and policy-gated arbitrary-file downloads. The exact
advertised surface, security defaults, quota
keys, and test evidence are recorded in
[`docs/graphics_protocol_conformance.md`](docs/graphics_protocol_conformance.md).
Executed release evidence and environment-specific blockers are recorded in
[`docs/graphics_release_validation.md`](docs/graphics_release_validation.md).

Build individual crates:

```sh
cd terminal_common && alr build
cd ../terminal_core && alr build
cd ../terminal_pty && alr build
cd ../glfw_vulkan && alr build
cd ../terminal_glfw_vulkan_app && alr build
```

Core smoke tests:

```sh
cd terminal_core
alr exec -- gprbuild -p -P tests/core_tests.gpr
tests/bin/core_smoke
tests/bin/core_sgr_smoke
tests/bin/core_modes_smoke
tests/bin/core_osc_smoke
tests/bin/core_utf8_smoke
tests/bin/core_alternate_smoke
tests/bin/core_scrollback_smoke
tests/bin/core_charset_smoke
tests/bin/core_cursor_smoke
tests/bin/core_damage_smoke
tests/bin/core_edit_smoke
tests/bin/core_insert_smoke
tests/bin/core_response_smoke
tests/bin/core_tabs_smoke
tests/bin/core_wide_smoke
tests/bin/core_wrap_smoke
tests/bin/core_graphics_stream_smoke
tests/bin/core_image_cells_smoke
tests/bin/core_large_graphics_smoke
tests/bin/core_graphics_fuzz_smoke
```

PTY smoke tests:

```sh
cd terminal_pty
alr exec -- gprbuild -p -P tests/pty_tests.gpr
tests/bin/pty_status_smoke
tests/bin/pty_env_smoke
tests/bin/pty_resize_smoke
tests/bin/pty_close_smoke
```

App smoke tests:

```sh
cd terminal_glfw_vulkan_app
alr exec -- gprbuild -p -P tests/app_tests.gpr
tests/bin/colour_glyph_submit_smoke
tests/bin/app_profile_smoke
tests/bin/vulkan_submit_smoke
tests/bin/vulkan_presenter_smoke
tests/bin/vulkan_recovery_smoke
tests/bin/vulkan_device_smoke
tests/bin/gui_present_smoke
tests/bin/shader_loader_smoke
tests/bin/font_discovery_smoke
tests/bin/text_shaper_smoke
tests/bin/renderer_metrics_smoke
tests/bin/renderer_kitty_object_smoke
tests/bin/renderer_large_payload_smoke
tests/bin/kitty_control_matrix_smoke
tests/bin/image_media_smoke
tests/bin/iterm2_media_smoke
tests/bin/iterm2_file_smoke
tests/bin/graphics_transport_smoke
tests/bin/graphics_replacement_benchmark_smoke
tests/bin/external_graphics_stream_probe /path/to/client-output.bin
tests/bin/pty_core_integration_smoke
tests/bin/pty_m1_commands_smoke
tests/bin/pty_program_progression_smoke
tests/bin/input_map_smoke
tests/bin/selection_smoke
tests/bin/hyperlink_smoke
tests/bin/clipboard_osc52_smoke
tests/bin/diagnostics_smoke
tests/bin/scrollback_view_smoke
tests/bin/render_policy_smoke
tests/bin/theme_config_smoke
tests/bin/graphics_capabilities_smoke
tests/bin/tabs_smoke
tests/bin/splits_smoke
tests/bin/sessions_smoke
tests/bin/session_runtime_smoke
tests/bin/session_table_smoke
tests/bin/session_hardening_smoke
tests/bin/cursor_blink_smoke
tests/bin/text_blink_smoke
tests/bin/queue_smoke
tests/bin/resize_smoke
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
