# Graphics parser coverage fuzzing

`core_graphics_fuzz_target` is a bounded, process-per-testcase target for the
terminal core. The first input byte selects raw (`R`), Kitty (`K`), Sixel (`S`),
iTerm2 (`I`), or tmux-wrapped Kitty (`T`) framing; lower-case selectors feed the
payload one byte at a time. All other first bytes exercise completely raw input.

Build and execute the seed corpus through the target with Alire:

```sh
cd terminal_core
alr exec -- gprbuild -p -P fuzz/core_graphics_fuzz.gpr
fuzz/bin/afl_coverage_smoke \
  fuzz/bin/core_graphics_fuzz_target \
  fuzz/corpus/kitty_query fuzz/corpus/sixel
for input in fuzz/corpus/*; do fuzz/bin/core_graphics_fuzz_target "$input"; done
```

The coverage smoke allocates the same System V shared map used by AFL++, runs
two distinct protocols through the instrumented target, and fails unless both
record coverage and produce different edge maps.

The deterministic smoke can also be promoted to a repeatable local soak without
AFL++ by setting `TERMINAL_GRAPHICS_FUZZ_ROUNDS` (capped at ten million) and
`TERMINAL_GRAPHICS_FUZZ_SEED` (an unsigned decimal 32-bit value):

```sh
TERMINAL_GRAPHICS_FUZZ_ROUNDS=250000 \
TERMINAL_GRAPHICS_FUZZ_SEED=3221344269 \
tests/bin/core_graphics_fuzz_smoke
```

Build the Ada fuzz runner and run a five-minute AFL++ campaign from the
repository root:

```sh
alr exec -- gprbuild -p -P tools/graphics_tools.gpr
tools/bin/graphics_fuzz_runner 300 fuzz/findings core
```

The fuzz project compiles the core with GCC `trace-pc` hooks and maps them into
AFL++'s shared edge map. GNAT remains pinned and invoked through Alire; no AFL
compiler wrapper replaces it. The output directory contains the resumable
queue, hangs, and crashes. Preserve interesting queue entries by reducing them
with `afl-tmin` and adding them to `fuzz/corpus`.
