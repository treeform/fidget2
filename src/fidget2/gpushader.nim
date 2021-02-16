import fidget2/glsl, print, vmath, gpublends

proc basic2dVert*(vertexPox: Vec2, gl_Position: var Vec4) =
  ## Simplest possible shader to put vertex on screen.
  gl_Position.xy = vertexPox

## Main input data, command buffer and texture atlas.
var dataBuffer*: Uniform[SamplerBuffer]
var textureAtlasSampler*: Uniform[Sampler2d]

const
  useAA = true
  useBlends = false
  useMask = false
  useBounds = false

const
  ## Command "enums"
  cmdExit*: int = 0
  cmdStartPath*: int = 1
  kEvenOdd*: int = 0
  kNonZero*: int = 1
  cmdEndPath*: int = 2
  cmdSetMat*: int = 3
  cmdSolidFill*: int = 4
  cmdApplyOpacity*: int = 5
  cmdTextureFill*: int = 6
  cmdGradientLinear*: int = 7
  cmdGradientRadial*: int = 8
  cmdGradientStop*: int = 9
  cmdM*: int = 10
  cmdL*: int = 11
  cmdC*: int = 12
  cmdQ*: int = 13
  cmdz*: int = 14
  cmdBoundCheck*: int = 15
  cmdMaskStart*: int = 16
  cmdMaskPush*: int = 17
  cmdMaskPop*: int = 18
  cmdIndex*: int = 19
  cmdLayerBlur*: int = 20
  cmdDropShadow*: int = 21
  cmdSetBlendMode*: int = 22
  cmdSetBoolMode*: int = 23
  cmdFullFill*: int = 24


  cbmNormal*: int = 0
  cbmDarken*: int = 1
  cbmMultiply*: int = 2
  cbmLinearBurn*: int = 3
  cbmColorBurn*: int = 4
  cbmLighten*: int = 5
  cbmScreen*: int = 6
  cbmLinearDodge*: int = 7
  cbmColorDodge*: int = 8
  cbmOverlay*: int = 9
  cbmSoftLight*: int = 10
  cbmHardLight*: int = 11
  cbmDifference*: int = 12
  cbmExclusion*: int = 13
  cbmHue*: int = 14
  cbmSaturation*: int = 15
  cbmColor*: int = 16
  cbmLuminosity*: int = 17

  cbmSubtractMask*: int = 18
  cbmIntersectMask*: int = 19
  cbmExcludeMask*: int = 20

var
  crossCountMat: Mat4     # Number of line crosses (4x4 AA fill).
  windingRule: int = 0    # 0 for EvenOdd and 1 for NonZero
  x0, y0, x1, y1: float32 # Control points of lines and curves.
  screen: Vec2            # Location of were we are on screen.
  backdropColor: Vec4     # Current backdrop color.
  fillMask: float32 = 0.0 # How much of the fill is visible.
  boolMode: int           # Boolean mode.
  mat: Mat3               # Current transform matrix.
  tMat: Mat3              # Texture matrix.

  gradientK: float32      # Gradient constant 0 to 1.
  prevGradientK: float32  # What as the prev gradient K.
  prevGradientColor: Vec4 # Current gradient Color.

  maskOn: bool            # Are we recording a mask?
  mask: float32 = 1.0     # Current mask (from real masking not fill mask)
  maskStack: array[100, float32]
  maskStackTop: int

  topIndex*: float32      # Current top index (for mouse picking)

  layerBlur: float32      # Layer blur param.

  shadowOn: bool          # Draw the next node as a shadow?
  shadowColor: Vec4
  shadowOffset: Vec2
  shadowRadius: float32
  shadowSpread: float32

  blendMode: int          # Current blend mode.

proc lineDir(a, b: Vec2): float32 =
  ## Return the direction of the line (up or down).
  if a.y - b.y > 0:
    # Count up if line is going up.
    return 1
  else:
    # Count down if line is going down.
    return -1

