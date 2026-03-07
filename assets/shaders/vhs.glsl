extern number iTime;
extern vec2   texsize;
extern Image noiseTex;

uniform float noise_strength;  // overall noise add strength
uniform float stripes_strength;  // how strongly stripes use noise
uniform float noise_color_mix;  // 0=mono, 1=full color, between = partial
uniform float scroll_amp; // overall strength of vertical roll (~0.4 bydefault)
uniform float scroll_speed; // how fast the roll progresses
uniform float wobble_amp; // horizontal wiggle strength (was ~1/50 * big multiplier)
uniform float stripes_speed; // motion of the stripe mask (lower = calmer)
uniform float sweep_speed; // speed of the bright sweep band
uniform float sweep_amp; // amplitude of the sweep band (brightness variation)
uniform float seam_feather; // feather amt, prevents edges from wrapping weirdly (not really important if you dont have scroll or wobble)

vec3 noiseRGB(vec2 p)
{
    vec2 uv = fract(vec2(1.0, 2.0 * cos(iTime)) * iTime * 8.0 + p);
    vec3 n  = Texel(noiseTex, uv).rgb;
    n *= n;
    float g = dot(n, vec3(0.299, 0.587, 0.114)); // luma inline
    return mix(vec3(g), n, clamp(noise_color_mix, 0.0, 1.0));
}

float onOff(float a, float b, float c)
{
    return step(c, sin(iTime + a * cos(iTime * b)));
}

float ramp(float y, float start, float end)
{
    float inside = step(start, y) - step(end, y);
    float fact   = (y - start) / (end - start) * inside;
    return (1.0 - fact) * inside;
}

vec3 stripesRGB(vec2 uv)
{
    float t = mod(uv.y*4.0 + iTime*stripes_speed + 0.5*sin(iTime*0.6), 1.0);
    float mask = ramp(t, 0.5, 0.6); // narrow band

    vec3 n = noiseRGB(uv * vec2(0.5, 1.0) + vec2(1.0, 3.0));

    vec3 stripe = n * mask * stripes_strength;
	stripe = stripe * 2.0 + 0.2 * stripe; // extra additive push
	return clamp(stripe, 0.0, 1.0);
}

// Wrap inside [0,1], but zero out any contribution from coords outside [0,1]
vec4 sampleWrapNoTile(in Image tex, in vec2 uv)
{
    vec2 uvWrapped = fract(uv);
    // inRange = 1 when 0 <= uv <= 1 for both components
    vec2 inRange  = step(0.0, uv) * step(uv, vec2(1.0));
    float mask    = inRange.x * inRange.y; // 1 if both in-range, else 0
    return Texel(tex, uvWrapped) * mask;
}

vec4 sampleWrapNoTileFeather(in Image tex, in vec2 uv)
{
    vec2 uvWrapped = fract(uv);

    vec2 inRange = step(0.0, uv) * step(uv, vec2(1.0));
    float inside = inRange.x * inRange.y;

    float dY = min(uv.y, 1.0 - uv.y);
    float fadeY = smoothstep(0.0, seam_feather, dY);

    float mask = mix(fadeY, 1.0, inside);

    return Texel(tex, uvWrapped) * mask;
}


vec3 getVideo(vec2 uv, Image texture)
{
    vec2 look = uv;

    float dy = look.y - mod(iTime*0.25, 1.0);
    float window = 1.0 / (1.0 + 14.0 * dy * dy); // was 20.0

    float wobble = sin(look.y*8.0 + iTime*0.8) * wobble_amp * onOff(4.0, 4.0, 0.3) * (0.5 + 0.5*cos(iTime*40.0));
    look.x += wobble * window;

    float vShiftCore =
        0.6*sin(iTime*0.7) * 0.6*sin(iTime*4.0)  // product gives intermittent motion
      + 0.3*sin(iTime*0.35);                     // slow drift

    float vShift = scroll_amp * vShiftCore * onOff(2.0, 3.0, 0.9);
    look.y = mod(look.y + vShift * scroll_speed, 1.0);

    return sampleWrapNoTileFeather(texture, look).rgb;
}

vec2 screenDistort(vec2 uv)
{
    uv -= vec2(0.5);
    uv  = uv * 1.2 * (1.0 / 1.2 + 2.0 * uv.x * uv.x * uv.y * uv.y);
    uv += vec2(0.5);
    return uv;
}

float vignetteFn(vec2 uv)
{
    float vigAmt = 3.0 + 0.3 * sin(iTime + 5.0 * cos(iTime * 5.0));
    return (1.0 - vigAmt * (uv.y - 0.5) * (uv.y - 0.5))
         * (1.0 - vigAmt * (uv.x - 0.5) * (uv.x - 0.5));
}

vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coords)
{
    vec2 uvraw = screen_coords / texsize;
    vec2 uv = screenDistort(uvraw);

    vec3 video = getVideo(uv, texture);

    float vignetteA = vignetteFn(uv);          // post-distort
    float vignetteB = vignetteFn(uvraw);      // pre-distort
    float vignette  = min(vignetteA, vignetteB);
    video += stripesRGB(uv);
    video += noiseRGB(uv * 2.0) * noise_strength;
    video *= vignette;
    float sweep = (12.0 + sweep_amp * mod(uv.y*22.0 + iTime*sweep_speed, 1.0)) / 13.0;
    video *= sweep;


    return vec4(video, 1.0) * color;
}
