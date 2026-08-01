uniform float iTime;
uniform vec2 screenSize;
uniform vec2 ttextureSize;

uniform Image noise1;
uniform Image noise2;
uniform Image trailMask;
uniform Image splashMask;

const float pixelSize = 2.0;
const float waveStrength = 0.008;
const float trailStrength = 0.7;
const float splashStrength = 2.0;
const float foamStrength = 1.4;
const float noiseScale1 = 1.35;
const float noiseScale2 = 5.0;
const vec2 scroll1 = vec2(0.03, 0.01);
const vec2 scroll2 = vec2(-0.02, 0.015);

// how many texture pixels outward to check for shoreline
const float edgeCheckPx = 2.0;

// how strong shoreline foam is
const float edgeFoamStrength = 1.65;
const float edgeNoiseScale = 3.0;

// how much the shader palette replaces the original lakebed color
// 0.0 = original texture only
// 1.0 = fully replace original texture
const float waterTintMix = 0.72;

vec2 pixelate(vec2 uv, vec2 texSize, float px) {
    vec2 p = floor(uv * texSize / px) * px;
    return p / texSize;
}

vec3 waterPalette(float t) {
    vec3 deep    = vec3(0.3255, 0.4745, 0.7333);
    vec3 mid     = vec3(0.4588, 0.7608, 0.8549);
    vec3 bright  = vec3(0.8118, 1.0, 0.9373);

    if (t < 0.33) return deep;
    if (t < 0.66) return mid;
    return bright;
}

float shorelineMask(Image tex, vec2 uv) {
    vec4 center = Texel(tex, uv);

    if (center.a <= 0.001) {
        return 0.0;
    }

    vec2 px1 = vec2(1.0) / ttextureSize;
    vec2 px2 = vec2(2.0) / ttextureSize;
    vec2 px3 = vec2(3.0) / ttextureSize;

    float min1 = min(
        min(Texel(tex, uv + vec2(-px1.x, 0.0)).a, Texel(tex, uv + vec2(px1.x, 0.0)).a),
        min(Texel(tex, uv + vec2(0.0, -px1.y)).a, Texel(tex, uv + vec2(0.0, px1.y)).a)
    );

    float min2 = min(
        min(Texel(tex, uv + vec2(-px2.x, 0.0)).a, Texel(tex, uv + vec2(px2.x, 0.0)).a),
        min(Texel(tex, uv + vec2(0.0, -px2.y)).a, Texel(tex, uv + vec2(0.0, px2.y)).a)
    );

    float min3 = min(
        min(Texel(tex, uv + vec2(-px3.x, 0.0)).a, Texel(tex, uv + vec2(px3.x, 0.0)).a),
        min(Texel(tex, uv + vec2(0.0, -px3.y)).a, Texel(tex, uv + vec2(0.0, px3.y)).a)
    );

    float edge1 = center.a - min1;
    float edge2 = center.a - min2;
    float edge3 = center.a - min3;

    // strongest right on the edge, then softer farther inward
    float mask1 = smoothstep(0.02, 0.20, edge1);
    float mask2 = smoothstep(0.02, 0.20, edge2);
    float mask3 = smoothstep(0.02, 0.20, edge3);

    return mask1 * 0.55 + mask2 * 0.30 + mask3 * 0.15;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    vec2 suv = screen_coords / screenSize;

    vec2 n1uv = suv * noiseScale1 + scroll1 * iTime;
    vec2 n2uv = suv * noiseScale2 + scroll2 * iTime;

    // use noise2 to warp noise1 a bit so it repeats less obviously
    float wx = Texel(noise2, fract(suv * 3.7 + vec2(0.03, -0.02) * iTime)).r - 0.5;
    float wy = Texel(noise2, fract(suv * 4.1 + vec2(-0.05, 0.01) * iTime)).r - 0.5;
    vec2 n2warp = vec2(wx, wy) * 0.06;

    float n1 = Texel(noise1, fract(n1uv + n2warp)).r;
    float n2 = Texel(noise2, fract(n2uv)).r;

    // compress contrast so noise1 does not read as a blotchy texture
    n1 = 0.5 + (n1 - 0.5) * 0.45;
    n2 = 0.5 + (n2 - 0.5) * 0.70;

    float trail = Texel(trailMask, suv).r;
    float splash = Texel(splashMask, suv).r;

    float localDistort = waveStrength
        + trail * trailStrength * 0.02
        + splash * splashStrength * 0.035;

    vec2 offset = vec2(
        (n1 - 0.5) + trail * 0.35 + splash * 0.90,
        (n2 - 0.5) + trail * 0.35 + splash * 0.90
    ) * localDistort;

    // pixelate in screen-space so the distortion feels crunchy
    vec2 distortedScreenUV = pixelate(suv + offset, screenSize, pixelSize);

    // convert that back to a local texture offset
    vec2 distortedUV = uv + (distortedScreenUV - suv);

    vec4 source = Texel(tex, distortedUV);

    float shade = n1 * 0.68 + n2 * 0.32;
    shade += trail * 0.05;
    shade += splash * 0.10;
    shade = clamp(shade, 0.0, 1.0);
    shade = 0.5 + (shade - 0.5) * 0.55;
    shade = floor(shade * 4.0) / 4.0;

    vec3 waterColor = waterPalette(shade);

    // shoreline foam uses sprite UV, not screen UV
    float edgeMask = shorelineMask(tex, uv);

    // animate shoreline foam so it does not look like a static outline
    float edgeNoise = Texel(noise1, fract(uv * edgeNoiseScale + vec2(0.0, 0.04) * iTime)).r;

    // sharper foam right at the edge
    float edgeFoamOuter = smoothstep(0.50, 0.82, edgeNoise) * smoothstep(0.55, 1.0, edgeMask);

    // softer foam farther inward
    float edgeFoamInner = smoothstep(0.60, 0.88, edgeNoise) * smoothstep(0.15, 0.65, edgeMask) * 0.45;

    float edgeFoam = edgeFoamOuter + edgeFoamInner;
    edgeFoam = floor(edgeFoam * 3.0) / 3.0;

    float foam = smoothstep(0.78, 0.96, n2 + splash * 0.70 + trail * 0.15);
    foam += edgeFoam * edgeFoamStrength;

    vec3 finalColor = mix(source.rgb, waterColor, waterTintMix);
    finalColor += foam * foamStrength * 0.28;

    return vec4(finalColor, source.a) * color;
}