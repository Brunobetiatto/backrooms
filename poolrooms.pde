// =====================================================================
// POOLROOMS
// =====================================================================

final int POOL = 5;                            // game state

final int   POOL_GRID      = 36;
final float POOL_VZ        = 200;              // springline of the barrel vaults (crown = VZ + CELL/2 - 12)
final float POOL_H1        = POOL_VZ + CELL / 2 - 12;   // ceiling heights: small rooms, wide corridors (= vault crown)
final float POOL_H2        = 470;              //                  halls
final float POOL_H3        = 580;              //                  big halls, halls with a balcony
final float POOL_LV        = 120;              // raised floor: balconies and upper rooms
final float POOL_SHAFT     = 170;              // skylight shaft depth above each ceiling
final float POOL_DEEP      = -125;             // pool floor (waist deep)
final float POOL_SHAL      = -40;              // flooded floor (ankle deep)
final float POOL_WATER     = -12;              // water surface
final float POOL_COL_R     = 56;               // column radius
final float POOL_PLINTH_R  = 112;              // dry island around a column standing in water
final float POOL_STAIR_R   = 168;              // spiral stair outer radius (blocked for the player)
final float POOL_HOLE_R    = 186;              // ceiling opening above the stair
final float POOL_WATER_R   = 135;              // corner rounding of the water outline
final float POOL_PREVIEW_EXPO = 2.6;          // fixed exposure of the menu polaroid (in game the camera auto exposes)
final float POOL_AE_BOOST = 2.3;               // auto exposure target vs the Backrooms (+1.2 EV: a bright white place)
final int   P_DECK = 0, P_DEEP = 1, P_SHAL = 2;
final int   F_NONE = 0, F_COLUMN = 1, F_STAIR = 2, F_LADDER = 3, F_SKY = 4;
final int   R_LAP = 0, R_FLOOD = 1, R_LAGOON = 2, R_GALLERY = 3, R_BASIN = 4, R_STAIRS = 5, R_DRY = 6, R_UPPER = 7;
final int   E_LOW = 1, E_HIGH = 2, E_RAMP_PX = 3, E_RAMP_NX = 4, E_RAMP_PY = 5, E_RAMP_NY = 6;   // floor level per cell
final PVector POOL_SUN = new PVector(0.40, 0.26, 0.88).normalize();

int[][] pBase, pFeat, pStyle, pElev;           // pStyle: 0 wall, else 1 + heightClass * 4 + palette
float[][] pLight;
PImage poolMapTex;                            // RGBA bytes: layout, light, style, elevation
float[] poolWakes  = new float[16];
final float[] NO_WAKES = new float[16];
int wakeIdx;
PShader poolSh, poolBright, poolBlur, poolBakeSh, poolSimSh, poolSecSh, poolHazeSh;
PGraphics poolHazeA, poolHazeB;
boolean poolHazeReady;
PGraphics poolBuf, poolPrevBuf, poolBloomA, poolBloomB, poolBloomC, poolBloomD;
PGraphics poolProbeA, poolProbeB;              // baked light, ping-pong (A = current)
PGraphics poolSimA, poolSimB;                  // water height field, ping-pong (A = current)
final int POOL_SIM_N = 2048;                    // water simulation texels per side (~19 units each)
final int POOL_BAKE_START = 4;                 // small initial bake; convergence continues in slices
final int POOL_BAKE_TOTAL = 96;                // converge lighting without tracing for the whole first minute
final int POOL_BAKE_SLICES = 16;               // smaller optional slices fit beside gameplay rendering
int poolBakePasses, poolBakeSlice;
final double POOL_SIM_DT = 1.0d / 60.0d;      // coefficients below are calibrated for 60 Hz
final int POOL_SIM_MAX_STEPS = 3;              // cap catch-up after a stall
double poolSimAccumulator;
float[] poolFlow = new float[4];               // continuous wading force, sampled once per simulation tick
float[] poolImp = new float[24];               // queued event impulses: x, y, radius, amplitude
PVector poolHaze = new PVector(0.4, 0.4, 0.4);
int poolImpN;
float poolDripT;
PImage poolDummy;
float poolFloorZ, poolExposure = 1, poolCamAmb = 0.5;
int poolStartMs;
boolean poolSynthReady, poolPrevReady;
Multiplier poolWaterAmp, poolSplashAmp;
Oscil poolTone;
float splashEnv, clickEnv;
AudioPlayer poolAmbience;
float prevX, prevY, prevYaw;

// =====================================================================
// SHADER
String[] POOL_VERT = {
  "#define PROCESSING_TEXTURE_SHADER",
  "uniform mat4 transformMatrix;",
  "attribute vec4 position;",
  "attribute vec2 texCoord;",
  "varying vec2 vUV;",
  "void main() {",
  "  gl_Position = transformMatrix * position;",
  "  vUV = texCoord;",
  "}"
};

// Raw GPU data must not derive a mip level inside divergent raymarch/cache branches.
// Use explicit LOD 0 on desktop and ES implementations that expose the operation.
String[] POOL_DATA_SAMPLING = {
  "#ifdef GL_ES",
  "#ifdef GL_EXT_shader_texture_lod",
  "#extension GL_EXT_shader_texture_lod : enable",
  "#endif",
  "precision highp float;",
  "#else",
  "#ifdef GL_ARB_shader_texture_lod",
  "#extension GL_ARB_shader_texture_lod : enable",
  "#endif",
  "#endif",
  "#if __VERSION__ >= 130",
  "#define poolDataFetch(s, uv) textureLod(s, uv, 0.0)",
  "#elif defined(GL_ES) && defined(GL_EXT_shader_texture_lod)",
  "#define poolDataFetch(s, uv) texture2DLodEXT(s, uv, 0.0)",
  "#elif defined(GL_ARB_shader_texture_lod)",
  "#define poolDataFetch(s, uv) texture2DLod(s, uv, 0.0)",
  "#else",
  "#define poolDataFetch(s, uv) texture2D(s, uv)",
  "#endif"
};

