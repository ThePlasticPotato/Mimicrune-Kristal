extern number iTime;
extern vec2 texsize;

// Settings
uniform float rainAmount;
uniform float zoom;
uniform float rainSpeed;
uniform float rainDensity;
uniform float glassFogginess;
uniform float glassClarity;
uniform float pixelSize;

#define S(a, b, t) smoothstep(a, b, t)

vec3 N13(float p) {
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.11369, 0.13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3(
        (p3.x + p3.y) * p3.z,
        (p3.x + p3.z) * p3.y,
        (p3.y + p3.z) * p3.x
    ));
}

float N(float t) {
    return fract(sin(t * 12345.564) * 7658.76);
}

float Saw(float b, float t) {
    return S(0.0, b, t) * S(1.0, b, t);
}

vec4 DropLayer2(vec2 uv, float t) {
    vec2 UV = uv;
    uv.y += t * 0.75;
    vec2 a = vec2(6.0, 1.0);
    vec2 grid = a * 2.0;
    vec2 id = floor(uv * grid);

    float colShift = N(id.x);
    uv.y += colShift;

    id = floor(uv * grid);
    vec3 n = N13(id.x * 35.2 + id.y * 2376.1);

    if (n.x > rainDensity) {
        return vec4(0.0);
    }

    vec2 st = fract(uv * grid) - vec2(0.5, 0.0);

    float x = n.x - 0.5;
    float y = UV.y * 20.0;
    float wiggle = sin(y + sin(y));
    x += wiggle * (0.5 - abs(x)) * (n.z - 0.5);
    x *= 0.7;
    float ti = fract(t + n.z);
    y = (Saw(0.85, ti) - 0.5) * 0.9 + 0.5;
    vec2 p = vec2(x, y);

    vec2 diff = st - p;
    float d = length(diff * a.yx);

    float mainDrop = S(0.4, 0.0, d);

    float r = sqrt(S(1.0, y, st.y));
    float cd = abs(st.x - x);
    float trail = S(0.23 * r, 0.15 * r * r, cd);
    float trailFront = S(-0.02, 0.02, st.y - y);
    trail *= trailFront * r * r;

    y = UV.y;
    float trail2 = S(0.2 * r, 0.0, cd);
    float droplets = max(0.0, (sin(y * (1.0 - y) * 120.0) - st.y)) * trail2 * trailFront * n.z;
    y = fract(y * 10.0) + (st.y - 0.5);
    float dd = length(st - vec2(x, y));
    droplets = S(0.3, 0.0, dd);
    float m = mainDrop + droplets * r * trailFront;

    return vec4(diff.x * a.x, diff.y * a.y, m, trail);
}

vec2 pixelateDropletUV(vec2 uv, float size) {
    return (floor(uv / size) + 0.5) * size;
}

float StaticDrops(vec2 uv, float t) {
    uv *= 40.0;
    vec2 id = floor(uv);
    uv = fract(uv) - 0.5;
    vec3 n = N13(id.x * 107.45 + id.y * 3543.654);

    if (n.x > rainDensity) {
        return 0.0;
    }

    vec2 p = (n.xy - 0.5) * 0.7;
    float d = length(uv - p);

    float fade = Saw(0.025, fract(t + n.z));
    float c = S(0.3, 0.0, d) * fract(n.z * 10.0) * fade;
    return c;
}

vec4 DropsWithOffset(vec2 uv, float t, float l0, float l1, float l2) {
    float s = StaticDrops(uv, t) * l0;
    vec4 m1 = DropLayer2(uv, t) * l1;
    vec4 m2 = DropLayer2(uv * 1.85, t) * l2;

    float c = s + m1.z + m2.z;
    c = S(0.3, 1.0, c);

    vec2 offset = vec2(0.0);
    float trail = 0.0;

    if (m1.z > m2.z) {
        offset = m1.xy;
        trail = m1.w;
    } else if (m2.z > 0.0) {
        offset = m2.xy;
        trail = m2.w;
    }

    trail = max(m1.w * l1, m2.w * l2);

    return vec4(c, trail, offset.x, offset.y);
}

vec2 pixelateScreen(vec2 fragCoord, float size) {
    return (floor(fragCoord / size) + 0.5) * size;
}

vec2 pixelateUV(vec2 uv, vec2 texSize, float size) {
    vec2 pixelCoord = uv * texSize;
    pixelCoord = (floor(pixelCoord / size) + 0.5) * size;
    return pixelCoord / texSize;
}

// vec3 sampleBlur(Image tex, vec2 uv, float focus) {
//     vec2 px = 1.0 / texsize;
//     float r = focus * 0.0015 * pixelSize;

//     // Snap the center and all taps to the same pixel grid
//     uv = pixelateUV(uv, texsize, pixelSize);

//     vec3 col = vec3(0.0);
//     col += Texel(tex, uv).rgb * 4.0;

//     col += Texel(tex, pixelateUV(uv + vec2( px.x,  0.0) * r, texsize, pixelSize)).rgb;
//     col += Texel(tex, pixelateUV(uv + vec2(-px.x,  0.0) * r, texsize, pixelSize)).rgb;
//     col += Texel(tex, pixelateUV(uv + vec2( 0.0,  px.y) * r, texsize, pixelSize)).rgb;
//     col += Texel(tex, pixelateUV(uv + vec2( 0.0, -px.y) * r, texsize, pixelSize)).rgb;

