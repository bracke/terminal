# Graphics pipeline coverage fuzzing

`graphics_pipeline_fuzz_target` drives complete framed graphics commands through
the terminal core, application decoders, image-object store, placement logic,
and headless renderer. The first input byte selects Kitty (`K`), Sixel (`S`),
iTerm2 (`I`), or tmux-wrapped Kitty (`T`) framing; lower-case selectors feed the
same protocol one byte at a time. Other first bytes exercise raw terminal input.

The target applies small core and renderer quotas, drains the ordered graphics
event and response queues, renders retained state, and verifies that object,
placement, frame, and byte accounting remain within those quotas.
The seed corpus includes native GIF and PICT iTerm2 payloads so their path-pinned
Ada decoders remain in the coverage surface.

Build and execute the checked-in corpus with the pinned Alire toolchain:

```sh
cd terminal_glfw_vulkan_app
alr exec -- gprbuild -p -P fuzz/graphics_pipeline_fuzz.gpr
fuzz/bin/afl_coverage_smoke \
  fuzz/bin/graphics_pipeline_fuzz_target \
  fuzz/corpus/kitty_rgba fuzz/corpus/kitty_png
for input in fuzz/corpus/*; do
  fuzz/bin/graphics_pipeline_fuzz_target "$input"
done
```

Run a five-minute AFL++ campaign:

```sh
alr exec -- gprbuild -p -P tools/graphics_tools.gpr
tools/bin/graphics_fuzz_runner 300 fuzz/findings pipeline
```

The Ada sources are compiled by pinned GNAT with GCC `trace-pc` hooks. The
small C coverage adapter maps those hooks into AFL++'s shared edge map; AFL
compiler wrappers do not replace GNAT. Reduce useful findings with `afl-tmin`
before adding them to the seed corpus.
