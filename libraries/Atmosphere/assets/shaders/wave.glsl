uniform float wave_sine;
uniform float wave_mag;
uniform float wave_height;
uniform vec2 texsize;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    number i = texture_coords.x * texsize.x;
    vec2 coords = vec2(max(0.0, min(1.0, texture_coords.x + 0.0)), max(0.0, min(1.0, texture_coords.y + (sin((i / wave_height) + (wave_sine / 30.0)) * wave_mag) / texsize.y)));
    return Texel(texture, coords) * color;
}