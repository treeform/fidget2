#version 300 es
precision highp float;
// from svgMain

float x1;
float textureOn;
uniform samplerBuffer dataBuffer;
vec2 screen;
float y0;
float y1;
float fillMask;
mat3 mat;
int crossCount = 0;
float x0;
vec4 backdropColor;

void draw(
) ;

void solidFill(
  float r,
  float g,
  float b,
  float a
) ;

void C(
  float x1,
  float y1,
  float x2,
  float y2,
  float x,
  float y
) ;

void z(
) ;

void Q(
  float x1,
  float y1,
  float x,
  float y
) ;

vec4 blendNormalFloats(
  vec4 backdrop,
  vec4 source
) ;

void quadratic(
  vec2 p0,
  vec2 p1,
  vec2 p2
) ;

void startPath(
) ;

void runCommands(
) ;

vec2 interpolate(
  vec2 G1,
  vec2 G2,
  vec2 G3,
  vec2 G4,
  float t
) ;

void bezier(
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

vec4 alphaFix(
  vec4 backdrop,
  vec4 source,
  vec4 mixed
) ;

void line(
  vec2 a0,
  vec2 b0
) ;

void L(
  float x,
  float y
) ;

void draw(
) {
"Use crossCount to apply color to backdrop.";
  if (! (((crossCount) % (2)) == (0))) {
        fillMask = 1.0;
  };
}

void solidFill(
  float r,
  float g,
  float b,
  float a
) {
"Set the source color.";
  if ((fillMask) == (1.0)) {
        backdropColor = blendNormalFloats(backdropColor, vec4(r, g, b, a));
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
"SVG cubic Curve command.";
  bezier(vec2(x0, y0), vec2(x1, y1), vec2(x2, y2), vec2(x, y));
  x0 = x;
  y0 = y;
}

void z(
) {
"SVG style end of shape command.";
  line(vec2(x0, y0), vec2(x1, y1));
}

void Q(
  float x1,
  float y1,
  float x,
  float y
) {
"SVG Quadratic curve command.";
  quadratic(vec2(x0, y0), vec2(x1, y1), vec2(x, y));
  x0 = x;
  y0 = y;
}

vec4 blendNormalFloats(
  vec4 backdrop,
  vec4 source
) {
    return alphaFix(backdrop, source, source);
}

void quadratic(
  vec2 p0,
  vec2 p1,
  vec2 p2
) {
"Turn a cubic curve into N lines.";
  float devx = ((p0.x) - ((2.0) * (p1.x))) + (p2.x);
  float devy = ((p0.y) - ((2.0) * (p1.y))) + (p2.y);
  float devsq = ((devx) * (devx)) + ((devy) * (devy));
  if ((devsq) < (0.333)) {
    line(p0, p2);
    return ;
  };
  float tol = 3.0;
  float n = (1.0) + (floor(sqrt(sqrt((tol) * (devsq)))));
  vec2 p = p0;
  float nrecip = (1.0) / (n);
  float t = 0.0;
  for(int i = 0; i < int(n); i++) {
(t) += (nrecip);
    vec2 pn = mix(mix(p0, p1, t), mix(p1, p2, t), t);
    line(p, pn);
    p = pn;
  };
}

void startPath(
) {
"Clear the status of things and start a new path.";
  crossCount = 0;
  fillMask = 0.0;
}

void runCommands(
) {
"Runs a little command interpreter.";
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
      solidFill(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)));
(i) += (4);
    } else if ((command) == (4.0)) {
      float opacity = texelFetch(dataBuffer, (i) + (1));
      backdropColor = (backdropColor) * (opacity);
(i) += (1);
    } else if ((command) == (5.0)) {
      textureOn = texelFetch(dataBuffer, (i) + (1));
(i) += (1);
    } else if ((command) == (6.0)) {
      mat[0][0] = texelFetch(dataBuffer, (i) + (1));
      mat[0][1] = texelFetch(dataBuffer, (i) + (2));
      mat[0][2] = 0.0;
      mat[1][0] = texelFetch(dataBuffer, (i) + (3));
      mat[1][1] = texelFetch(dataBuffer, (i) + (4));
      mat[1][2] = 0.0;
      mat[2][0] = texelFetch(dataBuffer, (i) + (5));
      mat[2][1] = texelFetch(dataBuffer, (i) + (6));
      mat[2][2] = 1.0;
(i) += (6);
    } else if ((command) == (10.0)) {
      M(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)));
