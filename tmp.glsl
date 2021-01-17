#version 300 es
precision highp float;
// from svgMain

int blendMode;
float x1;
float shadowSpread;
int windingRule = 0;
uniform sampler2D textureAtlasSampler;
vec2 shadowOffset;
bool shadowOn;
float shadowRadius;
uniform samplerBuffer dataBuffer;
vec2 screen;
float[99] maskStack;
float y0;
vec4 shadowColor;
float y1;
vec4 prevGradientColor;
mat3 tMat;
float gradientK;
float fillMask = 0.0;
float mask = 1.0;
int maskStackTop;
bool maskOn;
float topIndex;
mat3 mat;
float prevGradientK;
mat4 crossCountMat;
float layerBlur;
float x0;
vec4 backdropColor;

float Sat(vec4 C);
void draw();
float colorDodgeBlend(float backdrop, float source);
vec4 blendColorDodgeFloats(vec4 backdrop, vec4 source);
float zmod(float a, float b);
float colorBurnBlend(float backdrop, float source);
vec4 blendLinearDodgeFloats(vec4 backdrop, vec4 source);
void C(float x1, float y1, float x2, float y2, float x, float y);
vec4 blendLightenFloats(vec4 backdrop, vec4 source);
vec4 blendHueFloats(vec4 backdrop, vec4 source);
vec4 blendSubtractMaskFloats(vec4 backdrop, vec4 source);
float toLineSpace(vec2 at, vec2 to, vec2 point);
void z();
void Q(float x1, float y1, float x, float y);
void quadratic(vec2 p0, vec2 p1, vec2 p2);
float pixelCross(vec2 a0, vec2 b0);
vec4 blendOverwriteFloats(vec4 backdrop, vec4 source);
void runCommands();
vec4 blendIntersectMaskFloats(vec4 backdrop, vec4 source);
void ClipColor(inout vec4 C);
float pixelCover(vec2 a0, vec2 b0);
vec4 blendDarkenFloats(vec4 backdrop, vec4 source);
vec4 blendExcludeMaskFloats(vec4 backdrop, vec4 source);
vec4 alphaFix(vec4 backdrop, vec4 source, vec4 mixed);
vec4 runPixel(vec2 xy);
vec4 blendSoftLightFloats(vec4 backdrop, vec4 source);
void L(float x, float y);
void finalColor(vec4 applyColor);
vec4 blendMultiplyFloats(vec4 backdrop, vec4 source);
vec4 blendLuminosityFloats(vec4 backdrop, vec4 source);
float normPdf(float x, float sigma);
void solidFill(float r, float g, float b, float a);
void gradientRadial(vec2 at0, vec2 to0);
float softLight(float backdrop, float source);
void gradientLinear(vec2 at0, vec2 to0);
vec4 blendExclusionFloats(vec4 backdrop, vec4 source);
void gradientStop(float k, float r, float g, float b, float a);
float exclusionBlend(float backdrop, float source);
vec4 blendNormalFloats(vec4 backdrop, vec4 source);
float screenBlend(float backdrop, float source);
void startPath(float rule);
vec4 blendHardLightFloats(vec4 backdrop, vec4 source);
vec4 SetSat(vec4 C, float s);
vec4 blendLinearBurnFloats(vec4 backdrop, vec4 source);
float hardLight(float backdrop, float source);
vec4 blendMaskFloats(vec4 backdrop, vec4 source);
void textureFill(mat3 tMat, float tile, vec2 pos, vec2 size);
vec2 interpolate(vec2 G1, vec2 G2, vec2 G3, vec2 G4, float t);
float lineDir(vec2 a, vec2 b);
bool overlap(vec2 minA, vec2 maxA, vec2 minB, vec2 maxB);
vec4 blendSaturationFloats(vec4 backdrop, vec4 source);
void bezier(vec2 A, vec2 B, vec2 C, vec2 D);
void M(float x, float y);
void endPath();
vec4 blendScreenFloats(vec4 backdrop, vec4 source);
vec4 blendOverlayFloats(vec4 backdrop, vec4 source);
vec4 blendDifferenceFloats(vec4 backdrop, vec4 source);
float Lum(vec4 C);
vec4 SetLum(vec4 C, float l);
vec4 blendColorBurnFloats(vec4 backdrop, vec4 source);
vec4 blendColorFloats(vec4 backdrop, vec4 source);
void line(vec2 a0, vec2 b0);


float Sat(
  vec4 C
) {
  float result;
  result = max(max(C.x, C.y), C.z) - min(min(C.x, C.y), C.z);
  return result;
}

void draw(
) {
  // Apply the winding rule.
  if (windingRule == 0) {
    fillMask = 0.0;
    int n = 4;
    for(int x = 0; x < n; x++) {
      for(int y = 0; y < n; y++) {
        if (! (float(zmod(crossCountMat[x][y], 2.0)) == 0.0)) {
          fillMask += 1.0;
        }
      }
    }
    fillMask = fillMask / float(n * n);
  } else {
    fillMask = clamp(abs(fillMask), 0.0, 1.0);
  }
}

