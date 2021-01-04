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
float fillMask = 0.0;
float mask = 1.0;
float topIndex;
mat3 mat;
float prevGradientK;
float layerBlur;
mat4 crossCountMat;
float x0;
vec4 backdropColor;

void gradientRadial(vec2 at0, vec2 to0);
void draw();
void solidFill(float r, float g, float b, float a);
float zmod(float a, float b);
void C(float x1, float y1, float x2, float y2, float x, float y);
void gradientLinear(vec2 at0, vec2 to0);
float toLineSpace(vec2 at, vec2 to, vec2 point);
void gradientStop(float k, float r, float g, float b, float a);
void z();
float normpdf(float x, float sigma);
vec4 blendNormalFloats(vec4 backdrop, vec4 source);
void quadratic(vec2 p0, vec2 p1, vec2 p2);
void startPath(float rule);
float pixelCross(vec2 a0, vec2 b0);
void Q(float x1, float y1, float x, float y);
bool overlap(vec2 minA, vec2 maxA, vec2 minB, vec2 maxB);
void textureFill(mat3 tMat, float tile, vec2 pos, vec2 size);
void runCommands();
vec2 interpolate(vec2 G1, vec2 G2, vec2 G3, vec2 G4, float t);
float lineDir(vec2 a, vec2 b);
void bezier(vec2 A, vec2 B, vec2 C, vec2 D);
void M(float x, float y);
float pixelCover(vec2 a0, vec2 b0);
void endPath();
vec4 alphaFix(vec4 backdrop, vec4 source, vec4 mixed);
void line(vec2 a0, vec2 b0);
vec4 runPixel(vec2 xy);
void L(float x, float y);


void gradientRadial(
  vec2 at0,
  vec2 to0
) {
  if (float(0) < fillMask * mask) {
    vec2 at = (mat * vec3(at0, float(1))).xy;
    vec2 to = (mat * vec3(to0, float(1))).xy;
    float distance = length(at - to);
    gradientK = clamp(length(at - screen) / distance, float(0), float(1));
  }
}

void draw(
) {
  // Apply the winding rule.
  if (windingRule == 0) {
    fillMask = float(0);
    int n = 4;
    for(int x = 0; x < n; x++) {
      for(int y = 0; y < n; y++) {
        if (! (float(zmod(crossCountMat[x][y], float(2.0))) == 0.0)) {
          fillMask += float(1);
        }
      }
    }
    fillMask = fillMask / float(n * n);
  } else {
    fillMask = clamp(abs(fillMask), float(0), float(1));
  }
}

void solidFill(
  float r,
  float g,
  float b,
  float a
) {
  // Set the source color.
  if (float(0) < fillMask * mask) {
    backdropColor = blendNormalFloats(backdropColor, vec4(r, g, b, a * fillMask * mask));
  }
}