proc pixelCover(a0, b0: Vec2): float32 =
  ## Returns the amount of area a given segment sweeps to the right
  ## in a [0,0 to 1,1] box.
  var
    a = a0
    b = b0
    aI: Vec2
    bI: Vec2
    area: float32 = 0.0

  # Sort A on top.
  if a.y > b.y:
    let tmp = a
    a = b
    b = tmp

  if (b.y < 0 or a.y > 1) or # Above or bellow, no effect.
    (a.x >= 1 and b.x >= 1) or # To the right, no effect.
    (a.y == b.y): # Horizontal line, no effect.
    return 0

  elif (a.x < 0 and b.x < 0) or # Both to the left.
    (a.x == b.x): # Vertical line
    # Area of the rectangle:
    return (1 - clamp(a.x, 0, 1)) * (min(b.y, 1) - max(a.y, 0))

  else:
    # y = mm*x + bb
    let
      mm: float32 = (b.y - a.y) / (b.x - a.x)
      bb: float32 = a.y - mm * a.x

    if a.x >= 0 and a.x <= 1 and a.y >= 0 and a.y <= 1:
      # A is in pixel bounds.
      aI = a
    else:
      aI = vec2((0 - bb) / mm, 0)
      if aI.x < 0:
        let y = mm * 0 + bb
        # Area of the extra rectangle.
        area += (min(bb, 1) - max(a.y, 0)).clamp(0, 1)
        aI = vec2(0, y.clamp(0, 1))
      elif aI.x > 1:
        let y = mm * 1 + bb
        aI = vec2(1, y.clamp(0, 1))

    if b.x >= 0 and b.x <= 1 and b.y >= 0 and b.y <= 1:
      # B is in pixel bounds.
      bI = b
    else:
      bI = vec2((1 - bb) / mm, 1)
      if bI.x < 0:
        let y = mm * 0 + bb
        # Area of the extra rectangle.
        area += (min(b.y, 1) - max(bb, 0)).clamp(0, 1)
        bI = vec2(0, y.clamp(0, 1))
      elif bI.x > 1:
        let y = mm * 1 + bb
        bI = vec2(1, y.clamp(0, 1))

  area += ((1 - aI.x) + (1 - bI.x)) / 2 * (bI.y - aI.y)
  return area

proc pixelCross(a0, b0: Vec2): float32 =
  ## Turn a line into inc/dec/ignore of the crossCount.
  let
    a = a0
    b = b0
  if a.y == b.y:
    # horizontal lines should not have effect
    return 0.0
  # Y check to see if we can be affected by the line:
  if 1 >= min(a.y, b.y) and 1 < max(a.y, b.y):
    var xIntersect: float32
    if b.x != a.x:
      # Find the xIntersect of the line.
      let
        m = (b.y - a.y) / (b.x - a.x)
        bb = a.y - m * a.x
      xIntersect = (1 - bb) / m
    else:
      # Line is vertical, xIntersect is at x.
      xIntersect = a.x
    if xIntersect < 1:
      # Is the xIntersect is to the left, count cross.
      return lineDir(a, b)
  return 0.0