(i) += (2);
    } else if ((command) == (11.0)) {
      L(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)));
(i) += (2);
    } else if ((command) == (12.0)) {
      C(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)), texelFetch(dataBuffer, (i) + (5)), texelFetch(dataBuffer, (i) + (6)));
(i) += (6);
    } else if ((command) == (13.0)) {
      Q(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)));
(i) += (4);
    } else if ((command) == (20.0)) {
      z();
    };
(i) += (1);
  };
}

vec2 interpolate(
  vec2 G1,
  vec2 G2,
  vec2 G3,
  vec2 G4,
  float t
) {
"Solve the cubic bezier interpolation with 4 points.";
  vec2 A = ((G4) - (G1)) + ((3.0) * ((G2) - (G3)));
  vec2 B = (3.0) * (((G1) - ((2.0) * (G2))) + (G3));
  vec2 C = (3.0) * ((G2) - (G1));
  vec2 D = G1;
  return ((t) * (((t) * (((t) * (A)) + (B))) + (C))) + (D);
}

void bezier(
  vec2 A,
  vec2 B,
  vec2 C,
  vec2 D
) {
"Turn a cubic curve into N lines.";
  vec2 p = A;
  int discretization = 10;
  for(int t = 1; t <= discretization; t++) {
    vec2 q = interpolate(A, B, C, D, (float(t)) / (float(discretization)));
    line(p, q);
    p = q;
  };
}

void M(
  float x,
  float y
) {
"SVG style Move command.";
  x1 = x;
  x0 = x;
  y1 = y;
  y0 = y;
}

void endPath(
) {
"SVG style end path command.";
  draw();
}

vec4 alphaFix(
  vec4 backdrop,
  vec4 source,
  vec4 mixed
) {
  vec4 res;
  res.w = (source.w) + ((backdrop.w) * ((1.0) - (source.w)));
  if ((res.w) == (0.0)) {
        return res;
  };
  float t0 = (source.w) * ((1.0) - (backdrop.w));
  float t1 = (source.w) * (backdrop.w);
  float t2 = ((1.0) - (source.w)) * (backdrop.w);
  res.x = (((t0) * (source.x)) + ((t1) * (mixed.x))) + ((t2) * (backdrop.x));
  res.y = (((t0) * (source.y)) + ((t1) * (mixed.y))) + ((t2) * (backdrop.y));
  res.z = (((t0) * (source.z)) + ((t1) * (mixed.z))) + ((t2) * (backdrop.z));
(res.x) /= (res.w);
(res.y) /= (res.w);
(res.z) /= (res.w);
  return res;
}

void line(
  vec2 a0,
  vec2 b0
) {
"Turn a line into inc/dec/ignore of the crossCount.";
  vec2 a = ((mat) * (vec3(a0, 1))).xy;
  vec2 b = ((mat) * (vec3(b0, 1))).xy;
  if ((a.y) == (b.y)) {
        return ;
  };
  if (((min(a.y, b.y)) <= (screen.y)) && ((screen.y) < (max(a.y, b.y)))) {
    float xIntersect;
    if (! ((b.x) == (a.x))) {
      float m = ((b.y) - (a.y)) / ((b.x) - (a.x));
      float bb = (a.y) - ((m) * (a.x));
      xIntersect = ((screen.y) - (bb)) / (m);
    } else {
            xIntersect = a.x;
    };
    if ((xIntersect) <= (screen.x)) {
            if ((0.0) < ((a.y) - (b.y))) {
        (crossCount) += (1);
      } else {
        (crossCount) -= (1);
      };
    };
  };
}

void L(
  float x,
  float y
) {
"SVG style Line command.";
  line(vec2(x0, y0), vec2(x, y));
  x0 = x;
  y0 = y;
}
in vec4 gl_FragCoord;
out vec4 fragColor;

void main() {
"Main entry point to this huge shader.";
  crossCount = 0;
  backdropColor = vec4(0, 0, 0, 0);
  screen = gl_FragCoord.xy;
  runCommands();
  fragColor = backdropColor;
}
