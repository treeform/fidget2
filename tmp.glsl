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
int colorStackTop;
float[99] maskStack;
float y0;
vec4 shadowColor;
float y1;
vec4 prevGradientColor;
int boolMode;
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
vec4[24] colorStack;

void finalColor(vec4 applyColor);
void gradientRadial(vec2 at0, vec2 to0);
void draw();
float normPdf(float x, float sigma);
void solidFill(float r, float g, float b, float a);
float zmod(float a, float b);
void gradientLinear(vec2 at0, vec2 to0);
float toLineSpace(vec2 at, vec2 to, vec2 point);
void gradientStop(float k, float r, float g, float b, float a);
void startPath(float rule);
float pixelCross(vec2 a0, vec2 b0);
void runCommands();
void textureFill(mat3 tMat, float tile, vec2 pos, vec2 size);
float lineDir(vec2 a, vec2 b);
void M(float x, float y);
float pixelCover(vec2 a0, vec2 b0);
float blendAlphaPremul(float backdrop, float source);
void endPath();
void line(vec2 a0, vec2 b0);
vec4 blendNormalPremul(vec4 backdrop, vec4 source);
vec4 runPixel(vec2 xy);
void L(float x, float y);


void finalColor(
  vec4 applyColor
) {
  colorStack[colorStackTop] = applyColor;
  colorStackTop += 1;
}

void gradientRadial(
  vec2 at0,
  vec2 to0
) {
  // Setup color for radial gradient.
  if (0.0 < fillMask) {
    vec2 at = (vec3(at0, 1.0)).xy;
    vec2 to = (vec3(to0, 1.0)).xy;
    float distance = length(at - to);
    gradientK = clamp(length(at - screen) / distance, 0.0, 1.0);
  }
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
    finalColor(vec4(r, g, b, a) * fillMask);
  }
}

float zmod(
  float a,
  float b
) {
  float result;
  result = a - b * floor(a / b);
  return result;
}

void gradientLinear(
  vec2 at0,
  vec2 to0
) {
  // Setup color for linear gradient.
  if (0.0 < fillMask) {
    vec2 at = (vec3(at0, 1.0)).xy;
    vec2 to = (vec3(to0, 1.0)).xy;
    gradientK = clamp(toLineSpace(at, to, screen), 0.0, 1.0);
  }
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

void startPath(
  float rule
) {
  // Clear the status of things and start a new path.
  crossCountMat = mat4(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  fillMask = 0.0;
  windingRule = int(rule);
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

void runCommands(
) {
  // Runs a little command interpreter.
  int i = 0;
  while(true) {
    if ((0 < colorStackTop) && (float(colorStack[colorStackTop - 1].w) == 1.0)) {
      return;
    }
    float command = texelFetch(dataBuffer, i).x;
    switch(int(command)) {
    case 0:{
      return;
    };
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
    case 10:{
      M(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x);
      i += 2;
    }; break;
    case 11:{
      L(texelFetch(dataBuffer, i + 1).x, texelFetch(dataBuffer, i + 2).x);
      i += 2;
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
    case 23:{
      boolMode = int(texelFetch(dataBuffer, i + 1).x);
      i += 1;
    }; break;
    case 24:{
      fillMask = 1.0;
    }; break;
    default: {
      ;
    }; break;
    }
    i += 1;
  }
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

float blendAlphaPremul(
  float backdrop,
  float source
) {
  float result;
  result = float(float(source) + (float(backdrop)) * (1.0 - float(source)));
  return result;
}

void endPath(
) {
  // SVG style end path command.
  draw();
}

void line(
  vec2 a0,
  vec2 b0
) {
  // Draw the lines based on windingRule.
  vec2 a1 = (vec3(a0, 1.0)).xy - screen;
  vec2 b1 = (vec3(b0, 1.0)).xy - screen;
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

vec4 blendNormalPremul(
  vec4 backdrop,
  vec4 source
) {
  vec4 result;
  float k = 1.0 - float(source.w);
  result.x = float(float(source.x) + float(backdrop.x) * k);
  result.y = float(float(source.y) + float(backdrop.y) * k);
  result.z = float(float(source.z) + float(backdrop.z) * k);
  result.w = blendAlphaPremul(backdrop.w, source.w);
  return result;
}

vec4 runPixel(
  vec2 xy
) {
  vec4 result;
  // Runs commands for a single pixel.
  screen = xy;
  runCommands();
  if (colorStackTop == 0) {
    result = vec4(0.0, 0.0, 0.0, 0.0);
    return result;
  } else {
    colorStackTop -= 1;
    vec4 bg = colorStack[colorStackTop];
    while(0 < colorStackTop) {
      colorStackTop -= 1;
      bg = blendNormalPremul(bg, colorStack[colorStackTop]);
    }
    result = bg;
    return result;
  }
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
  maskOn = false;
  maskStackTop = 0;
  maskStack[maskStackTop] = 1.0;
  x0 = 0.0;
  y0 = 0.0;
  x1 = 0.0;
  y1 = 0.0;
  topIndex = 0.0;
  crossCountMat = mat4(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  mat = mat3(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
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
  colorStackTop = 0;
  colorStack[colorStackTop] = vec4(0.0, 0.0, 0.0, 0.0);
  float bias = 0.0001;
  vec2 offset = vec2(float(bias - 0.5), float(bias - 0.5));
  fragColor = runPixel(gl_FragCoord.xy + offset);
}
