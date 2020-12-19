#version 300 es
precision highp float;
// from svgMain

float x1;
int windingRule = 0;
uniform sampler2D textureAtlasSampler;
uniform samplerBuffer dataBuffer;
vec2 screen;
float y0;
float y1;
vec4 prevGradientColor;
mat3 tMat;
float gradientK;
float fillMask;
mat3 mat;
float prevGradientK;
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

void gradientLinear(
  vec2 at0,
  vec2 to0
) ;

float toLineSpace(
  vec2 at,
  vec2 to,
  vec2 point
) ;

void gradientStop(
  float k,
  float r,
  float g,
  float b,
  float a
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
  float rule
) ;

void runCommands(
) ;

void textureFill(
  mat3 tMat,
  float tile,
  vec2 pos,
  vec2 size
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
  if ((windingRule) == (0)) {
        if (! (((crossCount) % (2)) == (0))) {
            fillMask = float(1);
    };
  } else {
        if (! ((crossCount) == (0))) {
            fillMask = float(1);
    };
  };
}

void solidFill(
  float r,
  float g,
  float b,
  float a
) {
"Set the source color.";
  if ((fillMask) == (float(1))) {
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

void gradientLinear(
  vec2 at0,
  vec2 to0
) {
    if ((fillMask) == (float(1))) {
    vec2 at = ((mat) * (vec3(at0, float(1)))).xy;
    vec2 to = ((mat) * (vec3(to0, float(1)))).xy;
    gradientK = clamp(toLineSpace(at, to, screen), float(0), float(1));
  };
}

float toLineSpace(
  vec2 at,
  vec2 to,
  vec2 point
) {
  vec2 d = (to) - (at);
  float det = ((d.x) * (d.x)) + ((d.y) * (d.y));
  return (((d.y) * ((point.y) - (at.y))) + ((d.x) * ((point.x) - (at.x)))) / (det);
}

void gradientStop(
  float k,
  float r,
  float g,
  float b,
  float a
) {
    if ((fillMask) == (float(1))) {
    vec4 gradientColor = vec4(r, g, b, a);
    if (((prevGradientK) < (gradientK)) && ((gradientK) <= (k))) {
      float betweenColors = ((gradientK) - (prevGradientK)) / ((k) - (prevGradientK));
      vec4 colorG = mix(prevGradientColor, gradientColor, betweenColors);
      backdropColor = blendNormalFloats(backdropColor, colorG);
    };
    prevGradientK = k;
    prevGradientColor = gradientColor;
  };
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
  float devx = ((float(p0.x)) - ((2.0) * (float(p1.x)))) + (float(p2.x));
  float devy = ((float(p0.y)) - ((2.0) * (float(p1.y)))) + (float(p2.y));
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
(t) += (nrecip);;
    vec2 pn = mix(mix(p0, p1, float(t)), mix(p1, p2, float(t)), float(t));
    line(p, pn);
    p = pn;
  };
}

void startPath(
  float rule
) {
"Clear the status of things and start a new path.";
  crossCount = 0;
  fillMask = float(0);
  windingRule = int(rule);
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
      startPath(texelFetch(dataBuffer, (i) + (1)));
(i) += (1);;
    } else if ((command) == (2.0)) {
      endPath();
    } else if ((command) == (4.0)) {
      solidFill(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)));
(i) += (4);;
    } else if ((command) == (5.0)) {
      float opacity = texelFetch(dataBuffer, (i) + (1));
      backdropColor = (backdropColor) * (opacity);
(i) += (1);;
    } else if ((command) == (6.0)) {
      tMat[0][0] = texelFetch(dataBuffer, (i) + (1));
      tMat[0][1] = texelFetch(dataBuffer, (i) + (2));
      tMat[0][2] = float(0);
      tMat[1][0] = texelFetch(dataBuffer, (i) + (3));
      tMat[1][1] = texelFetch(dataBuffer, (i) + (4));
      tMat[1][2] = float(0);
      tMat[2][0] = texelFetch(dataBuffer, (i) + (5));
      tMat[2][1] = texelFetch(dataBuffer, (i) + (6));
      tMat[2][2] = float(1);
      float tile = texelFetch(dataBuffer, (i) + (7));
      vec2 pos;
      pos.x = texelFetch(dataBuffer, (i) + (8));
      pos.y = texelFetch(dataBuffer, (i) + (9));
      vec2 size;
      size.x = texelFetch(dataBuffer, (i) + (10));
      size.y = texelFetch(dataBuffer, (i) + (11));
      textureFill(tMat, tile, pos, size);
(i) += (11);;
    } else if ((command) == (7.0)) {
      vec2 at;
      vec2 to;
      at.x = texelFetch(dataBuffer, (i) + (1));
      at.y = texelFetch(dataBuffer, (i) + (2));
      to.x = texelFetch(dataBuffer, (i) + (3));
      to.y = texelFetch(dataBuffer, (i) + (4));
      gradientLinear(at, to);
(i) += (4);;
    } else if ((command) == (8.0)) {
      gradientStop(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)), texelFetch(dataBuffer, (i) + (5)));