String[] POOL_COMMON = poolJoin(POOL_DATA_SAMPLING, new String[]{
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision highp float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform sampler2D mapTex;",
  "uniform float gridSize;",
  "uniform float time;",
  "uniform vec3 camPos;",
  "uniform vec3 camF;",
  "uniform vec3 camR;",
  "uniform vec3 camU;",
  "uniform vec2 tanHalf;",
  "uniform vec3 sunDir;",
  "uniform float exposure;",
  "uniform float pixAng;",
  "uniform float camAmb;",
  "uniform vec4 wakes[4];",
  "uniform int zeroI;",                       // always 0: loops that start at it are not unrolled (keeps the shader small)
  "uniform sampler2D probes;",                // the baked multi-bounce light (see POOL_BAKE)
  "uniform vec2 probeTex;",
  "uniform sampler2D waterSim;",              // the simulated water height field (see POOL_SIM)
  "uniform float simN;",
  "uniform float simScale;",
  "uniform sampler2D hazeTex;",               // one GPU texel, never a synchronous probe readback
  "uniform sampler2D secTex;",                // pass 1: reflections and refractions at half resolution
  "uniform vec2 secSize;",
  "uniform vec2 bufSize;",
  "uniform vec2 renderOrigin;",
  "uniform vec2 secOrigin;",
  "uniform vec2 secCapacity;",
  "uniform float lite;",                      // graphics quality LEVE: primary surfaces shaded the cheap way
  "varying vec2 vUV;",

  "const float CS = " + CELL + ";",
  "const float HC = " + (CELL * 0.5) + ";",
  "const float H1 = " + POOL_H1 + ";",
  "const float H2 = " + POOL_H2 + ";",
  "const float H3 = " + POOL_H3 + ";",
  "const float VZ = " + POOL_VZ + ";",
  "const float VR = " + (CELL * 0.5 - 12) + ";",            // a little inside the side walls: no tangent seam
  "const float VTOP = " + (POOL_VZ + CELL * 0.5 - 12) + ";",
  "const float LV = " + POOL_LV + ";",
  "const float SHAFT = " + POOL_SHAFT + ";",
  "const float DEEP = " + POOL_DEEP + ";",
  "const float SHAL = " + POOL_SHAL + ";",
  "const float WATER = " + POOL_WATER + ";",
  "const float COLR = " + POOL_COL_R + ";",
  "const float PLR = " + POOL_PLINTH_R + ";",
  "const float STR = " + POOL_STAIR_R + ";",
  "const float STC = 66.0;",
  "const float HOLER = " + POOL_HOLE_R + ";",
  "const float RW = " + POOL_WATER_R + ";",
  "const float RF = 40.0;",
  "const float STH = 27.0;",
  "const float STT = 15.0;",
  "const float STEPS = 16.0;",
  "const float STA = 0.39269908;",
  "const vec3 SUNC = vec3(7.0, 6.9, 6.6);",
  "const vec3 SKYC = vec3(2.95, 3.05, 3.2);",
  "const vec3 AMBC = vec3(0.96, 0.985, 1.02);",
  "const vec3 SIGMA = vec3(0.0046, 0.00095, 0.00055);",         // clear pool water, per cm: red goes first
  "const vec3 WATERC = vec3(0.05, 0.36, 0.44);",

  // ---- utilities
  "float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }",
  "float vnoise(vec2 p) {",
  "  vec2 i = floor(p);",
  "  vec2 f = fract(p);",
  "  f = f * f * (3.0 - 2.0 * f);",
  "  return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);",
  "}",
  "float smin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }",
  "float smax(float a, float b, float k) { return -smin(-a, -b, k); }",
  "float sdBox2(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }",
  "float sdBox3(vec3 p, vec3 b) { vec3 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0); }",
  // intersection of a 2D region (signed distance a) with the half space z > h (b = h - z)
  "float sdExt(float a, float b) { return length(max(vec2(a, b), 0.0)) + min(max(a, b), 0.0); }",
  "vec3 aces(vec3 x) { return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }",

  // ---- one exact RGBA8 texel per cell; CPU row j maps to texture row j
  "bool outside(vec2 c) { return c.x < 0.0 || c.y < 0.0 || c.x >= gridSize || c.y >= gridSize; }",
  "vec4 cellData(vec2 c) {",
  "  if (outside(c)) return vec4(0.0);",
  "  return floor(poolDataFetch(mapTex, (c + 0.5) / gridSize) * 255.0 + 0.5);",
  "}",
  "float codeAt(vec2 c) { return cellData(c).r; }",
  "float styleAt(vec2 c) { return cellData(c).b; }",
  "float elevAt(vec2 c) { return cellData(c).a; }",
  "float lightAt(vec2 c) { float v = cellData(c).g; return v < 0.5 ? -1.0 : (v - 1.0) / 15.0; }",
  // code 0 = wall; otherwise code-1 = base + 3*feature
  "float baseOf(float c) { return mod(c - 1.0, 3.0); }",
  "float featOf(float c) { return floor((c - 1.0) / 3.0 + 0.01); }",
  "bool isWet(float c) { return c > 0.5 && baseOf(c) > 0.5; }",
  "bool isDeepC(float c) { return c > 0.5 && abs(baseOf(c) - 1.0) < 0.5; }",
  "bool isDeck(float c) { return c > 0.5 && baseOf(c) < 0.5; }",
  "bool isFeat(float c, float f) { return c > 0.5 && abs(featOf(c) - f) < 0.5; }",
  // style: 0 = wall; otherwise style-1 = heightClass*4 + palette (heightClass 0 = barrel vault)
  "float hOf(float s) { float hc = floor((s - 1.0) * 0.25 + 0.01); return hc < 0.5 ? VTOP : (hc < 1.5 ? H1 : (hc < 2.5 ? H2 : H3)); }",
  "bool vaultS(float s) { return s > 0.5 && s < 4.5; }",
  "float palOf(float s) { float k = s - 1.0; return k - 4.0 * floor(k * 0.25 + 0.01); }",
  // floor height of a cell at local offset o: 1 low, 2 raised, 3..6 ramp rising towards +x, -x, +y, -y
  "float fH(float e, vec2 o) {",
  "  if (e < 1.5) return 0.0;",
  "  if (e < 2.5) return LV;",
  "  vec2 dir = e < 3.5 ? vec2(1.0, 0.0) : (e < 4.5 ? vec2(-1.0, 0.0) : (e < 5.5 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));",
  "  return LV * clamp(0.5 + dot(o, dir) / CS, 0.0, 1.0);",
  "}",

  // ---- 3x3 neighborhood cache (reloaded only when the sample point changes cell)
  "vec2 gC = vec2(-1000.0, -1000.0);",
  "float gN[9];",
  "float gS[9];",
  "float gH[9];",
  "float gE[9];",
  "float gWD = 100000.0;",
  "bool gHi = false;",                                           // any raised floor or ramp in the 3x3
  "bool gWet = false;",                                       // any water / deep water in the 3x3: the outline work is skipped otherwise
  "bool gDeep = false;",
  "bool gSimple = false;",                    // exact planar interior: no rounded boundaries or local features
  "void loadCell(vec2 c) {",
  "  if (c.x == gC.x && c.y == gC.y) return;",
  "  gC = c;",
  "  gHi = false;",
  "  gWet = false;",
  "  gDeep = false;",
  "  vec4 center = cellData(c);",
  "  float centerBase = baseOf(center.r);",
  "  gSimple = center.r > 0.5 && featOf(center.r) < 0.5 && center.a == 1.0 && !vaultS(center.b);",
  "  for (int j = zeroI; j < 3; j++) {",
  "    for (int i = zeroI; i < 3; i++) {",
  "      vec2 q = c + vec2(float(i - 1), float(j - 1));",
  "      int k = j * 3 + i;",
  "      vec4 data = k == 4 ? center : cellData(q);",
  "      gN[k] = data.r;",
  "      gS[k] = data.b;",
  "      gH[k] = hOf(gS[k]);",
  "      gE[k] = data.a;",
  "      if (gE[k] > 1.5) gHi = true;",
  "      if (isWet(gN[k])) gWet = true;",
  "      if (isDeepC(gN[k])) gDeep = true;",
  "      if (data.r < 0.5 || data.a != 1.0 || baseOf(data.r) != centerBase || vaultS(data.b) || hOf(data.b) < hOf(center.b) - 1.0) gSimple = false;",
  "    }",
  "  }",
  "}",

  // ---- ceiling openings: skylights (square or slot) and the stair well
  "float holeD(vec2 lp, float code, vec2 c) {",
  "  if (isFeat(code, 2.0)) return length(lp) - HOLER;",
  "  if (isFeat(code, 4.0)) {",
  "    float hh = hash2(c + 7.3);",
  "    vec2 q = hh > 0.5 ? lp : lp.yx;",
  "    vec2 b = (hh > 0.7 || hh < 0.3) ? vec2(118.0, 118.0) : vec2(150.0, 58.0);",
  "    return sdBox2(q, b - 16.0) - 16.0;",
  "  }",
  "  return 10000.0;",
  "}",

  // ---- water outline: rounded corners decided per cell VERTEX from the 4 cells around it, so every
  //      cell that touches the vertex computes the same shape (no seams). Exactly one wet cell around
  //      the vertex = convex corner (cut), exactly one dry = concave corner (filled).
  // (da..dd: the same cells deep. The wet outline does not fill a dry corner that borders deep water along
  //  an edge, or a little shallow shelf with sharp corners would appear between the deck and the deep pool)
  // (xa..xd: the cell is a wall or a raised floor. Water meets those square: no rounded water corner inside
  //  a square room corner, and no cavity cut into a balcony)
  "float roundV(float f, vec2 u, vec2 s, bool a, bool b, bool c, bool d, bool da, bool db, bool dc, bool dd,",
  "             bool xa, bool xb, bool xc, bool xd) {",
  "  float n = float(a) + float(b) + float(c) + float(d);",
  "  if (n < 0.5 || n > 3.5 || abs(n - 2.0) < 0.5) return f;",
  "  bool one = n < 1.5;",
  "  bool qAD = (a == one) || (b != one && c != one);",          // the odd cell out is self or the diagonal
  "  if (one && (qAD ? (xb || xc) : (xa || xd))) return f;",
  "  if (!one) {",
  "    bool qx = a == one ? xa : (b == one ? xb : (c == one ? xc : xd));",
  "    if (qx || (qAD ? (db || dc) : (da || dd))) return f;",
  "  }",
  "  vec2 q;",
  "  if (a == one) q = -s; else if (b == one) q = vec2(s.x, -s.y); else if (c == one) q = vec2(-s.x, s.y); else q = s;",
  "  vec2 w = u * q;",
  "  vec2 r = vec2(RW) - w;",
  "  float rq = length(max(r, 0.0)) + min(max(r.x, r.y), 0.0) - RW;",
  "  float sq = length(max(-w, 0.0)) + min(max(-w.x, -w.y), 0.0);",
  "  return one ? max(f, min(-sq, rq)) : min(f, max(sq, -rq));",
  "}",

  // ---- chrome pool ladder: two tubes arcing over the edge (q relative to the ladder cell, dir towards the deck)
  "float ladderTube(vec2 q, vec2 dir, float z) {",
  "  vec2 perp = vec2(-dir.y, dir.x);",
  "  float u = HC - dot(q, dir);",
  "  float v = dot(q, perp);",
  "  vec2 a = vec2(u - 4.0, z - 92.0);",
  "  float dArc = a.y > 0.0 ? abs(length(a) - 34.0) : 100000.0;",
  "  float d1 = length(vec2(u + 30.0, z - clamp(z, 0.0, 92.0)));",
  "  float d2 = length(vec2(u - 38.0, z - clamp(z, DEEP + 8.0, 92.0)));",
  "  return length(vec2(min(dArc, min(d1, d2)), abs(v) - 34.0)) - 4.2;",
  "}",

  // ---- spiral stair: cantilevered slabs around a tiled core, up to the opening in this cell's ceiling
  "float stairD(vec3 p, vec2 lp, float fz, float hs) {",
  "  float a = atan(lp.y, lp.x);",
  "  if (a < 0.0) a += 6.2831853;",
  "  float k0 = floor(a / STA);",
  "  float zz = p.z - fz;",
  "  float kmax = floor((hs + 110.0 - fz) / STH);",
  "  float best = 100000.0;",
  "  for (int m = zeroI - 1; m <= 1; m++) {",
  "    float ka = k0 + float(m);",
  "    float k = ka + STEPS * floor((zz / STH - ka) / STEPS + 0.5);",
  "    k = clamp(k, 0.0, kmax);",
  "    float ang = (k + 0.5) * STA;",
  "    float ca = cos(ang);",
  "    float sa = sin(ang);",
  "    vec2 q = vec2(ca * lp.x + sa * lp.y, -sa * lp.x + ca * lp.y);",
  "    float top = (k + 1.0) * STH;",
  "    vec3 bq = vec3(q.x - (STC + STR) * 0.5, q.y, zz - top + STT * 0.5);",
  "    best = min(best, sdBox3(bq, vec3((STR - STC) * 0.5 + 4.0, STR * STA * 0.5, STT * 0.5)) - 1.5);",
  "  }",
  "  return best;",
  "}",

  // ---- the scene: x = distance, y = material (1 tile, 2 cylindrical tile, 3 plaster, 4 chrome)
  "vec2 map(vec3 p) {",
  "  vec2 c = floor(p.xy / CS);",
  "  loadCell(c);",
  "  vec2 lp = p.xy - (c + 0.5) * CS;",
  "  float z = p.z;",
  "  float self = gN[4];",
  "  if (gSimple) {",
  "    float base = baseOf(self);",
  "    gWD = base > 0.5 ? -100000.0 : 100000.0;",
  "    float floorZ = base < 0.5 ? 0.0 : (base < 1.5 ? DEEP : SHAL);",
  "    return vec2(smin(z - floorZ, gH[4] - z, 18.0), 1.0);",
  "  }",
  "  if (self < 0.5) {",
  "    float od = 100000.0;",
  "    for (int j = zeroI; j < 3; j++) {",
  "      for (int i = zeroI; i < 3; i++) {",
  "        if (gN[j * 3 + i] > 0.5) od = min(od, sdBox2(lp - vec2(float(i - 1), float(j - 1)) * CS, vec2(HC)));",
  "      }",
  "    }",
  "    gWD = 100000.0;",
  "    return vec2(-od, 1.0);",
  "  }",
  "  float hS = gH[4];",
  "  bool vS = vaultS(gS[4]);",
  "  float wallD = 100000.0;",
  "  float nbS = 100000.0;",
  "  float inW = 100000.0;",
  "  float outW = 100000.0;",
  "  float inD = 100000.0;",
  "  float outD = 100000.0;",
  "  for (int j = zeroI; j < 3; j++) {",
  "    for (int i = zeroI; i < 3; i++) {",
  "      if (i == 1 && j == 1) continue;",
  "      int k = j * 3 + i;",
  "      vec2 off = vec2(float(i - 1), float(j - 1));",
  "      vec2 o = lp - off * CS;",
  "      float n = gN[k];",
  "      float bd = sdBox2(o, vec2(HC));",
  "      if (n < 0.5) {",
  "        wallD = min(wallD, bd);",
  "      } else if (vaultS(gS[k])) {",
  // a vaulted neighbour: its barrel (orthogonal neighbours always run towards us), or its springline (diagonal)
  "        if (i != 1 && j != 1) nbS = min(nbS, sdExt(bd, VZ - z));",
  "        else {",
  "          float vx = abs(off.x) > 0.5 ? o.y : o.x;",
  "          nbS = min(nbS, max(VR - length(vec2(vx, max(z - VZ, 0.0))), bd));",
  "        }",
  "      } else if (gH[k] < hS - 1.0) {",
  "        nbS = min(nbS, sdExt(bd, gH[k] - z));",              // a lower neighbouring ceiling: a soffit
  "      }",
  "      if (isWet(n)) inW = min(inW, bd); else outW = min(outW, bd);",
  "      if (isDeepC(n)) inD = min(inD, bd); else outD = min(outD, bd);",
  "    }",
  "  }",
  "  bool selfW = isWet(self);",
  "  bool selfD = isDeepC(self);",
  "  float wd = selfW ? -outW : inW;",
  "  float dd = selfD ? -outD : inD;",
  "  for (int k = zeroI; k < 4; k++) {",
  "    vec2 s = vec2((k == 0 || k == 2) ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0);",
  "    int ix = 4 + int(s.x);",
  "    int iy = 4 + 3 * int(s.y);",
  "    int id = ix + 3 * int(s.y);",
  "    vec2 u = lp - s * HC;",
  "    bool dx = isDeepC(gN[ix]);",
  "    bool dy = isDeepC(gN[iy]);",
  "    bool dg = isDeepC(gN[id]);",
  "    bool xs = gE[4] > 1.5;",
  "    bool xx = gN[ix] < 0.5 || gE[ix] > 1.5;",
  "    bool xy = gN[iy] < 0.5 || gE[iy] > 1.5;",
  "    bool xg = gN[id] < 0.5 || gE[id] > 1.5;",
  "    if (gWet) wd = roundV(wd, u, s, selfW, isWet(gN[ix]), isWet(gN[iy]), isWet(gN[id]), selfD, dx, dy, dg, xs, xx, xy, xg);",
  "    if (gDeep) dd = roundV(dd, u, s, selfD, dx, dy, dg, false, false, false, false, xs, xx, xy, xg);",
  "    vec2 cf = lp * s - vec2(HC - RF);",                           // coved inner room corners
  "    if (gN[ix] < 0.5 && gN[iy] < 0.5 && cf.x > 0.0 && cf.y > 0.0) wallD = min(wallD, RF - length(cf));",
  "  }",
  "  float sf = featOf(self);",
  "  if (abs(sf - 1.0) < 0.5) {",
  "    float pl = PLR - length(lp);",
  "    wd = max(wd, pl);",
  "    dd = max(dd, pl);",
  "  }",
  "  gWD = wd;",
  "  float cav = min(smax(wd, SHAL - z, 10.0), smax(dd, DEEP - z, 16.0));",
  // floors: union of every open cell's slab up to its own height (flat, raised or a ramp), so steps and
  // balcony edges are exact from both sides
  "  float gfl = gHi ? 100000.0 : z;",                        // all nine cells on the ground floor: just the plane
  "  for (int j = zeroI; j < 3; j++) {",
  "    if (!gHi) break;",
  "    for (int i = zeroI; i < 3; i++) {",
  "      int k = j * 3 + i;",
  "      if (gN[k] < 0.5) continue;",
  "      vec2 o = lp - vec2(float(i - 1), float(j - 1)) * CS;",
  "      float f = fH(gE[k], clamp(o, -HC, HC));",
  "      gfl = min(gfl, sdExt(sdBox2(o, vec2(HC)), (z - f) * (gE[k] > 2.5 ? 0.92 : 1.0)));",
  "    }",
  "  }",
  "  float ground = gWet ? smax(gfl, -cav, 12.0) : gfl;",         // rounded ceramic coping, shared by every neighboring cell
  "  float ceilD = smax(hS - z, -holeD(lp, self, c), 12.0);",
  "  float room = smin(wallD, ceilD, 34.0);",
  "  if (vS) {",                                               // barrel vault; two crossing barrels at bends and junctions
  "    float bx = VR - length(vec2(lp.y, max(z - VZ, 0.0)));",
  "    float by = VR - length(vec2(lp.x, max(z - VZ, 0.0)));",
  "    bool ox = gN[3] > 0.5 || gN[5] > 0.5;",
  "    bool oy = gN[1] > 0.5 || gN[7] > 0.5;",
  "    room = min(room, (ox && oy) ? max(bx, by) : (ox ? bx : by));",
  "  }",
  "  room = min(room, nbS);",
  "  float d = smin(room, ground, 18.0);",                       // continuous floor/wall cove
  "  if (gE[4] > 1.5) {",                                       // tiled parapets along every drop of a raised floor
  "    float fp = fH(gE[4], lp);",
  "    for (int k = zeroI; k < 4; k++) {",
  "      int idx = k == 0 ? 1 : (k == 1 ? 3 : (k == 2 ? 5 : 7));",
  "      if (gN[idx] < 0.5) continue;",
  "      vec2 dir = k == 0 ? vec2(0.0, -1.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(1.0, 0.0) : vec2(0.0, 1.0)));",
  "      if (fH(gE[4], dir * HC) < fH(gE[idx], -dir * HC) + 20.0) continue;",
  "      float a = dot(lp, dir);",
  "      float b = dot(lp, vec2(-dir.y, dir.x));",
  "      float pd = smax(max(abs(a - (HC - 13.0)) - 9.0, abs(b) - HC), z - (fp + 92.0), 8.0);",
  "      d = min(d, pd);",
  "    }",
  "  }",
  "  float mat = 1.0;",
  "  if (abs(sf - 1.0) < 0.5) {",
  "    float cd = length(lp) - COLR - 14.0 * smoothstep(hS - 90.0, hS, z);",
  "    if (cd < d) mat = 2.0;",
  "    d = smin(d, cd, 18.0);",
  "  } else if (abs(sf - 2.0) < 0.5) {",
  "    float r = length(lp);",
  "    float core = r - STC;",
  "    if (core < d) mat = 2.0;",
  "    d = smin(d, core, 10.0);",
  "    float st = r > STR + 30.0 ? r - STR - 10.0 : stairD(p, lp, selfW ? SHAL : 0.0, hS);",
  "    if (st < d) { d = st; mat = 3.0; }",
  "  } else if (abs(sf - 3.0) < 0.5) {",
  "    vec2 dir = isDeck(gN[5]) ? vec2(1.0, 0.0) : (isDeck(gN[3]) ? vec2(-1.0, 0.0) : (isDeck(gN[7]) ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));",
  "    float ld = ladderTube(lp, dir, z);",
  "    if (ld < d) { d = ld; mat = 4.0; }",
  "  }",
  "  if (isDeck(self)) {",
  "    for (int k = zeroI; k < 4; k++) {",
  "      int idx = k == 0 ? 1 : (k == 1 ? 3 : (k == 2 ? 5 : 7));",
  "      if (!isFeat(gN[idx], 3.0)) continue;",
  "      vec2 off = k == 0 ? vec2(0.0, -1.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(1.0, 0.0) : vec2(0.0, 1.0)));",
  "      float ld = ladderTube(lp - off * CS, -off, z);",
  "      if (ld < d) { d = ld; mat = 4.0; }",
  "    }",
  "  }",
  "  return vec2(d, mat);",
  "}",

  // ---- marching (steps are clamped to the cell exit so cell-local features are never skipped)
  "float cellExit(vec3 p, vec3 rd) {",
  "  vec2 c0 = floor(p.xy / CS) * CS;",
  "  float tx = rd.x > 0.00001 ? (c0.x + CS - p.x) / rd.x : (rd.x < -0.00001 ? (c0.x - p.x) / rd.x : 100000.0);",
  "  float ty = rd.y > 0.00001 ? (c0.y + CS - p.y) / rd.y : (rd.y < -0.00001 ? (c0.y - p.y) / rd.y : 100000.0);",
  "  return min(tx, ty);",
  "}",
  // mat: >0 surface, 9 sky (up a skylight shaft), -2 reached tmax
  "float march(vec3 ro, vec3 rd, float tmax, int steps, out float mat) {",
  "  float t = 0.0;",
  "  mat = -1.0;",
  "  vec2 h = vec2(100000.0, 1.0);",
  "  for (int i = zeroI; i < 260; i++) {",
  "    if (i >= steps) break;",
  "    vec3 p = ro + rd * t;",
  "    h = map(p);",
  "    if (h.x < 0.25 + t * 0.0008) { mat = h.y; return t; }",
  "    if (gN[4] > 0.5 && p.z > gH[4] + SHAFT) { mat = 9.0; return t; }",
  "    t += min(h.x, cellExit(p, rd) + 0.5);",
  "    if (t >= tmax) { mat = -2.0; return tmax; }",
  "  }",
  "  if (h.x < 60.0) mat = h.y;",                 // out of steps right next to a surface: shade it, never a hole
  "  return t;",
  "}",
  "vec3 calcNormal(vec3 p) {",
  "  vec3 n = vec3(0.0);",
  "  for (int i = zeroI; i < 4; i++) {",                       // tetrahedral differences, as a loop: one map() copy
  "    vec3 e = i == 0 ? vec3(0.5, -0.5, -0.5) : (i == 1 ? vec3(-0.5, -0.5, 0.5) : (i == 2 ? vec3(-0.5, 0.5, -0.5) : vec3(0.5)));",
  // Only the exposed side defines a visible surface. Interior cell-local distance
  // estimates can have different depths at a join, which must not tilt its normal.
  "    n += e * max(map(p + e).x, 0.0);",
  "  }",
  "  float ln = length(n);",
  "  return (ln > 1e-6 && ln == ln) ? n / ln : vec3(0.0, 0.0, 1.0);",   // never a NaN normal (it would poison reflections)
  "}",
  "float calcAO(vec3 p, vec3 n) {",
  "  float occ = 0.0;",
  "  float sca = 1.0;",
  "  for (int i = zeroI; i < 4; i++) {",
  "    float h = 6.0 + 38.0 * float(i);",
  "    occ += (h - map(p + n * h).x) * sca;",
  "    sca *= 0.7;",
  "  }",
  "  return clamp(1.0 - occ * 0.0065, 0.0, 1.0);",
  "}",

  // ---- sunlight: through the opening of whichever ceiling the sun ray crosses, and the top of its shaft
  "float sunGate(vec3 p) {",
  "  float g = 0.0;",
  "  for (int k = zeroI; k < 3; k++) {",
  "    float H = k == 0 ? H1 : (k == 1 ? H2 : H3);",
  "    if (H < p.z + 1.0) continue;",
  "    float t1 = (H - p.z) / sunDir.z;",
  "    vec2 a = p.xy + sunDir.xy * t1;",
  "    vec2 c = floor(a / CS);",
  "    if (abs(hOf(styleAt(c)) - H) > 1.0) continue;",
  "    if (codeAt(floor((p.xy + a) * 0.5 / CS)) < 0.5) continue;",   // the way up to that skylight runs through a wall
  "    float code = codeAt(c);",
  "    vec2 ctr = (c + 0.5) * CS;",
  "    float pa = 3.0 + t1 * 0.02;",
  "    float ga = 1.0 - smoothstep(-pa, pa, holeD(a - ctr, code, c));",
  "    if (ga < 0.002) continue;",
  "    float t2 = t1 + SHAFT / sunDir.z;",
  "    float pb = 3.0 + t2 * 0.02;",
  "    ga *= 1.0 - smoothstep(-pb, pb, holeD(p.xy + sunDir.xy * t2 - ctr, code, c));",
  "    g = max(g, ga);",
  "  }",
  "  return g;",
  "}",
  "float sunLight(vec3 p, vec3 n, bool cheap) {",
  "  if (dot(n, sunDir) <= 0.0) return 0.0;",
  "  float g = sunGate(p);",
  "  if (g < 0.004 || cheap) return g;",
  "  float res = 1.0;",
  "  float t = 3.0;",
  "  vec3 o = p + n * 1.5;",
  "  for (int i = zeroI; i < 30; i++) {",
  "    vec3 q = o + sunDir * t;",
  "    float h = map(q).x;",
  "    if (gN[4] > 0.5 && q.z > gH[4] - 2.0 && h > 0.0) break;",
  "    res = min(res, 10.0 * h / t);",
  "    if (res < 0.02) return 0.0;",
  "    t += clamp(min(h, cellExit(q, sunDir) + 0.5), 2.5, 200.0);",
  "  }",
  "  return g * smoothstep(0.0, 1.0, res);",
  "}",

  // ---- caustics (tileable interference pattern, two layers)
  "float causticT(vec2 uv, float t) {",
  "  vec2 p = mod(uv * 6.2831853, 6.2831853) - 250.0;",
  "  vec2 i = p;",
  "  float c = 1.0;",
  "  for (int n = zeroI; n < 4; n++) {",
  "    float tt = t * (1.0 - 3.5 / float(n + 1));",
  "    i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));",
  "    c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / 0.005), p.y / (cos(i.y + tt) / 0.005)));",
  "  }",
  "  c /= 4.0;",
  "  c = 1.17 - pow(c, 1.4);",
  "  return pow(abs(c), 8.0);",
  "}",
  "float caustics(vec2 xy) {",
  "  return causticT(xy / 260.0, time * 0.45) * 0.65 + causticT(xy / 170.0 + 0.37, time * 0.57) * 0.45;",
  "}",

  // ---- light the water throws back up: where is there water (smooth over cell centres), and what it reflects
  "float wetAt(vec2 xy) {",
  "  vec2 g = xy / CS - 0.5;",
  "  vec2 c0 = floor(g);",
  "  vec2 f = smoothstep(0.0, 1.0, g - c0);",
  "  float w00 = isWet(codeAt(c0)) ? 1.0 : 0.0;",
  "  float w10 = isWet(codeAt(c0 + vec2(1.0, 0.0))) ? 1.0 : 0.0;",
  "  float w01 = isWet(codeAt(c0 + vec2(0.0, 1.0))) ? 1.0 : 0.0;",
  "  float w11 = isWet(codeAt(c0 + vec2(1.0, 1.0))) ? 1.0 : 0.0;",
  "  return mix(mix(w00, w10, f.x), mix(w01, w11, f.x), f.y);",
  "}",
  "bool openPath(vec2 a, vec2 b) { return codeAt(floor((a + b) * 0.5 / CS)) > 0.5; }",
  "vec3 waterBounce(vec3 p, vec3 n, vec3 ambC) {",
  "  float h = p.z - WATER;",
  "  if (h < 1.0) return vec3(0.0);",
  "  vec3 acc = vec3(0.0);",
  // 1) sunlight mirrored by a sunlit patch of water: bright dancing caustics on walls and ceilings
  "  vec3 rdir = vec3(sunDir.xy, -sunDir.z);",
  "  float facing = dot(n, rdir);",
  "  if (facing > 0.0) {",
  "    float tW = h / sunDir.z;",
  "    vec2 W = p.xy + sunDir.xy * tW;",
  "    float wet = wetAt(W);",
  "    if (wet > 0.01 && openPath(p.xy, W)) {",
  "      float g = sunGate(vec3(W, WATER));",
  "      if (g > 0.01) acc += SUNC * (wet * g * facing * 0.34 * (0.12 + 1.4 * caustics(W * 0.9 + vec2(h * 0.2))) * exp(-tW / 900.0));",
  "    }",
  "  }",
  // 2) the room's daylight bounced off the rippling water below: the shimmer on pool ceilings and walls
  "  if (n.z < 0.6) {",
  "    vec2 Wb = p.xy + n.xy * min(h, 160.0) * 0.8;",
  "    float wb = wetAt(Wb);",
  "    if (wb > 0.01 && openPath(p.xy, Wb))",
  "      acc += ambC * (wb * (0.06 + 0.8 * caustics(Wb * 0.9 + vec2(0.0, h * 0.05))) * exp(-h / 700.0) * (0.7 - 0.3 * n.z));",
  "  }",
  "  return acc;",
  "}",

  // ---- irradiance probes: 3 per cell (floor to ceiling), 6 faces each (an ambient cube), baked on the GPU with
  //      multiple bounces (see POOL_BAKE_MAIN). Stored as 1 - exp(-E/2) in an 8-bit texture.
  "vec3 probePos(vec2 c, float k) {",
  "  float code = codeAt(c);",
  "  float f = fH(elevAt(c), vec2(0.0));",
  "  float h = hOf(styleAt(c));",
  "  vec2 off = (isFeat(code, 1.0) || isFeat(code, 2.0)) ? vec2(115.0, 115.0) : vec2(0.0);",
  "  return vec3((c + 0.5) * CS + off, f + 35.0 + k * max(h - f - 70.0, 0.0) * 0.5);",
  "}",
  "vec3 probeFetch(vec2 c, float k, float face) {",
  "  vec3 e = poolDataFetch(probes, (vec2(c.x * 6.0 + face, c.y * 3.0 + k) + 0.5) / probeTex).rgb;",   // explicit LOD: discontinuous probe coordinates must not derive a mip level
  "  return -2.0 * log(max(vec3(1.0) - e, vec3(0.002)));",
  "}",
  "vec3 probeCube(vec2 c, float k, vec3 n) {",
  "  vec3 n2 = n * n;",
  "  vec3 e = vec3(0.0);",                                          // walls and floors face one axis: one fetch, not three
  "  if (n2.x > 0.002) e += probeFetch(c, k, n.x > 0.0 ? 0.0 : 1.0) * n2.x;",
  "  if (n2.y > 0.002) e += probeFetch(c, k, n.y > 0.0 ? 2.0 : 3.0) * n2.y;",
  "  if (n2.z > 0.002) e += probeFetch(c, k, n.z > 0.0 ? 4.0 : 5.0) * n2.z;",
  "  return e;",
  "}",
  // incoming diffuse light at p for normal n (cosine-weighted mean radiance): the probes of the 2x2 nearest
  // cells, walls excluded, probes behind the surface faded out
  "vec3 irradiance(vec3 p, vec3 n) {",
  "  vec2 g = p.xy / CS - 0.5;",
  "  vec2 c0 = floor(g);",
  "  vec2 f = g - c0;",
  "  vec3 s = vec3(0.0);",
  "  float w = 0.0;",
  // The loop slots hold the EVEN and the ODD cell (and probe level), not "first" and "second": the GPU derives
  // the texture detail level from neighbouring pixels, and with first/second slots the cell carrying the weight
  // jumped slots between two pixels at every probe boundary -> a garbage detail level -> dotted lines on walls
  // and ceilings. With parity slots the heavy cell stays in its slot; the slot that jumps has ~zero weight there.
  "  vec2 par = mod(c0, 2.0);",
  "  for (int j = zeroI; j < 2; j++) {",
  "    for (int i = zeroI; i < 2; i++) {",
  "      vec2 sel = mod(vec2(float(i), float(j)) + par, 2.0);",   // 0: this slot is c0, 1: it is c0 + 1
  "      vec2 c = c0 + sel;",
  "      float code = codeAt(c);",
  "      if (code < 0.5) continue;",
  "      float fl = fH(elevAt(c), vec2(0.0));",
  "      float span = max(hOf(styleAt(c)) - fl - 70.0, 1.0) * 0.5;",
  "      float lv = clamp((p.z - fl - 35.0) / span, 0.0, 1.999);",
  "      float k0 = floor(lv);",
  "      float wA = k0 < 0.5 ? 1.0 - (lv - k0) : lv - k0;",      // weight of the even level (0 or 2); level 1 is the odd slot
  "      vec3 e = probeCube(c, k0 + mod(k0, 2.0), n) * wA + probeCube(c, 1.0, n) * (1.0 - wA);",
  "      float ww = (sel.x > 0.5 ? f.x : 1.0 - f.x) * (sel.y > 0.5 ? f.y : 1.0 - f.y) + 0.0001;",
  "      vec2 poff = (isFeat(code, 1.0) || isFeat(code, 2.0)) ? vec2(115.0, 115.0) : vec2(0.0);",   // = probePos, without re-reading the cell
  "      vec3 dp = vec3((c + 0.5) * CS + poff, fl + 35.0 + k0 * span) - p;",
  "      ww *= 0.2 + 0.8 * smoothstep(-0.3, 0.2, dot(dp, n) / (length(dp) + 1.0));",
  "      s += e * ww;",
  "      w += ww;",
  "    }",
  "  }",
  "  return w > 0.0 ? s / w : vec3(0.0);",
  "}",

  // ---- the water simulation: a height field (16 bits in RG) over the whole level, stepped on the GPU
  "float simTexel(vec2 t) {",
  "  vec4 v = floor(poolDataFetch(waterSim, (t + 0.5) / simN) * 255.0 + 0.5);",
  "  return ((v.r * 256.0 + v.g) / 65535.0 - 0.5) * 8.0;",
  "}",
  "float simH(vec2 xy) {",
  "  vec2 t = xy * simScale - 0.5;",
  "  vec2 i = floor(t);",
  "  vec2 f = t - i;",
  "  return mix(mix(simTexel(i), simTexel(i + vec2(1.0, 0.0)), f.x), mix(simTexel(i + vec2(0.0, 1.0)), simTexel(i + vec2(1.0, 1.0)), f.x), f.y);",
  "}",
  "vec2 simGrad(vec2 xy) {",
  "  float e = 0.75 / simScale;",
  "  return vec2(simH(xy + vec2(e, 0.0)) - simH(xy - vec2(e, 0.0)), simH(xy + vec2(0.0, e)) - simH(xy - vec2(0.0, e))) / (2.0 * e);",
  "}",
  // light focused by the simulated surface: curvature concentrates it (bright rings around your wake)
  "float simFocus(vec2 xy) {",                                      // 5 texel taps (was 5 bilinear = 20)
  "  vec2 t = floor(xy * simScale);",
  "  float l = simTexel(t + vec2(1.0, 0.0)) + simTexel(t - vec2(1.0, 0.0)) + simTexel(t + vec2(0.0, 1.0)) + simTexel(t - vec2(0.0, 1.0)) - 4.0 * simTexel(t);",
  "  return clamp(1.0 - l * 5.0, 0.15, 3.0);",
  "}"
});

