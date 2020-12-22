#version 400
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

void gradientRadial(
  vec2 at0,
  vec2 to0
) ;

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

float lineDir(
  vec2 a,
  vec2 b
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

float pixelCover(
  vec2 a0,
  vec2 b0
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

vec4 runPixel(
  vec2 xy
) ;

void L(
  float x,
  float y
) ;

void gradientRadial(
  vec2 at0,
  vec2 to0
) {
    if ((float(0)) < (fillMask)) {
    vec2 at = ((mat) * (vec3(at0, float(1)))).xy;
    vec2 to = ((mat) * (vec3(to0, float(1)))).xy;
    float distance = length((at) - (to));
    gradientK = clamp((length((at) - (screen))) / (distance), float(0), float(1));
  };
}

void draw(
) {
"Use crossCount to apply color to backdrop.";
  fillMask = clamp(abs(fillMask), float(0), float(1));
}

void solidFill(
  float r,
  float g,
  float b,
  float a
) {
"Set the source color.";
  if ((float(0)) < (fillMask)) {
        backdropColor = blendNormalFloats(backdropColor, (vec4(r, g, b, a)) * (fillMask));
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
    if ((float(0)) < (fillMask)) {
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
    if ((float(0)) < (fillMask)) {
    vec4 gradientColor = vec4(r, g, b, a);
    if (((prevGradientK) < (gradientK)) && ((gradientK) <= (k))) {
      float betweenColors = ((gradientK) - (prevGradientK)) / ((k) - (prevGradientK));
      vec4 colorG = mix(prevGradientColor, gradientColor, betweenColors);
      backdropColor = blendNormalFloats(backdropColor, (colorG) * (fillMask));
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
    float command = texelFetch(dataBuffer, i).x;
    if ((command) == (0.0)) {
            break;
    } else if ((command) == (1.0)) {
      startPath(texelFetch(dataBuffer, (i) + (1)).x);
(i) += (1);;
    } else if ((command) == (2.0)) {
      endPath();
    } else if ((command) == (4.0)) {
      solidFill(texelFetch(dataBuffer, (i) + (1)).x, texelFetch(dataBuffer, (i) + (2)).x, texelFetch(dataBuffer, (i) + (3)).x, texelFetch(dataBuffer, (i) + (4)).x);
(i) += (4);;
    } else if ((command) == (5.0)) {
      float opacity = texelFetch(dataBuffer, (i) + (1)).x;
      backdropColor = (backdropColor) * (opacity);
(i) += (1);;
    } else if ((command) == (6.0)) {
      tMat[0][0] = texelFetch(dataBuffer, (i) + (1)).x;
      tMat[0][1] = texelFetch(dataBuffer, (i) + (2)).x;
      tMat[0][2] = float(0);
      tMat[1][0] = texelFetch(dataBuffer, (i) + (3)).x;
      tMat[1][1] = texelFetch(dataBuffer, (i) + (4)).x;
      tMat[1][2] = float(0);
      tMat[2][0] = texelFetch(dataBuffer, (i) + (5)).x;
      tMat[2][1] = texelFetch(dataBuffer, (i) + (6)).x;
      tMat[2][2] = float(1);
      float tile = texelFetch(dataBuffer, (i) + (7)).x;
      vec2 pos;
      pos.x = texelFetch(dataBuffer, (i) + (8)).x;
      pos.y = texelFetch(dataBuffer, (i) + (9)).x;
      vec2 size;
      size.x = texelFetch(dataBuffer, (i) + (10)).x;
      size.y = texelFetch(dataBuffer, (i) + (11)).x;
      textureFill(tMat, tile, pos, size);
(i) += (11);;
    } else if ((command) == (7.0)) {
      vec2 at;
      vec2 to;
      at.x = texelFetch(dataBuffer, (i) + (1)).x;
      at.y = texelFetch(dataBuffer, (i) + (2)).x;
      to.x = texelFetch(dataBuffer, (i) + (3)).x;
      to.y = texelFetch(dataBuffer, (i) + (4)).x;
      gradientLinear(at, to);
(i) += (4);;
    } else if ((command) == (8.0)) {
      vec2 at;
      vec2 to;
      at.x = texelFetch(dataBuffer, (i) + (1)).x;
      at.y = texelFetch(dataBuffer, (i) + (2)).x;
      to.x = texelFetch(dataBuffer, (i) + (3)).x;
      to.y = texelFetch(dataBuffer, (i) + (4)).x;
      gradientRadial(at, to);
(i) += (4);;
    } else if ((command) == (9.0)) {
      gradientStop(texelFetch(dataBuffer, (i) + (1)).x, texelFetch(dataBuffer, (i) + (2)).x, texelFetch(dataBuffer, (i) + (3)).x, texelFetch(dataBuffer, (i) + (4)).x, texelFetch(dataBuffer, (i) + (5)).x);
(i) += (5);;
    } else if ((command) == (3.0)) {
      mat[0][0] = texelFetch(dataBuffer, (i) + (1)).x;
      mat[0][1] = texelFetch(dataBuffer, (i) + (2)).x;
      mat[0][2] = float(0);
      mat[1][0] = texelFetch(dataBuffer, (i) + (3)).x;
      mat[1][1] = texelFetch(dataBuffer, (i) + (4)).x;
      mat[1][2] = float(0);
      mat[2][0] = texelFetch(dataBuffer, (i) + (5)).x;
      mat[2][1] = texelFetch(dataBuffer, (i) + (6)).x;
      mat[2][2] = float(1);
(i) += (6);;
    } else if ((command) == (10.0)) {
      M(texelFetch(dataBuffer, (i) + (1)).x, texelFetch(dataBuffer, (i) + (2)).x);
(i) += (2);;
    } else if ((command) == (11.0)) {
      L(texelFetch(dataBuffer, (i) + (1)).x, texelFetch(dataBuffer, (i) + (2)).x);
(i) += (2);;
    } else if ((command) == (12.0)) {
      C(texelFetch(dataBuffer, (i) + (1)).x, texelFetch(dataBuffer, (i) + (2)).x, texelFetch(dataBuffer, (i) + (3)).x, texelFetch(dataBuffer, (i) + (4)).x, texelFetch(dataBuffer, (i) + (5)).x, texelFetch(dataBuffer, (i) + (6)).x);
(i) += (6);;
    } else if ((command) == (13.0)) {
      Q(texelFetch(dataBuffer, (i) + (1)).x, texelFetch(dataBuffer, (i) + (2)).x, texelFetch(dataBuffer, (i) + (3)).x, texelFetch(dataBuffer, (i) + (4)).x);
(i) += (4);;
    } else if ((command) == (14.0)) {
      z();
    } else if ((command) == (15.0)) {
      vec2 minP;
      vec2 maxP;
      minP.x = texelFetch(dataBuffer, (i) + (1)).x;
      minP.y = texelFetch(dataBuffer, (i) + (2)).x;
      maxP.x = texelFetch(dataBuffer, (i) + (3)).x;
      maxP.y = texelFetch(dataBuffer, (i) + (4)).x;
      int label = int(texelFetch(dataBuffer, (i) + (5)).x);
(i) += (5);;
      vec2 screenInv = ((inverse(mat)) * (vec3(screen, float(1)))).xy;
      if (((((screenInv.x) < (minP.x)) || ((maxP.x) < (screenInv.x))) || ((screenInv.y) < (minP.y))) || ((maxP.y) < (screenInv.y))) {
                i = (label) - (1);
      };
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
  if ((float(0)) < (fillMask)) {
    vec2 uv = ((tMat) * (vec3((floor(screen)) + (vec2(float(0.5), float(0.5))), float(1)))).xy;
    if ((tile) == (float(0))) {
            if (((((pos.x) < (uv.x)) && ((uv.x) < ((pos.x) + (size.x)))) && ((pos.y) < (uv.y))) && ((uv.y) < ((pos.y) + (size.y)))) {
        vec4 textureColor = texture(textureAtlasSampler, uv);
        backdropColor = blendNormalFloats(backdropColor, textureColor);
      };
    } else {
      uv = (mod((uv) - (pos), size)) + (pos);
      vec4 textureColor = texture(textureAtlasSampler, uv);
      backdropColor = blendNormalFloats(backdropColor, (textureColor) * (fillMask));
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

float lineDir(
  vec2 a,
  vec2 b
) {
    if ((float(0)) < ((a.y) - (b.y))) {
        return float(1);
  } else {
        return float(-1);
  };
}

void bezier(
  vec2 A,
  vec2 B,
  vec2 C,
  vec2 D
) {
"Turn a cubic curve into N lines.";
  vec2 p = A;
  int discretization = 20;
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

float pixelCover(
  vec2 a0,
  vec2 b0
) {
"Returns the amount of area a given segment sweeps to the right\nin a [0,0 to 1,1] box.";
  vec2 a = a0;
  vec2 b = b0;
  vec2 aI;
  vec2 bI;
  float area;
  float e = 0.0;
  float ee = -0.5;
  if ((b.y) < (a.y)) {
    vec2 tmp = a;
    a = b;
    b = tmp;
  };
  if (((((float(b.y)) < ((float(0)) + (e))) || (((float(1)) - (e)) < (float(a.y)))) || ((((float(1)) - (e)) < (float(a.x))) && (((float(1)) - (e)) < (float(b.x))))) || ((a.y) == (b.y))) {
        return float(0);
  } else if ((((float(a.x)) < ((float(0)) + (e))) && ((float(b.x)) < ((float(0)) + (e)))) || ((a.x) == (b.x))) {
        return ((float(1)) - (clamp(a.x, float(0), float(1)))) * ((min(b.y, float(1))) - (max(a.y, float(0))));
  } else {
    float mm = ((b.y) - (a.y)) / ((b.x) - (a.x));
    float bb = (a.y) - ((mm) * (a.x));
    if ((((((float(0)) + (e)) <= (float(a.x))) && ((float(a.x)) <= ((float(1)) - (e)))) && (((float(0)) + (e)) <= (float(a.y)))) && ((float(a.y)) <= ((float(1)) - (e)))) {
            aI = a;
    } else {
      aI = vec2(((float(0)) - (bb)) / (mm), float(0));
      if ((float(aI.x)) < ((float(0)) + (e))) {
        float y = ((mm) * (float(0))) + (bb);
(area) += (float(clamp((min(float(bb), (float(1)) - (ee))) - (max(float(a.y), (float(0)) + (ee))), float(0), float(1))));;
        aI = vec2(float((float(0)) + (ee)), clamp(y, float(0), float(1)));
      } else if (((float(1)) - (e)) < (float(aI.x))) {
        float y = ((mm) * (float(1))) + (bb);
        aI = vec2(float((float(1)) - (ee)), clamp(y, float(0), float(1)));
      };
    };
    if ((((((float(0)) + (e)) <= (float(b.x))) && ((float(b.x)) <= ((float(1)) - (e)))) && (((float(0)) + (e)) <= (float(b.y)))) && ((float(b.y)) <= ((float(1)) - (e)))) {
            bI = b;
    } else {
      bI = vec2(((float(1)) - (bb)) / (mm), float(1));
      if ((float(bI.x)) < ((float(0)) + (e))) {
        float y = ((mm) * (float(0))) + (bb);
(area) += (float(clamp((min(float(b.y), (float(1)) - (ee))) - (max(float(bb), (float(0)) + (ee))), float(0), float(1))));;
        bI = vec2(float((float(0)) + (ee)), clamp(y, float(0), float(1)));
      } else if (((float(1)) - (e)) < (float(bI.x))) {
        float y = ((mm) * (float(1))) + (bb);
        bI = vec2(float((float(1)) - (ee)), clamp(y, float(0), float(1)));
      };
    };
  };
(area) += (((((float(1)) - (aI.x)) + ((float(1)) - (bI.x))) / (float(2))) * ((bI.y) - (aI.y)));;
  return area;
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
  vec2 a1 = (((mat) * (vec3(a0, float(1)))).xy) - (screen);
  vec2 b1 = (((mat) * (vec3(b0, float(1)))).xy) - (screen);
  float area = pixelCover(a1, b1);
  area = area;
(fillMask) += ((area) * (lineDir(a1, b1)));;
}

vec4 runPixel(
  vec2 xy
) {
  screen = xy;
  backdropColor = vec4(float(0), float(0), float(0), float(0));
  runCommands();
  return backdropColor;
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
  float bias = 0.0001;
  vec2 offset = vec2(float((bias) - (0.5)), float((bias) - (0.5)));
  fragColor = runPixel((gl_FragCoord.xy) + (offset));
}
