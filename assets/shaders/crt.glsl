extern number iTime;
extern vec2   texsize;

// set these via shader:send if you want them dynamic:
extern number vertJerkOpt      = 1.0;
extern number vertMovementOpt  = 1.0;
extern number bottomStaticOpt  = 1.0;
extern number scalinesOpt      = 1.0;  // (typo kept to match your code)
extern number rgbOffsetOpt     = 1.0;
extern number horzFuzzOpt      = 1.0;

// --- ashima snoise 2D ---
vec3 mod289(vec3 x){ return x - floor(x*(1.0/289.0))*289.0; }
vec2 mod289(vec2 x){ return x - floor(x*(1.0/289.0))*289.0; }
vec3 permute(vec3 x){ return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v){
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                     -0.577350269189626, 0.024390243902439);
  vec2 i = floor(v + dot(v,C.yy));
  vec2 x0 = v - i + dot(i,C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0,0.0) : vec2(0.0,1.0);
  vec4 x12 = x0.xyxy + C.xxzz; x12.xy -= i1;
  i = mod289(i);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0))
                  + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0,x0),
                          dot(x12.xy,x12.xy),
                          dot(x12.zw,x12.zw)), 0.0);
  m *= m; m *= m;
  vec3 x = 2.0*fract(p*C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314*(a0*a0 + h*h);
  vec3 g;
  g.x  = a0.x*x0.x   + h.x*x0.y;
  g.yz = a0.yz*x12.xz + h.yz*x12.yw;
  return 130.0*dot(m,g);
}

float staticV(vec2 uv){
  float staticHeight   = snoise(vec2( 9.0, iTime*1.2+3.0))*0.3 + 5.0;
  float staticAmount   = snoise(vec2( 1.0, iTime*1.2-6.0))*0.1 + 0.3;
  float staticStrength = snoise(vec2(-9.75,iTime*0.6-3.0))*2.0 + 2.0;
  float s = snoise(vec2(5.0*pow(iTime,2.0) + pow(uv.x*7.0,1.2),
                        pow((mod(iTime,100.0)+100.0)*uv.y*0.3+3.0, staticHeight)));
  return (1.0 - step(s, staticAmount)) * staticStrength;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord, in Image tex)
{
  // screen-space pixels -> UVs
  vec2 uv = fragCoord / texsize;

  float jerkOffset   = (1.0 - step(snoise(vec2(iTime*1.3, 5.0)), 0.8)) * 0.05;
  float fuzzOffset   = snoise(vec2(iTime*15.0, uv.y*80.0)) * 0.003;
  float largeFuzzOff = snoise(vec2(iTime*1.0,  uv.y*25.0)) * 0.004;

  float vertMoveOn = (1.0 - step(snoise(vec2(iTime*0.2, 8.0)), 0.4)) * vertMovementOpt;
  float vertJerk   = (1.0 - step(snoise(vec2(iTime*1.5, 5.0)), 0.6)) * vertJerkOpt;
  float vertJerk2  = (1.0 - step(snoise(vec2(iTime*5.5, 5.0)), 0.2)) * vertJerkOpt;
  float yOffset    = abs(sin(iTime)*4.0)*vertMoveOn + vertJerk*vertJerk2*0.3;
  float y          = mod(uv.y + yOffset, 1.0);

  float xOffset = (fuzzOffset + largeFuzzOff) * horzFuzzOpt + jerkOffset;

  // vertical “bottom static”
  float staticVal = 0.0;
  for (float yy = -1.0; yy <= 1.0; yy += 1.0) {
    float maxDist = 5.0/200.0;
    float dist    = yy/200.0;
    staticVal += staticV(vec2(uv.x, uv.y + dist)) * (maxDist - abs(dist)) * 1.5;
  }
  staticVal *= bottomStaticOpt;

  // sample with wrap-safe coords (or set image wrap to repeat in Lua)
  float red   = Texel(tex, vec2(fract(uv.x + xOffset - 0.01*rgbOffsetOpt), y)).r + staticVal;
  float green = Texel(tex, vec2(fract(uv.x + xOffset),                     y)).g + staticVal;
  float blue  = Texel(tex, vec2(fract(uv.x + xOffset + 0.01*rgbOffsetOpt), y)).b + staticVal;

  vec3 color = vec3(red, green, blue);

  // optional scanlines; scale by screen height for consistency
  float scanline = sin(uv.y * texsize.y * 0.8) * 0.04 * scalinesOpt;
  color -= scanline;

  fragColor = vec4(color, 1.0);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
  vec4 c;
  // IMPORTANT: pass pixel coords, not texture_coords
  mainImage(c, screen_coords, texture);
  // Don’t multiply the source texture again; c already sampled it
  return c * color;
}