String[] POOL_FUNCS = {
  // ---- faces pressed into the wall tiles (the nerdolas' photos, embossed in the tiles' own glaze).
  // faceA: xyz = centre of the face on the wall, w = atlas slot; faceB: xy = wall normal (into the room),
  // z/w = half width/height. The atlas stores the shading factor / 1.6 (1.0 = a plain tile).
  "uniform vec4 faceA[8];",
  "uniform vec4 faceB[8];",
  "uniform int faceCount;",
  "uniform float faceSlots;",
  "uniform sampler2D faceAtlas;",
  "uniform vec2 faceTexel;",
  // returns the colour factor; tilt = how the relief bends the tile's normal (glints and reflections follow it)
  "float pressedFace(vec3 p, vec3 n, out vec3 tilt) {",
  "  tilt = vec3(0.0);",
  "  for (int k = zeroI; k < 8; k++) {",
  "    if (k >= faceCount) break;",
  "    vec4 a = faceA[k];",
  "    vec4 b = faceB[k];",
  "    if (dot(n.xy, b.xy) < 0.7) continue;",
  "    vec2 d = p.xy - a.xy;",
  "    if (abs(dot(d, b.xy)) > 6.0) continue;",
  "    vec2 q = vec2(dot(d, vec2(b.y, -b.x)) / b.z, (a.z - p.z) / b.w) * 0.5 + 0.5;",   // (b.y, -b.x) = screen right when facing the wall
  "    if (q.x <= 0.0 || q.x >= 1.0 || q.y <= 0.0 || q.y >= 1.0) continue;",
  "    vec2 fuv = vec2((a.w + q.x) / faceSlots, q.y);",
  "    float h = poolDataFetch(faceAtlas, fuv).r;",
  "    float gx = poolDataFetch(faceAtlas, fuv + vec2(faceTexel.x * 2.0, 0.0)).r - h;",
  "    float gy = poolDataFetch(faceAtlas, fuv + vec2(0.0, faceTexel.y * 2.0)).r - h;",
  "    vec2 g = clamp(vec2(gx, gy) * 5.0, -0.35, 0.35);",                  // brighter = pressed further out
  "    tilt = -vec3(b.y, -b.x, 0.0) * g.x + vec3(0.0, 0.0, 1.0) * g.y;",  // image x = screen right, image y = down
  "    return h * 1.6;",
  "  }",
  "  return 1.0;",
  "}",
  // ---- water surface normal: the simulated height field + faint capillary ripples, filtered with distance
  "vec3 waterN(vec2 xy, float t) {",
  "  float fw = t * pixAng;",
  "  vec2 g = simGrad(xy);",
  "  for (int k = zeroI; k < 6; k++) {",
  "    float fk = float(k);",
  "    float L = 110.0 * pow(0.66, fk);",
  "    float a = 0.07 * pow(0.78, fk);",
  "    float ang = fk * 2.39996 + 0.6;",
  "    vec2 dir = vec2(cos(ang), sin(ang));",
  "    float kk = 6.2831853 / L;",
  "    float w = sqrt(980.0 * kk) * 0.12;",
  "    float fade = clamp(1.0 - fw / (L * 0.3), 0.0, 1.0);",
  "    g += dir * (a * kk * cos(dot(dir, xy) * kk + time * w + fk * 1.7)) * fade;",
  "  }",
  "  float fn = clamp(1.0 - fw / 10.0, 0.0, 1.0);",
  "  if (fn > 0.0) {",
  "    vec2 q = xy / 22.0 + vec2(time * 0.09, -time * 0.07);",
  "    float n0 = vnoise(q);",
  "    g += vec2(vnoise(q + vec2(0.05, 0.0)) - n0, vnoise(q + vec2(0.0, 0.05)) - n0) / 0.05 / 22.0 * 0.12 * fn;",
  "  }",
  "  return normalize(vec3(-g, 1.0));",
  "}",

  // ---- tiles: x = grout amount (antialiased, fades to its average far away), y = per-tile variation
  // fw2 = the pixel footprint along each tile axis. At a glancing angle the footprint stretches along the view
  // only, so each family of grout lines gets its own antialiasing (one shared width left the lines running
  // across the view sub-pixel and dashed).
  "vec2 tileAt(vec2 uv, float size, vec2 fw2) {",
  "  vec2 f = fract(uv / size);",
  "  vec2 e2 = min(f, 1.0 - f) * size;",
  "  float w = 0.7;",
  "  vec2 aa = max(fw2 * 0.7, vec2(0.3));",
  "  vec2 ln = 1.0 - smoothstep(vec2(w) - aa, vec2(w) + aa, e2);",
  "  vec2 fade = smoothstep(vec2(size * 0.15), vec2(size * 0.6), fw2);",
  "  ln = mix(ln, vec2(2.0 * w / size), fade);",
  "  float fm = max(fade.x, fade.y);",
  "  return vec2(1.0 - (1.0 - ln.x) * (1.0 - ln.y), mix(hash2(floor(uv / size)), 0.5, fm));",
  "}",
  // the footprint frame of the point being shaded (set by shadeSurf): along the view projected on the surface
  // the pixel covers t*pixAng/cos, across it t*pixAng
  "vec3 gDp = vec3(1.0, 0.0, 0.0);",
  "vec3 gDq = vec3(0.0, 1.0, 0.0);",
  "float gNr = 1.0;",
  "float gFt = 1.0;",
  "float footOf(vec3 a) { float u = dot(a, gDp); float v = dot(a, gDq); return gFt * sqrt(u * u / gNr + v * v); }",
  // the surface of each tile, in its tangent plane: never quite coplanar with its neighbours, a slightly wavy
  // glaze, and edges that round off into the grout. This is what breaks the reflections up like real tiles.
  "vec2 tileTilt(vec2 uv, float size, float fw) {",
  "  vec2 id = floor(uv / size);",
  "  vec2 f = fract(uv / size) - 0.5;",
  "  vec2 tilt = (vec2(hash2(id + 3.1), hash2(id + 9.7)) - 0.5) * 0.045;",
  "  vec2 wav = (vec2(vnoise(uv * 0.19 + id * 3.0), vnoise(uv * 0.23 - id * 3.0)) - 0.5) * 0.025;",
  "  float b = 1.7 / size;",
  "  vec2 bev = sign(f) * smoothstep(0.5 - b * 1.8, 0.5, abs(f)) * 0.6;",
  "  return (tilt + wav) * (1.0 - smoothstep(size * 2.0, size * 8.0, fw)) + bev * (1.0 - smoothstep(size * 0.08, size * 0.5, fw));",
  "}",
  "vec2 surfaceTileAt(vec2 uv, vec2 footprint, float basin) {",
  "  if (basin <= 0.0) return tileAt(uv, 20.0, footprint);",
  "  if (basin >= 1.0) return tileAt(uv, 10.0, footprint);",
  "  return mix(tileAt(uv, 20.0, footprint), tileAt(uv, 10.0, footprint), basin);",
  "}",
  "vec2 surfaceTileTilt(vec2 uv, float fw, float basin) {",
  "  if (basin <= 0.0) return tileTilt(uv, 20.0, fw);",
  "  if (basin >= 1.0) return tileTilt(uv, 10.0, fw);",
  "  return mix(tileTilt(uv, 20.0, fw), tileTilt(uv, 10.0, fw), basin);",
  "}",

  // Physically based tile shading: GGX sun specular, Fresnel, diffuse from the baked multi-bounce probes.
  // glO = weight of the traced mirror reflection to add on top (0 when cheap: then it is approximated).
  "vec3 shadeSurf(vec3 p, vec3 rd, float mat, float t, bool cheap, out vec3 nO, out float glO) {",
  "  vec3 n = calcNormal(p);",
  "  nO = n;",
  "  glO = 0.0;",
  "  map(p);",
  "  float wdH = gWD;",
  "  float pal = palOf(gS[4]);",
  "  float fw = t * pixAng / max(abs(dot(n, rd)), 0.12);",            // isotropic estimate (tilt fades)
  "  vec3 dp0 = rd - n * dot(rd, n);",
  "  float lp0 = length(dp0);",
  "  gDp = lp0 > 1e-4 ? dp0 / lp0 : normalize(cross(n, abs(n.z) < 0.9 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0)));",
  "  gDq = cross(n, gDp);",
  "  gNr = max(dot(n, rd) * dot(n, rd), 0.0025);",
  "  gFt = t * pixAng;",
  "  vec3 E = irradiance(p + n * 4.0, n);",
  "  vec3 V = -rd;",
  "  float sv = sunLight(p, n, cheap);",
  "  if (mat > 3.5) {",                                          // chrome: a near-perfect mirror
  "    vec3 H = normalize(sunDir + V);",
  "    glO = cheap ? 0.0 : 0.8;",
  "    return E * (cheap ? 0.75 : 0.06) + SUNC * (sv * pow(max(dot(n, H), 0.0), 500.0) * 8.0);",
  "  }",
  "  vec3 alb;",
  "  float rough;",
  "  float gloss;",
  "  vec3 nP = n;",
  "  bool under = p.z < WATER - 1.0;",
  "  float basin = 1.0 - smoothstep(-18.0, -2.0, p.z);",
  "  float ao = cheap ? 1.0 : calcAO(p, n);",
  "  if (mat > 2.5) {",
  "    alb = vec3(0.88, 0.88, 0.87) * (0.97 + 0.04 * vnoise(p.xy * 0.04 + p.z * 0.03));",
  "    rough = 0.55;",
  "    gloss = 0.2;",
  "  } else {",
  "    bool floorS = n.z > 0.6;",
  // One world-space lattice across cells and curved surfaces. Palette and normal thresholds
  // must not change tile size or switch to a different local UV chart mid-surface.
  "    vec2 g;",
  "    vec2 uv;",
  "    vec3 tu;",
  "    vec3 tv;",
  "    float wDom = 1.0;",
  "    if (mat > 1.5 && abs(n.z) < 0.6) {",
  "      vec2 q = p.xy - (floor(p.xy / CS) + 0.5) * CS;",
  "      float radius = isFeat(gN[4], 2.0) ? STC : COLR;",
  "      float wrap = floor(6.2831853 * radius / 20.0 + 0.5) * 20.0;",
  "      uv = vec2(atan(q.y, q.x) * (wrap / 6.2831853), p.z);", // an integer number of tiles closes the cylinder without a seam
  "      tu = normalize(vec3(-q.y, q.x, 0.0));",
  "      tv = vec3(0.0, 0.0, 1.0);",
  "      g = surfaceTileAt(uv, vec2(footOf(tu), footOf(tv)), basin);",
  "    } else {",
  "      vec3 w = pow(abs(n), vec3(4.0));",
  "      w /= w.x + w.y + w.z;",
  "      vec3 X = vec3(1.0, 0.0, 0.0);",
  "      vec3 Y = vec3(0.0, 1.0, 0.0);",
  "      vec3 Z = vec3(0.0, 0.0, 1.0);",
  "      g = vec2(0.0);",
  "      if (w.x > 0.001) g += surfaceTileAt(p.yz, vec2(footOf(Y), footOf(Z)), basin) * w.x;",
  "      if (w.y > 0.001) g += surfaceTileAt(p.xz, vec2(footOf(X), footOf(Z)), basin) * w.y;",
  "      if (w.z > 0.001) g += surfaceTileAt(p.xy, vec2(footOf(X), footOf(Y)), basin) * w.z;",
  "      if (w.z >= w.x && w.z >= w.y) { uv = p.xy; tu = vec3(1.0, 0.0, 0.0); tv = vec3(0.0, 1.0, 0.0); wDom = w.z; }",
  "      else if (w.x >= w.y) { uv = p.yz; tu = vec3(0.0, 1.0, 0.0); tv = vec3(0.0, 0.0, 1.0); wDom = w.x; }",
  "      else { uv = p.xz; tu = vec3(1.0, 0.0, 0.0); tv = vec3(0.0, 0.0, 1.0); wDom = w.y; }",
  "      wDom = smoothstep(0.55, 0.9, wDom);",
  "    }",
  "    vec2 tl = cheap ? vec2(0.0) : surfaceTileTilt(uv, fw, basin) * wDom;",
  "    nP = normalize(n + tu * tl.x + tv * tl.y);",
  "    vec3 tileC = vec3(0.93, 0.935, 0.93);",
  "    vec3 groutC = vec3(0.60, 0.62, 0.62);",
  "    if (pal > 0.5 && pal < 1.5) tileC = vec3(0.90, 0.93, 0.95);",
  "    if (pal > 1.5 && pal < 2.5 && !floorS && p.z > 68.0 && p.z < 112.0) tileC = vec3(0.22, 0.60, 0.66);",
  "    if (pal > 2.5) groutC = vec3(0.78, 0.79, 0.79);",
  "    vec3 basinC = (pal > 1.5 && pal < 2.5) ? vec3(0.36, 0.72, 0.77) : vec3(0.60, 0.81, 0.93);",
  "    tileC = mix(tileC, basinC, basin);",
  "    groutC = mix(groutC, basinC * 0.72, basin);",
  "    tileC *= 0.97 + 0.06 * g.y;",
  "    if (!floorS && mat < 1.5 && faceCount > 0) {",                     // the grout still runs across it
  "      vec3 ft;",
  "      tileC *= pressedFace(p, n, ft);",
  "      nP = normalize(nP + ft);",
  "    }",
  "    alb = mix(tileC, groutC, g.x);",
  "    alb *= mix(vec3(0.84, 0.84, 0.80), vec3(1.0), mix(1.0, ao, 0.6 + 0.4 * g.x));",   // grime settles where light can't reach
  "    if (!floorS && abs(p.z - WATER) < 2.2) alb *= 0.84;",      // the waterline
  "    rough = mix(0.13, 0.75, g.x);",
  "    gloss = 1.0 - g.x;",
  "    if (floorS && abs(p.z) < 3.0 && wdH > 0.0 && wdH < 60.0) { alb *= 0.9; rough = 0.03; gloss = 1.0; }",   // wet rim
  "  }",
  "  vec3 H = normalize(sunDir + V);",
  "  float NdL = max(dot(nP, sunDir), 0.0) * step(0.0, dot(n, sunDir));",
  "  float NdV = max(dot(nP, V), 0.001);",
  "  float NdH = max(dot(nP, H), 0.0);",
  "  float a2 = rough * rough * rough * rough;",
  "  float dd = NdH * NdH * (a2 - 1.0) + 1.0;",
  "  float D = a2 / (3.14159 * dd * dd);",
  "  float kG = (rough + 1.0) * (rough + 1.0) / 8.0;",
  "  float G = NdV / (NdV * (1.0 - kG) + kG) * NdL / (NdL * (1.0 - kG) + kG);",
  "  float Fs = 0.04 + 0.96 * pow(clamp(1.0 - max(dot(V, H), 0.0), 0.0, 1.0), 5.0);",
  "  float spec = min(D * G * Fs / (4.0 * NdV * max(NdL, 0.001)), 16.0) * NdL;",
  "  float Fv = 0.04 + 0.96 * pow(clamp(1.0 - NdV, 0.0, 1.0), 5.0);",      // how much of the view the glaze mirrors
  "  float refl = Fv * gloss * (1.0 - smoothstep(0.1, 0.45, rough));",
  "  vec3 col = alb * (E * ao + SUNC * (max(dot(n, sunDir), 0.0) * sv)) * (1.0 - Fv * gloss);",
  "  col += SUNC * (spec * sv * gloss);",
  // traced mirror for floors (the reflections you notice) and strong grazing glints; elsewhere the room's
  // baked light stands in for what the glaze reflects
  "  if (!cheap && n.z > 0.5) glO = refl * mix(0.55, 1.0, ao);",
  "  else col += E * (refl * 0.9);",
  "  nO = nP;",
  "  if (under) {",                                               // refracted sun and sky caustics, focused by the simulated surface
  "    float cs = caustics(p.xy + n.xy * 25.0 + p.z * 0.4) * simFocus(p.xy);",
  "    col += alb * cs * (E * 0.4 + SUNC * (sv * 1.1 + 0.03)) * clamp((WATER - p.z) / 30.0, 0.0, 1.0);",
  "  } else if (!cheap) {",                                        // (not in reflections: too small to see there)
  "    col += alb * waterBounce(p, n, E);",                         // light reflected by the water onto walls and ceilings
  "  }",
  "  return col;",
  "}",

  // ---- sun shafts in the air (only where the sky is visible through an opening)
  "float shafts(vec3 ro, vec3 rd, float tEnd) {",
  "  float L = min(tEnd, 3200.0);",
  "  float jit = hash2(gl_FragCoord.xy - renderOrigin + fract(time * 7.0) * 61.0);",
  "  float acc = 0.0;",
  "  for (int s = zeroI; s < 5; s++) {",
  "    vec3 q = ro + rd * ((float(s) + jit) / 5.0 * L);",
  "    if (q.z < WATER) continue;",
  "    if (q.z > hOf(styleAt(floor(q.xy / CS)))) continue;",
  "    acc += sunGate(q);",
  "  }",
  "  return acc / 5.0 * L;",
  "}",

};