float colorDodgeBlend(
  float backdrop,
  float source
) {
  float result;
  if (backdrop == 0.0) {
    result = 0.0;
    return result;
  } else if (source == 1.0) {
    result = 1.0;
    return result;
  } else {
    result = min(1.0, (backdrop) / (1.0 - source));
    return result;
  }
}

vec4 blendColorDodgeFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = colorDodgeBlend(backdrop.x, source.x);
  result.y = colorDodgeBlend(backdrop.y, source.y);
  result.z = colorDodgeBlend(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

float zmod(
  float a,
  float b
) {
  float result;
  result = a - b * floor(a / b);
  return result;
}

float colorBurnBlend(
  float backdrop,
  float source
) {
  float result;
  if (backdrop == 1.0) {
    result = 1.0;
    return result;
  } else if (source == 0.0) {
    result = 0.0;
    return result;
  } else {
    result = float(1.0 - float(min(1.0, (1.0 - backdrop) / (source))));
    return result;
  }
}

vec4 blendLinearDodgeFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = backdrop.x + source.x;
  result.y = backdrop.y + source.y;
  result.z = backdrop.z + source.z;
  result = alphaFix(backdrop, source, result);
  return result;
}

void C(
  float x1,
  float y1,
  float x2,
  float y2,
  float x,
  float y
) {
  // SVG cubic Curve command.
  bezier(vec2(x0, y0), vec2(x1, y1), vec2(x2, y2), vec2(x, y));
  x0 = x;
  y0 = y;
}

vec4 blendLightenFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = max(backdrop.x, source.x);
  result.y = max(backdrop.y, source.y);
  result.z = max(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendHueFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = SetLum(SetSat(source, Sat(backdrop)), Lum(backdrop));
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendSubtractMaskFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = backdrop;
  result.w = (backdrop.w) * (1.0 - source.w);
  return result;
}

float toLineSpace(
  vec2 at,
  vec2 to,
  vec2 point
) {
  float result;
  // Covert a point to be in the line space (used for gradients).
  vec2 d = to - at;
  float det = d.x * d.x + d.y * d.y;
  result = ((d.y) * (point.y - at.y) + (d.x) * (point.x - at.x)) / (det);
  return result;
}

void z(
) {
  // SVG style end of shape command.
  line(vec2(x0, y0), vec2(x1, y1));
}

void Q(
  float x1,
  float y1,
  float x,
  float y
) {
  // SVG Quadratic curve command.
  quadratic(vec2(x0, y0), vec2(x1, y1), vec2(x, y));
  x0 = x;
  y0 = y;
}

void quadratic(
  vec2 p0,
  vec2 p1,
  vec2 p2
) {
  // Turn a cubic curve into N lines.
  float devx = float(p0.x) - 2.0 * float(p1.x) + float(p2.x);
  float devy = float(p0.y) - 2.0 * float(p1.y) + float(p2.y);
  float devsq = devx * devx + devy * devy;
  if (devsq < 0.333) {
    line(p0, p2);
    return;
  }
  float tol = 3.0;
  float n = 1.0 + floor(sqrt(sqrt(tol * devsq)));
  vec2 p = p0;
  float nrecip = 1.0 / n;
  float t = 0.0;
  for(int i = 0; i < int(n); i++) {
    t += nrecip;
    vec2 pn = mix(mix(p0, p1, float(t)), mix(p1, p2, float(t)), float(t));
    line(p, pn);
    p = pn;
  }
}

float pixelCross(
  vec2 a0,
  vec2 b0
) {
  float result;
  // Turn a line into inc/dec/ignore of the crossCount.
  vec2 a = a0;
  vec2 b = b0;
  if (a.y == b.y) {
    result = 0.0;
    return result;
  }
  if ((min(a.y, b.y) <= 1.0) && (1.0 < max(a.y, b.y))) {
    float xIntersect = 0.0;
    if (! (b.x == a.x)) {
      float m = (b.y - a.y) / (b.x - a.x);
      float bb = a.y - m * a.x;
      xIntersect = (1.0 - bb) / (m);
    } else {
      xIntersect = a.x;
    }
    if (xIntersect < 1.0) {
      result = lineDir(a, b);
      return result;
    }
  }
  result = 0.0;
  return result;
}

vec4 blendOverwriteFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = source;
  return result;
}

