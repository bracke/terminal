#!/bin/sh
#  Regenerate the SPIR-V the renderer loads, from the GLSL beside it.
#
#  The .spv files are committed, because the application loads them at run time
#  and a build here does not produce them. That is a standing invitation for the
#  two to drift: an edited shader that nobody recompiled changes nothing, and
#  says nothing about it either. Run this after touching a shader, and commit
#  both halves together.
#
#  Requires glslangValidator (Debian/Ubuntu: glslang-tools).
set -eu

dir="$(dirname "$0")/../terminal_glfw_vulkan_app/assets/shaders"

if ! command -v glslangValidator >/dev/null 2>&1; then
    echo "compile_shaders: glslangValidator not found (install glslang-tools)" >&2
    exit 1
fi

for stage in vert frag; do
    src="$dir/terminal.$stage"
    out="$dir/terminal.$stage.spv"
    echo "compile_shaders: $src -> $out"
    glslangValidator -V "$src" -o "$out"
done

echo "compile_shaders: completed"