// ---- PASS 2 (full resolution): the camera rays, fully shaded. What glazed floors, chrome and the water show by
//      reflection / refraction comes from pass 1 (POOL_SEC_MAIN) at half resolution, blended in per surface type.
//      Output: the camera sensor's response, 1 - exp(-light * exposure), exactly like the Backrooms' world shader,
//      so the engine's metering, auto exposure, lens, tape and codec treat it the same way.
String[] POOL_MAIN = {
  // pass 1's result around this pixel, only from samples of the same kind of surface (0.25 mirror, 0.75 water)
  "vec3 secSample(float type, vec3 fallback) {",
  "  vec2 tc = (gl_FragCoord.xy - renderOrigin) * (secSize / bufSize) - 0.5;",
  "  vec2 i0 = floor(tc);",
  "  vec2 f = tc - i0;",
  "  vec3 s = vec3(0.0);",
  "  float w = 0.0;",
  "  for (int j = zeroI; j < 2; j++) {",
  "    for (int i = zeroI; i < 2; i++) {",
  "      vec4 v = poolDataFetch(secTex, (secOrigin + clamp(i0 + vec2(float(i), float(j)), vec2(0.0), secSize - 1.0) + 0.5) / secCapacity);",
  "      float ww = (i == 1 ? f.x : 1.0 - f.x) * (j == 1 ? f.y : 1.0 - f.y) * (abs(v.a - type) < 0.2 ? 1.0 : 0.0) + 1e-6;",
  "      s += -2.0 * log(max(vec3(1.0) - v.rgb, vec3(0.002))) * ww;",
  "      w += ww;",
  "    }",
  "  }",
  "  return w > 0.01 ? s / w : fallback;",
  "}",
  "void main() {",
  "  vec2 uv = vUV * 2.0 - 1.0;",
  "  vec3 rd = normalize(camF + camR * (uv.x * tanHalf.x) - camU * (uv.y * tanHalf.y));",
  "  vec3 hazeC = -log(max(vec3(1.0) - poolDataFetch(hazeTex, vec2(0.5)).rgb, vec3(0.002)));",
  "  float tw = rd.z < -0.0001 ? (WATER - camPos.z) / rd.z : 1000000.0;",
  "  float mat;",
  "  float t = march(camPos, rd, min(tw, 12000.0), 220, mat);",
  "  vec3 col = hazeC;",
  "  if (mat > 8.5) col = SKYC;",
  "  else if (mat > 0.0) {",
  "    vec3 p = camPos + rd * t;",
  "    vec3 n;",
  "    float gl;",
  "    col = shadeSurf(p, rd, mat, t, lite > 0.5, n, gl);",
  "    if (gl > 0.0) col += secSample(0.25, hazeC) * gl;",          // the mirror image in the glaze
  "  } else if (mat < -1.5 && tw < 100000.0) {",                   // the water: glint here, the rest from pass 1
  "    vec3 p = camPos + rd * tw;",
  "    vec3 wn = waterN(p.xy, tw);",
  "    vec3 H = normalize(sunDir - rd);",
  "    col = SUNC * (sunGate(p) * pow(max(dot(wn, H), 0.0), 1400.0) * 9.0) + secSample(0.75, WATERC * hazeC * 1.4);",
  "    t = tw;",
  "  }",
  "  col += SUNC * (shafts(camPos, rd, t) * 0.000014 * (0.5 + 1.2 * pow(max(dot(rd, sunDir), 0.0), 4.0)));",
  "  col = mix(col, hazeC, 1.0 - exp(-t / 9000.0));",
  "  if (!(col.r == col.r) || !(col.g == col.g) || !(col.b == col.b)) col = hazeC;",   // never let a NaN reach the bloom
  "  col = 1.0 - exp(-max(col, 0.0) * exposure * 1.6);",
  "  gl_FragColor = vec4(pow(col, vec3(1.0 / 2.2)), 1.0);",
  "}"
};
String[] POOL_FRAG = poolJoin(poolJoin(POOL_COMMON, POOL_FUNCS), POOL_MAIN);

// ---- PASS 1 (half resolution): the secondary rays. For a glazed floor or chrome: the unweighted mirror image
//      (pass 2 applies its own detailed Fresnel and gloss). For the water: the whole surface — reflection times
//      Fresnel plus the refracted, absorbed pool below. Stored as 1 - exp(-L/2); alpha = which kind of surface.
//      One march / shadeSurf call site for the secondary rays (a 2-step loop), as everywhere in these shaders.
String[] POOL_SEC_MAIN = {
  "void main() {",
  "  vec2 uv = vUV * 2.0 - 1.0;",
  "  vec3 rd = normalize(camF + camR * (uv.x * tanHalf.x) - camU * (uv.y * tanHalf.y));",
  "  vec3 hazeC = -log(max(vec3(1.0) - poolDataFetch(hazeTex, vec2(0.5)).rgb, vec3(0.002)));",
  "  float tw = rd.z < -0.0001 ? (WATER - camPos.z) / rd.z : 1000000.0;",
  "  float mat;",
  "  float t0 = march(camPos, rd, min(tw, 12000.0), 220, mat);",
  "  float type = 0.0;",
  "  vec3 oA = camPos; vec3 dA = rd; vec3 wA = vec3(0.0); float tmA = 0.0;",
  "  vec3 oB = camPos; vec3 dB = rd; vec3 wB = vec3(0.0); float tmB = 0.0;",
  "  float tBase = t0;",
  "  if (mat > 0.0 && mat < 8.5) {",
  "    vec3 p = camPos + rd * t0;",
  "    vec3 n = calcNormal(p);",
  "    if (n.z > 0.5 || mat > 3.5) {",
  "      vec3 rr = reflect(rd, n);",
  "      if (rr.z * n.z < -0.2) rr = reflect(rd, vec3(0.0, 0.0, sign(n.z)));",
  "      oA = p + n * 1.0; dA = rr; wA = vec3(1.0); tmA = 2200.0; type = 0.25;",
  "    }",
  "  } else if (mat < -1.5 && tw < 100000.0) {",
  "    vec3 p = camPos + rd * tw;",
  "    vec3 wn = waterN(p.xy, tw);",
  "    float fres = 0.02 + 0.98 * pow(clamp(1.0 - dot(wn, -rd), 0.0, 1.0), 5.0);",
  "    vec3 rr = reflect(rd, wn);",
  "    rr.z = max(rr.z, 0.02);",
  "    oA = p + vec3(0.0, 0.0, 0.5); dA = normalize(rr); wA = vec3(fres); tmA = 5000.0;",
  "    oB = p - vec3(0.0, 0.0, 0.5); dB = refract(rd, wn, 0.7519); wB = vec3(1.0 - fres); tmB = 1600.0;",
  "    type = 0.75;",
  "    tBase = tw;",
  "  }",
  "  vec3 col = vec3(0.0);",
  "  for (int k = zeroI; k < 2; k++) {",
  "    if (type < 0.1 || (k == 1 && type < 0.5)) break;",
  "    bool under = k == 1;",
  "    vec3 o = under ? oB : oA;",
  "    vec3 d = under ? dB : dA;",
  "    float twk = (!under && d.z < -0.0001) ? (WATER - o.z) / d.z : 1000000.0;",
  "    if (twk < 0.0) twk = 1000000.0;",
  "    float m2;",
  "    float t2 = march(o, d, min(twk, under ? tmB : tmA), under ? 48 : 64, m2);",
  "    vec3 c = hazeC;",
  "    if (m2 > 8.5) c = SKYC;",
  "    else if (m2 > 0.0) { vec3 nn; float gg; c = shadeSurf(o + d * t2, d, m2, tBase + t2, true, nn, gg); }",
  "    else if (m2 < -1.5 && twk < 100000.0) c = WATERC * hazeC * 2.2;",   // a reflection that lands on water
  "    if (under) {",                                           // absorption and in-scattering along the path
  "      vec3 trans = exp(-SIGMA * t2);",
  "      c = c * trans + WATERC * irradiance(o + vec3(0.0, 0.0, 20.0), vec3(0.0, 0.0, 1.0)) * 0.35 * (1.0 - trans);",
  "    }",
  "    col += (under ? wB : wA) * c;",
  "  }",
  "  if (!(col.r == col.r) || !(col.g == col.g) || !(col.b == col.b)) col = vec3(0.0);",
  "  gl_FragColor = vec4(1.0 - exp(-max(col, 0.0) * 0.5), type);",
  "}"
};
String[] POOL_SEC = poolJoin(poolJoin(POOL_COMMON, POOL_FUNCS), POOL_SEC_MAIN);

// ---- the light bake: every texel is one face of one probe. It traces cosine-distributed rays into the level,
//      lights what they hit with the sun through the skylights plus the previous pass's probes (so every pass adds
//      one more bounce), and blends the result in. White glazed tiles reflect ~86%: the light goes everywhere.
String[] POOL_BAKE_MAIN = {
  "uniform float bakeSlice;",
  "uniform float bakeSlices;",
  "uniform float blendK;",
  "uniform float frameSeed;",
  "void main() {",
  "  vec2 px = floor(gl_FragCoord.xy);",
  "  if (mod(px.y, bakeSlices) != bakeSlice) {",
  "    gl_FragColor = poolDataFetch(probes, (px + 0.5) / probeTex); return;",
  "  }",
  "  float ci = floor(px.x / 6.0);",
  "  float face = px.x - ci * 6.0;",
  "  float cj = floor(px.y / 3.0);",
  "  float k = px.y - cj * 3.0;",
  "  vec2 c = vec2(ci, cj);",
  "  if (codeAt(c) < 0.5) { gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }",
  "  vec3 prev = probeFetch(c, k, face);",
  "  vec3 P = probePos(c, k);",
  "  vec3 N = face < 0.5 ? vec3(1.0, 0.0, 0.0) : (face < 1.5 ? vec3(-1.0, 0.0, 0.0) : (face < 2.5 ? vec3(0.0, 1.0, 0.0)",
  "         : (face < 3.5 ? vec3(0.0, -1.0, 0.0) : (face < 4.5 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 0.0, -1.0)))));",
  "  vec3 T = normalize(abs(N.z) < 0.9 ? cross(N, vec3(0.0, 0.0, 1.0)) : cross(N, vec3(1.0, 0.0, 0.0)));",
  "  vec3 B = cross(N, T);",
  "  vec3 acc = vec3(0.0);",
  "  for (int r = zeroI; r < 8; r++) {",
  "    float fr = float(r);",
  "    vec2 u = vec2(hash2(px * 1.37 + vec2(frameSeed * 7.13 + fr * 3.71, fr * 1.3)), hash2(px * 2.11 + vec2(fr * 5.3, frameSeed * 1.91 - fr)));",
  "    float phi = 6.2831853 * u.x;",
  "    float st = sqrt(u.y);",
  "    vec3 d = normalize(T * (cos(phi) * st) + B * (sin(phi) * st) + N * sqrt(max(1.0 - u.y, 0.0)));",
  "    float mat;",
  "    float t = march(P, d, 6000.0, 120, mat);",
  "    vec3 L = prev;",
  "    if (mat > 8.5) L = SKYC;",
  "    else if (mat > 0.0) {",
  "      vec3 q = P + d * t;",
  "      vec3 nq = calcNormal(q);",
  "      vec3 alb = q.z < WATER - 1.0 ? vec3(0.72, 0.86, 0.92) : (mat > 3.5 ? vec3(0.5) : vec3(0.86, 0.865, 0.86));",
  "      float sg = dot(nq, sunDir) > 0.0 ? sunGate(q) : 0.0;",
  "      L = alb * (SUNC * (max(dot(nq, sunDir), 0.0) * sg) + irradiance(q + nq * 4.0, nq));",
  "    }",
  "    acc += L;",
  "  }",
  "  vec3 res = mix(prev, acc / 8.0, blendK);",
  "  gl_FragColor = vec4(1.0 - exp(-res * 0.5), 1.0);",
  "}"
};
String[] POOL_BAKE = poolJoin(POOL_COMMON, POOL_BAKE_MAIN);

String[] POOL_HAZE = poolJoin(POOL_COMMON, new String[]{
  "uniform float hazeBlend;",
  "void main() {",
  "  vec2 c = floor(camPos.xy / CS); vec3 light = vec3(0.0);",
  "  if (codeAt(c) > 0.5) {",
  "    float floorZ = fH(elevAt(c), vec2(0.0));",
  "    float k = clamp(floor((camPos.z-floorZ-35.0)/max((hOf(styleAt(c))-floorZ-70.0)*0.5,1.0)+0.5),0.0,2.0);",
  "    for (int face = 0; face < 6; face++) light += probeFetch(c,k,float(face)) / 6.0;",
  "  }",
  "  vec3 previous = -2.0 * log(max(vec3(1.0)-poolDataFetch(hazeTex,vec2(0.5)).rgb,vec3(0.002)));",
  "  gl_FragColor = vec4(1.0-exp(-mix(previous,light,hazeBlend)*0.5),1.0);",
  "}"
});

// ---- the water: a damped wave equation on a height field covering the level (16-bit height and previous
//      height packed in RGBA8). Walls and the pool edges reflect the waves; impulses come from you and from drips.
String[] POOL_SIM = poolJoin(POOL_DATA_SAMPLING, new String[]{
  "#define PROCESSING_TEXTURE_SHADER",
  "#ifdef GL_ES",
  "precision highp float;",
  "#endif",
  "uniform sampler2D texture;",
  "uniform sampler2D state;",
  "uniform sampler2D mapTex;",
  "uniform float gridSize;",
  "uniform float simN;",
  "uniform float simScale;",
  "uniform vec4 imp[6];",
  "uniform vec4 flow;",
  "uniform float c2;",
  "uniform float damp;",
  "varying vec2 vUV;",
  "const float CS = " + CELL + ";",
  "bool wetT(vec2 t) {",
  "  vec2 c = floor((t + 0.5) / simScale / CS);",
  "  if (c.x < 0.0 || c.y < 0.0 || c.x >= gridSize || c.y >= gridSize) return false;",
  "  float code = floor(poolDataFetch(mapTex, (c + 0.5) / gridSize).r * 255.0 + 0.5);",
  "  return code > 0.5 && mod(code - 1.0, 3.0) > 0.5;",
  "}",
  "vec2 dec(vec4 v) { vec4 b = floor(v * 255.0 + 0.5); return (vec2(b.r * 256.0 + b.g, b.b * 256.0 + b.a) / 65535.0 - 0.5) * 8.0; }",
  "vec4 enc(vec2 h) {",
  "  vec2 u = floor(clamp(h / 8.0 + 0.5, 0.0, 1.0) * 65535.0 + 0.5);",
  "  vec2 hi = floor(u / 256.0);",
  "  vec2 lo = u - hi * 256.0;",
  "  return vec4(hi.x, lo.x, hi.y, lo.y) / 255.0;",
  "}",
  "void main() {",
  "  vec2 t = floor(gl_FragCoord.xy);",
  "  if (!wetT(t)) { gl_FragColor = enc(vec2(0.0)); return; }",
  "  vec2 s = dec(poolDataFetch(state, (t + 0.5) / simN));",
  "  float h = s.x;",
  "  float sum = 0.0;",
  "  for (int k = 0; k < 4; k++) {",
  "    vec2 o = k == 0 ? vec2(1.0, 0.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));",
  "    sum += wetT(t + o) ? dec(poolDataFetch(state, (t + o + 0.5) / simN)).x : h;",
  "  }",
  "  float hn = (2.0 * h - s.y + c2 * (sum - 4.0 * h)) * damp;",
  "  vec2 w = (t + 0.5) / simScale;",
  "  for (int k = 0; k < 6; k++) {",
  "    vec4 m = imp[k];",
  "    if (m.z <= 0.0) continue;",
  "    vec2 dv = w - m.xy;",
  "    hn += m.w * exp(-dot(dv, dv) / (m.z * m.z));",
  "  }",
  "  if (flow.z > 0.0) {",
  "    vec2 dv = w - flow.xy; hn += flow.w * exp(-dot(dv, dv) / (flow.z * flow.z));",
  "  }",
  "  gl_FragColor = enc(vec2(hn, h));",
  "}"
});

String[] poolJoin(String[] a, String[] b) {
  String[] r = new String[a.length + b.length];
  System.arraycopy(a, 0, r, 0, a.length);
  System.arraycopy(b, 0, r, a.length, b.length);
  return r;
}

// ---- bloom: bright pass + separable gaussian at 1/4 and 1/16 of the raymarch resolution
String[] POOL_BRIGHT = {
  "#ifdef GL_ES",
  "precision mediump float;",
  "#endif",
  "#define PROCESSING_TEXTURE_SHADER",
  "uniform sampler2D texture;",
  "uniform vec2 px;",
  "uniform float thresh;",
  "uniform vec2 brightMin, brightMax;",
  "varying vec4 vertTexCoord;",
  "vec3 brightAt(vec2 uv) { return texture2D(texture, clamp(uv, brightMin, brightMax)).rgb; }",
  "void main() {",
  "  vec2 uv = vertTexCoord.st;",
  "  vec3 c = brightAt(uv + px * vec2(-1.0, -1.0)) + brightAt(uv + px * vec2(1.0, -1.0))",
  "         + brightAt(uv + px * vec2(-1.0, 1.0)) + brightAt(uv + px * vec2(1.0, 1.0));",
  "  c *= 0.25;",
  "  float l = max(c.r, max(c.g, c.b));",
  "  gl_FragColor = vec4(c * smoothstep(thresh, 1.0, l), 1.0);",
  "}"
};

String[] POOL_BLUR = {
  "#ifdef GL_ES",
  "precision mediump float;",
  "#endif",
  "#define PROCESSING_TEXTURE_SHADER",
  "uniform sampler2D texture;",
  "uniform vec2 dir;",
  "uniform vec2 blurMin, blurMax;",
  "varying vec4 vertTexCoord;",
  "vec3 blurAt(vec2 uv) { return texture2D(texture, clamp(uv, blurMin, blurMax)).rgb; }",
  "void main() {",
  "  vec2 uv = vertTexCoord.st;",
  "  vec3 c = blurAt(uv) * 0.227027;",
  "  c += (blurAt(uv + dir * 1.384615) + blurAt(uv - dir * 1.384615)) * 0.316216;",
  "  c += (blurAt(uv + dir * 3.230769) + blurAt(uv - dir * 3.230769)) * 0.070270;",
  "  gl_FragColor = vec4(c, 1.0);",
  "}"
};

// ---- faces pressed into the tiles (ported from the poolrooms-lino branch): a few big, rare faces on
// tall walls. Each photo becomes a shading factor (brightness + a slight emboss lit from the top left,
// fading into plain tile at its edges); the shader multiplies it into the wall's own tile colour, so every
// palette gets its own tint and the grout keeps running across the face.
final int POOL_FACES = 6;                      // per level
final float POOL_FACE_Z = 200, POOL_FACE_HW = 120, POOL_FACE_HH = 150;   // centre height, half size
final int FACE_TW = 128, FACE_TH = 160;        // atlas slot
PImage poolFaceAtlas;
float[] poolFaceA = new float[32], poolFaceB = new float[32];
int poolFaceN;

void makePoolFaceAtlas() {
  poolFaceAtlas = createImage(FACE_TW * NAMES.length, FACE_TH, RGB);
  poolFaceAtlas.loadPixels();
  for (int k = 0; k < NAMES.length; k++) {
    PImage src = faces[k].get(faces[k].width / 8, 0, faces[k].width * 3 / 4, faces[k].height * 15 / 16);
    src.resize(FACE_TW, FACE_TH);
    src.filter(BLUR, 1);                       // only the broad shapes survive as relief
    src.loadPixels();
    for (int y = 0; y < FACE_TH; y++) for (int x = 0; x < FACE_TW; x++) {
      float l = brightness(src.pixels[y * FACE_TW + x]) / 255.0;
      float l2 = brightness(src.pixels[min(FACE_TH - 1, y + 2) * FACE_TW + min(FACE_TW - 1, x + 2)]) / 255.0;
      float edge = constrain(min(min(x, FACE_TW - 1 - x), min(y, FACE_TH - 1 - y)) / 20.0, 0, 1);
      float face = 0.42 + 0.68 * pow(l, 0.85) + (l - l2) * 1.4;
      float v = lerp(1, face, edge * edge * (3 - 2 * edge));
      poolFaceAtlas.pixels[y * poolFaceAtlas.width + k * FACE_TW + x] = color(constrain(v / 1.6, 0, 1) * 255);
    }
  }
  poolFaceAtlas.updatePixels();
}

void placePoolFaces() {
  poolFaceN = 0;
  java.util.ArrayList<PVector> used = new java.util.ArrayList<PVector>();
  for (int tries = 0; tries < 4000 && poolFaceN < POOL_FACES; tries++) {
    int[] c = randomOpenCell();
    int i = c[0], j = c[1];
    if ((pStyle[i][j] - 1) / 4 < 1) continue;  // barrel vaults curve in above 200: only flat, tall walls
    if (pElev[i][j] != E_LOW || pFeat[i][j] != F_NONE) continue;
    int[] d = DIRS[(int) random(4)];
    if (!isWall(i + d[0], j + d[1])) continue;
    float cx = (i + 0.5) * CELL + d[0] * CELL * 0.5, cy = (j + 0.5) * CELL + d[1] * CELL * 0.5;
    boolean near = false;
    for (PVector u : used) if (dist(u.x, u.y, cx, cy) < CELL * 3) near = true;
    if (near) continue;
    used.add(new PVector(cx, cy));
    int k = poolFaceN * 4;
    poolFaceA[k] = cx; poolFaceA[k + 1] = cy; poolFaceA[k + 2] = POOL_FACE_Z; poolFaceA[k + 3] = (int) random(NAMES.length);
    poolFaceB[k] = -d[0]; poolFaceB[k + 1] = -d[1]; poolFaceB[k + 2] = POOL_FACE_HW; poolFaceB[k + 3] = POOL_FACE_HH;
    poolFaceN++;
  }
}

void initPools() {
  poolSh = new PShader(this, POOL_VERT, POOL_FRAG);
  poolBright = new PShader(this, POST_VERT, POOL_BRIGHT);
  poolBlur = new PShader(this, POST_VERT, POOL_BLUR);
  poolBakeSh = new PShader(this, POOL_VERT, POOL_BAKE);
  poolSimSh = new PShader(this, POOL_VERT, POOL_SIM);
  poolSecSh = new PShader(this, POOL_VERT, POOL_SEC);
  poolHazeSh = new PShader(this, POOL_VERT, POOL_HAZE);
  poolDummy = createImage(4, 4, RGB);
  poolDummy.loadPixels();
  java.util.Arrays.fill(poolDummy.pixels, color(255));
  poolDummy.updatePixels();
  makePoolFaceAtlas();
}