void runCommands(
) {
  // Runs a little command interpreter.
  int i = 0;
  while(true) {
    float command = texelFetch(dataBuffer, i).x;
    switch(int(command)) {
    case 0:{
      return;
    }; break;
    case 1:{
      startPath(texelFetch(dataBuffer, i + 1).x);
      i += 1;
    }; break;
    case 2:{
      endPath();
    }; break;
    case 4:{
      solidFill(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x);
      i += 4;
    }; break;
    case 5:{
      float opacity = texelFetch(dataBuffer, i + 1).x;
      backdropColor = backdropColor * opacity;
      i += 1;
    }; break;
    case 6:{
      tMat[0][0] = texelFetch(dataBuffer, i + 1).x;
      tMat[0][1] = texelFetch(dataBuffer, i + 2).x;
      tMat[0][2] = 0.0;
      tMat[1][0] = texelFetch(dataBuffer, i + 3).x;
      tMat[1][1] = texelFetch(dataBuffer, i + 4).x;
      tMat[1][2] = 0.0;
      tMat[2][0] = texelFetch(dataBuffer, i + 5).x;
      tMat[2][1] = texelFetch(dataBuffer, i + 6).x;
      tMat[2][2] = 1.0;
      float tile = texelFetch(dataBuffer, i + 7).x;
      vec2 pos = vec2(0.0);
      pos.x = texelFetch(dataBuffer, i + 8).x;
      pos.y = texelFetch(dataBuffer, i + 9).x;
      vec2 size = vec2(0.0);
      size.x = texelFetch(dataBuffer, i + 10).x;
      size.y = texelFetch(dataBuffer, i + 11).x;
      textureFill(tMat, tile, pos, size);
      i += 11;
    }; break;
    case 7:{
      vec2 at = vec2(0.0);
      vec2 to = vec2(0.0);
      at.x = texelFetch(dataBuffer, i + 1).x;
      at.y = texelFetch(dataBuffer, i + 2).x;
      to.x = texelFetch(dataBuffer, i + 3).x;
      to.y = texelFetch(dataBuffer, i + 4).x;
      gradientLinear(at, to);
      i += 4;
    }; break;
    case 8:{
      vec2 at = vec2(0.0);
      vec2 to = vec2(0.0);
      at.x = texelFetch(dataBuffer, i + 1).x;
      at.y = texelFetch(dataBuffer, i + 2).x;
      to.x = texelFetch(dataBuffer, i + 3).x;
      to.y = texelFetch(dataBuffer, i + 4).x;
      gradientRadial(at, to);
      i += 4;
    }; break;
    case 9:{
      gradientStop(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x, texelFetch(dataBuffer, i + 5).x);
      i += 5;
    }; break;
    case 3:{
      mat[0][0] = texelFetch(dataBuffer, i + 1).x;
      mat[0][1] = texelFetch(dataBuffer, i + 2).x;
      mat[0][2] = 0.0;
      mat[1][0] = texelFetch(dataBuffer, i + 3).x;
      mat[1][1] = texelFetch(dataBuffer, i + 4).x;
      mat[1][2] = 0.0;
      mat[2][0] = texelFetch(dataBuffer, i + 5).x;
      mat[2][1] = texelFetch(dataBuffer, i + 6).x;
      mat[2][2] = 1.0;
      i += 6;
    }; break;
    case 10:{
      M(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x);
      i += 2;
    }; break;
    case 11:{
      L(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x);
      i += 2;
    }; break;
    case 12:{
      C(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x, texelFetch(dataBuffer, i + 5).x, texelFetch(dataBuffer, i + 6).x);
      i += 6;
    }; break;
    case 13:{
      Q(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x);
      i += 4;
    }; break;
    case 14:{
      z();
    }; break;
    case 15:{
      vec2 minP = vec2(0.0);
      vec2 maxP = vec2(0.0);
      minP.x = texelFetch(dataBuffer, i + 1).x;
      minP.y = texelFetch(dataBuffer, i + 2).x;
      maxP.x = texelFetch(dataBuffer, i + 3).x;
      maxP.y = texelFetch(dataBuffer, i + 4).x;
      int label = int(texelFetch(dataBuffer, i + 5).x);
      i += 5;
      mat3 matInv = inverse(mat);
      vec2 screenInvA = (matInv * vec3(screen + vec2(0.0, 0.0), 1.0)).xy;
      vec2 screenInvB = (matInv * vec3(screen + vec2(1.0, 0.0), 1.0)).xy;
      vec2 screenInvC = (matInv * vec3(screen + vec2(1.0, 0.0), 1.0)).xy;
      vec2 screenInvD = (matInv * vec3(screen + vec2(0.0, 1.0), 1.0)).xy;
      vec2 minS = vec2(0.0);
      vec2 maxS = vec2(0.0);
      minS.x = min(min(screenInvA.x, screenInvB.x), min(screenInvC.x, screenInvD.x));
      minS.y = min(min(screenInvA.y, screenInvB.y), min(screenInvC.y, screenInvD.y));
      maxS.x = max(max(screenInvA.x, screenInvB.x), max(screenInvC.x, screenInvD.x));
      maxS.y = max(max(screenInvA.y, screenInvB.y), max(screenInvC.y, screenInvD.y));
      if (! (overlap(minS, maxS, minP, maxP))) {
        i = label - 1;
      }
    }; break;
    case 16:{
      maskOn = true;
      maskStackTop += 1;
      maskStack[maskStackTop] = 0.0;
    }; break;
    case 17:{
      maskOn = false;
    }; break;
    case 18:{
      maskStackTop -= 1;
    }; break;
    case 19:{
      float index = texelFetch(dataBuffer, i + 1).x;
      if (0.0 < fillMask * mask) {
        topIndex = index;
      }
      i += 1;
    }; break;
    case 20:{
      layerBlur = texelFetch(dataBuffer, i + 1).x;
      i += 1;
    }; break;
    case 21:{
      shadowOn = true;
      shadowColor.x = texelFetch(dataBuffer, i + 1).x;
      shadowColor.y = texelFetch(dataBuffer, i + 2).x;
      shadowColor.z = texelFetch(dataBuffer, i + 3).x;
      shadowColor.w = texelFetch(dataBuffer, i + 4).x;
      shadowOffset.x = texelFetch(dataBuffer, i + 5).x;
      shadowOffset.y = texelFetch(dataBuffer, i + 6).x;
      shadowRadius = texelFetch(dataBuffer, i + 7).x;
      shadowSpread = texelFetch(dataBuffer, i + 8).x;
      i += 8;
    }; break;
    case 22:{
      blendMode = int(texelFetch(dataBuffer, i + 1).x);
      i += 1;
    }; break;
    default: {
      ;
    }; break;
    }
    i += 1;
  }
}

