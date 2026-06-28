uniform vec2 texsize;

uniform float dissolve_value;
uniform float dissolve_mix;
uniform float dissolve_noise_scale;
uniform vec2 dissolve_origin;
uniform vec2 dissolve_size;
uniform float dissolve_use_screen_coords;

uniform Image dissolve_gradient;

float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p){
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u*u*(3.0-2.0*u);
	
	float res = mix(
		mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
		mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
	return res*res;
}

float fbm(vec2 x) {
	float v = 0.0;
	float a = 0.5;
	vec2 shift = vec2(100);
	// Rotate to reduce axial bias
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
	for (int i = 0; i < 5; ++i) {
		v += a * noise(x);
		x = rot * x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

float noise(float st) {
    return fbm(vec2(st * 5.)) * 0.5 + 0.5;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 main_texture = Texel(texture, texture_coords);

    vec2 canvas_pos = mix(texture_coords * texsize, screen_coords, dissolve_use_screen_coords);
    vec2 local_uv = (canvas_pos - dissolve_origin) / dissolve_size;
    vec2 uv = local_uv - vec2(0.5);
    uv.x *= dissolve_size.x / dissolve_size.y;

    float n1 = noise(dot(uv, vec2(0.73, 0.41)) * dissolve_noise_scale);
    float n2 = noise(dot(uv, vec2(-0.32, 0.91)) * dissolve_noise_scale + 19.17);
    float prog_noise = (n1 + n2) * 0.5;

    float gradient = Texel(dissolve_gradient, clamp(local_uv, 0.0, 1.0)).r;
    float noise_value = mix(prog_noise, gradient, dissolve_mix);

    float visible = min(1.0, floor(dissolve_value + min(1.0, noise_value)));
    return main_texture * visible * color;
}