PGraphics poolDataBuffer(int w, int h) {       // exact data texture: no multisampling, no blending
  PGraphics g = createGraphics(w, h, P2D);
  g.noSmooth();
  return g;
}

// draw one full-screen pass of a data shader into dst (writes every texel, blending off)
void poolDataPass(PGraphics dst, PShader sh) {
  poolDataPassRegion(dst, sh, dst.width, dst.height);
}

void poolDataPassRegion(PGraphics dst, PShader sh, int w, int h) {
  dst.beginDraw();
  prepareLightingData(dst, poolMapTex);
  dst.blendMode(REPLACE);
  dst.textureMode(NORMAL);
  dst.shader(sh);
  dst.noStroke();
  dst.beginShape(QUADS);
  dst.texture(poolDummy);
  dst.vertex(0, 0, 0, 0);
  dst.vertex(w, 0, 1, 0);
  dst.vertex(w, h, 1, 1);
  dst.vertex(0, h, 0, 1);
  dst.endShape();
  dst.resetShader();
  dst.endDraw();
}

// The level's data textures and lighting uniforms shared by the renderer and the bake.
void poolSetScene(PShader sh, float t) {
  sh.set("mapTex", poolMapTex);
  sh.set("gridSize", (float) POOL_GRID);
  sh.set("time", t);
  sh.set("sunDir", POOL_SUN.x, POOL_SUN.y, POOL_SUN.z);
  sh.set("zeroI", 0);
  sh.set("probeTex", (float) poolProbeA.width, (float) poolProbeA.height);
  sh.set("probes", poolProbeA);
  sh.set("waterSim", poolSimA);
  if (poolHazeA != null) sh.set("hazeTex", poolHazeA);
  sh.set("simN", (float) POOL_SIM_N);
  sh.set("simScale", POOL_SIM_N / (POOL_GRID * CELL));
}

// a new level: dark probes and still water
void poolResetLighting() {
  if (poolProbeA == null) {
    poolProbeA = poolDataBuffer(POOL_GRID * 6, POOL_GRID * 3);
    poolProbeB = poolDataBuffer(POOL_GRID * 6, POOL_GRID * 3);
    poolSimA = poolDataBuffer(POOL_SIM_N, POOL_SIM_N);
    poolSimB = poolDataBuffer(POOL_SIM_N, POOL_SIM_N);
  }
  for (PGraphics g : new PGraphics[]{poolProbeA, poolProbeB}) {
    g.beginDraw();
    g.background(0);
    g.endDraw();
  }
  for (PGraphics g : new PGraphics[]{poolSimA, poolSimB}) {   // height 0 encodes as 0x8000 in both halves
    g.beginDraw();
    g.blendMode(REPLACE);
    g.background(128, 0, 128, 0);
    g.endDraw();
  }
  // data textures: exact texels, no filtering, no mipmaps. The lookups jump between probe cells from one pixel
  // to the next; with mipmapped sampling the GPU then reads a level that was never generated, which drew
  // dotted lines on the walls and ceilings at every probe cell boundary.
  for (PGraphics g : new PGraphics[]{poolProbeA, poolProbeB, poolSimA, poolSimB})
    prepareLightingData(g, g); // exact texels, including anisotropy off
  poolBakePasses = poolBakeSlice = 0;
  poolProbePix = null;
  poolImpN = 0;
  poolFlow[2] = 0;
  poolSimAccumulator = 0;
  poolDripT = 0;
  poolHazeReady = false;
}

// bounce passes: each one traces rays from every probe and adds one more bounce of light
void poolBake(int passes) {
  for (int k = 0; k < passes; k++) {
    poolSetScene(poolBakeSh, 0);
    poolBakeSh.set("bakeSlices", 1.0);
    poolBakeSh.set("bakeSlice", 0.0);
    poolBakeSh.set("blendK", max(1.0 / (poolBakePasses + 1), 0.12));
    poolBakeSh.set("frameSeed", (float) (poolBakePasses % 997));
    poolDataPass(poolProbeB, poolBakeSh);
    PGraphics s = poolProbeA;
    poolProbeA = poolProbeB;
    poolProbeB = s;
    poolBakePasses++;
  }
}

// One interleaved row group per scheduled slice; untouched probes are copied exactly from the previous target.
// Both ping-pong targets therefore always contain a complete light field.
void poolAdvanceLighting() {
  if (poolBakePasses >= POOL_BAKE_TOTAL) return;
  poolSetScene(poolBakeSh, 0);
  poolBakeSh.set("bakeSlices", (float) POOL_BAKE_SLICES);
  poolBakeSh.set("bakeSlice", (float) poolBakeSlice);
  poolBakeSh.set("blendK", max(1.0 / (poolBakePasses + 1), 0.12));
  poolBakeSh.set("frameSeed", (float) (poolBakePasses % 997));
  poolDataPass(poolProbeB, poolBakeSh);
  PGraphics swap = poolProbeA; poolProbeA = poolProbeB; poolProbeB = swap;
  if (++poolBakeSlice == POOL_BAKE_SLICES) { poolBakeSlice = 0; poolBakePasses++; }
  // Haze reads probes on the GPU; gameplay never downloads a lighting atlas.
}

// Optional diagnostic readback. Gameplay computes camera haze on the GPU.
int[] poolProbePix;
void poolReadProbes() {
  poolProbeA.loadPixels();
  if (poolProbePix == null || poolProbePix.length != poolProbeA.pixels.length)
    poolProbePix = new int[poolProbeA.pixels.length];
  System.arraycopy(poolProbeA.pixels, 0, poolProbePix, 0, poolProbePix.length);
}

// mean incoming light around (x, y, z), from the probes of that cell
PVector poolLightProbe(float x, float y, float z) {
  PVector r = new PVector();
  int ci = cellOf(x), cj = cellOf(y);
  if (poolProbePix == null || isWall(ci, cj)) return r;
  float f = pFH(pElev[ci][cj], 0, 0);
  int hc = (pStyle[ci][cj] - 1) / 4;
  float h = hc == 0 ? POOL_VZ + CELL / 2 - 12 : (hc == 1 ? POOL_H1 : (hc == 2 ? POOL_H2 : POOL_H3));
  int k = constrain(round((z - f - 35) / max((h - f - 70) * 0.5, 1)), 0, 2);
  int W = poolProbeA.width, H = poolProbeA.height;
  for (int face = 0; face < 6; face++) {
    int tx = ci * 6 + face, ty = cj * 3 + k;
    int c = poolProbePix[(H - 1 - ty) * W + tx];         // the data was written bottom-up (GL), the readback is top-down
    r.x += -2 * log(max(1 - ((c >> 16) & 255) / 255.0, 0.002));
    r.y += -2 * log(max(1 - ((c >> 8) & 255) / 255.0, 0.002));
    r.z += -2 * log(max(1 - (c & 255) / 255.0, 0.002));
  }
  r.div(6);
  return r;
}

void poolImpulse(float x, float y, float r, float amp) {
  if (poolImpN >= 6) return;
  poolImp[poolImpN * 4] = x;
  poolImp[poolImpN * 4 + 1] = y;
  poolImp[poolImpN * 4 + 2] = r;
  poolImp[poolImpN * 4 + 3] = amp;
  poolImpN++;
}

// Accumulate elapsed time; event impulses survive frames with no tick and are consumed once.
// Continuous wading is applied per tick, independent of the display refresh rate.
void poolSimStep(float dt) {
  poolSimAccumulator = Math.min(poolSimAccumulator + Math.max(0, dt), POOL_SIM_DT * POOL_SIM_MAX_STEPS);
  int steps = 0;
  while (poolSimAccumulator + 1e-9d >= POOL_SIM_DT && steps++ < POOL_SIM_MAX_STEPS) {
    for (int k = poolImpN; k < 6; k++) poolImp[k * 4 + 2] = 0;
    poolSimSh.set("state", poolSimA);
    poolSimSh.set("mapTex", poolMapTex);
    poolSimSh.set("gridSize", (float) POOL_GRID);
    poolSimSh.set("simN", (float) POOL_SIM_N);
    poolSimSh.set("simScale", POOL_SIM_N / (POOL_GRID * CELL));
    poolSimSh.set("imp", poolImp, 4);
    poolSimSh.set("flow", poolFlow[0], poolFlow[1], poolFlow[2], poolFlow[3]);
    poolSimSh.set("c2", 0.08);
    poolSimSh.set("damp", 0.9965);
    poolDataPass(poolSimB, poolSimSh);
    PGraphics swap = poolSimA; poolSimA = poolSimB; poolSimB = swap;
    poolImpN = 0;
    poolSimAccumulator -= POOL_SIM_DT;
  }
}

PGraphics poolTarget(PGraphics buf, int w, int h) {
  if (buf == null || buf.width != w || buf.height != h) {
    if (buf != null) buf.dispose();
    buf = poolDataBuffer(w, h);               // full-screen shader output needs neither MSAA nor a 3D target
  }
  return buf;
}

PGraphics poolTarget2D(PGraphics buf, int w, int h) {
  if (buf == null || buf.width != w || buf.height != h) {
    if (buf != null) buf.dispose();
    buf = poolDataBuffer(w, h);
  }
  return buf;
}

// Release targets when leaving the level; the preview lazily recreates what it needs.
void poolReleaseBuffers() {
  poolFrameTimer.release();
  poolMeterReadback.release();
  for (PGraphics buf : new PGraphics[]{poolBuf, poolPrevBuf, poolBloomA, poolBloomB, poolBloomC,
      poolBloomD, poolSecMain, poolSecPrev, poolProbeA, poolProbeB, poolSimA, poolSimB, poolHazeA, poolHazeB})
    if (buf != null) buf.dispose();
  poolBuf = poolPrevBuf = poolBloomA = poolBloomB = poolBloomC = poolBloomD = null;
  poolSecMain = poolSecPrev = poolProbeA = poolProbeB = poolSimA = poolSimB = null;
  poolLastScene = null;
  poolProbePix = null;
  poolPrevReady = false;
  poolSimAccumulator = 0;
  poolImpN = 0;
  poolHazeA = poolHazeB = null;
  poolHazeReady = false;
}

int poolRnd(int a, int b) { return min(b, (int) random(a, b + 1)); }   // inclusive

// =====================================================================
// GENERATION
void generatePools() {
  GRID = POOL_GRID;
  solid = new boolean[GRID][GRID];
  for (boolean[] row : solid) java.util.Arrays.fill(row, true);
  wallX = new boolean[GRID + 1][GRID];         // no Backrooms thin walls in here: leftovers were invisible walls
  wallY = new boolean[GRID][GRID + 1];
  pBase = new int[GRID][GRID];
  pFeat = new int[GRID][GRID];
  pStyle = new int[GRID][GRID];
  pElev = new int[GRID][GRID];
  pLight = new float[GRID][GRID];
  int[][] roomOf = new int[GRID][GRID];
  for (int[] row : roomOf) java.util.Arrays.fill(row, -1);
  boolean[][] corr = new boolean[GRID][GRID];

  // 1) rooms, each with an archetype: many small ones, a third of them dry
  int[] bag = {R_LAP, R_LAP, R_FLOOD, R_FLOOD, R_LAGOON, R_LAGOON, R_GALLERY, R_GALLERY, R_BASIN, R_BASIN,
               R_STAIRS, R_STAIRS, R_DRY, R_DRY, R_DRY, R_DRY, R_UPPER, R_UPPER, R_UPPER};
  for (int k = bag.length - 1; k > 0; k--) {
    int m = (int) random(k + 1), s = bag[k];
    bag[k] = bag[m];
    bag[m] = s;
  }
  ArrayList<int[]> rooms = new ArrayList<int[]>();
  for (int tries = 0; tries < 3000 && rooms.size() < 22; tries++) {
    int type = bag[rooms.size() % bag.length];
    int w, h;
    if (type == R_LAP)          { w = poolRnd(6, 9); h = poolRnd(4, 6); }
    else if (type == R_FLOOD)   { w = poolRnd(4, 7); h = poolRnd(4, 7); }
    else if (type == R_LAGOON)  { w = poolRnd(5, 8); h = poolRnd(5, 8); }
    else if (type == R_GALLERY) { w = poolRnd(7, 11); h = random(1) < 0.5 ? 3 : 5; }
    else if (type == R_BASIN)   { w = poolRnd(5, 6); h = poolRnd(5, 6); }
    else if (type == R_STAIRS)  { w = poolRnd(4, 5); h = poolRnd(4, 5); }
    else if (type == R_DRY)     { w = poolRnd(3, 6); h = poolRnd(3, 6); }
    else                        { w = poolRnd(4, 6); h = poolRnd(4, 6); }
    if (random(1) < 0.5) { int s = w; w = h; h = s; }
    int i0 = poolRnd(2, GRID - 2 - w), j0 = poolRnd(2, GRID - 2 - h);
    boolean overlap = false;
    for (int[] o : rooms)
      if (i0 - 1 <= o[0] + o[2] && i0 + w + 1 >= o[0] && j0 - 1 <= o[1] + o[3] && j0 + h + 1 >= o[1]) overlap = true;
    if (overlap) continue;
    rooms.add(new int[]{i0, j0, w, h, type});
    for (int i = i0; i < i0 + w; i++) for (int j = j0; j < j0 + h; j++) {
      solid[i][j] = false;
      roomOf[i][j] = rooms.size() - 1;
    }
  }

  // 2) corridors: every room joins its nearest earlier neighbour, plus a few loops
  for (int k = 1; k < rooms.size(); k++) {
    int[] a = rooms.get(k);
    int best = 0;
    float bd = 1e9;
    for (int m = 0; m < k; m++) {
      int[] b = rooms.get(m);
      float d = dist(a[0] + a[2] / 2, a[1] + a[3] / 2, b[0] + b[2] / 2, b[1] + b[3] / 2);
      if (d < bd) {
        bd = d;
        best = m;
      }
    }
    int[] b = rooms.get(best);
    carvePoolCorridor(a[0] + a[2] / 2, a[1] + a[3] / 2, b[0] + b[2] / 2, b[1] + b[3] / 2, corr, roomOf);
  }
  for (int e = 0; e < 4 && rooms.size() > 2; e++) {
    int[] a = rooms.get((int) random(rooms.size())), b = rooms.get((int) random(rooms.size()));
    if (a != b) carvePoolCorridor(a[0] + a[2] / 2, a[1] + a[3] / 2, b[0] + b[2] / 2, b[1] + b[3] / 2, corr, roomOf);
  }
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) if (!solid[i][j]) pElev[i][j] = E_LOW;

  // 3) water and style of every room
  for (int[] rm : rooms) poolRoomWater(rm);

  // 4) raised floors: upper rooms (a ramp down at every doorway) and balconies over the pools
  for (int[] rm : rooms) {
    if (rm[4] == R_UPPER) poolRaiseRoom(rm);
    else poolBalcony(rm);
  }
  poolFixCheckers();

  // 5) corridor style: one-wide corridors are barrel vaulted (crossing vaults at bends), wide ones flat
  float cp = random(1);
  int corPal = cp < 0.5 ? 0 : (cp < 0.8 ? 1 : 3);
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (solid[i][j] || !corr[i][j]) continue;
    boolean wide = false;
    for (int a = -1; a <= 0; a++) for (int b = -1; b <= 0; b++)
      if (!isWall(i + a, j + b) && !isWall(i + a + 1, j + b) && !isWall(i + a, j + b + 1) && !isWall(i + a + 1, j + b + 1)) wide = true;
    pStyle[i][j] = 1 + (wide ? 1 : 0) * 4 + corPal;
  }

  // 6) features: columns, stairs
  for (int[] rm : rooms) poolRoomFeatures(rm);

  // 7) ladders: deep cells with exactly one deck neighbour, on the ground floor
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (solid[i][j] || pBase[i][j] != P_DEEP || pFeat[i][j] != F_NONE) continue;
    int low = 0, high = 0;
    for (int[] d : DIRS) {
      int a = i + d[0], b = j + d[1];
      if (isWall(a, b) || pBase[a][b] != P_DECK) continue;
      if (pElev[a][b] == E_LOW) low++;
      else high++;
    }
    boolean nearLadder = false;
    for (int di = -2; di <= 2; di++) for (int dj = -2; dj <= 2; dj++)
      if (!isWall(i + di, j + dj) && pFeat[i + di][j + dj] == F_LADDER) nearLadder = true;
    if (low == 1 && high == 0 && !nearLadder && random(1) < 0.4) pFeat[i][j] = F_LADDER;
  }

  // 8) skylights: every room gets some, flat-ceilinged corridors a few
  for (int[] rm : rooms) {
    int want = max(1, round(rm[2] * rm[3] / 7.0));
    for (int tries = 0; tries < 300 && want > 0; tries++) {
      int i = rm[0] + (int) random(rm[2]), j = rm[1] + (int) random(rm[3]);
      if (pFeat[i][j] != F_NONE) continue;
      boolean free = true;
      for (int di = -1; di <= 1; di++) for (int dj = -1; dj <= 1; dj++)
        if (!isWall(i + di, j + dj) && (pFeat[i + di][j + dj] == F_SKY || pFeat[i + di][j + dj] == F_STAIR)) free = false;
      if (!free) continue;
      pFeat[i][j] = F_SKY;
      want--;
    }
  }
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (solid[i][j] || !corr[i][j] || pFeat[i][j] != F_NONE || pStyle[i][j] <= 4) continue;
    if (random(1) < 0.3) pFeat[i][j] = F_SKY;
  }

  // 9) bounced daylight: falls off with walking distance from every opening
  float[][] acc = new float[GRID][GRID];
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++) {
    if (solid[i][j] || (pFeat[i][j] != F_SKY && pFeat[i][j] != F_STAIR)) continue;
    int[][] f = bfs(i, j);
    float k = pFeat[i][j] == F_STAIR ? 0.7 : 1;
    for (int a = 0; a < GRID; a++) for (int b = 0; b < GRID; b++) if (f[a][b] >= 0) acc[a][b] += exp(-f[a][b] / 2.6) * k;
  }
  for (int i = 0; i < GRID; i++) for (int j = 0; j < GRID; j++)
    pLight[i][j] = solid[i][j] ? 0 : (0.16 + 0.84 * (1 - exp(-1.3 * acc[i][j]))) * (pStyle[i][j] <= 4 ? 0.85 : 1);
}

void carvePoolCorridor(int x0, int y0, int x1, int y1, boolean[][] corr, int[][] roomOf) {
  boolean wet = random(1) < 0.35, wide = random(1) < 0.18;
  int x = x0, y = y0;
  boolean hFirst = random(1) < 0.5;
  for (int pass = 0; pass < 2; pass++) {
    boolean horiz = (pass == 0) == hFirst;
    while (horiz ? x != x1 : y != y1) {
      poolCarve(x, y, wet, corr, roomOf);
      if (wide) poolCarve(horiz ? x : x + 1, horiz ? y + 1 : y, wet, corr, roomOf);
      if (horiz) x += x1 > x ? 1 : -1;
      else y += y1 > y ? 1 : -1;
    }
  }
  poolCarve(x1, y1, wet, corr, roomOf);
  if (wide) poolCarve(x1 + 1, y1 + 1, wet, corr, roomOf);
}

void poolCarve(int i, int j, boolean wet, boolean[][] corr, int[][] roomOf) {
  if (i < 1 || j < 1 || i > GRID - 2 || j > GRID - 2) return;
  solid[i][j] = false;
  if (roomOf[i][j] >= 0) return;
  corr[i][j] = true;
  if (wet) pBase[i][j] = P_SHAL;
}

boolean poolOpenAround(int i, int j) {
  for (int di = -1; di <= 1; di++) for (int dj = -1; dj <= 1; dj++) if (isWall(i + di, j + dj)) return false;
  return true;
}

boolean poolInRoom(int i, int j, int[] rm) { return i >= rm[0] && j >= rm[1] && i < rm[0] + rm[2] && j < rm[1] + rm[3]; }

int poolRampCode(int dx, int dy) {             // a ramp that rises towards (dx, dy)
  return dx > 0 ? E_RAMP_PX : (dx < 0 ? E_RAMP_NX : (dy > 0 ? E_RAMP_PY : E_RAMP_NY));
}

void poolSetHeightClass(int[] rm, int hc) {
  for (int i = rm[0]; i < rm[0] + rm[2]; i++) for (int j = rm[1]; j < rm[1] + rm[3]; j++)
    pStyle[i][j] = 1 + hc * 4 + (pStyle[i][j] - 1) % 4;
}