vec4 blendIntersectMaskFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = backdrop;
  result.w = backdrop.w * source.w;
  return result;
}

void ClipColor(
  inout vec4 C
) {
  float L = Lum(C);
  float n = min(min(C.x, C.y), C.z);
  float x = max(max(C.x, C.y), C.z);
  if (n < 0.0) {
    C = vec4(L) + ((C - vec4(L)) * (L)) / (L - n);
  }
  if (1.0 < x) {
    C = vec4(L) + ((C - vec4(L)) * (1.0 - L)) / (x - L);
  }
}

float pixelCover(
  vec2 a0,
  vec2 b0
) {
  float result;
  // Returns the amount of area a given segment sweeps to the right
  // in a [0,0 to 1,1] box.
  vec2 a = a0;
  vec2 b = b0;
  vec2 aI = vec2(0.0);
  vec2 bI = vec2(0.0);
  float area = 0.0;
  if (b.y < a.y) {
    vec2 tmp = a;
    a = b;
    b = tmp;
  }
  if (((b.y < 0.0) || (1.0 < a.y) || 1.0 <= a.x && 1.0 <= b.x) || (a.y == b.y)) {
    result = 0.0;
    return result;
  } else if (((a.x < 0.0) && (b.x < 0.0)) || (a.x == b.x)) {
    result = (1.0 - clamp(a.x, 0.0, 1.0)) * (min(b.y, 1.0) - max(a.y, 0.0));
    return result;
  } else {
    float mm = (b.y - a.y) / (b.x - a.x);
    float bb = a.y - mm * a.x;
    if (((0.0 <= a.x) && (a.x <= 1.0) && 0.0 <= a.y) && (a.y <= 1.0)) {
      aI = a;
    } else {
      aI = vec2((0.0 - bb) / (mm), 0.0);
      if (aI.x < 0.0) {
        float y = mm * 0.0 + bb;
        area += clamp(min(bb, 1.0) - max(a.y, 0.0), 0.0, 1.0);
        aI = vec2(0.0, clamp(y, 0.0, 1.0));
      } else if (1.0 < aI.x) {
        float y = mm * 1.0 + bb;
        aI = vec2(1.0, clamp(y, 0.0, 1.0));
      }
    }
    if (((0.0 <= b.x) && (b.x <= 1.0) && 0.0 <= b.y) && (b.y <= 1.0)) {
      bI = b;
    } else {
      bI = vec2((1.0 - bb) / (mm), 1.0);
      if (bI.x < 0.0) {
        float y = mm * 0.0 + bb;
        area += clamp(min(b.y, 1.0) - max(bb, 0.0), 0.0, 1.0);
        bI = vec2(0.0, clamp(y, 0.0, 1.0));
      } else if (1.0 < bI.x) {
        float y = mm * 1.0 + bb;
        bI = vec2(1.0, clamp(y, 0.0, 1.0));
      }
    }
  }
  area += ((1.0 - aI.x + 1.0 - bI.x) / (2.0)) * (bI.y - aI.y);
  result = area;
  return result;
}

vec4 blendDarkenFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = min(backdrop.x, source.x);
  result.y = min(backdrop.y, source.y);
  result.z = min(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendExcludeMaskFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = backdrop;
  result.w = abs(backdrop.w - source.w);
  return result;
}

vec4 alphaFix(
  vec4 backdrop,
  vec4 source,
  vec4 mixed
) {
  vec4 result;
  result.w = float(float(source.w) + (float(backdrop.w)) * (1.0 - float(source.w)));
  if (result.w == 0.0) {
    return result;
  }
  float t0 = (source.w) * (1.0 - backdrop.w);
  float t1 = source.w * backdrop.w;
  float t2 = (1.0 - source.w) * (backdrop.w);
  result.x = t0 * source.x + t1 * mixed.x + t2 * backdrop.x;
  result.y = t0 * source.y + t1 * mixed.y + t2 * backdrop.y;
  result.z = t0 * source.z + t1 * mixed.z + t2 * backdrop.z;
  result.x /= result.w;
  result.y /= result.w;
  result.z /= result.w;
  return result;
}

