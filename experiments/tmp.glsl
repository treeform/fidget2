#version 300 es
precision mediump float;

vec2 uv;
float x1;
float S = 1.0;
float FILL = 1.0;
float contrast = 1.0;
float y0;
float fill = 1.0;
float y1;
vec4 COL;
float d = 1e+038;
float x0;

void draw(
  float d0,
  inout vec4 O
) ;

void style(
  float f,
  vec4 c
) ;

void SVG(
  vec2 inUv,
  inout vec4 O
) ;

void C(
  float x1,
  float y1,
  float x2,
  float y2,
  float x,
  float y
) ;

void mainImage(
  inout vec4 O,
  vec2 U0
) ;

void z(
) ;

void startPath(
) ;

vec2 interpolate(
  vec2 G1,
  vec2 G2,
  vec2 G3,
  vec2 G4,
  float t
) ;

float bezier(
  vec2 uv,
  vec2 A,
  vec2 B,
  vec2 C,
  vec2 D
) ;

void M(
  float x,
  float y
) ;

void endPath(
  inout vec4 O
) ;

float line(
  vec2 p,
  vec2 a,
  vec2 b
) ;

void L(
  float x,
  float y
) ;

void draw(
  float d0,
  inout vec4 O
) {
  float d = min(((sqrt(d0)) * (contrast)) * (2.0), 1.0);
  float value = 0.0;
  if ((0.0) < (fill)) {
        value = (0.5) + (((0.5) * (S)) * (d));
  } else {
        value = d;
  };
  O = mix(COL, O, value);
}

void style(
  float f,
  vec4 c
) {
  fill = f;
  S = 1.0;
  COL = c;
}

void SVG(
  vec2 inUv,
  inout vec4 O
) {
  uv = (inUv) * (400.0);
  contrast = 1.0;
  startPath();
  style(FILL, vec4(0.45, 0.71, 0.1, 1.0));
  M(82.2115, 102.414);
  C(82.2115, 102.414, 104.7155, 69.211, 149.6485, 65.777);
  L(149.6485, 53.73);
  C(99.87949999999999, 57.727, 56.7818, 99.87900000000001, 56.7818, 99.87900000000001);
  C(56.7818, 99.87900000000001, 81.19150000000001, 170.445, 149.6485, 176.906);
  L(149.6485, 164.102);
  C(99.4105, 157.781, 82.2115, 102.414, 82.2115, 102.414);
  z();
  endPath(O);
  startPath();
  style(FILL, vec4(0.45, 0.71, 0.1, 1.0));
  M(149.6485, 138.637);
  L(149.6485, 150.363);
  C(111.6805, 143.594, 101.1415, 104.125, 101.1415, 104.125);
  C(101.1415, 104.125, 119.3715, 83.93000000000001, 149.6485, 80.65600000000001);
  L(149.6485, 93.523);
  C(149.6255, 93.523, 149.6095, 93.51600000000001, 149.5905, 93.51600000000001);
  C(133.6995, 91.609, 121.2855, 106.453, 121.2855, 106.453);
  C(121.2855, 106.453, 128.2425, 131.445, 149.6485, 138.637);
  endPath(O);
  startPath();
  style(FILL, vec4(0.45, 0.71, 0.1, 1.0));
  M(149.6485, 31.512);
  L(149.6485, 53.73);
  C(151.1095, 53.617, 152.5705, 53.523, 154.0395, 53.473);
  C(210.6215, 51.566, 247.4885, 99.87900000000001, 247.4885, 99.87900000000001);
  C(247.4885, 99.87900000000001, 205.1455, 151.367, 161.0315, 151.367);
  C(156.9885, 151.367, 153.2035, 150.992, 149.6485, 150.363);
  L(149.6485, 164.102);
  C(152.6885, 164.488, 155.8405, 164.715, 159.1295, 164.715);
  C(200.1805, 164.715, 229.8675, 143.75, 258.6135, 118.937);
  C(263.3795, 122.754, 282.8915, 132.039, 286.9025, 136.105);
  C(259.5705, 158.988, 195.8715, 177.434, 159.7585, 177.434);
  C(156.2775, 177.434, 152.9345, 177.223, 149.6485, 176.906);
  L(149.6485, 196.211);
  L(305.6805, 196.211);
  L(305.6805, 31.512);
  L(149.6485, 31.512);
  z();
  endPath(O);
  startPath();
  style(FILL, vec4(0.45, 0.71, 0.1, 1.0));
  M(149.6485, 80.65600000000001);
  L(149.6485, 65.777);
  C(151.0945, 65.676, 152.5515, 65.598, 154.0395, 65.551);
  C(194.7275, 64.273, 221.4225, 100.516, 221.4225, 100.516);
  C(221.4225, 100.516, 192.5905, 140.559, 161.6765, 140.559);
  C(157.2275, 140.559, 153.2385, 139.844, 149.6485, 138.637);
  L(149.6485, 93.523);
  C(165.4885, 95.437, 168.6765, 102.434, 178.1995, 118.309);
  L(199.3795, 100.449);
  C(199.3795, 100.449, 183.9185, 80.172, 157.8555, 80.172);
  C(155.0205, 80.172, 152.3095, 80.371, 149.6485, 80.65600000000001);
  endPath(O);
}

