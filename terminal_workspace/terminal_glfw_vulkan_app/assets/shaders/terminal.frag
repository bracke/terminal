#version 450

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in vec4 frag_color;
layout(location = 2) in float frag_textured;
layout(location = 3) in float frag_texture_id;

layout(set = 0, binding = 0) uniform sampler2D text_atlas;

layout(location = 0) out vec4 out_color;

void main() {
    if (frag_textured > 0.5) {
        float coverage = texture(text_atlas, frag_uv).r;
        out_color = vec4(frag_color.rgb, frag_color.a * coverage);
    } else {
        out_color = frag_color;
    }
}
