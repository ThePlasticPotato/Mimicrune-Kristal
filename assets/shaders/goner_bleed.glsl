uniform float progress;
uniform float time;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    float column = floor(texture_coords.x * 96.0);
    float noise = hash(column) * 0.22 + sin(column * 0.71 + time * 3.0) * 0.025;
    float edge = progress * 1.38 - noise;
    float distance_to_edge = edge - texture_coords.y;

    vec2 uv = texture_coords;
    if (distance_to_edge > -0.18 && distance_to_edge < 0.05) {
        uv.y = clamp(uv.y - max(distance_to_edge, 0.0) * (0.7 + hash(column + 8.0)), 0.0, 1.0);
        uv.x += (hash(column + floor(time * 12.0)) - 0.5) * 0.006;
    }

    vec4 pixel = Texel(texture, uv) * color;
    if (texture_coords.y < edge - 0.16) {
        pixel.a = 0.0;
    } else if (texture_coords.y < edge) {
        pixel.rgb *= mix(0.08, 0.55, (texture_coords.y - (edge - 0.16)) / 0.16);
    }
    return pixel;
}
