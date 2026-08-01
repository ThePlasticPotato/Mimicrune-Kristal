uniform vec3 shadow_color;
uniform float shadow_alpha;

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords)
{
    vec4 source = Texel(texture, uv) * color;

    if (source.a <= 0.0)
        return vec4(0.0);

    return vec4(shadow_color, min(shadow_alpha, source.a));
}