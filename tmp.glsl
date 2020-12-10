#version 300 es
precision highp float;

vec2 uv;
float x1;
float S = 1.0;
uniform samplerBuffer dataBuffer;
float FILL = 1.0;
float contrast = 12.0;
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
  float r,
  float g,
  float b,
  float a
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

vec4 mainImage(
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
  float d = min((sqrt(d0)) * (contrast), 1.0);
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
  float r,
  float g,
  float b,
  float a
) {
  fill = f;
  S = 1.0;
  COL = vec4(r, g, b, a);
}

void SVG(
  vec2 inUv,
  inout vec4 O
) {
  uv = (inUv) * (400.0);
  int i = 0;
  while(true) {
    float command = texelFetch(dataBuffer, i);
    if ((command) == (0.0)) {
            break;
    } else if ((command) == (1.0)) {
      startPath();
    } else if ((command) == (2.0)) {
      endPath(O);
    } else if ((command) == (3.0)) {
      style(FILL, texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)));
(i) += (4);
    } else if ((command) == (10.0)) {
      M(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)));
(i) += (2);
    } else if ((command) == (11.0)) {
      L(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)));
(i) += (2);
    } else if ((command) == (12.0)) {
      C(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)), texelFetch(dataBuffer, (i) + (5)), texelFetch(dataBuffer, (i) + (6)));
(i) += (6);
    } else if ((command) == (20.0)) {
      z();
    };
(i) += (1);
  };
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

vec4 mainImage(
  vec2 U0
) {
  vec4 O = vec4(1);
  vec2 R = vec2(400, 400);
  vec2 U = U0;
  U = (U) / (R.x);
  SVG(U, O);
  return O;
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
    fragColor = mainImage(gl_FragCoord.xy);
}