//     col += Texel(tex, pixelateUV(uv + vec2( px.x,  px.y) * r, texsize, pixelSize)).rgb;
//     col += Texel(tex, pixelateUV(uv + vec2(-px.x,  px.y) * r, texsize, pixelSize)).rgb;
//     col += Texel(tex, pixelateUV(uv + vec2( px.x, -px.y) * r, texsize, pixelSize)).rgb;
//     col += Texel(tex, pixelateUV(uv + vec2(-px.x, -px.y) * r, texsize, pixelSize)).rgb;

//     return col / 12.0;
// }

vec3 sampleBlur(Image tex, vec2 uv, float focus) {
    vec2 px = 1.0 / texsize;
    float r = focus * 0.0015;

    vec3 col = vec3(0.0);
    col += Texel(tex, uv).rgb * 4.0;

    col += Texel(tex, uv + vec2( px.x,  0.0) * r).rgb;
    col += Texel(tex, uv + vec2(-px.x,  0.0) * r).rgb;
    col += Texel(tex, uv + vec2( 0.0,  px.y) * r).rgb;
    col += Texel(tex, uv + vec2( 0.0, -px.y) * r).rgb;

    col += Texel(tex, uv + vec2( px.x,  px.y) * r).rgb;
    col += Texel(tex, uv + vec2(-px.x,  px.y) * r).rgb;
    col += Texel(tex, uv + vec2( px.x, -px.y) * r).rgb;
    col += Texel(tex, uv + vec2(-px.x, -px.y) * r).rgb;

    return col / 12.0;
}

// vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
//     // Snap the whole effect to a coarse grid first
//     vec2 snappedFragCoord = pixelateScreen(screen_coords, pixelSize);

//     vec2 uv = (snappedFragCoord.xy - 0.5 * texsize.xy) / texsize.y;
//     uv.y = -uv.y;

//     vec2 UV = snappedFragCoord.xy / texsize.xy;
//     float T = iTime;

//     uv *= zoom;
//     UV = (UV - 0.5) * zoom + 0.5;

//     float t = T * rainSpeed;
//     float rainAmt = rainAmount;

//     float staticDrops = S(-0.5, 1.0, rainAmt) * 2.0;
//     float layer1 = S(0.25, 0.75, rainAmt);
//     float layer2 = S(0.0, 0.5, rainAmt);

//     vec4 dropData = DropsWithOffset(uv, t, staticDrops, layer1, layer2);
//     float alpha = dropData.x;
//     float trail = dropData.y;
//     vec2 offsetToCenter = dropData.zw;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec2 fragCoord = screen_coords;

    // Smooth background sampling
    vec2 UV = fragCoord.xy / texsize.xy;

    // Procedural droplet coordinates
    vec2 uv = (fragCoord.xy - 0.5 * texsize.xy) / texsize.y;
    uv.y = -uv.y;

    float T = iTime;

    // Apply zoom first
    uv *= zoom;
    UV = (UV - 0.5) * zoom + 0.5;

    // Pixelate ONLY the droplet simulation space
    // Smaller divisor = stronger visible chunking control
    float dropletStep = max(pixelSize, 1.0) / texsize.y;
    uv = pixelateDropletUV(uv, dropletStep);

    float t = T * rainSpeed;
    float rainAmt = rainAmount;

    float staticDrops = S(-0.5, 1.0, rainAmt) * 2.0;
    float layer1 = S(0.25, 0.75, rainAmt);
    float layer2 = S(0.0, 0.5, rainAmt);

    vec4 dropData = DropsWithOffset(uv, t, staticDrops, layer1, layer2);
    float alpha = dropData.x;
    float trail = dropData.y;
    vec2 offsetToCenter = dropData.zw;

    float distFromCenter = length(offsetToCenter);
    float sizeDamping = mix(1.0, 0.4, alpha);
    float refractIndex = alpha * (1.0 - distFromCenter * 0.5) * sizeDamping;

    vec2 refractDir = normalize(offsetToCenter + vec2(0.51, 0.51));
    float strength = refractIndex * (0.03 + trail * 0.04);
    vec2 refraction = -refractDir * strength;

    float focus = mix(glassFogginess - trail * 2.0, glassClarity, S(0.1, 0.2, alpha));

    // Keep refraction sampling smooth
    vec2 sampleUV = clamp(UV + refraction, vec2(0.0), vec2(1.0));
    vec3 colOut = sampleBlur(tex, sampleUV, focus);

    float brightness = 1.0 + alpha * refractIndex * 0.3;
    colOut *= brightness;

    colOut *= S(0.0, 10.0, T);

    return vec4(colOut, 1.0) * color;
}
//     float distFromCenter = length(offsetToCenter);
//     float sizeDamping = mix(1.0, 0.4, alpha);
//     float refractIndex = alpha * (1.0 - distFromCenter * 0.5) * sizeDamping;

//     vec2 refractDir = normalize(offsetToCenter + vec2(0.51, 0.51));
//     float strength = refractIndex * (0.03 + trail * 0.04);
//     vec2 refraction = -refractDir * strength;

//     // Snap the refraction result too
//     vec2 sampleUV = clamp(UV + refraction, vec2(0.0), vec2(1.0));
//     sampleUV = pixelateUV(sampleUV, texsize, pixelSize);

//     float focus = mix(glassFogginess - trail * 2.0, glassClarity, S(0.1, 0.2, alpha));
//     vec3 colOut = sampleBlur(tex, sampleUV, focus);

//     float brightness = 1.0 + alpha * refractIndex * 0.3;
//     colOut *= brightness;
//     colOut *= S(0.0, 10.0, T);

//     return vec4(colOut, 1.0) * color;
// }