vec4 runPixel(
  vec2 xy
) {
  vec4 result;
  // Runs commands for a single pixel.
  screen = xy;
  backdropColor = vec4(0.0, 0.0, 0.0, 0.0);
  runCommands();
  result = backdropColor;
  return result;
}

vec4 blendSoftLightFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = softLight(backdrop.x, source.x);
  result.y = softLight(backdrop.y, source.y);
  result.z = softLight(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

void L(
  float x,
  float y
) {
  // SVG style Line command.
  line(vec2(x0, y0), vec2(x, y));
  x0 = x;
  y0 = y;
}

void finalColor(
  vec4 applyColor
) {
  if (maskOn) {
    maskStack[maskStackTop] += applyColor.w;
  } else {
    vec4 c = applyColor;
    c.w = c.w * maskStack[maskStackTop];
    switch(blendMode) {
    case 0:{
      backdropColor = blendNormalFloats(backdropColor, c);
    }; break;
    case 1:{
      backdropColor = blendDarkenFloats(backdropColor, c);
    }; break;
    case 2:{
      backdropColor = blendMultiplyFloats(backdropColor, c);
    }; break;
    case 3:{
      backdropColor = blendLinearBurnFloats(backdropColor, c);
    }; break;
    case 4:{
      backdropColor = blendColorBurnFloats(backdropColor, c);
    }; break;
    case 5:{
      backdropColor = blendLightenFloats(backdropColor, c);
    }; break;
    case 6:{
      backdropColor = blendScreenFloats(backdropColor, c);
    }; break;
    case 7:{
      backdropColor = blendLinearDodgeFloats(backdropColor, c);
    }; break;
    case 8:{
      backdropColor = blendColorDodgeFloats(backdropColor, c);
    }; break;
    case 9:{
      backdropColor = blendOverlayFloats(backdropColor, c);
    }; break;
    case 10:{
      backdropColor = blendSoftLightFloats(backdropColor, c);
    }; break;
    case 11:{
      backdropColor = blendHardLightFloats(backdropColor, c);
    }; break;
    case 12:{
      backdropColor = blendDifferenceFloats(backdropColor, c);
    }; break;
    case 13:{
      backdropColor = blendExclusionFloats(backdropColor, c);
    }; break;
    case 16:{
      backdropColor = blendColorFloats(backdropColor, c);
    }; break;
    case 17:{
      backdropColor = blendLuminosityFloats(backdropColor, c);
    }; break;
    case 14:{
      backdropColor = blendHueFloats(backdropColor, c);
    }; break;
    case 15:{
      backdropColor = blendSaturationFloats(backdropColor, c);
    }; break;
    case 18:{
      backdropColor = blendMaskFloats(backdropColor, c);
    }; break;
    case 20:{
      backdropColor = blendSubtractMaskFloats(backdropColor, c);
    }; break;
    case 21:{
      backdropColor = blendIntersectMaskFloats(backdropColor, c);
    }; break;
    case 22:{
      backdropColor = blendExcludeMaskFloats(backdropColor, c);
    }; break;
    case 19:{
      backdropColor = blendOverwriteFloats(backdropColor, c);
    }; break;
    default: {
      ;
    }; break;
    }
  }
}

vec4 blendMultiplyFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = backdrop.x * source.x;
  result.y = backdrop.y * source.y;
  result.z = backdrop.z * source.z;
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendLuminosityFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = SetLum(backdrop, Lum(source));
  result = alphaFix(backdrop, source, result);
  return result;
}

float normPdf(
  float x,
  float sigma
) {
  float result;
  // Normal Probability Density Function (used for shadow and blurs)
  result = float(0.39894 * exp(-0.5 * x * x / float(sigma * sigma)) / float(sigma));
  return result;
}

void solidFill(
  float r,
  float g,
  float b,
  float a
) {
  // Set the source color.
  if (0.0 < fillMask) {
    finalColor(vec4(r, g, b, a * fillMask));
  }
}

void gradientRadial(
  vec2 at0,
  vec2 to0
) {
  // Setup color for radial gradient.
  if (0.0 < fillMask) {
    vec2 at = (mat * vec3(at0, 1.0)).xy;
    vec2 to = (mat * vec3(to0, 1.0)).xy;
    float distance = length(at - to);
    gradientK = clamp(length(at - screen) / distance, 0.0, 1.0);
  }
}

float softLight(
  float backdrop,
  float source
) {
  float result;
  result = // Pegtop
(1.0 - 2.0 * source) * (backdrop) * backdrop + 2.0 * source * backdrop;
  return result;
}