void poolRoomWater(int[] rm) {
  int i0 = rm[0], j0 = rm[1], w = rm[2], h = rm[3], type = rm[4];
  int area = w * h;
  int hc = area >= 30 ? 3 : (area >= 16 ? 2 : poolRnd(1, 2));
  if (type == R_LAP || type == R_GALLERY || type == R_STAIRS || type == R_UPPER) hc = max(hc, 2);
  float pr = random(1);
  int pal = pr < 0.34 ? 0 : (pr < 0.56 ? 1 : (pr < 0.8 ? 2 : 3));
  for (int i = i0; i < i0 + w; i++) for (int j = j0; j < j0 + h; j++) {
    pStyle[i][j] = 1 + hc * 4 + pal;
    pBase[i][j] = P_DECK;                      // rooms decide their own water (corridors may have crossed them)
  }
  if (type == R_LAP) {                         // a rectangular deep pool with a deck all around
    for (int i = i0 + 1; i < i0 + w - 1; i++) for (int j = j0 + 1; j < j0 + h - 1; j++) pBase[i][j] = P_DEEP;
  } else if (type == R_FLOOD) {                // the whole floor under water
    for (int i = i0; i < i0 + w; i++) for (int j = j0; j < j0 + h; j++) pBase[i][j] = P_SHAL;
  } else if (type == R_LAGOON) {               // organic deep pools with a shallow beach around them
    float ox = random(100), oy = random(100);
    for (int i = i0 + 1; i < i0 + w - 1; i++) for (int j = j0 + 1; j < j0 + h - 1; j++) {
      float n = noise(i * 0.45 + ox, j * 0.45 + oy);
      if (n > 0.5) pBase[i][j] = P_DEEP;
      else if (n > 0.36) pBase[i][j] = P_SHAL;
    }
    for (int i = i0; i < i0 + w; i++) for (int j = j0; j < j0 + h; j++) {
      if (pBase[i][j] != P_DEEP) continue;
      for (int di = -1; di <= 1; di++) for (int dj = -1; dj <= 1; dj++) {
        int a = i + di, b = j + dj;
        if (a >= i0 && b >= j0 && a < i0 + w && b < j0 + h && pBase[a][b] == P_DECK) pBase[a][b] = P_SHAL;
      }
    }
  } else if (type == R_GALLERY) {              // a long hall with a water channel down the middle
    boolean longX = w >= h;
    int cross = longX ? h : w, len = longX ? w : h;
    int baseCh = random(1) < 0.45 ? P_DEEP : P_SHAL;
    for (int a = 1; a < len - 1; a++) {
      int i = longX ? i0 + a : i0 + cross / 2, j = longX ? j0 + cross / 2 : j0 + a;
      pBase[i][j] = baseCh;
    }
  } else if (type == R_BASIN) {                // terraces: deck ring, shallow ring, deep core
    for (int i = i0 + 1; i < i0 + w - 1; i++) for (int j = j0 + 1; j < j0 + h - 1; j++) pBase[i][j] = P_SHAL;
    for (int i = i0 + 2; i < i0 + w - 2; i++) for (int j = j0 + 2; j < j0 + h - 2; j++) pBase[i][j] = P_DEEP;
  } else if (type == R_STAIRS) {               // stair hall: flooded or dry
    if (random(1) < 0.6)
      for (int i = i0; i < i0 + w; i++) for (int j = j0; j < j0 + h; j++) pBase[i][j] = P_SHAL;
  }                                            // R_DRY, R_UPPER: dry tiled halls
}

// an upper room: the whole floor raised, with a ramp down to the corridor at every doorway
void poolRaiseRoom(int[] rm) {
  ArrayList<int[]> ramps = new ArrayList<int[]>();
  for (int i = rm[0]; i < rm[0] + rm[2]; i++) for (int j = rm[1]; j < rm[1] + rm[3]; j++) {
    int outs = 0;
    int[] od = null;
    for (int[] d : DIRS) if (!poolInRoom(i + d[0], j + d[1], rm) && !isWall(i + d[0], j + d[1])) { outs++; od = d; }
    if (outs == 0) continue;
    if (outs > 1 || !poolInRoom(i - od[0], j - od[1], rm)) return;   // a corner doorway: stay on the ground floor
    ramps.add(new int[]{i, j, poolRampCode(-od[0], -od[1]), i - od[0], j - od[1]});
  }
  if (ramps.isEmpty()) return;
  for (int[] r : ramps) for (int[] q : ramps) if (q[0] == r[3] && q[1] == r[4]) return;   // a ramp may not land on a ramp
  for (int i = rm[0]; i < rm[0] + rm[2]; i++) for (int j = rm[1]; j < rm[1] + rm[3]; j++) {
    pElev[i][j] = E_HIGH;
    pBase[i][j] = P_DECK;
  }
  for (int[] r : ramps) pElev[r[0]][r[1]] = r[2];
  poolSetHeightClass(rm, max(2, (pStyle[rm[0]][rm[1]] - 1) / 4));
}

// a balcony: a raised walkway along one wall of a pool hall, a ramp down at one end, parapets along its edge
void poolBalcony(int[] rm) {
  int i0 = rm[0], j0 = rm[1], w = rm[2], h = rm[3], type = rm[4];
  if (type == R_DRY || type == R_STAIRS || min(w, h) < 5 || random(1) > 0.55) return;
  int[] order = {0, 1, 2, 3};
  for (int k = 3; k > 0; k--) { int m = (int) random(k + 1), s = order[k]; order[k] = order[m]; order[m] = s; }
  for (int side : order) {
    int si, sj, ti, tj, ni, nj, len;           // strip start, tangent, inward
    if (side == 0)      { si = i0;         sj = j0;         ti = 1; tj = 0; ni = 0;  nj = 1;  len = w; }
    else if (side == 1) { si = i0;         sj = j0 + h - 1; ti = 1; tj = 0; ni = 0;  nj = -1; len = w; }
    else if (side == 2) { si = i0;         sj = j0;         ti = 0; tj = 1; ni = 1;  nj = 0;  len = h; }
    else                { si = i0 + w - 1; sj = j0;         ti = 0; tj = 1; ni = -1; nj = 0;  len = h; }
    int ri = si + ni, rj = sj + nj, li = si + 2 * ni, lj = sj + 2 * nj;   // ramp, landing
    boolean ok = poolInRoom(li, lj, rm);
    for (int a = 0; a <= len && ok; a++) {     // no doorway may open onto the strip or the ramp
      int i = a < len ? si + ti * a : ri, j = a < len ? sj + tj * a : rj;
      for (int[] d : DIRS) if (!poolInRoom(i + d[0], j + d[1], rm) && !isWall(i + d[0], j + d[1])) ok = false;
    }
    if (!ok) continue;
    for (int a = 0; a < len; a++) {
      pElev[si + ti * a][sj + tj * a] = E_HIGH;
      pBase[si + ti * a][sj + tj * a] = P_DECK;
    }
    pElev[ri][rj] = poolRampCode(-ni, -nj);
    pBase[ri][rj] = P_DECK;
    pBase[li][lj] = P_DECK;                    // a dry landing at the foot of the ramp
    poolSetHeightClass(rm, 3);
    return;
  }
}

boolean poolFeatFree(int i, int j) { return pFeat[i][j] == F_NONE && pElev[i][j] <= E_HIGH; }

void poolRoomFeatures(int[] rm) {
  int i0 = rm[0], j0 = rm[1], w = rm[2], h = rm[3], type = rm[4];
  if (type == R_LAP && random(1) < 0.75) {     // columns along the long sides of the deck
    boolean longX = w >= h;
    for (int a = 1; a < (longX ? w : h) - 1; a += 2) {
      int[][] spots = longX ? new int[][]{{i0 + a, j0}, {i0 + a, j0 + h - 1}} : new int[][]{{i0, j0 + a}, {i0 + w - 1, j0 + a}};
      for (int[] s : spots) if (poolFeatFree(s[0], s[1]) && poolDoorFree(s[0], s[1], rm)) pFeat[s[0]][s[1]] = F_COLUMN;
    }
  } else if ((type == R_FLOOD && random(1) < 0.9) || ((type == R_DRY || type == R_UPPER) && min(w, h) >= 4 && random(1) < 0.5)) {
    int sp = (min(w, h) >= 7 && random(1) < 0.5) ? 3 : 2;   // a grid of columns
    for (int i = i0 + 1; i < i0 + w - 1; i++) for (int j = j0 + 1; j < j0 + h - 1; j++)
      if ((i - i0) % sp == 1 && (j - j0) % sp == 1 && poolOpenAround(i, j) && poolFeatFree(i, j)) pFeat[i][j] = F_COLUMN;
  } else if (type == R_LAGOON) {               // a few columns standing in the water, on little islands
    for (int k = 0, tries = 0; k < 3 && tries < 60; tries++) {
      int i = i0 + 1 + (int) random(w - 2), j = j0 + 1 + (int) random(h - 2);
      if (pBase[i][j] == P_DECK || !poolFeatFree(i, j) || !poolOpenAround(i, j)) continue;
      pFeat[i][j] = F_COLUMN;
      k++;
    }
  } else if (type == R_GALLERY) {              // colonnades on both banks of the channel, or columns in it
    boolean longX = w >= h;
    int len = longX ? w : h, cross = longX ? h : w;
    for (int a = 1; a < len - 1; a += 2) {
      int[] cs = cross >= 5 ? new int[]{cross / 2 - 1, cross / 2 + 1} : (a % 4 == 1 ? new int[]{cross / 2} : new int[0]);
      for (int c : cs) {
        int i = longX ? i0 + a : i0 + c, j = longX ? j0 + c : j0 + a;
        if (poolFeatFree(i, j)) pFeat[i][j] = F_COLUMN;
      }
    }
  } else if (type == R_BASIN) {                // columns at the corners of the deck ring
    if (random(1) < 0.7) {
      int[][] spots = {{i0, j0}, {i0 + w - 1, j0}, {i0, j0 + h - 1}, {i0 + w - 1, j0 + h - 1}};
      for (int[] s : spots) if (poolFeatFree(s[0], s[1]) && poolDoorFree(s[0], s[1], rm)) pFeat[s[0]][s[1]] = F_COLUMN;
    }
  } else if (type == R_STAIRS) {               // a spiral stair in the middle
    int ci = i0 + w / 2, cj = j0 + h / 2;
    if (pBase[ci][cj] != P_DEEP && pElev[ci][cj] == E_LOW) pFeat[ci][cj] = F_STAIR;
  }
}

// a column may not stand in a doorway: no open cell outside the room may touch it
boolean poolDoorFree(int i, int j, int[] rm) {
  for (int di = -1; di <= 1; di++) for (int dj = -1; dj <= 1; dj++) {
    int a = i + di, b = j + dj;
    if (!poolInRoom(a, b, rm) && !isWall(a, b)) return false;
  }
  return true;
}

// two wet cells touching only at a corner pinch the water to a point: fill or drain one side
void poolFixCheckers() {
  for (int pass = 0; pass < 6; pass++) {
    boolean changed = false;
    for (int deepK = 0; deepK < 2; deepK++) {
      boolean deep = deepK == 1;
      for (int i = 0; i < GRID - 1; i++) for (int j = 0; j < GRID - 1; j++) {
        boolean a = pWater(i, j, deep), b = pWater(i + 1, j, deep), c = pWater(i, j + 1, deep), d = pWater(i + 1, j + 1, deep);
        int[][] dry;
        if (a && d && !b && !c) dry = new int[][]{{i + 1, j}, {i, j + 1}};
        else if (b && c && !a && !d) dry = new int[][]{{i, j}, {i + 1, j + 1}};
        else continue;
        boolean filled = false;
        for (int[] q : dry) {
          if (isWall(q[0], q[1]) || pElev[q[0]][q[1]] != E_LOW) continue;
          pBase[q[0]][q[1]] = deep ? P_DEEP : P_SHAL;
          filled = true;
        }
        if (!filled) {                         // the dry cells are walls or raised: drain one of the wet ones instead
          int wi = (a && d) ? i : i + 1, wj = j;
          pBase[wi][wj] = deep ? P_SHAL : P_DECK;
        }
        changed = true;
      }
    }
    if (!changed) break;
  }
}

void packPools() {
  if (poolMapTex == null) poolMapTex = createImage(POOL_GRID, POOL_GRID, ARGB);
  poolMapTex.loadPixels();
  for (int i = 0; i < POOL_GRID; i++) for (int j = 0; j < POOL_GRID; j++) {
    int code = solid[i][j] ? 0 : 1 + pBase[i][j] + 3 * pFeat[i][j];
    int lc = solid[i][j] ? 0 : 1 + round(constrain(pLight[i][j], 0, 1) * 15);
    int sc = solid[i][j] ? 0 : pStyle[i][j];
    int ec = solid[i][j] ? 0 : pElev[i][j];
    poolMapTex.pixels[j * POOL_GRID + i] = (ec << 24) | (code << 16) | (lc << 8) | sc;
  }
  poolMapTex.updatePixels();
  placePoolFaces();
}

// =====================================================================
// COLLISION AND WADING (mirrors the shader's floors, parapets and 2D water outline exactly)
boolean pWater(int i, int j, boolean deep) {
  if (isWall(i, j)) return false;
  return deep ? pBase[i][j] == P_DEEP : pBase[i][j] != P_DECK;
}

boolean pSquare(int i, int j) { return isWall(i, j) || pElev[i][j] != E_LOW; }   // water meets it square

float poolSdBox(float px, float py, float b) {
  float dx = abs(px) - b, dy = abs(py) - b;
  return sqrt(sq(max(dx, 0)) + sq(max(dy, 0))) + min(max(dx, dy), 0);
}

float pRegionD(float x, float y, boolean deep) {
  int ci = cellOf(x), cj = cellOf(y);
  if (isWall(ci, cj)) return 1e5;
  float h = CELL / 2, R = POOL_WATER_R;
  float lx = x - (ci + 0.5) * CELL, ly = y - (cj + 0.5) * CELL;
  boolean self = pWater(ci, cj, deep);
  float in = 1e5, out = 1e5;
  for (int di = -1; di <= 1; di++) for (int dj = -1; dj <= 1; dj++) {
    if (di == 0 && dj == 0) continue;
    float bd = poolSdBox(lx - di * CELL, ly - dj * CELL, h);
    if (pWater(ci + di, cj + dj, deep)) in = min(in, bd);
    else out = min(out, bd);
  }
  float d = self ? -out : in;
  for (int sx = -1; sx <= 1; sx += 2) for (int sy = -1; sy <= 1; sy += 2) {
    boolean a = self, b = pWater(ci + sx, cj, deep), c = pWater(ci, cj + sy, deep), e = pWater(ci + sx, cj + sy, deep);
    int n = (a ? 1 : 0) + (b ? 1 : 0) + (c ? 1 : 0) + (e ? 1 : 0);
    if (n != 1 && n != 3) continue;
    boolean one = n == 1;
    boolean xa = pSquare(ci, cj), xb = pSquare(ci + sx, cj), xc = pSquare(ci, cj + sy), xe = pSquare(ci + sx, cj + sy);
    boolean qAD = (a == one) || (b != one && c != one);
    if (one && (qAD ? (xb || xc) : (xa || xe))) continue;
    if (!one) {
      boolean qx = a == one ? xa : (b == one ? xb : (c == one ? xc : xe));
      if (qx) continue;
      if (!deep) {                             // same rule as the shader: no filled corner against deep water
        boolean da = pWater(ci, cj, true), db = pWater(ci + sx, cj, true), dc = pWater(ci, cj + sy, true), de = pWater(ci + sx, cj + sy, true);
        if (qAD ? (db || dc) : (da || de)) continue;
      }
    }
    float qx, qy;
    if (a == one)      { qx = -sx; qy = -sy; }
    else if (b == one) { qx = sx;  qy = -sy; }
    else if (c == one) { qx = -sx; qy = sy; }
    else               { qx = sx;  qy = sy; }
    float wx = (lx - sx * h) * qx, wy = (ly - sy * h) * qy;
    float rx = R - wx, ry = R - wy;
    float rq = sqrt(sq(max(rx, 0)) + sq(max(ry, 0))) + min(max(rx, ry), 0) - R;
    float sh = sqrt(sq(max(-wx, 0)) + sq(max(-wy, 0))) + min(max(-wx, -wy), 0);
    d = one ? max(d, min(-sh, rq)) : min(d, max(sh, -rq));
  }
  if (pFeat[ci][cj] == F_COLUMN) d = max(d, POOL_PLINTH_R - sqrt(lx * lx + ly * ly));
  return d;
}

// floor height of a cell at local offset (ox, oy): ground floor, raised, or a ramp
float pFH(int e, float ox, float oy) {
  if (e <= E_LOW) return 0;
  if (e == E_HIGH) return POOL_LV;
  float dx = e == E_RAMP_PX ? 1 : (e == E_RAMP_NX ? -1 : 0), dy = e == E_RAMP_PY ? 1 : (e == E_RAMP_NY ? -1 : 0);
  return POOL_LV * constrain(0.5 + (ox * dx + oy * dy) / CELL, 0, 1);
}

float poolGroundAt(float x, float y) {
  int ci = cellOf(x), cj = cellOf(y);
  if (isWall(ci, cj)) return 0;
  return pFH(pElev[ci][cj], x - (ci + 0.5) * CELL, y - (cj + 0.5) * CELL);
}

float poolFloorAt(float x, float y) {
  float g = poolGroundAt(x, y);
  if (g > 0.5) return g;
  if (pRegionD(x, y, true) < 0) return POOL_DEEP;
  if (pRegionD(x, y, false) < 0) return POOL_SHAL;
  return 0;
}

// the shader's rule: a raised cell has a parapet on every edge where the floor beyond drops by 20 or more
boolean poolParapet(int i, int j, int[] d) {
  if (isWall(i, j) || pElev[i][j] < E_HIGH) return false;
  int a = i + d[0], b = j + d[1];
  if (isWall(a, b)) return false;
  float h = CELL / 2;
  return pFH(pElev[i][j], d[0] * h, d[1] * h) >= pFH(pElev[a][b], -d[0] * h, -d[1] * h) + 20;
}

boolean poolBlocked(float x, float y) {
  if (hitsWall(x, y)) return true;
  int ci = cellOf(x), cj = cellOf(y);
  float h = CELL / 2;
  for (int i = ci - 1; i <= ci + 1; i++) for (int j = cj - 1; j <= cj + 1; j++) {
    if (isWall(i, j)) continue;
    float cx = (i + 0.5) * CELL, cy = (j + 0.5) * CELL;
    float r = pFeat[i][j] == F_COLUMN ? POOL_COL_R : (pFeat[i][j] == F_STAIR ? POOL_STAIR_R : -1);
    if (r >= 0 && dist(x, y, cx, cy) < r + PLAYER_R) return true;
    for (int[] d : DIRS) {
      if (!poolParapet(i, j, d)) continue;
      float a0 = h - 22, a1 = h - 4;
      float x0 = d[0] != 0 ? cx + d[0] * (d[0] > 0 ? a0 : a1) : cx - h, x1 = d[0] != 0 ? cx + d[0] * (d[0] > 0 ? a1 : a0) : cx + h;
      float y0 = d[1] != 0 ? cy + d[1] * (d[1] > 0 ? a0 : a1) : cy - h, y1 = d[1] != 0 ? cy + d[1] * (d[1] > 0 ? a1 : a0) : cy + h;
      if (circleBox(x, y, PLAYER_R, x0, y0, x1, y1)) return true;
    }
  }
  return false;
}

// no walking up or off a step: every real drop has a parapet, this only guards the edge cases
boolean poolStepOk(float x0, float y0, float x1, float y1) {
  return abs(poolGroundAt(x1, y1) - poolGroundAt(x0, y0)) < 35;
}

float poolLightAt(float x, float y) {
  float gx = x / CELL - 0.5, gy = y / CELL - 0.5;
  int i0 = floor(gx), j0 = floor(gy);
  float fx = gx - i0, fy = gy - j0;
  float s = 0, w = 0;
  for (int a = 0; a < 2; a++) for (int b = 0; b < 2; b++) {
    int i = i0 + a, j = j0 + b;
    if (isWall(i, j)) continue;
    float ww = (a == 1 ? fx : 1 - fx) * (b == 1 ? fy : 1 - fy) + 0.0001;
    s += pLight[i][j] * ww;
    w += ww;
  }
  return w > 0 ? s / w : 0;
}

void addWake(float x, float y, float amp) {
  int k = (wakeIdx++) % 4;
  poolWakes[k * 4] = x;
  poolWakes[k * 4 + 1] = y;
  poolWakes[k * 4 + 2] = (millis() - poolStartMs) / 1000.0;
  poolWakes[k * 4 + 3] = amp;
}

