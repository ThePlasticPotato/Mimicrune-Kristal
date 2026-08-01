const float saturation = 0.62;
const float blueAmount = 0.42;
const float dimAmount = 0.66;
const float contrast = 1.08;

const vec3 luminanceWeights = vec3(0.299, 0.587, 0.114);
const vec3 nightBlue = vec3(0.24, 0.34, 0.78);
const vec3 shadowBlue = vec3(0.05, 0.09, 0.22);

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 source = Texel(tex, texture_coords) * color;

    float luminance = dot(source.rgb, luminanceWeights);
    vec3 muted = mix(vec3(luminance), source.rgb, saturation);

    float shadowMask = 1.0 - smoothstep(0.10, 0.55, luminance);
    float tintMask = smoothstep(0.02, 0.80, luminance);

    vec3 deepBlue = mix(nightBlue, vec3(0.62, 0.70, 1.0), luminance);
    vec3 nightColor = vec3(luminance) * deepBlue;
    nightColor = mix(nightColor, shadowBlue * luminance, shadowMask * 0.55);

    vec3 finalColor = mix(muted, nightColor, blueAmount * tintMask);
    finalColor = (finalColor - 0.5) * contrast + 0.5;

    return vec4(clamp(finalColor * dimAmount, 0.0, 1.0), source.a);
}