proc line(a0, b0: Vec2) =
  ## Draw the lines based on windingRule.
  var
    a1 = (mat * vec3(a0, 1)).xy - screen
    b1 = (mat * vec3(b0, 1)).xy - screen

  when useAA:
    if windingRule == 0:
      # Event-odd
      a1 += vec2(0.125, 0.125) # Center scan lines in each quarter.
      b1 += vec2(0.125, 0.125) # 1/4/2
      # DO I KNOW WHAT I AM DOING? NO...
      crossCountMat[0, 0] = crossCountMat[0, 0] + pixelCross(a1 + vec2(0,0)/4, b1 + vec2(0,0)/4)
      crossCountMat[0, 1] = crossCountMat[0, 1] + pixelCross(a1 + vec2(0,1)/4, b1 + vec2(0,1)/4)
      crossCountMat[0, 2] = crossCountMat[0, 2] + pixelCross(a1 + vec2(0,2)/4, b1 + vec2(0,2)/4)
      crossCountMat[0, 3] = crossCountMat[0, 3] + pixelCross(a1 + vec2(0,3)/4, b1 + vec2(0,3)/4)
      crossCountMat[1, 0] = crossCountMat[1, 0] + pixelCross(a1 + vec2(1,0)/4, b1 + vec2(1,0)/4)
      crossCountMat[1, 1] = crossCountMat[1, 1] + pixelCross(a1 + vec2(1,1)/4, b1 + vec2(1,1)/4)
      crossCountMat[1, 2] = crossCountMat[1, 2] + pixelCross(a1 + vec2(1,2)/4, b1 + vec2(1,2)/4)
      crossCountMat[1, 3] = crossCountMat[1, 3] + pixelCross(a1 + vec2(1,3)/4, b1 + vec2(1,3)/4)
      crossCountMat[2, 0] = crossCountMat[2, 0] + pixelCross(a1 + vec2(2,0)/4, b1 + vec2(2,0)/4)
      crossCountMat[2, 1] = crossCountMat[2, 1] + pixelCross(a1 + vec2(2,1)/4, b1 + vec2(2,1)/4)
      crossCountMat[2, 2] = crossCountMat[2, 2] + pixelCross(a1 + vec2(2,2)/4, b1 + vec2(2,2)/4)
      crossCountMat[2, 3] = crossCountMat[2, 3] + pixelCross(a1 + vec2(2,3)/4, b1 + vec2(2,3)/4)
      crossCountMat[3, 0] = crossCountMat[3, 0] + pixelCross(a1 + vec2(3,0)/4, b1 + vec2(3,0)/4)
      crossCountMat[3, 1] = crossCountMat[3, 1] + pixelCross(a1 + vec2(3,1)/4, b1 + vec2(3,1)/4)
      crossCountMat[3, 2] = crossCountMat[3, 2] + pixelCross(a1 + vec2(3,2)/4, b1 + vec2(3,2)/4)
      crossCountMat[3, 3] = crossCountMat[3, 3] + pixelCross(a1 + vec2(3,3)/4, b1 + vec2(3,3)/4)
    else:
      # Non-Zero
      let area = pixelCover(a1, b1)
      fillMask += area * lineDir(a1, b1)
  else:
    # NO AA way:
    crossCountMat[0, 0] = crossCountMat[0, 0] + pixelCross(a1 + vec2(0,0)/4, b1 + vec2(0,0)/4)

proc interpolate(G1, G2, G3, G4: Vec2, t: float32): Vec2 =
  ## Solve the cubic bezier interpolation with 4 points.
  let
    A = G4 - G1 + 3 * (G2 - G3)
    B = 3 * (G1 - 2 * G2 + G3)
    C = 3 * (G2 - G1)
    D = G1
  return t * (t * (t * A + B) + C) + D

const
  # Quality of bezier discretization:
  perPixel = 0.5
  maxLines = 20
proc bezier(A, B, C, D: Vec2) =
  ## Turn a cubic curve into N lines.
  var p = A
  let dist = (A - B).length + (B - C).length + (C - D).length
  let discretization = clamp(int(dist*perPixel), 1, maxLines)
  for t in 1 .. discretization:
    let
      q = interpolate(A, B, C, D, float32(t)/float32(discretization))
    line(p, q)
    p = q

proc quadratic(p0, p1, p2: Vec2) =
  ## Turn a cubic curve into N lines.
  let devx = p0.x - 2.0 * p1.x + p2.x
  let devy = p0.y - 2.0 * p1.y + p2.y
  let devsq = devx * devx + devy * devy
  if devsq < 0.333:
    line(p0, p2)
    return
  let tol = 3.0
  let n = 1.0 + (tol * (devsq)).sqrt().sqrt().floor()
  var p = p0
  let nrecip = 1.0 / n
  var t = 0.0
  for i in 0 ..< int(n):
    t += nrecip
    let pn = mix(mix(p0, p1, t), mix(p1, p2, t), t)
    line(p, pn)
    p = pn

