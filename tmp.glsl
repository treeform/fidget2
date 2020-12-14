#version 300 es
precision highp float;
// from svgMain

vec2 uv;
vec4 sourceColor;
float x1;
float textureOn;
uniform samplerBuffer dataBuffer;
float y0;
float y1;
int crossCount = 0;
float x0;
vec4 backdropColor;

void draw(
) ;

void style(
  float r,
  float g,
  float b,
  float a
) ;

void SVG(
  vec2 inUv
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

void bezier(
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
) ;

void line(
  vec2 p,
  vec2 a,
  vec2 b
) ;

void L(
  float x,
  float y
) ;

void draw(
) {
    if (! (((crossCount) % (2)) == (0))) {
        backdropColor = sourceColor;
  };
}

void style(
  float r,
  float g,
  float b,
  float a
) {
    sourceColor = vec4(r, g, b, a);
}

void SVG(
  vec2 inUv
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
      endPath();
    } else if ((command) == (3.0)) {
      textureOn = 0.0;
      style(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)));
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
    } else if ((command) == (5.0)) {
      textureOn = texelFetch(dataBuffer, (i) + (1));
(i) += (1);
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
  bezier(uv, vec2(x0, y0), vec2(x1, y1), vec2(x2, y2), vec2(x, y));
  x0 = x;
  y0 = y;
}

void mainImage(
  vec2 U0
) {
  vec2 R = vec2(400, 400);
  vec2 U = U0;
  U = (U) / (R.x);
  SVG(U);
}

void z(
) {
  line(uv, vec2(x0, y0), vec2(x1, y1));
}

void startPath(
) {
    crossCount = 0;
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

void bezier(
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
    line(uv, p, q);
  };
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
) {
  draw();
}

void line(
  vec2 p,
  vec2 a,
  vec2 b
) {
  if ((a.y) == (b.y)) {
        return ;
  };
  if (((min(a.y, b.y)) <= (p.y)) && ((p.y) < (max(a.y, b.y)))) {
        if ((b.x) == (a.x)) {
      float xIntersect = a.x;
      if ((xIntersect) <= (p.x)) {
                if ((0.0) < ((a.y) - (b.y))) {
          (crossCount) += (1);
        } else {
          (crossCount) -= (1);
        };
      };
    } else {
      float m = ((b.y) - (a.y)) / ((b.x) - (a.x));
      float bb = (a.y) - ((m) * (a.x));
      float xIntersect = ((p.y) - (bb)) / (m);
      if ((xIntersect) <= (p.x)) {
                if ((0.0) < ((a.y) - (b.y))) {
          (crossCount) += (1);
        } else {
          (crossCount) -= (1);
        };
      };
    };
  };
}

void L(
  float x,
  float y
) {
  line(uv, vec2(x0, y0), vec2(x, y));
  x0 = x;
  y0 = y;
}
in vec4 gl_FragCoord;
out vec4 fragColor;

void main() {
  crossCount = 0;
  backdropColor = vec4(0, 0, 0, 0);
  mainImage(gl_FragCoord.xy);
  fragColor = backdropColor;
}