// =====================================================================
// START / UPDATE
void startPools() {
  if (poolPrevBuf != null) poolPrevBuf.dispose();
  if (poolSecPrev != null) poolSecPrev.dispose();
  poolPrevBuf = poolSecPrev = null;
  if (poolSh == null) initPools();
  generatePools();
  packPools();
  poolResetLighting();
  poolBake(POOL_BAKE_START);                   // short bootstrap; remaining work is amortized
  poolPrevReady = false;                       // the menu preview builds a fresh map next time

  int[] best = null;
  for (int tries = 0; tries < 3000; tries++) {
    int[] c = randomOpenCell();
    if (pBase[c[0]][c[1]] != P_DECK || pFeat[c[0]][c[1]] != F_NONE || pElev[c[0]][c[1]] > E_HIGH) continue;
    if (poolBlocked((c[0] + 0.5) * CELL, (c[1] + 0.5) * CELL)) continue;
    best = c;
    if (pLight[c[0]][c[1]] > 0.45) break;
  }
  if (best == null) best = randomOpenCell();
  player.set((best[0] + 0.5) * CELL, (best[1] + 0.5) * CELL);
  int bestRun = -1;
  for (int[] d : DIRS) {
    int run = 0;
    while (run < 8 && !isWall(best[0] + d[0] * (run + 1), best[1] + d[1] * (run + 1))) run++;
    if (run > bestRun) {
      bestRun = run;
      yaw = atan2(d[1], d[0]) + random(-0.3, 0.3);
    }
  }
  pitch = 0;
  resetCamera();                               // neutral iris/gain/shutter for the lens pass
  irisN = LENS_F_MIN;                          // start wide open: the auto exposure settles from a bright guess
  renderQuality = 1;                           // every visit starts at full resolution; the engine lowers it only if needed
  renderCostMs = 0;
  resolutionFrames = 0;
  resolutionCooldown = millis() + 500;

  java.util.Arrays.fill(poolWakes, 0);
  energyUntil = swiftUntil = ghostUntil = fedUntil = 0;
  useType = -1;
  stamina = staminaMax();
  exhausted = false;
  crouchToggle = false;
  eyeH = EYE_H;
  poolFloorZ = poolFloorAt(player.x, player.y);
  fov = radians(50);
  roll = bobPhase = stepEnv = splashEnv = clickEnv = 0;
  lastStep = 0;
  playerStepTravel = -1;
  lastConcreteStep = -1;
  poolCamAmb = poolLightAt(player.x, player.y);
  poolExposure = constrain(1.0 / (0.42 + 0.62 * poolCamAmb), 0.85, 1.9);
  toastQueue.clear();

  releaseKeys();
  silenceSynth();
  pauseVoices();
  ambience.mute();
  startPoolAudio();
  poolStartMs = millis();
  survived = 0;
  state = POOL;
  lockMouse(true);
}

void poolKey(int kc) {
  if (kc == 'C') crouchToggle = !crouchToggle;
  if (kc == 'P') pauseGame();
}

void updatePools(float dt) {
  int now = millis();
  survived = (now - poolStartMs) / 1000.0;
  if (!focused) releaseKeys();

  float fx = cos(yaw), fy = sin(yaw), rx = -fy, ry = fx;
  float mx = 0, my = 0;
  if (kUp)    { mx += fx; my += fy; }
  if (kDown)  { mx -= fx; my -= fy; }
  if (kRight) { mx += rx; my += ry; }
  if (kLeft)  { mx -= rx; my -= ry; }
  float len = sqrt(mx * mx + my * my);
  moving = len > 0;
  if (crouchToggle && kSprint && moving) crouchToggle = false;
  crouching = crouchToggle || kCrouch;

  float floorT = poolFloorAt(player.x, player.y);
  boolean deep = floorT < POOL_SHAL - 10, wet = floorT < -1;
  sprinting = moving && kSprint && !crouching && !exhausted && stamina > 0 && !deep;
  if (sprinting) stamina = max(0, stamina - dt);
  else stamina = min(staminaMax(), stamina + dt * 0.6);
  if (stamina <= 0) exhausted = true;
  if (exhausted && stamina >= staminaMax() * 0.35) exhausted = false;

  eyeH = lerp(eyeH, crouching ? CROUCH_EYE : EYE_H, 1 - exp(-dt * 10));

  if (moving) {
    float px0 = player.x, py0 = player.y;
    float speed = crouching ? CROUCH_SPEED : (sprinting ? SPRINT_SPEED : WALK_SPEED);
    speed *= deep ? 0.55 : (wet ? 0.8 : 1);
    float step = speed * dt / len;
    float nx = player.x + mx * step, ny = player.y + my * step;
    if (!poolBlocked(nx, player.y) && poolStepOk(player.x, player.y, nx, player.y)) player.x = nx;
    if (!poolBlocked(player.x, ny) && poolStepOk(player.x, player.y, player.x, ny)) player.y = ny;
    if (advancePlayerFootsteps(dist(px0, py0, player.x, player.y))) {
      if (wet) {
        splashEnv = deep ? 0.8 : 0.5;
        stepEnv = 0.1;
        addWake(player.x, player.y, deep ? 1 : 0.6);
        poolImpulse(player.x + mx / len * 30, player.y + my / len * 30, deep ? 34 : 26, deep ? 1.6 : 0.9);   // a footstep
      } else {
        if (playConcreteFootstep()) {
          clickEnv = stepEnv = 0;
        } else {
          clickEnv = crouching ? 0.04 : (sprinting ? 0.22 : 0.14);
          stepEnv = crouching ? 0.05 : 0.2;
        }
      }
    }
  } else {
    bobPhase = lerp(bobPhase, round(bobPhase / PI) * PI, 1 - exp(-dt * 8));
  }

  floorT = poolFloorAt(player.x, player.y);
  poolFloorZ = lerp(poolFloorZ, floorT, 1 - exp(-dt * (floorT < poolFloorZ ? 7 : 5)));

  float strafe = (kRight ? 1 : 0) - (kLeft ? 1 : 0);
  roll = lerp(roll, strafe * 0.03, 1 - exp(-dt * 7));
  fov = lerp(fov, radians(sprinting ? 60 : 50), 1 - exp(-dt * 5));

  float L = poolLightAt(player.x, player.y);
  poolCamAmb = lerp(poolCamAmb, L, 1 - exp(-dt * 2));
  poolExposure = lerp(poolExposure, constrain(1.0 / (0.42 + 0.62 * L), 0.85, 1.9), 1 - exp(-dt * 1.0));
  updateAutoExposure(dt);                      // the engine's iris and AGC, metered from the last frame

  // the water: your legs push a bow wave while wading, drips fall from the skylights now and then
  poolFlow[2] = 0;
  if (wet && moving) {
    poolFlow[0] = player.x + cos(yaw) * 40;
    poolFlow[1] = player.y + sin(yaw) * 40;
    poolFlow[2] = deep ? 40 : 30;
    poolFlow[3] = (deep ? 0.10 : 0.06) * (sprinting ? 1.5 : (crouching ? 0.5 : 1.0));
  } else if (wet && random(1) < dt * 2) {
    poolImpulse(player.x + random(-30, 30), player.y + random(-30, 30), 22, 0.12);   // standing still: small sways
  }
  poolDripT -= dt;
  if (poolDripT <= 0) {
    poolDripT = random(0.15, 0.7);
    for (int tries = 0; tries < 12; tries++) {
      int i = cellOf(player.x) + (int) random(-7, 8), j = cellOf(player.y) + (int) random(-7, 8);
      if (isWall(i, j) || pBase[i][j] == P_DECK) continue;
      poolImpulse((i + random(0.1, 0.9)) * CELL, (j + random(0.1, 0.9)) * CELL, 9, random(0.6, 1.4));
      break;
    }
  }

  updatePoolAudio(dt);
}

// =====================================================================
// RENDER
PGraphics poolSecMain, poolSecPrev;            // pass 1 targets (half resolution) of the game view and the menu polaroid
int poolDrawWidth, poolDrawHeight, poolBloomWidth, poolBloomHeight, poolBloomWideWidth, poolBloomWideHeight;
PGraphics poolLastScene;                      // the scene frame of the previous frame (to spot reallocations)

void poolCamera(PShader sh, int w, int h, PVector eye, PVector F, PVector R, PVector U, float tanY, float t, float expo, float[] wk) {
  poolSetScene(sh, t);
  sh.set("lite", gfxLight() ? 1.0 : 0.0);
  sh.set("camPos", eye.x, eye.y, eye.z);
  sh.set("camF", F.x, F.y, F.z);
  sh.set("camR", R.x, R.y, R.z);
  sh.set("camU", U.x, U.y, U.z);
  sh.set("tanHalf", tanY * w / (float) h, tanY);
  sh.set("exposure", expo);
  sh.set("pixAng", 2 * tanY / h);
  sh.set("camAmb", poolCamAmb);
  sh.set("wakes", wk, 4);
  sh.set("faceA", poolFaceA, 4);
  sh.set("faceB", poolFaceB, 4);
  sh.set("faceCount", poolFaceN);
  sh.set("faceSlots", (float) NAMES.length);
  sh.set("faceAtlas", poolFaceAtlas);
  sh.set("faceTexel", 1.0 / poolFaceAtlas.width, 1.0 / poolFaceAtlas.height);
}

void poolUpdateHaze(PVector eye) {
  if (poolHazeA == null) {
    poolHazeA = poolDataBuffer(1, 1); poolHazeB = poolDataBuffer(1, 1);
    for (PGraphics target : new PGraphics[]{poolHazeA, poolHazeB}) {
      target.beginDraw(); target.background(0); target.endDraw();
      prepareLightingData(target, target);
    }
  }
  poolSetScene(poolHazeSh, 0);
  poolHazeSh.set("camPos", eye.x, eye.y, eye.z);
  poolHazeSh.set("hazeBlend", poolHazeReady ? 1 - exp(-max(frameDt, 0) * 3) : 1.0);
  poolDataPass(poolHazeB, poolHazeSh);
  PGraphics swap = poolHazeA; poolHazeA = poolHazeB; poolHazeB = swap;
  poolHazeReady = true;
}

void drawPoolFrame(PGraphics buf, PVector eye, PVector F, PVector R, PVector U, float tanY, float t, float expo, float[] wk) {
  drawPoolFrameRegion(buf, buf.width, buf.height, eye, F, R, U, tanY, t, expo, wk);
}

void drawPoolFrameRegion(PGraphics buf, int w, int h, PVector eye, PVector F, PVector R, PVector U, float tanY, float t, float expo, float[] wk) {
  poolDrawWidth = w; poolDrawHeight = h;
  poolUpdateHaze(eye);
  int div = gfxLight() ? 3 : 2;                // LEVE: reflections/refractions at a third of the resolution
  int sw = max(16, w / div), sh = max(16, h / div);
  int capacityW = max(16, buf.width / 2), capacityH = max(16, buf.height / 2);
  boolean prev = buf == poolPrevBuf;
  PGraphics sec = prev ? poolSecPrev : poolSecMain;
  if (sec == null || sec.width != capacityW || sec.height != capacityH) {
    if (sec != null) sec.dispose();
    sec = poolDataBuffer(capacityW, capacityH);
    sec.beginDraw(); sec.background(0); sec.endDraw();
    prepareLightingData(sec, sec);
    if (prev) poolSecPrev = sec; else poolSecMain = sec;
  }
  poolCamera(poolSecSh, sw, sh, eye, F, R, U, tanY, t, expo, wk);
  poolDataPassRegion(sec, poolSecSh, sw, sh);
  poolCamera(poolSh, w, h, eye, F, R, U, tanY, t, expo, wk);
  poolSh.set("secTex", sec);
  poolSh.set("secSize", (float) sw, (float) sh);
  poolSh.set("bufSize", (float) w, (float) h);
  poolSh.set("renderOrigin", 0.0, (float) (buf.height - h));
  poolSh.set("secOrigin", 0.0, (float) (sec.height - sh));
  poolSh.set("secCapacity", (float) sec.width, (float) sec.height);
  poolDataPassRegion(buf, poolSh, w, h);
}

void poolPass(PGraphics dst, PImage src, PShader sh) {
  poolPassRegion(dst, src, sh, dst.width, dst.height, src.width, src.height);
}

void poolPassRegion(PGraphics dst, PImage src, PShader sh, int w, int h, int sourceW, int sourceH) {
  if (sh == poolBright) {
    sh.set("brightMin", 0.5 / src.width, (src.height - sourceH + 0.5) / src.height);
    sh.set("brightMax", (sourceW - 0.5) / src.width, 1.0 - 0.5 / src.height);
  }
  if (sh == poolBlur) {
    sh.set("blurMin", 0.5 / src.width, (src.height - sourceH + 0.5) / src.height);
    sh.set("blurMax", (sourceW - 0.5) / src.width, 1.0 - 0.5 / src.height);
  }
  dst.beginDraw(); dst.blendMode(REPLACE); dst.imageMode(CORNER); dst.noTint();
  ((processing.opengl.PGraphicsOpenGL) dst).getTexture(src).usingMipmaps(false, 4); // Texture.BILINEAR (private Processing constant)
  dst.shader(sh);
  dst.image(src, 0, 0, w, h, 0, 0, sourceW, sourceH);
  dst.resetShader(); dst.endDraw();
}

void poolBloom() {
  int w = max(16, poolBuf.width / 4), h = max(16, poolBuf.height / 4);
  int w2 = max(8, w / 4), h2 = max(8, h / 4);
  poolBloomWidth = max(16, poolDrawWidth / 4); poolBloomHeight = max(16, poolDrawHeight / 4);
  poolBloomWideWidth = max(8, poolBloomWidth / 4); poolBloomWideHeight = max(8, poolBloomHeight / 4);
  poolBloomA = poolTarget2D(poolBloomA, w, h); poolBloomB = poolTarget2D(poolBloomB, w, h);
  poolBloomC = poolTarget2D(poolBloomC, w2, h2); poolBloomD = poolTarget2D(poolBloomD, w2, h2);
  poolBright.set("px", 1.0 / poolBuf.width, 1.0 / poolBuf.height); poolBright.set("thresh", 0.78);
  poolPassRegion(poolBloomA, poolBuf, poolBright, poolBloomWidth, poolBloomHeight, poolDrawWidth, poolDrawHeight);
  poolBlur.set("dir", 1.0 / w, 0.0);
  poolPassRegion(poolBloomB, poolBloomA, poolBlur, poolBloomWidth, poolBloomHeight, poolBloomWidth, poolBloomHeight);
  poolBlur.set("dir", 0.0, 1.0 / h);
  poolPassRegion(poolBloomA, poolBloomB, poolBlur, poolBloomWidth, poolBloomHeight, poolBloomWidth, poolBloomHeight);
  poolBlur.set("dir", 1.5 / w, 1.5 / h);
  poolPassRegion(poolBloomC, poolBloomA, poolBlur, poolBloomWideWidth, poolBloomWideHeight, poolBloomWidth, poolBloomHeight);
  poolBlur.set("dir", 1.0 / w2, 0.0);
  poolPassRegion(poolBloomD, poolBloomC, poolBlur, poolBloomWideWidth, poolBloomWideHeight, poolBloomWideWidth, poolBloomWideHeight);
  poolBlur.set("dir", 0.0, 1.0 / h2);
  poolPassRegion(poolBloomC, poolBloomD, poolBlur, poolBloomWideWidth, poolBloomWideHeight, poolBloomWideWidth, poolBloomWideHeight);
}

// Same pipeline as the Backrooms' render(): the scene goes into the engine's sceneFrame, which then gets
// bloom, optics (applyLens), the fade, the tape signal, the camcorder OSD and the final grade; the HUD is
// drawn crisp on the display afterwards.
void renderPools() {
  updateDisplaySize();
  poolEnsureSceneFrame();                      // stable recording targets, GPU-adaptive raymarch only
  long started = System.nanoTime();
  poolFrameTimer.begin(viewGraphics());

  float t = (millis() - poolStartMs) / 1000.0;
  float ht = millis() * 0.0004;
  float yawR = yaw + (noise(ht, 3.1) - 0.5) * 0.014 * HANDHELD;
  float pitchR = pitch + (noise(ht, 7.7) - 0.5) * 0.010 * HANDHELD;
  float sway = cos(bobPhase) * (crouching ? 2 : 4);

  PVector F = new PVector(cos(yawR) * cos(pitchR), sin(yawR) * cos(pitchR), sin(pitchR));
  PVector R0 = new PVector(-sin(yawR), cos(yawR), 0);
  PVector U0 = F.cross(R0);
  U0.normalize();
  PVector R = PVector.add(PVector.mult(R0, cos(roll)), PVector.mult(U0, sin(roll)));
  PVector U = F.cross(R);
  U.normalize();
  PVector eye = new PVector(player.x + R0.x * sway, player.y + R0.y * sway,
    poolFloorZ + eyeH - abs(sin(bobPhase)) * (crouching ? 3 : 7));

  // the lens pass zooms the center in: widen the view to keep the framing (same as the Backrooms)
  lensFovNow = fov;
  updateShutter();
  float tanY = tan(fov / 2) * lensEdge();


  poolBuf = poolTarget(poolBuf, sceneFrame.width, sceneFrame.height);   // fixed-capacity target; the active ray region follows the GPU budget
  poolSimStep(frameDt);
  poolFrameTimer.mark(viewGraphics(), 1);
  poolScheduleLighting();
  poolFrameTimer.mark(viewGraphics(), 2);
  // same sensor exposure as the Backrooms: the engine's auto exposure (iris + AGC), metered below
  drawPoolFrameRegion(poolBuf, poolRayWidth, poolRayHeight, eye, F, R, U, tanY, t, EXPOSURE_BASE * exposureAdapt, poolWakes);
  poolBloom();

  PGraphics display = viewGraphics(), previous = renderTarget;
  // a freshly allocated scene frame (resolution change) comes out of the engine's filter chain one frame
  // overexposed: warm it up with a discarded pass so the change is invisible instead of a white flash
  int passes = sceneFrame != poolLastScene ? 2 : 1;
  poolLastScene = sceneFrame;
  for (int pass = 0; pass < passes; pass++) {
  sceneFrame.beginDraw();
  try {
    renderTarget = sceneFrame;
    PGraphics v = viewGraphics();
    begin2D();
    v.background(0);
    v.pushStyle();
    v.imageMode(CORNER);
    v.noTint();
    v.image(poolBuf, 0, 0, v.width, v.height, 0, 0, poolRayWidth, poolRayHeight);
    v.popStyle();
    poolMeterCamera(v);                    // 0. the camera meters the scene for its auto exposure
    v.pushStyle();
    v.imageMode(CORNER);
    v.blendMode(ADD);
    v.tint(255 * 0.20);
    v.image(poolBloomA, 0, 0, v.width, v.height, 0, 0, poolBloomWidth, poolBloomHeight);
    v.tint(255 * 0.32);
    v.image(poolBloomC, 0, 0, v.width, v.height, 0, 0, poolBloomWideWidth, poolBloomWideHeight);
    v.blendMode(BLEND);
    v.popStyle();
    applyLens();                       // 1. optics, shutter, CCD and camera DSP
    drawPoolFade();                    // 2. fade-in
    applyTape();                       // 3. recording signal
    drawPoolOsd();                     // 4. crisp character generator
    applyPost(0, 0);                   // 5. tape faults and grade (poolGrade() makes it neutral white)
    applyCodec(viewGraphics());        // 6. decoded SD copy, including the camcorder OSD
    end2D();
  } finally {
    renderTarget = previous;
    sceneFrame.endDraw();
  }
  }
  processing.opengl.PGraphicsOpenGL pg = (processing.opengl.PGraphicsOpenGL) display;
  pg.beginPGL();
  pg.endPGL();
  begin2D();
  display.pushStyle();
  display.imageMode(CORNER);
  display.noTint();
  display.blendMode(REPLACE);
  display.image(sceneFrame, 0, 0, width, height);
  display.blendMode(BLEND);
  display.popStyle();
  drawPoolHUD();
  end2D();
  poolFrameTimer.mark(display, 3);
  poolTuneResolution((System.nanoTime() - started) / 1000000.0);

}

// called by applyPostTo() while in the Poolrooms: daylight white instead of the Backrooms' yellow grade
void poolGrade() {
  post.set("saturation", 1.06);
  post.set("contrast", 0.30);
  post.set("brightness", 0.0);
  post.set("gammaAdj", 1.0);
  post.set("tint", 1.03, 1.0, 0.965);
  post.set("vignette", 0.12);
  post.set("bloomAmt", 0.18);
  post.set("halation", 0.0);
}

void drawPoolFade() {
  float fadeIn = 1 - constrain(survived / 1.5, 0, 1);
  if (fadeIn <= 0) return;
  viewGraphics().rectMode(CORNER);
  viewGraphics().noStroke();
  viewGraphics().fill(0, 255 * fadeIn);
  viewGraphics().rect(0, 0, viewWidth(), viewHeight());
}

