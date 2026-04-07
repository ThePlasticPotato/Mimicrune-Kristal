uniform float iTime;
uniform vec2 screenSize;

uniform Image noise1;
uniform Image noise2;
uniform Image trailMask;
uniform Image splashMask;

uniform float pixelSize;
uniform float waveStrength;
uniform float trailStrength;
uniform float splashStrength;
uniform float foamStrength;
uniform float noiseScale1;
uniform float noiseScale2;
uniform vec2 scroll1;
uniform vec2 scroll2;

vec2 pixelate(vec2 uv, vec2 texSize, float px) {
    vec2 p = floor(uv * texSize / px) * px;
    return p / texSize;
}

vec3 waterPalette(float t) {
    vec3 deep    = vec3(0.05, 0.20, 0.45);
    vec3 mid     = vec3(0.12, 0.42, 0.72);
    vec3 bright  = vec3(0.35, 0.78, 1.00);

    if (t < 0.33) return deep;
    if (t < 0.66) return mid;
    return bright;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    vec2 suv = screen_coords / screenSize;

    vec2 n1uv = suv * noiseScale1 + scroll1 * iTime;
    vec2 n2uv = suv * noiseScale2 + scroll2 * iTime;

    float n1 = Texel(noise1, fract(n1uv)).r;
    float n2 = Texel(noise2, fract(n2uv)).r;

    float trail = Texel(trailMask, suv).r;
    float splash = Texel(splashMask, suv).r;

    float localDistort = waveStrength
        + trail * trailStrength * 0.02
        + splash * splashStrength * 0.035;

    vec2 offset = vec2(
        (n1 - 0.5) + (trail - 0.5) * trailStrength + (splash - 0.5) * splashStrength,
        (n2 - 0.5) + (trail - 0.5) * trailStrength + (splash - 0.5) * splashStrength
    ) * localDistort;

    vec2 texSize = vec2(love_ScreenSize.x, love_ScreenSize.y);
    vec2 distorted = pixelate(suv + offset, texSize, pixelSize);

    vec4 base = Texel(tex, distorted);

    float shade = (n1 * 0.55 + n2 * 0.45);
    shade += trail * 0.08;
    shade += splash * 0.18;

    shade = floor(shade * 4.0) / 4.0;
    base.rgb = waterPalette(clamp(shade, 0.0, 1.0));

    float foam = smoothstep(0.70, 0.95, n1 + splash * 0.85 + trail * 0.2);
    base.rgb += foam * foamStrength * 0.18;

    return base * color;
}