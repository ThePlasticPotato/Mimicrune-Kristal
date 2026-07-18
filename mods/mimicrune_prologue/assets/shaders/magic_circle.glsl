extern vec2 center;
extern vec3 circleColor;
extern number progress;
extern number intensity;
extern number circleRadius;
extern number rotation;

const float TAU = 6.28318530718;
const float PIXEL_SIZE = 2.0;

float ring(float distanceFromCenter, float radius, float width)
{
    return 1.0 - smoothstep(width, width + 1.4, abs(distanceFromCenter - radius));
}

float angularDistance(float angle, float divisions, float radius)
{
    float sector = TAU / divisions;
    float centered = mod(angle + sector * 0.5, sector) - sector * 0.5;
    return abs(centered) * radius;
}

float radialMask(float distanceFromCenter, float innerRadius, float outerRadius)
{
    return smoothstep(innerRadius - 2.0, innerRadius + 1.0, distanceFromCenter)
        * (1.0 - smoothstep(outerRadius - 1.0, outerRadius + 2.0, distanceFromCenter));
}

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec2 pixel = floor(screenCoords / PIXEL_SIZE) * PIXEL_SIZE + vec2(PIXEL_SIZE * 0.5);
    vec2 point = pixel - center;
    float distanceFromCenter = length(point);
    float angle = atan(point.y, point.x);
    float radius = max(4.0, circleRadius * progress);

    float outerRings = max(
        ring(distanceFromCenter, radius, 1.35),
        ring(distanceFromCenter, radius * 0.955, 0.9)
    );
    float middleRings = max(
        ring(distanceFromCenter, radius * 0.69, 0.9),
        ring(distanceFromCenter, radius * 0.44, 0.8)
    );
    float centerRings = max(
        ring(distanceFromCenter, radius * 0.17, 0.8),
        ring(distanceFromCenter, radius * 0.095, 0.7)
    );

    float outerAngle = angle + rotation * 0.18;
    float hourDistance = angularDistance(outerAngle, 12.0, distanceFromCenter);
    float hourTicks = (1.0 - smoothstep(1.15, 2.8, hourDistance))
        * radialMask(distanceFromCenter, radius * 0.75, radius * 0.91);

    float minuteDistance = angularDistance(angle - rotation * 0.32, 24.0, distanceFromCenter);
    float minuteTicks = (1.0 - smoothstep(0.8, 2.0, minuteDistance))
        * radialMask(distanceFromCenter, radius * 0.5, radius * 0.62);

    float dashedArc = ring(distanceFromCenter, radius * 0.79, 0.75)
        * step(0.12, sin(outerAngle * 12.0));
    float firstHandAngle = angle + rotation * 0.75;
    float firstHand = (1.0 - smoothstep(0.75, 2.2, abs(sin(firstHandAngle)) * distanceFromCenter))
        * step(0.0, cos(firstHandAngle))
        * radialMask(distanceFromCenter, radius * 0.08, radius * 0.57);

    float secondHandAngle = angle + rotation * 0.42 - TAU / 3.0;
    float secondHand = (1.0 - smoothstep(0.7, 1.9, abs(sin(secondHandAngle)) * distanceFromCenter))
        * step(0.0, cos(secondHandAngle))
        * radialMask(distanceFromCenter, radius * 0.08, radius * 0.42);

    float cardinalDistance = angularDistance(outerAngle, 4.0, distanceFromCenter);
    float cardinalMarks = (1.0 - smoothstep(2.0, 4.0, cardinalDistance))
        * radialMask(distanceFromCenter, radius * 0.64, radius * 0.72);

    float pattern = max(outerRings, middleRings);
    pattern = max(pattern, centerRings);
    pattern = max(pattern, hourTicks);
    pattern = max(pattern, minuteTicks * 0.8);
    pattern = max(pattern, dashedArc * 0.8);
    pattern = max(pattern, firstHand * 0.72);
    pattern = max(pattern, secondHand * 0.62);
    pattern = max(pattern, cardinalMarks * 0.75);

    float innerGlow = (1.0 - smoothstep(0.0, radius * 1.08, distanceFromCenter)) * 0.075;
    float finalAlpha = clamp((pattern + innerGlow) * intensity * progress * color.a, 0.0, 1.0);
    return vec4(circleColor, finalAlpha);
}