// camcorder OSD: same layout as drawCamOsd(), with the Poolrooms' own top-left block
void drawPoolOsd() {
  beginUi();
  PGraphics v = viewGraphics();
  v.pushStyle();
  v.rectMode(CORNER);
  float m = 40, L = 46, W = uiWidth(), H = uiHeight();
  v.stroke(255, 140);
  v.strokeWeight(3);
  v.noFill();
  v.line(m, m, m + L, m);                  v.line(m, m, m, m + L);
  v.line(W - m, m, W - m - L, m);          v.line(W - m, m, W - m, m + L);
  v.line(m, H - m, m + L, H - m);          v.line(m, H - m, m, H - m - L);
  v.line(W - m, H - m, W - m - L, H - m);  v.line(W - m, H - m, W - m, H - m - L);
  v.noStroke();

  v.textFont(fontMono);
  if ((millis() / 600) % 2 == 0) {
    v.fill(225, 30, 30);
    v.ellipse(W - 168, 72, 16, 16);
  }
  v.textAlign(LEFT, CENTER);
  v.textSize(24);
  osdText("REC", W - 150, 70, color(255, 215));
  v.textSize(20);
  v.textAlign(LEFT, BOTTOM);
  osdText(nf(day(), 2) + " " + MESES[month() - 1] + " " + year() + "   "
    + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2), 70, H - 62, color(255, 215));
  v.textAlign(RIGHT, BOTTOM);
  osdText("SP", W - 130, H - 62, color(255, 215));
  drawBattery(W - 118, H - 84, 0);

  v.textAlign(LEFT, CENTER);
  v.textSize(19);
  osdText("POOLROOMS  —  EXPLORAÇÃO LIVRE", 72, 74, color(255, 225));
  v.textSize(34);
  osdText(fmtTime(survived), 72, 110, color(255, 225));
  v.popStyle();
  endUi();
}

void drawPoolHUD() {
  beginUi();
  PGraphics v = viewGraphics();
  v.rectMode(CORNER);
  v.imageMode(CORNER);
  v.noStroke();
  drawStamina();
  float cx = uiWidth() / 2, cy = uiHeight() / 2;
  v.stroke(235, 150);
  v.strokeWeight(2);
  v.line(cx - 9, cy, cx - 4, cy);
  v.line(cx + 4, cy, cx + 9, cy);
  v.line(cx, cy - 9, cx, cy - 4);
  v.line(cx, cy + 4, cx, cy + 9);
  v.noStroke();
  if (survived < 4.5) {
    float a = 255 * constrain(min(survived * 1.5, (4.5 - survived) * 1.5), 0, 1);
    v.textAlign(CENTER, CENTER);
    v.textFont(fontHud);
    v.textSize(64);
    v.fill(0, a * 0.45);
    v.text("POOLROOMS", cx + 3, cy - 147);
    v.fill(235, 230, 215, a);
    v.text("POOLROOMS", cx, cy - 150);
    v.textFont(fontMono);
    v.textSize(15);
    String help = "EXPLORAÇÃO LIVRE   ·   SHIFT CORRER   C AGACHAR   ESC PAUSAR";
    v.fill(0, a * 0.7);
    v.text(help, cx + 1.5, cy - 98.5);
    v.fill(235, a);
    v.text(help, cx, cy - 100);
  }
  drawToasts();
  endUi();
}

// =====================================================================
// AUDIO (patched into the engine's effects bus, so the effects volume applies)
void startPoolAudio() {
  stepEcho.setDelTime(0.045);
  stepEcho.setDelAmp(0.28);
  echoWet.setValue(0.24);
  if (!poolSynthReady) {
    poolSynthReady = true;
    poolWaterAmp = new Multiplier(0);
    new Noise(1, Noise.Tint.PINK).patch(new MoogFilter(480, 0.25)).patch(poolWaterAmp).patch(fxMix);
    poolSplashAmp = new Multiplier(0);
    new Noise(1, Noise.Tint.WHITE).patch(new MoogFilter(2400, 0.3)).patch(poolSplashAmp).patch(fxMix);
    poolTone = new Oscil(58, 0, Waves.SINE);
    poolTone.patch(fxMix);
    if (new File(dataPath("pools.mp3")).exists()) poolAmbience = minim.loadFile("pools.mp3");
  }
  if (poolAmbience != null) {
    poolAmbience.rewind();
    poolAmbience.loop();
  }
}

void updatePoolAudio(float dt) {
  float t = millis() * 0.001;
  float lap = 0.5 + 0.3 * sin(t * 0.63) + 0.2 * noise(t * 0.4, 5);
  poolWaterAmp.setValue((poolAmbience != null ? 0.02 : 0.05) * lap);
  splashEnv *= exp(-dt * 7);
  poolSplashAmp.setValue(splashEnv * 0.12);
  clickEnv *= exp(-dt * 45);
  tickAmp.setValue(clickEnv);                  // hard tile footsteps
  stepEnv *= exp(-dt * 16);
  stepAmp.setValue(stepEnv);
  poolTone.setAmplitude(0.018 * (0.8 + 0.2 * sin(t * 0.21)));
  breathAmp.setValue(0);
}

// the pause menu: water, splashes, tone and the ambience hold still, then pick up where they were
void pausePoolAudio() {
  clickEnv = splashEnv = 0;
  tickAmp.setValue(0);
  if (poolSynthReady) {
    poolWaterAmp.setValue(0);
    poolSplashAmp.setValue(0);
    poolTone.setAmplitude(0);
  }
  if (poolAmbience != null) poolAmbience.pause();
}

void resumePoolAudio() {
  if (poolAmbience != null) poolAmbience.loop();
}

void stopPools() {
  stopConcreteFootsteps();
  echoWet.setValue(0);
  poolReleaseBuffers();
  renderQuality = 1; renderCostMs = 0; resolutionFrames = 0;
  if (poolSynthReady) {
    poolWaterAmp.setValue(0);
    poolSplashAmp.setValue(0);
    poolTone.setAmplitude(0);
  }
  if (poolAmbience != null) poolAmbience.pause();
  ambience.unmute();
  releaseKeys();
}

// =====================================================================
// MENU PREVIEW: a live polaroid rendered by the same raymarcher
void preparePoolPreview() {
  if (poolSh == null) initPools();
  generatePools();
  packPools();
  poolResetLighting();
  poolBake(POOL_BAKE_START);                   // short bootstrap; remaining work is amortized
  float bestScore = -1;
  prevX = player.x;
  prevY = player.y;
  for (int tries = 0; tries < 400; tries++) {
    int[] c = randomOpenCell();
    if (pBase[c[0]][c[1]] != P_DECK || pFeat[c[0]][c[1]] != F_NONE) continue;
    for (int[] d : DIRS) {
      float score = 0;
      for (int s = 1; s <= 4; s++) {
        int i = c[0] + d[0] * s, j = c[1] + d[1] * s;
        if (isWall(i, j)) break;
        if (pBase[i][j] != P_DECK) score += 2;
        if (pFeat[i][j] == F_COLUMN) score += 1.5;
        if (pFeat[i][j] == F_STAIR) score += 3;
        score += 0.5 + pLight[i][j];
      }
      if (score > bestScore) {
        bestScore = score;
        prevX = (c[0] + 0.5) * CELL - d[0] * CELL * 0.35;
        prevY = (c[1] + 0.5) * CELL - d[1] * CELL * 0.35;
        prevYaw = atan2(d[1], d[0]);
      }
    }
  }
  poolPrevReady = true;
}

void drawPoolsPreview() {
  if (poolSh == null) initPools();
  if (!poolPrevReady) preparePoolPreview();
  float t = millis() / 1000.0;
  float yawP = prevYaw + sin(t * 0.12) * 0.25;
  PVector F = new PVector(cos(yawP) * cos(0.04), sin(yawP) * cos(0.04), sin(0.04));
  PVector R = new PVector(-sin(yawP), cos(yawP), 0);
  PVector U = F.cross(R);
  U.normalize();
  poolCamAmb = poolLightAt(prevX, prevY);
  poolAdvanceLighting();
  poolPrevBuf = poolTarget(poolPrevBuf, 300, 380);
  drawPoolFrame(poolPrevBuf, new PVector(prevX, prevY, poolGroundAt(prevX, prevY) + EYE_H), F, R, U, tan(radians(32)), t,
    EXPOSURE_BASE * POOL_PREVIEW_EXPO, NO_WAKES);

  PGraphics v = viewGraphics();
  float x = lineX(0), y = lineY(0) - 10;
  float w = 340, h = 430;
  v.pushMatrix();
  v.translate(x, y);
  v.rotate(0.025 + sin(millis() * 0.0006) * 0.008);
  v.rectMode(CENTER);
  v.imageMode(CENTER);
  v.noStroke();
  v.fill(0, 120);
  v.rect(10, 12, w + 24, h + 70);
  v.fill(232, 228, 214);
  v.rect(0, 0, w + 24, h + 70);
  v.tint(255 * menuFlicker);
  v.image(poolPrevBuf, 0, -18, w, h);
  v.noTint();
  v.fill(40);
  v.textFont(fontHud);
  v.textAlign(CENTER, CENTER);
  v.textSize(22);
  v.text("POOLROOMS", 0, h / 2 + 10);
  v.rectMode(CORNER);
  v.imageMode(CORNER);
  v.popMatrix();
  previewLabel("POOLROOMS", "Exploração livre  ·  sem nerdolas (por enquanto)");
}

// Poolrooms GPU timing and exposure readback. All gameplay polls have a zero timeout.
PoolFrameTimer poolFrameTimer = new PoolFrameTimer();
PoolMeterReadback poolMeterReadback = new PoolMeterReadback();
float poolGpuFrameMs, poolGpuSceneMs, poolGpuBakeMs;
int poolRayWidth, poolRayHeight;
int poolQualityUpAfter;

void poolEnsureSceneFrame() {
  // Keep recording/post targets stable; only raymarch targets follow GPU quality.
  float quality=renderQuality;
  try {renderQuality=1;ensureSceneFrame();} finally {renderQuality=quality;}
  int[] size=sceneSize(sceneFrame.width,sceneFrame.height,quality);
  poolRayWidth=size[0];poolRayHeight=size[1];
}

class PoolFrameTimer {
  final int slots=8;
  int[][] queries=new int[slots][4];
  boolean[] pending=new boolean[slots];
  int[] widths=new int[slots],heights=new int[slots];
  int[] issued=new int[slots];boolean[] eligible=new boolean[slots];
  int cursor,active=-1;
  int sequence,lastAccepted=-1,warmup=20,lastWidth,lastHeight;
  boolean initialized,supported;
  int[] ready={0};long[] stamp=new long[4],result=new long[1];
  com.jogamp.opengl.GL2ES2 gl(PGraphics target) {
    return ((processing.opengl.PJOGL)target.beginPGL()).gl.getGL2ES2();
  }
  void begin(PGraphics display) {
    com.jogamp.opengl.GL2ES2 gpu=gl(display);
    try {
      if(!initialized){
        supported=gpu.isFunctionAvailable("glQueryCounter")&&gpu.isFunctionAvailable("glGetQueryObjectui64v");
        if(supported)for(int[] ids:queries)gpu.glGenQueries(4,ids,0);
        initialized=true;
      }
      if(!supported)return;
      for(int slot=0;slot<slots;slot++)if(pending[slot]) {
        gpu.glGetQueryObjectiv(queries[slot][3],com.jogamp.opengl.GL2ES2.GL_QUERY_RESULT_AVAILABLE,ready,0);
        if(ready[0]==0)continue;
        for(int k=0;k<4;k++){gpu.glGetQueryObjectui64v(queries[slot][k],com.jogamp.opengl.GL2ES2.GL_QUERY_RESULT,result,0);stamp[k]=result[0];}
        if(eligible[slot]&&issued[slot]>lastAccepted&&widths[slot]==poolRayWidth&&heights[slot]==poolRayHeight) {
          float frame=(float)((stamp[3]-stamp[0])/1000000.0d),bake=(float)((stamp[2]-stamp[1])/1000000.0d);
          if(frame>0&&frame<1000){poolGpuFrameMs=frame;poolGpuSceneMs=max(0,frame-bake);if(bake>0.1)poolGpuBakeMs=poolGpuBakeMs==0?bake:lerp(poolGpuBakeMs,bake,0.15);}
          lastAccepted=issued[slot];
        }
        pending[slot]=false;
      }
      active=pending[cursor]?-1:cursor;
      if(lastWidth!=poolRayWidth||lastHeight!=poolRayHeight){warmup=max(warmup,3);lastWidth=poolRayWidth;lastHeight=poolRayHeight;}
      if(active>=0){widths[active]=poolRayWidth;heights[active]=poolRayHeight;issued[active]=sequence++;eligible[active]=warmup==0;if(warmup>0)warmup--;
        gpu.glQueryCounter(queries[active][0],com.jogamp.opengl.GL2ES2.GL_TIMESTAMP);cursor=(cursor+1)%slots;}
    } finally {display.endPGL();}
  }
  void mark(PGraphics display,int point) {
    if(active<0)return;
    com.jogamp.opengl.GL2ES2 gpu=gl(display);
    gpu.glQueryCounter(queries[active][point],com.jogamp.opengl.GL2ES2.GL_TIMESTAMP);display.endPGL();
    if(point==3){pending[active]=true;active=-1;}
  }
  void release() {
    if(initialized&&supported){PGraphics display=viewGraphics();com.jogamp.opengl.GL2ES2 gpu=gl(display);for(int[] ids:queries)gpu.glDeleteQueries(4,ids,0);display.endPGL();}
    java.util.Arrays.fill(pending,false);initialized=supported=false;active=-1;cursor=0;
    sequence=0;lastAccepted=-1;warmup=20;lastWidth=lastHeight=0;
    poolGpuFrameMs=poolGpuSceneMs=poolGpuBakeMs=0;
  }
}

class PoolMeterReadback {
  int[] buffers=new int[2];long[] fences=new long[2];
  int[] pixels=new int[48];
  boolean initialized,supported;
  boolean initialize(com.jogamp.opengl.GL base) {
    if(initialized)return supported;
    initialized=true;supported=base.isGL3ES3();
    if(supported){
      com.jogamp.opengl.GL3ES3 gpu=base.getGL3ES3();int[] old={0};
      gpu.glGetIntegerv(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER_BINDING,old,0);
      gpu.glGenBuffers(2,buffers,0);
      for(int buffer:buffers){gpu.glBindBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,buffer);gpu.glBufferData(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,48*4,null,com.jogamp.opengl.GL2ES3.GL_STREAM_READ);}
      gpu.glBindBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,old[0]);
    }
    return supported;
  }
  void poll() {
    PGraphics display=viewGraphics();com.jogamp.opengl.GL base=((processing.opengl.PJOGL)display.beginPGL()).gl;
    try {
      if(!initialize(base))return;
      com.jogamp.opengl.GL3ES3 gpu=base.getGL3ES3();
      for(int slot=0;slot<2;slot++)if(fences[slot]!=0){
        int status=gpu.glClientWaitSync(fences[slot],0,0);
        if(status!=com.jogamp.opengl.GL3ES3.GL_ALREADY_SIGNALED&&status!=com.jogamp.opengl.GL3ES3.GL_CONDITION_SATISFIED)continue;
        int[] old={0};gpu.glGetIntegerv(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER_BINDING,old,0);
        gpu.glBindBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,buffers[slot]);
        java.nio.ByteBuffer data=gpu.glMapBufferRange(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,0,48*4,com.jogamp.opengl.GL.GL_MAP_READ_BIT);
        if(data!=null){
          for(int y=0;y<6;y++)for(int x=0;x<8;x++){int index=(y*8+x)*4;pixels[(5-y)*8+x]=0xff000000|((data.get(index)&255)<<16)|((data.get(index+1)&255)<<8)|(data.get(index+2)&255);}
          gpu.glUnmapBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER);
          cameraExposureTarget=exposureFromMeter(pixels);
        }
        gpu.glBindBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,old[0]);gpu.glDeleteSync(fences[slot]);fences[slot]=0;
      }
    } finally {display.endPGL();}
  }
  void enqueue(PGraphics target) {
    int slot=fences[0]==0?0:fences[1]==0?1:-1;if(slot<0)return;
    com.jogamp.opengl.GL3ES3 gpu=((processing.opengl.PJOGL)target.beginPGL()).gl.getGL3ES3();
    try {
      int[] old={0};gpu.glGetIntegerv(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER_BINDING,old,0);
      gpu.glBindBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,buffers[slot]);
      gpu.glReadPixels(0,0,8,6,com.jogamp.opengl.GL.GL_RGBA,com.jogamp.opengl.GL.GL_UNSIGNED_BYTE,0L);
      fences[slot]=gpu.glFenceSync(com.jogamp.opengl.GL3ES3.GL_SYNC_GPU_COMMANDS_COMPLETE,0);
      gpu.glBindBuffer(com.jogamp.opengl.GL2ES3.GL_PIXEL_PACK_BUFFER,old[0]);
    } finally {target.endPGL();}
  }
  void release() {
    if(initialized&&supported){PGraphics display=viewGraphics();com.jogamp.opengl.GL3ES3 gpu=((processing.opengl.PJOGL)display.beginPGL()).gl.getGL3ES3();
      for(int slot=0;slot<2;slot++)if(fences[slot]!=0){gpu.glDeleteSync(fences[slot]);fences[slot]=0;}
      gpu.glDeleteBuffers(2,buffers,0);display.endPGL();}
    initialized=supported=false;
  }
}

void poolMeterCamera(PGraphics target) {
  poolMeterReadback.poll();
  if(!poolMeterReadback.supported){meterCamera(target);return;}
  int now=millis();if(now<meterNext)return;meterNext=now+125;
  if(meterFrame==null){meterFrame=createGraphics(8,6,P2D);meterFrame.noSmooth();meterShader=new PShader(this,POST_VERT,METER_FRAG);}
  processing.opengl.PGraphicsOpenGL source=(processing.opengl.PGraphicsOpenGL)target;
  source.flush();processing.opengl.Texture signal=source.getTexture();
  if(meterSource==null){meterSource=new PImage();meterSource.parent=this;meterSource.format=ARGB;}
  meterSource.width=meterSource.pixelWidth=signal.width;meterSource.height=meterSource.pixelHeight=signal.height;
  meterSource.setModified(false);((processing.opengl.PGraphicsOpenGL)meterFrame).setCache(meterSource,signal);
  meterShader.set("appliedExposure",EXPOSURE_BASE*exposureAdapt);
  meterFrame.beginDraw();meterFrame.imageMode(CORNER);meterFrame.noTint();meterFrame.blendMode(REPLACE);
  meterFrame.shader(meterShader);meterFrame.image(meterSource,0,0,8,6);meterFrame.resetShader();
  poolMeterReadback.enqueue(meterFrame);meterFrame.endDraw();source.beginPGL();source.endPGL();
}

void poolScheduleLighting() {
  // Give gameplay the frame budget first. A single optional slice never controls resolution readiness.
  float budget=1000.0/RENDER_TARGET_FPS;
  // A busy GPU still bakes every 4th frame, so the light keeps converging instead of hanging half-done.
  if(poolGpuSceneMs>0&&poolGpuSceneMs+max(poolGpuBakeMs,0.5)>budget*0.95&&(frameCount%4)!=0)return;
  if((frameCount&1)==0)poolAdvanceLighting();
}

void poolTuneResolution(float fallbackMs) {
  if(!ADAPTIVE_RESOLUTION||!focused||millis()<displaySettleUntil)return;
  if(poolFrameTimer.supported&&poolGpuFrameMs<=0)return; // shader/FBO warmup is not a gameplay sample
  float cost=poolGpuFrameMs>0?poolGpuFrameMs:max(fallbackMs,frameDt*1000);
  renderCostMs=renderCostMs==0?cost:lerp(renderCostMs,cost,0.05);
  if(++resolutionFrames<45||millis()<resolutionCooldown)return;
  float budget=1000.0/RENDER_TARGET_FPS,previous=renderQuality;
  if(renderCostMs>budget) {
    float predicted=renderQuality*sqrt(budget*0.8/max(renderCostMs,cost)); // headroom for view changes and gameplay
    renderQuality=max(0.5,min(renderQuality-0.05,floor(predicted*20)/20.0));
  } else if(resolutionFrames>=240&&millis()>=poolQualityUpAfter&&renderCostMs*sq((renderQuality+0.05)/renderQuality)<budget*0.8)
    renderQuality=min(1,renderQuality+0.05);
  if(renderQuality!=previous){
    resolutionCooldown=millis()+1000;
    poolQualityUpAfter=millis()+(renderQuality<previous?6000:4000);
    resolutionFrames=0;poolGpuFrameMs=poolGpuSceneMs=0;
  }
}