proc finalColor(applyColor: Vec4) =
  if maskOn:
    case blendMode:
      of cbmNormal:
        maskStack[maskStackTop] += applyColor.w
      of cbmSubtractMask:
        maskStack[maskStackTop] = 0 #maskStack[maskStackTop] * (1 - applyColor.w)
      # of cbmIntersectMask:
      #   backdropColor = blendIntersectMaskFloats(backdropColor, c)
      # of cbmExcludeMask:
      #   backdropColor = blendExcludeMaskFloats(backdropColor, c)
      else:
        discard

  else:
    var c = applyColor
    when useMask:
      c.w = c.w * maskStack[maskStackTop]

    when useBlends:
      if blendMode == cbmNormal:
        backdropColor = blendNormalFloats(backdropColor, c)
      else:
        case blendMode:
          # of cbmNormal:
          #   backdropColor = blendNormalFloats(backdropColor, c)
          of cbmDarken:
            backdropColor = blendDarkenFloats(backdropColor, c)
          of cbmMultiply:
            backdropColor = blendMultiplyFloats(backdropColor, c)
          of cbmLinearBurn:
            backdropColor = blendLinearBurnFloats(backdropColor, c)
          of cbmColorBurn:
            backdropColor = blendColorBurnFloats(backdropColor, c)
          of cbmLighten:
            backdropColor = blendLightenFloats(backdropColor, c)
          of cbmScreen:
            backdropColor = blendScreenFloats(backdropColor, c)
          of cbmLinearDodge:
            backdropColor = blendLinearDodgeFloats(backdropColor, c)
          of cbmColorDodge:
            backdropColor = blendColorDodgeFloats(backdropColor, c)
          of cbmOverlay:
            backdropColor = blendOverlayFloats(backdropColor, c)
          of cbmSoftLight:
            backdropColor = blendSoftLightFloats(backdropColor, c)
          of cbmHardLight:
            backdropColor = blendHardLightFloats(backdropColor, c)
          of cbmDifference:
            backdropColor = blendDifferenceFloats(backdropColor, c)
          of cbmExclusion:
            backdropColor = blendExclusionFloats(backdropColor, c)
          of cbmColor:
            backdropColor = blendColorFloats(backdropColor, c)
          of cbmLuminosity:
            backdropColor = blendLuminosityFloats(backdropColor, c)
          of cbmHue:
            backdropColor = blendHueFloats(backdropColor, c)
          of cbmSaturation:
            backdropColor = blendSaturationFloats(backdropColor, c)
          # of cbmMask:
          #   backdropColor = blendMaskFloats(backdropColor, c)
          # of cbmSubtractMask:
          #   backdropColor = blendSubtractMaskFloats(backdropColor, c)
          # of cbmIntersectMask:
          #   backdropColor = blendIntersectMaskFloats(backdropColor, c)
          # of cbmExcludeMask:
          #   backdropColor = blendExcludeMaskFloats(backdropColor, c)
          # of cbmOverwrite:
          #   backdropColor = blendOverwriteFloats(backdropColor, c)
          else:
            discard
    else:
      backdropColor = blendNormalFloats(backdropColor, c)


proc solidFill(r, g, b, a: float32) =
  ## Set the source color.
  if fillMask > 0:
    finalColor(vec4(r, g, b, a * fillMask))

proc normPdf(x: float, sigma: float32): float32 =
  ## Normal Probability Density Function (used for shadow and blurs)
  return 0.39894 * exp(-0.5 * x * x / (sigma * sigma)) / sigma