void C(
  float x1,
  float y1,
  float x2,
  float y2,
  float x,
  float y
) {
  d = min(d, bezier(uv, vec2(x0, y0), vec2(x1, y1), vec2(x2, y2), vec2(x, y)));
  x0 = x;
  y0 = y;
}

void mainImage(
  inout vec4 O,
  vec2 U0
) {
  O = vec4(1);
  vec2 R = vec2(1000, 1000);
  vec2 U = U0;
  U.y = (R.y) - (U.y);
  U = (U) / (R.x);
  SVG(U, O);
}

void z(
) {
    d = min(d, line(uv, vec2(x0, y0), vec2(x1, y1)));
}

void startPath(
) {
    d = 1e+038;
}

vec2 interpolate(
  vec2 G1,
  vec2 G2,
  vec2 G3,
  vec2 G4,
  float t
) {
  vec2 A = ((G4) - (G1)) + ((3.0) * ((G2) - (G3)));
  vec2 B = (3.0) * (((G1) - ((2.0) * (G2))) + (G3));
  vec2 C = (3.0) * ((G2) - (G1));
  vec2 D = G1;
  return ((t) * (((t) * (((t) * (A)) + (B))) + (C))) + (D);
}

float bezier(
  vec2 uv,
  vec2 A,
  vec2 B,
  vec2 C,
  vec2 D
) {
  vec2 p = A;
  int discretization = 10;
  for(int t = 1; t <= discretization; t++) {
    vec2 q = interpolate(A, B, C, D, (float(t)) / (float(discretization)));
    float l = line(uv, p, q);
    d = min(d, l);
    p = q;
  };
  return d;
}

void M(
  float x,
  float y
) {
  x1 = x;
  x0 = x;
  y1 = y;
  y0 = y;
}

void endPath(
  inout vec4 O
) {
  draw(d, O);
;
}

float line(
  vec2 p,
  vec2 a,
  vec2 b
) {
  vec2 pa = (p) - (a);
  vec2 ba = (b) - (a);
  vec2 d = (pa) - ((ba) * (clamp((dot(pa, ba)) / (dot(ba, ba)), 0.0, 1.0)));
  if ((! (((p.y) < (a.y)) == ((p.y) < (b.y)))) && ((pa.x) < (((ba.x) * (pa.y)) / (ba.y)))) {
        S = - (S);
  };
  return dot(d, d);
}

void L(
  float x,
  float y
) {
  d = min(d, line(uv, vec2(x0, y0), vec2(x, y)));
  x0 = x;
  y0 = y;
}
// name: svgMain

in vec4 gl_FragCoord;
out vec4 fragColor;

void main() {
  mainImage(fragColor, gl_FragCoord.xy);
}