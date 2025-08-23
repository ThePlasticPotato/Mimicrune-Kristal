extern number iTime;
extern number glitchScale;
	
float time;
	
float round(float n) {
	return floor(n + .5);
}

vec2 round(vec2 n) {
	return floor(n + .5);
}

float rand(vec2 co){
	return fract(dot(co.xy,vec2(12.9898,78.233)) * 43758.5453);
}

vec2 glitchCoord(vec2 p, vec2 gridSize) {
	vec2 coord = floor(p / gridSize) * gridSize;
	coord += (gridSize / 2.);
	return coord;
}

struct GlitchSeed {
	vec2 seed;
	float prob;
};

GlitchSeed glitchSeed(vec2 p, float speed) {
	float seedTime = floor(time * speed);
	vec2 seed = vec2(
		1. + mod(seedTime / 100., 100.),
		1. + mod(seedTime, 100.)
	) / 100.;
	seed += p;

	float prob = 1;

	return GlitchSeed(seed, prob);
}

float shouldApply(GlitchSeed seed) {
	return round(
		mix(
			mix(rand(seed.seed), 1., seed.prob - .5),
			0.,
			(1. - seed.prob) * .5
		)
	);
}

vec4 swapCoords(vec2 seed, vec2 groupSize, vec2 subGrid, vec2 blockSize) {
	vec2 rand2 = vec2(rand(seed), rand(seed+.1));
	vec2 range = subGrid - (blockSize - 1.);
	vec2 coord = floor(rand2 * range) / subGrid;
	vec2 bottomLeft = coord * groupSize;
	vec2 realBlockSize = (groupSize / subGrid) * blockSize;
	vec2 topRight = bottomLeft + realBlockSize;
	topRight -= groupSize / 2.;
	bottomLeft -= groupSize / 2.;
	return vec4(bottomLeft, topRight);
}

float isInBlock(vec2 pos, vec4 block) {
	vec2 a = sign(pos - block.xy);
	vec2 b = sign(block.zw - pos);
	return min(sign(a.x + a.y + b.x + b.y - 3.), 0.);
}

vec2 moveDiff(vec2 pos, vec4 swapA, vec4 swapB) {
	vec2 diff = swapB.xy - swapA.xy;
	return diff * isInBlock(pos, swapA);
}

void swapBlocks(inout vec2 xy, vec2 groupSize, vec2 subGrid, vec2 blockSize, vec2 seed, float apply) {
	vec2 groupOffset = glitchCoord(xy, groupSize);
	vec2 pos = xy - groupOffset;
	
	vec2 seedA = seed * groupOffset;
	vec2 seedB = seed * (groupOffset + .1);
		
	vec4 swapA = swapCoords(seedA, groupSize, subGrid, blockSize);
	vec4 swapB = swapCoords(seedB, groupSize, subGrid, blockSize);
	
	vec2 newPos = pos;
	newPos += moveDiff(pos, swapA, swapB) * apply;
	newPos += moveDiff(pos, swapB, swapA) * apply;
	pos = newPos;
			
	xy = pos + groupOffset;
}

void staticNoise(inout vec2 p, vec2 groupSize, float grainSize, float contrast) {
	GlitchSeed seedA = glitchSeed(glitchCoord(p, groupSize), 5.);
	seedA.prob *= .5;
	if (shouldApply(seedA) == 1.) {
		GlitchSeed seedB = glitchSeed(glitchCoord(p, vec2(grainSize)), 5.);
		vec2 offset = vec2(rand(seedB.seed), rand(seedB.seed + .1));
		offset = round(offset * 2. - 1.);
		offset *= contrast;
		p += offset;
	}
}

void freezeTime(vec2 p, inout float time, vec2 groupSize, float speed) {
	GlitchSeed seed = glitchSeed(glitchCoord(p, groupSize), speed);
	if (shouldApply(seed) == 1.) {
		float frozenTime = floor(time * speed) / speed;
		time = frozenTime;
	}
}

void glitchSwap(inout vec2 p) {
	vec2 pp = p;
	
	float scale = glitchScale;
	float speed = 50.;
		
	vec2 groupSize;
	vec2 subGrid;
	vec2 blockSize;    
	GlitchSeed seed;
	float apply;
		
	groupSize = vec2(.6) * scale;
	subGrid = vec2(2);
	blockSize = vec2(1);

	seed = glitchSeed(glitchCoord(p, groupSize), speed);
	apply = shouldApply(seed);
	swapBlocks(p, groupSize, subGrid, blockSize, seed.seed, apply);
		
	groupSize = vec2(.8) * scale;
	subGrid = vec2(3);
	blockSize = vec2(1);
		
	seed = glitchSeed(glitchCoord(p, groupSize), speed);
	apply = shouldApply(seed);
	swapBlocks(p, groupSize, subGrid, blockSize, seed.seed, apply);

	groupSize = vec2(.2) * scale;
	subGrid = vec2(6);
	blockSize = vec2(1);
		
	seed = glitchSeed(glitchCoord(p, groupSize), speed);
	float apply2 = shouldApply(seed);
	swapBlocks(p, groupSize, subGrid, blockSize, (seed.seed + 1.), apply * apply2);
	swapBlocks(p, groupSize, subGrid, blockSize, (seed.seed + 2.), apply * apply2);
	swapBlocks(p, groupSize, subGrid, blockSize, (seed.seed + 3.), apply * apply2);
	swapBlocks(p, groupSize, subGrid, blockSize, (seed.seed + 4.), apply * apply2);
	swapBlocks(p, groupSize, subGrid, blockSize, (seed.seed + 5.), apply * apply2);
	
	groupSize = vec2(1.2, .2) * scale;
	subGrid = vec2(9,2);
	blockSize = vec2(3,1);
	
	seed = glitchSeed(glitchCoord(p, groupSize), speed);
	apply = shouldApply(seed);
	swapBlocks(p, groupSize, subGrid, blockSize, seed.seed, apply);
}

void glitchStatic(inout vec2 p) {
	staticNoise(p, vec2(.5, .25/2.) * glitchScale, .2 * glitchScale, 2.);
}

void glitchTime(vec2 p, inout float time) {
	freezeTime(p, time, vec2(.5) * glitchScale, 2.);
}

float sat( float t ) {
	return clamp( t, 0.0, 1.0 );
}

vec2 sat( vec2 t ) {
	return clamp( t, 0.0, 1.0 );
}

float remap  ( float t, float a, float b ) {
	return sat( (t - a) / (b - a) );
}

float linterp( float t ) {
	return sat( 1.0 - abs( 2.0*t - 1.0 ) );
}

vec3 spectrum_offset( float t ) {
	vec3 ret;
	float lo = step(t,0.5);
	float hi = 1.0-lo;
	float w = linterp( remap( t, 1.0/6.0, 5.0/6.0 ) );
	float neg_w = 1.0-w;
	ret = vec3(lo,1.0,hi) * vec3(neg_w, w, neg_w);
	return pow( ret, vec3(1.0/2.2) );
}

vec4 effect (vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	time = iTime;
	time /= 3.;
	time = mod(time, 1.);
	
	glitchSwap(texture_coords);
	glitchTime(texture_coords, time);
	glitchStatic(texture_coords);

	GlitchSeed seed = glitchSeed(glitchCoord(texture_coords, vec2(.5, .25/2.) * glitchScale * 2), 5.);
	vec3 s = spectrum_offset(rand(seed.seed));
	color.rgb = color.rgb * s;

	return Texel(tex,texture_coords) * (color);
}