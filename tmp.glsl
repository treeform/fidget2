#version 300 es
precision highp float;
// from svgMain

vec4 sourceColor;
float x1;
float textureOn;
uniform samplerBuffer dataBuffer;
vec2 screen;
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

void line(
  vec2 a,
  vec2 b
) ;

void L(
  float x,
  float y
) ;

void draw(
) {
"Use crossCount to apply color to backdrop.";
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
"Set the source color.";
  sourceColor = vec4(r, g, b, a);
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

void startPath(
) {
"Clear the status of things and start a new path.";
  crossCount = 0;
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
    } else if ((command) == (4.0)) {
      textureOn = texelFetch(dataBuffer, (i) + (1));
(i) += (1);
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

void line(
  vec2 a,
  vec2 b
) {
"Turn a line into inc/dec/ignore of the crossCount.";
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
