struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@vertex
fn vs_main(
    @builtin(vertex_index) in_vertex_index: u32,
) -> VertexOutput {
    var out: VertexOutput;
    
    // Fullscreen triangle
    let x = f32((in_vertex_index << 1u) & 2u);
    let y = f32(in_vertex_index & 2u);
    
    out.clip_position = vec4<f32>(x * 2.0 - 1.0, y * 2.0 - 1.0, 0.0, 1.0);
    out.uv = vec2<f32>(x, y);
    
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let grid_size = 20.0;
    let dot_radius = 1.0;
    
    let scaled_uv = in.uv * 1000.0; // scale based on screen size
    let grid_uv = fract(scaled_uv / grid_size) * grid_size;
    
    let dist = length(grid_uv - vec2<f32>(grid_size * 0.5));
    
    // Dot rendering
    var alpha = 1.0 - smoothstep(dot_radius - 0.5, dot_radius + 0.5, dist);
    
    // Aurora glow effect based on cursor distance (mocked here, should use a uniform)
    let cursor_pos = vec2<f32>(500.0, 500.0);
    let dist_to_cursor = length(scaled_uv - cursor_pos);
    let glow = max(0.0, 1.0 - (dist_to_cursor / 200.0));
    
    alpha = alpha * 0.3 + glow * 0.2;
    
    return vec4<f32>(0.5, 0.5, 0.5, alpha);
}