proc textureFill(tMat: Mat3, tile: float32, pos, size: Vec2) =
  ## Set the source color.
  if true or fillMask > 0:
    # WE need to undo the AA when sampling images
    # * That is why we need to floor.
    # * That is why we need to add vec2(0.5, 0.5).

    if shadowOn:
      # TODO: Some thing when shadow radius is more then 50px
      shadowRadius = min(50, shadowRadius)
      let mSize = shadowRadius.int*2 + 1
      let kSize = shadowRadius.int
      var kernel: array[101, float32]
      var sigma = 2.0 - 0.1

      for x in 0 .. kSize:
        let v = normPdf((x).float32, sigma)
        kernel[kSize + x] = v
        kernel[kSize - x] = v

      var zNormal = 0.0 # Total for normalization
      for x in 0 ..< mSize:
        for y in 0 ..< mSize:
          zNormal = zNormal + kernel[x]*kernel[y]

      var combinedShadow = 0.0

      for x in -shadowRadius.int .. shadowRadius.int:
        for y in -shadowRadius.int .. shadowRadius.int:
          let
            offset = vec2(x.float32, y.float32) - shadowOffset
            kValue = kernel[kSize + x] * kernel[kSize + y]
            uv = (tMat * vec3(screen.floor + vec2(0.5, 0.5) + offset, 1)).xy
          if uv.x > pos.x and uv.x < pos.x + size.x and
            uv.y > pos.y and uv.y < pos.y + size.y:
            let textureColor = texture(textureAtlasSampler, uv).w
            combinedShadow += textureColor * kValue

      combinedShadow = combinedShadow / zNormal
      var combinedColor = shadowColor
      combinedColor.w = combinedShadow
      finalColor(combinedColor)

    if layerBlur > 0:

      let mSize = layerBlur.int*2 + 1
      let kSize = layerBlur.int
      var kernel: array[20, float32]
      var sigma = 2.0 - 0.1

      for x in 0 .. kSize:
        let v = normpdf((x).float32, sigma)
        kernel[kSize + x] = v
        kernel[kSize - x] = v

      var zNormal = 0.0 # Total for normalization
      for x in 0 ..< mSize:
        for y in 0 ..< mSize:
          zNormal = zNormal + kernel[x]*kernel[y]

      var combinedColor = vec4(0)

      var colorAdj = 0.0
      for x in -layerBlur.int .. layerBlur.int:
        for y in -layerBlur.int .. layerBlur.int:
          let
            offset = vec2(x.float32, y.float32)
            kValue = kernel[kSize + x] * kernel[kSize + y]
            uv = (tMat * vec3(screen.floor + vec2(0.5, 0.5) + offset, 1)).xy
          if uv.x > pos.x and uv.x < pos.x + size.x and
            uv.y > pos.y and uv.y < pos.y + size.y:
            let textureColor = texture(textureAtlasSampler, uv)
            combinedColor += textureColor * kValue
            colorAdj += kValue

      if colorAdj != 0:
        combinedColor.x = combinedColor.x / colorAdj
        combinedColor.y = combinedColor.y / colorAdj
        combinedColor.z = combinedColor.z / colorAdj
      combinedColor.w = combinedColor.w / zNormal
      finalColor(combinedColor)

    else:

      # Normal texture operation.
      var uv = (tMat * vec3(screen.floor + vec2(0.5, 0.5), 1)).xy
      if tile == 0:
        if uv.x > pos.x and uv.x < pos.x + size.x and
          uv.y > pos.y and uv.y < pos.y + size.y:
          var textureColor = texture(textureAtlasSampler, uv)
          textureColor.w *= fillMask
          finalColor(textureColor)
      else:
        uv = ((uv - pos) mod size) + pos
        var textureColor = texture(textureAtlasSampler, uv)
        textureColor.w *= fillMask
        finalColor(textureColor)

proc toLineSpace(at, to, point: Vec2): float32 =
  ## Covert a point to be in the line space (used for gradients).
  let
    d = to - at
    det = d.x*d.x + d.y*d.y
  return (d.y*(point.y-at.y)+d.x*(point.x-at.x))/det

