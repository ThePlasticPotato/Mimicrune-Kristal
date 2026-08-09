extern number warp;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Clickteam's Panorama mode does not use a radial/barrel warp. It keeps X
    // unchanged and progressively compresses the sampled Y range at the sides.
    float horizontal = texture_coords.x - 0.5;
    float vertical_scale = max(0.02, 1.0 - warp * 4.0 * horizontal * horizontal);
    vertical_scale = floor(vertical_scale * 230.0) / 230.0;
    vec2 source = texture_coords * vec2(1.0, vertical_scale)
        + vec2(0.0, (1.0 - vertical_scale) * 0.5);

    return Texel(texture, source) * color;
}
