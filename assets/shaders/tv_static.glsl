extern number time;

float random(vec2 position)
{
    return fract(sin(dot(position, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    float frame = floor(time * 30.0);
    vec2 pixel = floor(screen_coords / 2.0);
    float noise = random(pixel + vec2(frame * 17.0, frame * 31.0));

    float fine_noise = random(screen_coords + vec2(frame * 43.0, frame * 11.0));
    noise = mix(noise, fine_noise, 0.35);

    float scanline = 0.88 + 0.12 * sin(screen_coords.y * 3.14159265);
    float band = step(0.985, random(vec2(floor(screen_coords.y / 3.0), frame))) * 0.35;
    float value = clamp(noise * scanline + band, 0.0, 1.0);

    return vec4(vec3(value), 1.0) * color;
}