proc gradientLinear(at0, to0: Vec2) =
  ## Setup color for linear gradient.
  if fillMask > 0:
    let
      at = (mat * vec3(at0, 1)).xy
      to = (mat * vec3(to0, 1)).xy
    gradientK = toLineSpace(at, to, screen).clamp(0, 1)

proc gradientRadial(at0, to0: Vec2) =
  ## Setup color for radial gradient.
  if fillMask > 0:
    let
      at = (mat * vec3(at0, 1)).xy
      to = (mat * vec3(to0, 1)).xy
      distance = (at - to).length()
    gradientK = ((at - screen).length() / distance).clamp(0, 1)

proc gradientStop(k, r, g, b, a: float32) =
  ## Compute a gradient stop.
  if fillMask > 0:
    let gradientColor = vec4(r, g, b, a)
    if gradientK > prevGradientK and gradientK <= k:
      let betweenColors = (gradientK - prevGradientK) / (k - prevGradientK)
      var colorG = mix(
        prevGradientColor,
        gradientColor,
        betweenColors
      )
      colorG.w *= fillMask
      finalColor(colorG)
    prevGradientK = k
    prevGradientColor = gradientColor

proc startPath(rule: float32) =
  ## Clear the status of things and start a new path.
  crossCountMat = mat4(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  fillMask = 0
  windingRule = rule.int

proc draw() =
  ## Apply the winding rule.
  when useAA:
    if windingRule == 0:
      # Even-Odd winding rule:
      fillMask = 0
      let n = 4
      for x in 0 ..< n:
        for y in 0 ..< n:
          if zmod(crossCountMat[x, y], 2.0) != 0.0:
            fillMask += 1
      fillMask = fillMask / (n * n).float32
    else:
      # Non-Zero winding rule:
      fillMask = abs(fillMask).clamp(0, 1)
  else:
    ## NO AA WAY
    if windingRule == 0:
      if zmod(crossCountMat[0, 0], 2) != 0:
        fillMask = 1
    else:
      if crossCountMat[0, 0] != 0:
        fillMask = 1

proc endPath() =
  ## SVG style end path command.
  draw()

proc M(x, y: float32) =
  ## SVG style Move command.
  x1 = x
  x0 = x
  y1 = y
  y0 = y

proc L(x, y: float32) =
  ## SVG style Line command.
  line(vec2(x0, y0), vec2(x, y))
  x0 = x
  y0 = y

proc C(x1, y1, x2, y2, x, y: float32) =
  ## SVG cubic Curve command.
  bezier(vec2(x0, y0), vec2(x1, y1), vec2(x2, y2), vec2(x, y))
  x0 = x
  y0 = y

proc Q(x1, y1, x, y: float32) =
  ## SVG Quadratic curve command.
  quadratic(vec2(x0, y0), vec2(x1, y1), vec2(x, y))
  x0 = x
  y0 = y

proc z() =
  ## SVG style end of shape command.
  line(vec2(x0, y0), vec2(x1, y1))

proc overlap*(minA, maxA, minB, maxB: Vec2): bool =
  ## Test overlap: rect vs rect.
  return
    maxA.x >= minB.x and # A right edge past b left?
    minA.x <= maxB.x and # A left edge past b right?
    maxA.y >= minB.y and # A top edge past b bottom?
    minA.y <= maxB.y # A bottom edge past b top?

proc runCommands() =
  ## Runs a little command interpreter.
  var i = 0
  while true:
    let command = texelFetch(dataBuffer, i).x
    case command.int:
    of cmdExit:
      return

    of cmdStartPath:
      startPath(texelFetch(dataBuffer, i + 1).x)
      i += 1

    of cmdEndPath:
      endPath()

    of cmdSolidFill:
      solidFill(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x
      )
      i += 4

    of cmdApplyOpacity:
      let opacity = texelFetch(dataBuffer, i + 1).x
      backdropColor = backdropColor * opacity
      i += 1

    of cmdTextureFill:
      tMat[0, 0] = texelFetch(dataBuffer, i + 1).x
      tMat[0, 1] = texelFetch(dataBuffer, i + 2).x
      tMat[0, 2] = 0
      tMat[1, 0] = texelFetch(dataBuffer, i + 3).x
      tMat[1, 1] = texelFetch(dataBuffer, i + 4).x
      tMat[1, 2] = 0
      tMat[2, 0] = texelFetch(dataBuffer, i + 5).x
      tMat[2, 1] = texelFetch(dataBuffer, i + 6).x
      tMat[2, 2] = 1
      let tile = texelFetch(dataBuffer, i + 7).x
      var pos: Vec2
      pos.x = texelFetch(dataBuffer, i + 8).x
      pos.y = texelFetch(dataBuffer, i + 9).x
      var size: Vec2
      size.x = texelFetch(dataBuffer, i + 10).x
      size.y = texelFetch(dataBuffer, i + 11).x
      textureFill(tMat, tile, pos, size)
      i += 11

    of cmdGradientLinear:
      var at, to: Vec2
      at.x = texelFetch(dataBuffer, i + 1).x
      at.y = texelFetch(dataBuffer, i + 2).x
      to.x = texelFetch(dataBuffer, i + 3).x
      to.y = texelFetch(dataBuffer, i + 4).x
      gradientLinear(at, to)
      i += 4

    of cmdGradientRadial:
      var at, to: Vec2
      at.x = texelFetch(dataBuffer, i + 1).x
      at.y = texelFetch(dataBuffer, i + 2).x
      to.x = texelFetch(dataBuffer, i + 3).x
      to.y = texelFetch(dataBuffer, i + 4).x
      gradientRadial(at, to)
      i += 4

    of cmdGradientStop:
      gradientStop(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x,
        texelFetch(dataBuffer, i + 5).x
      )
      i += 5

    of cmdSetMat:
      mat[0, 0] = texelFetch(dataBuffer, i + 1).x
      mat[0, 1] = texelFetch(dataBuffer, i + 2).x
      mat[0, 2] = 0
      mat[1, 0] = texelFetch(dataBuffer, i + 3).x
      mat[1, 1] = texelFetch(dataBuffer, i + 4).x
      mat[1, 2] = 0
      mat[2, 0] = texelFetch(dataBuffer, i + 5).x
      mat[2, 1] = texelFetch(dataBuffer, i + 6).x
      mat[2, 2] = 1
      i += 6

    of cmdM:
      M(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x
      )
      i += 2

    of cmdL:
      L(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x
      )
      i += 2

    of cmdC:
      C(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x,
        texelFetch(dataBuffer, i + 5).x,
        texelFetch(dataBuffer, i + 6).x
      )
      i += 6

    of cmdQ:
      Q(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x,
      )
      i += 4

    of cmdz:
      z()

    of cmdBoundCheck:
      # Jump over code if screen not in bounds
      var
        minP: Vec2
        maxP: Vec2
      minP.x = texelFetch(dataBuffer, i + 1).x
      minP.y = texelFetch(dataBuffer, i + 2).x
      maxP.x = texelFetch(dataBuffer, i + 3).x
      maxP.y = texelFetch(dataBuffer, i + 4).x
      let label = texelFetch(dataBuffer, i + 5).x.int
      i += 5

      # Compute pixel bounds.
      let
        matInv = mat.inverse()
        screenInvA = (matInv * vec3(screen + vec2(0, 0), 1)).xy
        screenInvB = (matInv * vec3(screen + vec2(1, 0), 1)).xy
        screenInvC = (matInv * vec3(screen + vec2(1, 0), 1)).xy
        screenInvD = (matInv * vec3(screen + vec2(0, 1), 1)).xy
      var
        minS: Vec2
        maxS: Vec2
      minS.x = min(min(screenInvA.x, screenInvB.x), min(screenInvC.x, screenInvD.x))
      minS.y = min(min(screenInvA.y, screenInvB.y), min(screenInvC.y, screenInvD.y))
      maxS.x = max(max(screenInvA.x, screenInvB.x), max(screenInvC.x, screenInvD.x))
      maxS.y = max(max(screenInvA.y, screenInvB.y), max(screenInvC.y, screenInvD.y))

      when useBounds:
        if not overlap(minS, maxS, minP, maxP):
          i = label - 1

    of cmdMaskStart:
      maskOn = true
      maskStackTop += 1
      maskStack[maskStackTop] = 0.0

    of cmdMaskPush:
      maskOn = false

    of cmdMaskPop:
      maskStackTop -= 1

    of cmdIndex:
      let index = texelFetch(dataBuffer, i + 1).x
      if fillMask * mask > 0:
        topIndex = index
      i += 1

    of cmdLayerBlur:
      layerBlur = texelFetch(dataBuffer, i + 1).x
      i += 1

    of cmdDropShadow:
      shadowOn = true
      shadowColor.x = texelFetch(dataBuffer, i + 1).x
      shadowColor.y = texelFetch(dataBuffer, i + 2).x
      shadowColor.z = texelFetch(dataBuffer, i + 3).x
      shadowColor.w = texelFetch(dataBuffer, i + 4).x
      shadowOffset.x = texelFetch(dataBuffer, i + 5).x
      shadowOffset.y = texelFetch(dataBuffer, i + 6).x
      shadowRadius = texelFetch(dataBuffer, i + 7).x
      shadowSpread = texelFetch(dataBuffer, i + 8).x
      i += 8

    of cmdSetBlendMode:
      blendMode = texelFetch(dataBuffer, i + 1).x.int
      i += 1

    of cmdSetBoolMode:
      boolMode = texelFetch(dataBuffer, i + 1).x.int
      i += 1

    of cmdFullFill:
      fillMask = 1.0

    else:
      discard

    i += 1

proc runPixel(xy: Vec2): Vec4 =
  ## Runs commands for a single pixel.
  screen = xy
  backdropColor = vec4(0, 0, 0, 0)
  runCommands()
  return backdropColor

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =
  ## Main entry point to this huge shader.

  maskOn = false
  maskStackTop = 0
  maskStack[maskStackTop] = 1.0

  x0 = 0
  y0 = 0
  x1 = 0
  y1 = 0
  topIndex = 0

  crossCountMat = mat4(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

  mat = mat3(
    1, 0, 0,
    0, 1, 0,
    0, 0, 1
  )

  gradientK = 0
  prevGradientK = 0
  prevGradientColor = vec4(0, 0, 0, 0)

  layerBlur = 0.0
  shadowOn = false
  shadowColor = vec4(0, 0, 0, 0)
  shadowOffset = vec2(0, 0)
  shadowRadius = 0.0
  shadowSpread = 0.0

  blendMode = 0

  let bias = 1E-4
  let offset = vec2(bias - 0.5, bias - 0.5)
  fragColor = runPixel(gl_FragCoord.xy + offset)


  # fragColor = vec4(1,0,0,1)

  # if gl_FragCoord.x > 100 and gl_FragCoord.x < 200 and
  #   gl_FragCoord.y > 100 and gl_FragCoord.y < 200:
  #     fragColor = vec4(0,1,0,1)

  # fragColor = blendNormalFloats(fragColor, vec4(1,0,0,topIndex/32))

  # if pixelCrossDelta > 0:
  #   fragColor = vec4(1,0,0,1)
  # if pixelCrossDelta < 0:
  #   fragColor = vec4(0,1,0,1)

  #fragColor.x = debug.x
  #print fragColor

  #fragColor.x = gl_FragCoord.x - floor(gl_FragCoord.x)

  #fragColor.x = numTrapezoids

  #fragColor.w = 1
  #dataBuffer
