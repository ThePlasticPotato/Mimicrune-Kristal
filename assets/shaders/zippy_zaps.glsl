// Love2D port of "Zippy Zaps" by SnoopethDuckDuck:
// https://www.shadertoy.com/view/XXyGzh

extern number iTime;
extern vec2 screenSize;

const float pixelScale = 2.0;

vec2 safeTanh(vec2 value)
{
    vec2 exponential = exp(-2.0 * abs(value));
    return sign(value) * (1.0 - exponential) / (1.0 + exponential);
}

vec4 zippyZaps(vec2 fragCoord)
{
    vec2 v = screenSize;
    vec2 u = 0.2 * (fragCoord + fragCoord - v) / v.y;

    vec4 z = vec4(1.0, 2.0, 3.0, 0.0);
    vec4 outputColor = z;
    float a = 0.5;
    float t = iTime;

    for (float i = 1.0; i < 19.0; i += 1.0) {
        t += 1.0;
        a += 0.03;

        v = cos(t - 7.0 * u * pow(a, i)) - 5.0 * u;

        mat2 rotation = mat2(cos(i + 0.02 * t - z.wxzw * 11.0));
        u *= rotation;
        u += safeTanh(
                40.0 * dot(u, u) * cos(100.0 * u.yx + t)
            ) / 200.0
            + 0.2 * a * u
            + cos(4.0 / exp(dot(outputColor, outputColor) / 100.0) + t) / 300.0;

        outputColor += (1.0 + cos(z + t))
            / length(
                (1.0 + i * dot(v, v))
                * sin(1.5 * u / (0.5 - dot(u, u)) - 9.0 * u.yx + t)
            );
    }

    return 25.6 / (min(outputColor, 13.0) + 164.0 / outputColor)
        - dot(u, u) / 250.0;
}

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec2 pixelCoords = floor(screenCoords / pixelScale) * pixelScale
        + vec2(pixelScale * 0.5);

    vec2 fragCoord = vec2(pixelCoords.x, screenSize.y - pixelCoords.y);
    vec4 raw = zippyZaps(fragCoord);
    float sourceAlpha = Texel(texture, textureCoords).a;

    float finalAlpha = sourceAlpha * color.a;
    vec3 premultipliedColor = raw.rgb * color.rgb * finalAlpha;
    return vec4(premultipliedColor, finalAlpha);
}