float zmod(
  float a,
  float b
) {
  return a - b * floor(a / b);
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

void gradientLinear(
  vec2 at0,
  vec2 to0
) {
  if (float(0) < fillMask) {
    vec2 at = (mat * vec3(at0, float(1))).xy;
    vec2 to = (mat * vec3(to0, float(1))).xy;
    gradientK = clamp(toLineSpace(at, to, screen), float(0), float(1));
  }
}

float toLineSpace(
  vec2 at,
  vec2 to,
  vec2 point
) {
  vec2 d = to - at;
  float det = d.x * d.x + d.y * d.y;
  return ((d.y) * (point.y - at.y) + (d.x) * (point.x - at.x)) / (det);
}

void gradientStop(
  float k,
  float r,
  float g,
  float b,
  float a
) {
  if (float(0) < fillMask * mask) {
    vec4 gradientColor = vec4(r, g, b, a);
    if ((prevGradientK < gradientK) && (gradientK <= k)) {
      float betweenColors = (gradientK - prevGradientK) / (k - prevGradientK);
      vec4 colorG = mix(prevGradientColor, gradientColor, betweenColors);
      colorG.w *= fillMask * mask;
      backdropColor = blendNormalFloats(backdropColor, colorG);
    }
    prevGradientK = k;
    prevGradientColor = gradientColor;
  }
}

void z(
) {
  // SVG style end of shape command.
  line(vec2(x0, y0), vec2(x1, y1));
}

float normpdf(
  float x,
  float sigma
) {
  return float(0.39894 * exp(-0.5 * x * x / float(sigma * sigma)) / float(sigma));
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
  // Turn a cubic curve into N lines.
  float devx = float(p0.x) - 2.0 * float(p1.x) + float(p2.x);
  float devy = float(p0.y) - 2.0 * float(p1.y) + float(p2.y);
  float devsq = devx * devx + devy * devy;
  if (devsq < 0.333) {
    line(p0, p2);
    return ;
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

void startPath(
  float rule
) {
  // Clear the status of things and start a new path.
  crossCountMat = mat4(float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0));
  fillMask = float(0);
  windingRule = int(rule);
}

float pixelCross(
  vec2 a0,
  vec2 b0
) {
  // Turn a line into inc/dec/ignore of the crossCount.
  vec2 a = a0;
  vec2 b = b0;
  if (a.y == b.y) {
    return float(0.0);
  }
  if ((min(a.y, b.y) <= float(1)) && (float(1) < max(a.y, b.y))) {
    float xIntersect = 0.0;
    if (! (b.x == a.x)) {
      float m = (b.y - a.y) / (b.x - a.x);
      float bb = a.y - m * a.x;
      xIntersect = (float(1) - bb) / (m);
    } else {
      xIntersect = a.x;
    }
    if (xIntersect < float(1)) {
      return lineDir(a, b);
    }
  }
  return float(0.0);
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

bool overlap(
  vec2 minA,
  vec2 maxA,
  vec2 minB,
  vec2 maxB
) {
  // Test overlap: rect vs rect.
  return ((minB.x <= maxA.x) && (minA.x <= maxB.x) && minB.y <= maxA.y) && (minA.y <= maxB.y);
}

void textureFill(
  mat3 tMat,
  float tile,
  vec2 pos,
  vec2 size
) {
  // Set the source color.
  if (true || float(0) < fillMask * mask) {
    if (float(0) < layerBlur) {
      int mSize = int(layerBlur) * 2 + 1;
      int kSize = int(layerBlur);
      float[20] kernel;
      float sigma = 1.9;
      for(int x = 0; x <= kSize; x++) {
        float v = normpdf(float(float(x)), float(sigma));
        kernel[(kSize + x)] = v;
        kernel[(kSize - x)] = v;
      }

      float zNormal = 0.0;
      for(int x = 0; x < mSize; x++) {
        for(int y = 0; y < mSize; y++) {
          zNormal = zNormal + float(kernel[(x)] * kernel[(y)]);
        }
      }

      vec4 combinedColor = vec4(float(0));
      float colorAdj = 0.0;
      for(int x = - (int(layerBlur)); x <= int(layerBlur); x++) {
        for(int y = - (int(layerBlur)); y <= int(layerBlur); y++) {
          vec2 offset = vec2(float(x), float(y));
          float kValue = kernel[(kSize + x)] * kernel[(kSize + y)];
          vec2 uv = (tMat * vec3(floor(screen) + vec2(float(0.5), float(0.5)) + offset, float(1))).xy;

          if (((pos.x < uv.x) && (uv.x < pos.x + size.x) && pos.y < uv.y) && (uv.y < pos.y + size.y)) {
            vec4 textureColor = texture(textureAtlasSampler, uv);

            combinedColor += textureColor * kValue;
            colorAdj += float(kValue);
          }
        }
      }
      if (! (colorAdj == float(0))) {
        combinedColor.x = float(float(combinedColor.x) / colorAdj);
        combinedColor.y = float(float(combinedColor.y) / colorAdj);
        combinedColor.z = float(float(combinedColor.z) / colorAdj);
      }
      combinedColor.w = float(float(combinedColor.w) / zNormal);

      backdropColor = blendNormalFloats(backdropColor, combinedColor);
    } else {
      vec2 uv = (tMat * vec3(floor(screen) + vec2(float(0.5), float(0.5)), float(1))).xy;
      if (tile == float(0)) {
        if (((pos.x < uv.x) && (uv.x < pos.x + size.x) && pos.y < uv.y) && (uv.y < pos.y + size.y)) {
          vec4 textureColor = texture(textureAtlasSampler, uv);
          textureColor.w *= fillMask * mask;
          backdropColor = blendNormalFloats(backdropColor, textureColor);
        }
      } else {
        uv = mod(uv - pos, size) + pos;
        vec4 textureColor = texture(textureAtlasSampler, uv);
        textureColor.w *= fillMask * mask;
        backdropColor = blendNormalFloats(backdropColor, textureColor);
      }
    }
  }
}

void runCommands(
) {
  // Runs a little command interpreter.
  int i = 0;
  while(true) {
    float command = texelFetch(dataBuffer, i).x;
    if (command == 0.0) {
      break;
    } else if (command == 1.0) {
      startPath(texelFetch(dataBuffer, i + 1).x);
      i += 1;
    } else if (command == 2.0) {
      endPath();
    } else if (command == 4.0) {
      solidFill(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x);
      i += 4;
    } else if (command == 5.0) {
      float opacity = texelFetch(dataBuffer, i + 1).x;
      backdropColor = backdropColor * opacity;
      i += 1;
    } else if (command == 6.0) {
      tMat[0][0] = texelFetch(dataBuffer, i + 1).x;
      tMat[0][1] = texelFetch(dataBuffer, i + 2).x;
      tMat[0][2] = float(0);
      tMat[1][0] = texelFetch(dataBuffer, i + 3).x;
      tMat[1][1] = texelFetch(dataBuffer, i + 4).x;
      tMat[1][2] = float(0);
      tMat[2][0] = texelFetch(dataBuffer, i + 5).x;
      tMat[2][1] = texelFetch(dataBuffer, i + 6).x;
      tMat[2][2] = float(1);
      float tile = texelFetch(dataBuffer, i + 7).x;
      vec2 pos = vec2(0.0);
      pos.x = texelFetch(dataBuffer, i + 8).x;
      pos.y = texelFetch(dataBuffer, i + 9).x;
      vec2 size = vec2(0.0);
      size.x = texelFetch(dataBuffer, i + 10).x;
      size.y = texelFetch(dataBuffer, i + 11).x;
      textureFill(tMat, tile, pos, size);
      i += 11;
    } else if (command == 7.0) {
      vec2 at = vec2(0.0);
      vec2 to = vec2(0.0);
      at.x = texelFetch(dataBuffer, i + 1).x;
      at.y = texelFetch(dataBuffer, i + 2).x;
      to.x = texelFetch(dataBuffer, i + 3).x;
      to.y = texelFetch(dataBuffer, i + 4).x;
      gradientLinear(at, to);
      i += 4;
    } else if (command == 8.0) {
      vec2 at = vec2(0.0);
      vec2 to = vec2(0.0);
      at.x = texelFetch(dataBuffer, i + 1).x;
      at.y = texelFetch(dataBuffer, i + 2).x;
      to.x = texelFetch(dataBuffer, i + 3).x;
      to.y = texelFetch(dataBuffer, i + 4).x;
      gradientRadial(at, to);
      i += 4;
    } else if (command == 9.0) {
      gradientStop(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x, texelFetch(dataBuffer, i + 5).x);
      i += 5;
    } else if (command == 3.0) {
      mat[0][0] = texelFetch(dataBuffer, i + 1).x;
      mat[0][1] = texelFetch(dataBuffer, i + 2).x;
      mat[0][2] = float(0);
      mat[1][0] = texelFetch(dataBuffer, i + 3).x;
      mat[1][1] = texelFetch(dataBuffer, i + 4).x;
      mat[1][2] = float(0);
      mat[2][0] = texelFetch(dataBuffer, i + 5).x;
      mat[2][1] = texelFetch(dataBuffer, i + 6).x;
      mat[2][2] = float(1);
      i += 6;
    } else if (command == 10.0) {
      M(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x);
      i += 2;
    } else if (command == 11.0) {
      L(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x);
      i += 2;
    } else if (command == 12.0) {
      C(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x, texelFetch(dataBuffer, i + 5).x, texelFetch(dataBuffer, i + 6).x);
      i += 6;
    } else if (command == 13.0) {
      Q(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x, texelFetch(dataBuffer, i + 3).x, texelFetch(dataBuffer, i + 4).x);
      i += 4;
    } else if (command == 14.0) {
      z();
    } else if (command == 15.0) {
      vec2 minP = vec2(0.0);
      vec2 maxP = vec2(0.0);
      minP.x = texelFetch(dataBuffer, i + 1).x;
      minP.y = texelFetch(dataBuffer, i + 2).x;
      maxP.x = texelFetch(dataBuffer, i + 3).x;
      maxP.y = texelFetch(dataBuffer, i + 4).x;
      int label = int(texelFetch(dataBuffer, i + 5).x);
      i += 5;
      mat3 matInv = inverse(mat);
      vec2 screenInvA = (matInv * vec3(screen + vec2(float(0), float(0)), float(1))).xy;
      vec2 screenInvB = (matInv * vec3(screen + vec2(float(1), float(0)), float(1))).xy;
      vec2 screenInvC = (matInv * vec3(screen + vec2(float(1), float(0)), float(1))).xy;
      vec2 screenInvD = (matInv * vec3(screen + vec2(float(0), float(1)), float(1))).xy;
      vec2 minS = vec2(0.0);
      vec2 maxS = vec2(0.0);
      minS.x = min(min(screenInvA.x, screenInvB.x), min(screenInvC.x, screenInvD.x));
      minS.y = min(min(screenInvA.y, screenInvB.y), min(screenInvC.y, screenInvD.y));
      maxS.x = max(max(screenInvA.x, screenInvB.x), max(screenInvC.x, screenInvD.x));
      maxS.y = max(max(screenInvA.y, screenInvB.y), max(screenInvC.y, screenInvD.y));
      if (! (overlap(minS, maxS, minP, maxP))) {
        i = label - 1;
      }
    } else if (command == 16.0) {
      mask = fillMask;
    } else if (command == 17.0) {
      mask = float(1.0);
    } else if (command == 18.0) {
      float index = texelFetch(dataBuffer, i + 1).x;
      if (float(0) < fillMask * mask) {
        topIndex = index;
      }
      i += 1;
    } else if (command == 19.0) {
      layerBlur = texelFetch(dataBuffer, i + 1).x;
      i += 1;
    }
    i += 1;
  }
}

vec2 interpolate(
  vec2 G1,
  vec2 G2,
  vec2 G3,
  vec2 G4,
  float t
) {
  // Solve the cubic bezier interpolation with 4 points.
  vec2 A = G4 - G1 + (float(3)) * (G2 - G3);
  vec2 B = (float(3)) * (G1 - float(2) * G2 + G3);
  vec2 C = (float(3)) * (G2 - G1);
  vec2 D = G1;
  return (t) * ((t) * (t * A + B) + C) + D;
}

float lineDir(
  vec2 a,
  vec2 b
) {
  if (float(0) < a.y - b.y) {
    return float(1);
  } else {
    return float(-1);
  }
}

void bezier(
  vec2 A,
  vec2 B,
  vec2 C,
  vec2 D
) {
  // Turn a cubic curve into N lines.
  vec2 p = A;
  int discretization = 20;
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

float pixelCover(
  vec2 a0,
  vec2 b0
) {
  // Returns the amount of area a given segment sweeps to the right
  // in a [0,0 to 1,1] box.
  vec2 a = a0;
  vec2 b = b0;
  vec2 aI = vec2(0.0);
  vec2 bI = vec2(0.0);
  float area = float(0.0);
  if (b.y < a.y) {
    vec2 tmp = a;
    a = b;
    b = tmp;
  }
  if (((b.y < float(0)) || (float(1) < a.y) || float(1) <= a.x && float(1) <= b.x) || (a.y == b.y)) {
    return float(0);
  } else if (((a.x < float(0)) && (b.x < float(0))) || (a.x == b.x)) {
    return (float(1) - clamp(a.x, float(0), float(1))) * (min(b.y, float(1)) - max(a.y, float(0)));
  } else {
    float mm = (b.y - a.y) / (b.x - a.x);
    float bb = a.y - mm * a.x;
    if (((float(0) <= a.x) && (a.x <= float(1)) && float(0) <= a.y) && (a.y <= float(1))) {
      aI = a;
    } else {
      aI = vec2((float(0) - bb) / (mm), float(0));
      if (aI.x < float(0)) {
        float y = mm * float(0) + bb;
        area += clamp(min(bb, float(1)) - max(a.y, float(0)), float(0), float(1));
        aI = vec2(float(0), clamp(y, float(0), float(1)));
      } else if (float(1) < aI.x) {
        float y = mm * float(1) + bb;
        aI = vec2(float(1), clamp(y, float(0), float(1)));
      }
    }
    if (((float(0) <= b.x) && (b.x <= float(1)) && float(0) <= b.y) && (b.y <= float(1))) {
      bI = b;
    } else {
      bI = vec2((float(1) - bb) / (mm), float(1));
      if (bI.x < float(0)) {
        float y = mm * float(0) + bb;
        area += clamp(min(b.y, float(1)) - max(bb, float(0)), float(0), float(1));
        bI = vec2(float(0), clamp(y, float(0), float(1)));
      } else if (float(1) < bI.x) {
        float y = mm * float(1) + bb;
        bI = vec2(float(1), clamp(y, float(0), float(1)));
      }
    }
  }
  area += ((float(1) - aI.x + float(1) - bI.x) / (float(2))) * (bI.y - aI.y);
  return area;
}

void endPath(
) {
  // SVG style end path command.
  draw();
}

vec4 alphaFix(
  vec4 backdrop,
  vec4 source,
  vec4 mixed
) {
  vec4 res = vec4(0.0);
  res.w = float(float(source.w) + (float(backdrop.w)) * (1.0 - float(source.w)));
  if (float(res.w) == 0.0) {
    return res;
  }
  float t0 = (float(source.w)) * (1.0 - float(backdrop.w));
  float t1 = source.w * backdrop.w;
  float t2 = (1.0 - float(source.w)) * (float(backdrop.w));
  res.x = float(t0 * float(source.x) + float(t1 * mixed.x) + t2 * float(backdrop.x));
  res.y = float(t0 * float(source.y) + float(t1 * mixed.y) + t2 * float(backdrop.y));
  res.z = float(t0 * float(source.z) + float(t1 * mixed.z) + t2 * float(backdrop.z));
  res.x /= res.w;
  res.y /= res.w;
  res.z /= res.w;
  return res;
}

void line(
  vec2 a0,
  vec2 b0
) {
  // Draw the lines based on windingRule.
  vec2 a1 = (mat * vec3(a0, float(1))).xy - screen;
  vec2 b1 = (mat * vec3(b0, float(1))).xy - screen;
  if (windingRule == 0) {
    a1 += vec2(float(0.125), float(0.125));
    b1 += vec2(float(0.125), float(0.125));
    crossCountMat[0][0] = crossCountMat[0][0] + pixelCross(a1 + vec2(float(0), float(0)) / float(4), b1 + vec2(float(0), float(0)) / float(4));
    crossCountMat[0][1] = crossCountMat[0][1] + pixelCross(a1 + vec2(float(0), float(1)) / float(4), b1 + vec2(float(0), float(1)) / float(4));
    crossCountMat[0][2] = crossCountMat[0][2] + pixelCross(a1 + vec2(float(0), float(2)) / float(4), b1 + vec2(float(0), float(2)) / float(4));
    crossCountMat[0][3] = crossCountMat[0][3] + pixelCross(a1 + vec2(float(0), float(3)) / float(4), b1 + vec2(float(0), float(3)) / float(4));
    crossCountMat[1][0] = crossCountMat[1][0] + pixelCross(a1 + vec2(float(1), float(0)) / float(4), b1 + vec2(float(1), float(0)) / float(4));
    crossCountMat[1][1] = crossCountMat[1][1] + pixelCross(a1 + vec2(float(1), float(1)) / float(4), b1 + vec2(float(1), float(1)) / float(4));
    crossCountMat[1][2] = crossCountMat[1][2] + pixelCross(a1 + vec2(float(1), float(2)) / float(4), b1 + vec2(float(1), float(2)) / float(4));
    crossCountMat[1][3] = crossCountMat[1][3] + pixelCross(a1 + vec2(float(1), float(3)) / float(4), b1 + vec2(float(1), float(3)) / float(4));
    crossCountMat[2][0] = crossCountMat[2][0] + pixelCross(a1 + vec2(float(2), float(0)) / float(4), b1 + vec2(float(2), float(0)) / float(4));
    crossCountMat[2][1] = crossCountMat[2][1] + pixelCross(a1 + vec2(float(2), float(1)) / float(4), b1 + vec2(float(2), float(1)) / float(4));
    crossCountMat[2][2] = crossCountMat[2][2] + pixelCross(a1 + vec2(float(2), float(2)) / float(4), b1 + vec2(float(2), float(2)) / float(4));
    crossCountMat[2][3] = crossCountMat[2][3] + pixelCross(a1 + vec2(float(2), float(3)) / float(4), b1 + vec2(float(2), float(3)) / float(4));
    crossCountMat[3][0] = crossCountMat[3][0] + pixelCross(a1 + vec2(float(3), float(0)) / float(4), b1 + vec2(float(3), float(0)) / float(4));
    crossCountMat[3][1] = crossCountMat[3][1] + pixelCross(a1 + vec2(float(3), float(1)) / float(4), b1 + vec2(float(3), float(1)) / float(4));
    crossCountMat[3][2] = crossCountMat[3][2] + pixelCross(a1 + vec2(float(3), float(2)) / float(4), b1 + vec2(float(3), float(2)) / float(4));
    crossCountMat[3][3] = crossCountMat[3][3] + pixelCross(a1 + vec2(float(3), float(3)) / float(4), b1 + vec2(float(3), float(3)) / float(4));
  } else {
    float area = pixelCover(a1, b1);
    fillMask += area * lineDir(a1, b1);
  }
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
  // SVG style Line command.
  line(vec2(x0, y0), vec2(x, y));
  x0 = x;
  y0 = y;
}
layout(origin_upper_left) in vec4 gl_FragCoord;
out vec4 fragColor;

void main() {
  // Main entry point to this huge shader.
  x0 = float(0);
  y0 = float(0);
  x1 = float(0);
  y1 = float(0);
  topIndex = float(0);
  crossCountMat = mat4(float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0));
  mat = mat3(float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0), float(0));
  gradientK = float(0);
  prevGradientK = float(0);
  prevGradientColor = vec4(float(0), float(0), float(0), float(0));
  layerBlur = float(0.0);
  float bias = 0.0001;
  vec2 offset = vec2(float(bias - 0.5), float(bias - 0.5));
  fragColor = runPixel(gl_FragCoord.xy + offset);
}