void gradientLinear(
  vec2 at0,
  vec2 to0
) {
  // Setup color for linear gradient.
  if (0.0 < fillMask) {
    vec2 at = (mat * vec3(at0, 1.0)).xy;
    vec2 to = (mat * vec3(to0, 1.0)).xy;
    gradientK = clamp(toLineSpace(at, to, screen), 0.0, 1.0);
  }
}

vec4 blendExclusionFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = exclusionBlend(backdrop.x, source.x);
  result.y = exclusionBlend(backdrop.y, source.y);
  result.z = exclusionBlend(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

void gradientStop(
  float k,
  float r,
  float g,
  float b,
  float a
) {
  // Compute a gradient stop.
  if (0.0 < fillMask) {
    vec4 gradientColor = vec4(r, g, b, a);
    if ((prevGradientK < gradientK) && (gradientK <= k)) {
      float betweenColors = (gradientK - prevGradientK) / (k - prevGradientK);
      vec4 colorG = mix(prevGradientColor, gradientColor, betweenColors);
      colorG.w *= fillMask;
      finalColor(colorG);
    }
    prevGradientK = k;
    prevGradientColor = gradientColor;
  }
}

float exclusionBlend(
  float backdrop,
  float source
) {
  float result;
  result = backdrop + source - 2.0 * backdrop * source;
  return result;
}

vec4 blendNormalFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = source;
  result = alphaFix(backdrop, source, result);
  return result;
}

float screenBlend(
  float backdrop,
  float source
) {
  float result;
  result = 1.0 - (1.0 - backdrop) * (1.0 - source);
  return result;
}

void startPath(
  float rule
) {
  // Clear the status of things and start a new path.
  crossCountMat = mat4(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  fillMask = 0.0;
  windingRule = int(rule);
}

vec4 blendHardLightFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = hardLight(backdrop.x, source.x);
  result.y = hardLight(backdrop.y, source.y);
  result.z = hardLight(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 SetSat(
  vec4 C,
  float s
) {
  vec4 result;
  float satC = Sat(C);
  if (0.0 < satC) {
    result = (C - vec4(min(min(C.x, C.y), C.z))) * (s) / satC;
    return result;
  }
}

vec4 blendLinearBurnFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = backdrop.x + source.x - 1.0;
  result.y = backdrop.y + source.y - 1.0;
  result.z = backdrop.z + source.z - 1.0;
  result = alphaFix(backdrop, source, result);
  return result;
}

float hardLight(
  float backdrop,
  float source
) {
  float result;
  if (float(source) <= 0.5) {
    result = backdrop * 2.0 * source;
    return result;
  } else {
    result = screenBlend(backdrop, 2.0 * source - 1.0);
    return result;
  }
}

vec4 blendMaskFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = backdrop;
  result.w = min(backdrop.w, source.w);
  return result;
}

void textureFill(
  mat3 tMat,
  float tile,
  vec2 pos,
  vec2 size
) {
  // Set the source color.
  if (true || 0.0 < fillMask) {
    if (shadowOn) {
      shadowRadius = min(50.0, shadowRadius);
      int mSize = int(shadowRadius) * 2 + 1;
      int kSize = int(shadowRadius);
      float[101] kernel;
      float sigma = 1.9;
      for(int x = 0; x <= kSize; x++) {
        float v = normPdf(float(float(x)), float(sigma));
        kernel[kSize + x] = v;
        kernel[kSize - x] = v;
      }
      float zNormal = 0.0;
      for(int x = 0; x < mSize; x++) {
        for(int y = 0; y < mSize; y++) {
          zNormal = zNormal + float(kernel[x] * kernel[y]);
        }
      }
      float combinedShadow = 0.0;
      for(int x = - (int(shadowRadius)); x <= int(shadowRadius); x++) {
        for(int y = - (int(shadowRadius)); y <= int(shadowRadius); y++) {
          vec2 offset = vec2(float(x), float(y)) - shadowOffset;
          float kValue = kernel[kSize + x] * kernel[kSize + y];
          vec2 uv = (tMat * vec3(floor(screen) + vec2(0.5, 0.5) + offset, 1.0)).xy;
          if (((pos.x < uv.x) && (uv.x < pos.x + size.x) && pos.y < uv.y) && (uv.y < pos.y + size.y)) {
            float textureColor = texture(textureAtlasSampler, uv).w;
            combinedShadow += float(textureColor * kValue);
          }
        }
      }
      combinedShadow = combinedShadow / zNormal;
      vec4 combinedColor = shadowColor;
      combinedColor.w = float(combinedShadow);
      finalColor(combinedColor);
    }
    if (0.0 < layerBlur) {
      int mSize = int(layerBlur) * 2 + 1;
      int kSize = int(layerBlur);
      float[20] kernel;
      float sigma = 1.9;
      for(int x = 0; x <= kSize; x++) {
        float v = normPdf(float(float(x)), float(sigma));
        kernel[kSize + x] = v;
        kernel[kSize - x] = v;
      }
      float zNormal = 0.0;
      for(int x = 0; x < mSize; x++) {
        for(int y = 0; y < mSize; y++) {
          zNormal = zNormal + float(kernel[x] * kernel[y]);
        }
      }
      vec4 combinedColor = vec4(0.0);
      float colorAdj = 0.0;
      for(int x = - (int(layerBlur)); x <= int(layerBlur); x++) {
        for(int y = - (int(layerBlur)); y <= int(layerBlur); y++) {
          vec2 offset = vec2(float(x), float(y));
          float kValue = kernel[kSize + x] * kernel[kSize + y];
          vec2 uv = (tMat * vec3(floor(screen) + vec2(0.5, 0.5) + offset, 1.0)).xy;
          if (((pos.x < uv.x) && (uv.x < pos.x + size.x) && pos.y < uv.y) && (uv.y < pos.y + size.y)) {
            vec4 textureColor = texture(textureAtlasSampler, uv);
            combinedColor += textureColor * kValue;
            colorAdj += float(kValue);
          }
        }
      }
      if (! (colorAdj == 0.0)) {
        combinedColor.x = float(float(combinedColor.x) / colorAdj);
        combinedColor.y = float(float(combinedColor.y) / colorAdj);
        combinedColor.z = float(float(combinedColor.z) / colorAdj);
      }
      combinedColor.w = float(float(combinedColor.w) / zNormal);
      finalColor(combinedColor);
    } else {
      vec2 uv = (tMat * vec3(floor(screen) + vec2(0.5, 0.5), 1.0)).xy;
      if (tile == 0.0) {
        if (((pos.x < uv.x) && (uv.x < pos.x + size.x) && pos.y < uv.y) && (uv.y < pos.y + size.y)) {
          vec4 textureColor = texture(textureAtlasSampler, uv);
          textureColor.w *= fillMask;
          finalColor(textureColor);
        }
      } else {
        uv = mod(uv - pos, size) + pos;
        vec4 textureColor = texture(textureAtlasSampler, uv);
        textureColor.w *= fillMask;
        finalColor(textureColor);
      }
    }
  }
}

