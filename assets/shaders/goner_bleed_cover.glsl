uniform float progress;
uniform float time;
uniform vec2 screen_size;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = screen_coords / screen_size;
    float column = floor(uv.x * 96.0);
    float noise = hash(column) * 0.22 + sin(column * 0.71 + time * 3.0) * 0.025;
    float edge = progress * 1.38 - noise;
    float cover = 0.0;

    if (uv.y < edge - 0.16) {
        cover = 1.0;
    } else if (uv.y < edge) {
        float band = (uv.y - (edge - 0.16)) / 0.16;
        cover = 1.0 - mix(0.08, 0.55, band);
    }

    return vec4(0.0, 0.0, 0.0, cover * color.a);
}
