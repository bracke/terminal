#version 450

layout(location = 0) in vec2 frag_uv;
layout(location = 1) in vec4 frag_color;
layout(location = 2) in float frag_textured;
layout(location = 3) in float frag_texture_id;

layout(set = 0, binding = 0) uniform sampler2D text_atlas;
layout(set = 0, binding = 1) uniform sampler2D image_texture;

//  Colour glyphs -- emoji -- packed into a sheet of their own. Not the image
//  texture: that holds one picture at a time for the inline-image protocols, and
//  a cell of emoji and a Sixel have to be able to share a frame.
layout(set = 0, binding = 2) uniform sampler2D colour_glyph_sheet;

layout(location = 0) out vec4 out_color;

void main() {
    if (frag_textured > 0.5) {
        if (frag_texture_id > 2.5) {
            //  A picture carries its own colour and alpha; the cell's colour
            //  says nothing about it.
            out_color = texture(colour_glyph_sheet, frag_uv);
        } else if (frag_texture_id > 1.5) {
            out_color = texture(image_texture, frag_uv) * frag_color;
        } else {
            float coverage = texture(text_atlas, frag_uv).r;
            out_color = vec4(frag_color.rgb, frag_color.a * coverage);
        }
    } else {
        out_color = frag_color;
    }
}