vec2 interpolate(
  vec2 G1,
  vec2 G2,
  vec2 G3,
  vec2 G4,
  float t
) {
  vec2 result;
  // Solve the cubic bezier interpolation with 4 points.
  vec2 A = G4 - G1 + (3.0) * (G2 - G3);
  vec2 B = (3.0) * (G1 - 2.0 * G2 + G3);
  vec2 C = (3.0) * (G2 - G1);
  vec2 D = G1;
  result = (t) * ((t) * (t * A + B) + C) + D;
  return result;
}

float lineDir(
  vec2 a,
  vec2 b
) {
  float result;
  // Return the direction of the line (up or down).
  if (0.0 < a.y - b.y) {
    result = 1.0;
    return result;
  } else {
    result = -1.0;
    return result;
  }
}

bool overlap(
  vec2 minA,
  vec2 maxA,
  vec2 minB,
  vec2 maxB
) {
  bool result;
  // Test overlap: rect vs rect.
  result = ((minB.x <= maxA.x) && (minA.x <= maxB.x) && minB.y <= maxA.y) && (minA.y <= maxB.y);
  return result;
}

vec4 blendSaturationFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = SetLum(SetSat(backdrop, Sat(source)), Lum(backdrop));
  result = alphaFix(backdrop, source, result);
  return result;
}

void bezier(
  vec2 A,
  vec2 B,
  vec2 C,
  vec2 D
) {
  // Turn a cubic curve into N lines.
  vec2 p = A;
  float dist = length(A - B) + length(B - C) + length(C - D);
  int discretization = clamp(int(float(dist) * 0.5), 1, 20);
  for(int t = 1; t <= discretization; t++) {
    vec2 q = interpolate(A, B, C, D, float(t) / float(discretization));
    line(p, q);
    p = q;
  }
}

void M(
  float x,
  float y
) {
  // SVG style Move command.
  x1 = x;
  x0 = x;
  y1 = y;
  y0 = y;
}

void endPath(
) {
  // SVG style end path command.
  draw();
}