(i) += (5);;
    } else if ((command) == (3.0)) {
      mat[0][0] = texelFetch(dataBuffer, (i) + (1));
      mat[0][1] = texelFetch(dataBuffer, (i) + (2));
      mat[0][2] = float(0);
      mat[1][0] = texelFetch(dataBuffer, (i) + (3));
      mat[1][1] = texelFetch(dataBuffer, (i) + (4));
      mat[1][2] = float(0);
      mat[2][0] = texelFetch(dataBuffer, (i) + (5));
      mat[2][1] = texelFetch(dataBuffer, (i) + (6));
      mat[2][2] = float(1);
(i) += (6);;
    } else if ((command) == (10.0)) {
      M(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)));
(i) += (2);;
    } else if ((command) == (11.0)) {
      L(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)));
(i) += (2);;
    } else if ((command) == (12.0)) {
      C(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)), texelFetch(dataBuffer, (i) + (5)), texelFetch(dataBuffer, (i) + (6)));
(i) += (6);;
    } else if ((command) == (13.0)) {
      Q(texelFetch(dataBuffer, (i) + (1)), texelFetch(dataBuffer, (i) + (2)), texelFetch(dataBuffer, (i) + (3)), texelFetch(dataBuffer, (i) + (4)));
(i) += (4);;
    } else if ((command) == (20.0)) {
      z();
    };
(i) += (1);;
  };
}

void textureFill(
  mat3 tMat,
  float tile,
  vec2 pos,
  vec2 size
) {
"Set the source color.";
  if ((fillMask) == (float(1))) {
    vec2 uv = ((tMat) * (vec3(screen, float(1)))).xy;
    if ((tile) == (float(0))) {
            if (((((pos.x) < (uv.x)) && ((uv.x) < ((pos.x) + (size.x)))) && ((pos.y) < (uv.y))) && ((uv.y) < ((pos.y) + (size.y)))) {
        vec4 textureColor = texture(textureAtlasSampler, uv);
        backdropColor = blendNormalFloats(backdropColor, textureColor);
      };
    } else {
      uv = (mod((uv) - (pos), size)) + (pos);
      vec4 textureColor = texture(textureAtlasSampler, uv);
      backdropColor = blendNormalFloats(backdropColor, textureColor);
    };
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
  vec2 A = ((G4) - (G1)) + ((float(3)) * ((G2) - (G3)));
  vec2 B = (float(3)) * (((G1) - ((float(2)) * (G2))) + (G3));
  vec2 C = (float(3)) * ((G2) - (G1));
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
  res.w = float((float(source.w)) + ((float(backdrop.w)) * ((1.0) - (float(source.w)))));
  if ((float(res.w)) == (0.0)) {
        return res;
  };
  float t0 = (float(source.w)) * ((1.0) - (float(backdrop.w)));
  float t1 = (source.w) * (backdrop.w);
  float t2 = ((1.0) - (float(source.w))) * (float(backdrop.w));
  res.x = float((((t0) * (float(source.x))) + (float((t1) * (mixed.x)))) + ((t2) * (float(backdrop.x))));
  res.y = float((((t0) * (float(source.y))) + (float((t1) * (mixed.y)))) + ((t2) * (float(backdrop.y))));
  res.z = float((((t0) * (float(source.z))) + (float((t1) * (mixed.z)))) + ((t2) * (float(backdrop.z))));
(res.x) /= (res.w);;
(res.y) /= (res.w);;
(res.z) /= (res.w);;
  return res;
}

void line(
  vec2 a0,
  vec2 b0
) {
"Turn a line into inc/dec/ignore of the crossCount.";
  vec2 a = ((mat) * (vec3(a0, float(1)))).xy;
  vec2 b = ((mat) * (vec3(b0, float(1)))).xy;
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
            if ((float(0)) < ((a.y) - (b.y))) {
        (crossCount) += (1);;
      } else {
        (crossCount) -= (1);;
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
  backdropColor = vec4(float(0), float(0), float(0), float(0));
  screen = gl_FragCoord.xy;
  runCommands();
  fragColor = backdropColor;
}
