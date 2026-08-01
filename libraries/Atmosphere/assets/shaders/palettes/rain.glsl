uniform float amount;
uniform float harshness;

const float saturation = 0.78;
const float blueAmount = 0.16;
const float dimAmount = 0.94;

const vec3 luminanceWeights = vec3(0.299, 0.587, 0.114);
const vec3 rainBlue = vec3(0.56, 0.66, 0.90);

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec4 source = Texel(tex, texture_coords) * color;
    float harsh = clamp(harshness, 0.0, 1.0);

    float luminance = dot(source.rgb, luminanceWeights);
    vec3 muted = mix(vec3(luminance), source.rgb, mix(saturation, 0.56, harsh));

    float tintMask = smoothstep(0.03, 0.45, luminance);
    vec3 harshBlue = vec3(0.34, 0.43, 0.76);
    vec3 coolGray = vec3(luminance) * mix(rainBlue, harshBlue, harsh);
    vec3 rainy = mix(muted, coolGray, mix(blueAmount, 0.34, harsh) * tintMask);

    vec3 finalColor = clamp(rainy * mix(dimAmount, 0.76, harsh), 0.0, 1.0);
    return vec4(mix(source.rgb, finalColor, clamp(amount, 0.0, 1.0)), source.a);
}