vec4 blendScreenFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = screenBlend(backdrop.x, source.x);
  result.y = screenBlend(backdrop.y, source.y);
  result.z = screenBlend(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendOverlayFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = hardLight(source.x, backdrop.x);
  result.y = hardLight(source.y, backdrop.y);
  result.z = hardLight(source.z, backdrop.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendDifferenceFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = abs(backdrop.x - source.x);
  result.y = abs(backdrop.y - source.y);
  result.z = abs(backdrop.z - source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

float Lum(
  vec4 C
) {
  float result;
  result = float(0.3 * float(C.x) + 0.59 * float(C.y) + 0.11 * float(C.z));
  return result;
}

vec4 SetLum(
  vec4 C,
  float l
) {
  vec4 result;
  float d = l - Lum(C);
  result.x = C.x + d;
  result.y = C.y + d;
  result.z = C.z + d;
  ClipColor(result);
  return result;
}

vec4 blendColorBurnFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result.x = colorBurnBlend(backdrop.x, source.x);
  result.y = colorBurnBlend(backdrop.y, source.y);
  result.z = colorBurnBlend(backdrop.z, source.z);
  result = alphaFix(backdrop, source, result);
  return result;
}

vec4 blendColorFloats(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  result = SetLum(source, Lum(backdrop));
  result = alphaFix(backdrop, source, result);
  return result;
}

void line(
  vec2 a0,
  vec2 b0
) {
  // Draw the lines based on windingRule.
  vec2 a1 = (mat * vec3(a0, 1.0)).xy - screen;
  vec2 b1 = (mat * vec3(b0, 1.0)).xy - screen;
  if (windingRule == 0) {
    a1 += vec2(0.125, 0.125);
    b1 += vec2(0.125, 0.125);
    crossCountMat[0][0] = crossCountMat[0][0] + pixelCross(a1 + vec2(0.0, 0.0) / 4.0, b1 + vec2(0.0, 0.0) / 4.0);
    crossCountMat[0][1] = crossCountMat[0][1] + pixelCross(a1 + vec2(0.0, 1.0) / 4.0, b1 + vec2(0.0, 1.0) / 4.0);
    crossCountMat[0][2] = crossCountMat[0][2] + pixelCross(a1 + vec2(0.0, 2.0) / 4.0, b1 + vec2(0.0, 2.0) / 4.0);
    crossCountMat[0][3] = crossCountMat[0][3] + pixelCross(a1 + vec2(0.0, 3.0) / 4.0, b1 + vec2(0.0, 3.0) / 4.0);
    crossCountMat[1][0] = crossCountMat[1][0] + pixelCross(a1 + vec2(1.0, 0.0) / 4.0, b1 + vec2(1.0, 0.0) / 4.0);
    crossCountMat[1][1] = crossCountMat[1][1] + pixelCross(a1 + vec2(1.0, 1.0) / 4.0, b1 + vec2(1.0, 1.0) / 4.0);
    crossCountMat[1][2] = crossCountMat[1][2] + pixelCross(a1 + vec2(1.0, 2.0) / 4.0, b1 + vec2(1.0, 2.0) / 4.0);
    crossCountMat[1][3] = crossCountMat[1][3] + pixelCross(a1 + vec2(1.0, 3.0) / 4.0, b1 + vec2(1.0, 3.0) / 4.0);
    crossCountMat[2][0] = crossCountMat[2][0] + pixelCross(a1 + vec2(2.0, 0.0) / 4.0, b1 + vec2(2.0, 0.0) / 4.0);
    crossCountMat[2][1] = crossCountMat[2][1] + pixelCross(a1 + vec2(2.0, 1.0) / 4.0, b1 + vec2(2.0, 1.0) / 4.0);
    crossCountMat[2][2] = crossCountMat[2][2] + pixelCross(a1 + vec2(2.0, 2.0) / 4.0, b1 + vec2(2.0, 2.0) / 4.0);
    crossCountMat[2][3] = crossCountMat[2][3] + pixelCross(a1 + vec2(2.0, 3.0) / 4.0, b1 + vec2(2.0, 3.0) / 4.0);
    crossCountMat[3][0] = crossCountMat[3][0] + pixelCross(a1 + vec2(3.0, 0.0) / 4.0, b1 + vec2(3.0, 0.0) / 4.0);
    crossCountMat[3][1] = crossCountMat[3][1] + pixelCross(a1 + vec2(3.0, 1.0) / 4.0, b1 + vec2(3.0, 1.0) / 4.0);
    crossCountMat[3][2] = crossCountMat[3][2] + pixelCross(a1 + vec2(3.0, 2.0) / 4.0, b1 + vec2(3.0, 2.0) / 4.0);
    crossCountMat[3][3] = crossCountMat[3][3] + pixelCross(a1 + vec2(3.0, 3.0) / 4.0, b1 + vec2(3.0, 3.0) / 4.0);
  } else {
    float area = pixelCover(a1, b1);
    fillMask += area * lineDir(a1, b1);
  }
}
layout(origin_upper_left) in vec4 gl_FragCoord;
out vec4 fragColor;

void main() {
  // Main entry point to this huge shader.
  maskOn = false;
  maskStackTop = 0;
  maskStack[maskStackTop] = 1.0;
  x0 = 0.0;
  y0 = 0.0;
  x1 = 0.0;
  y1 = 0.0;
  topIndex = 0.0;
  crossCountMat = mat4(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  mat = mat3(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  gradientK = 0.0;
  prevGradientK = 0.0;
  prevGradientColor = vec4(0.0, 0.0, 0.0, 0.0);
  layerBlur = 0.0;
  shadowOn = false;
  shadowColor = vec4(0.0, 0.0, 0.0, 0.0);
  shadowOffset = vec2(0.0, 0.0);
  shadowRadius = 0.0;
  shadowSpread = 0.0;
  blendMode = 0;
  float bias = 0.0001;
  vec2 offset = vec2(float(bias - 0.5), float(bias - 0.5));
  fragColor = runPixel(gl_FragCoord.xy + offset);
}
