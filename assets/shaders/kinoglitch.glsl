extern number iTime;
uniform float scan_line_jitter = 0.015;
uniform float horizontal_shake = 0.01;
uniform float color_drift = 0.03; 

float nrand(float x, float y) {
	return fract(sin(dot(vec2(x,y),vec2(12.9898, 78.233))) * 43758.5433);
}

vec4 effect (vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	float u = texture_coords.x;
	float v = texture_coords.y;
	
	float jitter = nrand(v, iTime) * 2.0 - 1.0;
	jitter *= step(0, abs(jitter)) * scan_line_jitter;
	float jump = mix(v, fract(v), 0.0);
	float shake = (nrand(iTime,2.0) - 0.5) * horizontal_shake;
	float drift = sin(jump) * color_drift;
	
	vec4 src1 = Texel(tex, fract(vec2(u+jitter+shake,jump)));
	vec4 src2 = Texel(tex, fract(vec2(u+jitter+shake+drift,jump)));
	return vec4(src1.r,src2.g,src1.b,src1.a);
}