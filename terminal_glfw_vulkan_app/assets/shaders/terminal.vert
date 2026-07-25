#version 450

layout(location = 0) in vec2 in_position;
layout(location = 1) in vec2 in_uv;
layout(location = 2) in vec4 in_color;
layout(location = 3) in float in_textured;
layout(location = 4) in float in_texture_id;

layout(location = 0) out vec2 frag_uv;
layout(location = 1) out vec4 frag_color;
layout(location = 2) out float frag_textured;
layout(location = 3) out float frag_texture_id;

void main() {
    gl_Position = vec4(in_position, 0.0, 1.0);
    frag_uv = in_uv;
    frag_color = in_color;
    frag_textured = in_textured;
    frag_texture_id = in_texture_id;
}
