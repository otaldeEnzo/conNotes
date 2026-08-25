#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture_input;
uniform float u_blur_radius;

out vec4 frag_color;

// Simple 9-tap Kawase-like dual filtering kernel for single pass
void main() {
    vec2 uv = FlutterFragCoord().xy / u_size;
    
    #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
    #endif

    vec2 texel = 1.0 / u_size;
    vec2 offset = texel * u_blur_radius;
    
    vec4 color = texture(u_texture_input, uv) * 4.0;
    
    color += texture(u_texture_input, uv + vec2(offset.x, offset.y));
    color += texture(u_texture_input, uv + vec2(offset.x, -offset.y));
    color += texture(u_texture_input, uv + vec2(-offset.x, offset.y));
    color += texture(u_texture_input, uv + vec2(-offset.x, -offset.y));
    
    color += texture(u_texture_input, uv + vec2(offset.x * 0.5, 0.0)) * 2.0;
    color += texture(u_texture_input, uv + vec2(-offset.x * 0.5, 0.0)) * 2.0;
    color += texture(u_texture_input, uv + vec2(0.0, offset.y * 0.5)) * 2.0;
    color += texture(u_texture_input, uv + vec2(0.0, -offset.y * 0.5)) * 2.0;
    
    frag_color = color / 16.0;
}
