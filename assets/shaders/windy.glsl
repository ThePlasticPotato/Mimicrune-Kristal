uniform float iTime;
uniform float weatherSway;
uniform float windPhaseOffset;

// Main motion
const float wind_strength = 2.0;   // try 2.0 to 6.0
uniform float wind_speed;      // try 0.8 to 2.0
const float wind_scale = 0.02;      // try 0.01 to 0.04

// Gust layer
const float gust_strength = 0.5;   // try 0.5 to 2.5
const float gust_speed = 0.2;      // try 0.2 to 0.8
const float gust_scale = 0.003;      // try 0.003 to 0.015

// Direction of the wind in screen/local space
const vec2 wind_dir = vec2(1.0, 0.15);         // usually vec2(1.0, 0.15)

// How much the bottom stays anchored.
// 0.0 = whole tile moves the same
// 1.0 = top moves most, bottom barely moves
const float anchor_bottom = 0.0;

// Optional offset so multiple layers do not move identically
const vec2 layer_offset = vec2(0.0,0.0);

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    vec2 p = vertex_position.xy + layer_offset;
    float weather = clamp(weatherSway, 0.0, 1.5);
    float wind_time = iTime * wind_speed + windPhaseOffset;

    vec2 dir = normalize(wind_dir);

    // Make the top of the tile sway more than the bottom.
    // In local sprite/tile coords, smaller y is usually nearer the top.
    float topness = clamp(1.0 - (p.y / 32.0), 0.0, 1.0);
    float bend = mix(1.0, topness, anchor_bottom);

    // Base wave
    float wave1 = sin(p.x * wind_scale + wind_time);
    float wave2 = sin(p.y * (wind_scale * 0.7) + wind_time * 1.13);
    float sway = (wave1 + wave2 * 0.5) * wind_strength * (1.0 + weather * 0.9);

    // Gust wave
    float gust = sin((p.x + p.y) * gust_scale + wind_time * 0.25) * gust_strength * (1.0 + weather * 1.4);

    // Tiny flutter so it feels leafy instead of like a rigid sheet
    float flutter = sin((p.x * 0.13 + p.y * 0.21) + wind_time * 4.625) * 0.35 * (1.0 + weather * 0.6);

    vec2 offset = dir * (sway + gust) * bend;

    // Slight vertical lift/drop to feel softer
    offset.y = offset.y + flutter * bend * abs(dir.x) * 0.6;

    vertex_position.xy += offset;

    return transform_projection * vertex_position;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    return Texel(texture, texture_coords) * color;
}
