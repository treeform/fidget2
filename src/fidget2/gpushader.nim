import vmath, fidget2/glsl, print

proc basic2dVert*(vertexPox: Vec2, gl_Position: var Vec4) =
  ## Simplest possible shader to put vertex on screen.
  gl_Position.xy = vertexPox

var dataBuffer*: Uniform[SamplerBuffer]
var textureAtlasSampler*: Uniform[Sampler2d]

const
  ## Command "enums"
  cmdExit*: float32 = 0
  cmdStartPath*: float32 = 1
  kEvenOdd*: float32 = 0
  kNonZero*: float32 = 1
  cmdEndPath*: float32 = 2
  cmdSetMat*: float32 = 3
  cmdSolidFill*: float32 = 4
  cmdApplyOpacity*: float32 = 5
  cmdTextureFill*: float32 = 6
  cmdGradientLinear*: float32 = 7
  cmdGradientRadial*: float32 = 8
  cmdGradientStop*: float32 = 9
  cmdM*: float32 = 10
  cmdL*: float32 = 11
  cmdC*: float32 = 12
  cmdQ*: float32 = 13
  cmdz*: float32 = 14
  cmdBoundCheck*: float32 = 15
  cmdMaskFill*: float32 = 16
  cmdMaskClear*: float32 = 17
  cmdIndex*: float32 = 18
  cmdLayerBlur*: float32 = 19

var
  crossCountMat: Mat4     # Number of line crosses (4x4 AA fill).
  windingRule: int = 0    # 0 for EvenOdd and 1 for NonZero
  x0, y0, x1, y1: float32 # Control points of lines and curves.
  screen: Vec2            # Location of were we are on screen.
  backdropColor: Vec4     # Current backdrop color.
  fillMask: float32 = 0.0 # How much of the fill is visible.
  mat: Mat3               # Current transform matrix.
  tMat: Mat3              # Texture matrix.
  gradientK: float32      # Gradient constant 0 to 1.
  prevGradientK: float32
  prevGradientColor: Vec4
  mask: float32 = 1.0

  topIndex*: float32
  layerBlur*: float32

proc lineDir(a, b: Vec2): float32 =
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

proc interpolate(G1, G2, G3, G4: Vec2, t: float32): Vec2 =
  ## Solve the cubic bezier interpolation with 4 points.
  let
    A = G4 - G1 + 3 * (G2 - G3)
    B = 3 * (G1 - 2 * G2 + G3)
    C = 3 * (G2 - G1)
    D = G1
  return t * (t * (t * A + B) + C) + D

proc bezier(A, B, C, D: Vec2) =
  ## Turn a cubic curve into N lines.
  var p = A
  let discretization = 20
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

proc alphaFix(backdrop, source, mixed: Vec4): Vec4 =
  var res: Vec4
  res.w = (source.w + backdrop.w * (1.0 - source.w))
  if res.w == 0.0:
    return res

  let
    t0 = source.w * (1.0 - backdrop.w)
    t1 = source.w * backdrop.w
    t2 = (1.0 - source.w) * backdrop.w

  res.x = t0 * source.x + t1 * mixed.x + t2 * backdrop.x
  res.y = t0 * source.y + t1 * mixed.y + t2 * backdrop.y
  res.z = t0 * source.z + t1 * mixed.z + t2 * backdrop.z

  res.x /= res.w
  res.y /= res.w
  res.z /= res.w
  return res

proc blendNormalFloats*(backdrop, source: Vec4): Vec4 =
  return alphaFix(backdrop, source, source)

proc normpdf(x: float, sigma: float32): float32 =
  return 0.39894 * exp(-0.5 * x * x / (sigma * sigma)) / sigma

proc solidFill(r, g, b, a: float32) =
  ## Set the source color.
  if fillMask * mask > 0:
    backdropColor = blendNormalFloats(backdropColor, vec4(r, g, b, a * fillMask * mask))

proc textureFill(tMat: Mat3, tile: float32, pos, size: Vec2) =
  ## Set the source color.
  if true or fillMask * mask > 0:
    # WE need to undo the AA when sampling images
    # * That is why we need to floor.
    # * That is why we need to add vec2(0.5, 0.5).

    if layerBlur > 0:

      let mSize = layerBlur.int*2 + 1
      let kSize = layerBlur.int
      var kernel: array[20, float32]
      var sigma = 2.0 - 0.1

      for x in 0 .. kSize:
        let v = normpdf((x).float32, sigma)
        kernel[kSize + x] = v
        kernel[kSize - x] = v
      print kernel

      var zNormal = 0.0 # Total for normalization
      for x in 0 ..< mSize:
        for y in 0 ..< mSize:
          zNormal = zNormal + kernel[x]*kernel[y]
      print zNormal

      var combinedColor = vec4(0)

      var colorAdj = 0.0
      for x in -layerBlur.int .. layerBlur.int:
        for y in -layerBlur.int .. layerBlur.int:
          let
            offset = vec2(x.float32, y.float32)
            kValue = kernel[kSize + x] * kernel[kSize + y]
            uv = (tMat * vec3(screen.floor + vec2(0.5, 0.5) + offset, 1)).xy
          print kValue
          if uv.x > pos.x and uv.x < pos.x + size.x and
            uv.y > pos.y and uv.y < pos.y + size.y:
            let textureColor = texture(textureAtlasSampler, uv)
            print textureColor
            combinedColor += textureColor * kValue
            colorAdj += kValue

      if colorAdj != 0:
        combinedColor.x = combinedColor.x / colorAdj
        combinedColor.y = combinedColor.y / colorAdj
        combinedColor.z = combinedColor.z / colorAdj
      combinedColor.w = combinedColor.w / zNormal
      # combinedColor.w *= mask
      print combinedColor
      backdropColor = blendNormalFloats(backdropColor, combinedColor)

    else:
      var uv = (tMat * vec3(screen.floor + vec2(0.5, 0.5), 1)).xy
      if tile == 0:
        if uv.x > pos.x and uv.x < pos.x + size.x and
          uv.y > pos.y and uv.y < pos.y + size.y:
          var textureColor = texture(textureAtlasSampler, uv)
          textureColor.w *= fillMask * mask
          backdropColor = blendNormalFloats(backdropColor, textureColor)
      else:
        uv = ((uv - pos) mod size) + pos
        var textureColor = texture(textureAtlasSampler, uv)
        textureColor.w *= fillMask * mask
        backdropColor = blendNormalFloats(backdropColor, textureColor)

proc toLineSpace(at, to, point: Vec2): float32 =
  let
    d = to - at
    det = d.x*d.x + d.y*d.y
  return (d.y*(point.y-at.y)+d.x*(point.x-at.x))/det

proc gradientLinear(at0, to0: Vec2) =
  if fillMask > 0:
    let
      at = (mat * vec3(at0, 1)).xy
      to = (mat * vec3(to0, 1)).xy
    gradientK = toLineSpace(at, to, screen).clamp(0, 1)

proc gradientRadial(at0, to0: Vec2) =
  if fillMask * mask > 0:
    let
      at = (mat * vec3(at0, 1)).xy
      to = (mat * vec3(to0, 1)).xy
      distance = (at - to).length()
    gradientK = ((at - screen).length() / distance).clamp(0, 1)

proc gradientStop(k, r, g, b, a: float32) =
  if fillMask * mask > 0:
    let gradientColor = vec4(r, g, b, a)
    if gradientK > prevGradientK and gradientK <= k:
      let betweenColors = (gradientK - prevGradientK) / (k - prevGradientK)
      var colorG = mix(
        prevGradientColor,
        gradientColor,
        betweenColors
      )
      colorG.w *= fillMask * mask
      backdropColor = blendNormalFloats(backdropColor, colorG)
    prevGradientK = k
    prevGradientColor = gradientColor

proc startPath(rule: float32) =
  ## Clear the status of things and start a new path.
  crossCountMat = mat4(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0)
  fillMask = 0
  windingRule = rule.int

proc draw() =
  ## Apply the winding rule.
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
  bezier(vec2(x0,y0), vec2(x1,y1), vec2(x2,y2), vec2(x,y))
  x0 = x
  y0 = y

proc Q(x1, y1, x, y: float32) =
  ## SVG Quadratic curve command.
  quadratic(vec2(x0,y0), vec2(x1,y1), vec2(x,y))
  x0 = x
  y0 = y

proc z() =
  ## SVG style end of shape command.
  line(vec2(x0, y0), vec2(x1,y1))

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
    if command == cmdExit: break
    elif command == cmdStartPath:
      startPath(texelFetch(dataBuffer, i + 1).x)
      i += 1
    elif command == cmdEndPath: endPath()
    elif command == cmdSolidFill:
      solidFill(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x
      )
      i += 4
    elif command == cmdApplyOpacity:
      let opacity = texelFetch(dataBuffer, i + 1).x
      backdropColor = backdropColor * opacity
      i += 1
    elif command == cmdTextureFill:
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
    elif command == cmdGradientLinear:
      var at, to: Vec2
      at.x = texelFetch(dataBuffer, i + 1).x
      at.y = texelFetch(dataBuffer, i + 2).x
      to.x = texelFetch(dataBuffer, i + 3).x
      to.y = texelFetch(dataBuffer, i + 4).x
      gradientLinear(at, to)
      i += 4
    elif command == cmdGradientRadial:
      var at, to: Vec2
      at.x = texelFetch(dataBuffer, i + 1).x
      at.y = texelFetch(dataBuffer, i + 2).x
      to.x = texelFetch(dataBuffer, i + 3).x
      to.y = texelFetch(dataBuffer, i + 4).x
      gradientRadial(at, to)
      i += 4
    elif command == cmdGradientStop:
      gradientStop(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x,
        texelFetch(dataBuffer, i + 5).x
      )
      i += 5
    elif command == cmdSetMat:
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
    elif command == cmdM:
      M(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x
      )
      i += 2
    elif command == cmdL:
      L(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x
      )
      i += 2
    elif command == cmdC:
      C(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x,
        texelFetch(dataBuffer, i + 5).x,
        texelFetch(dataBuffer, i + 6).x
      )
      i += 6
    elif command == cmdQ:
      Q(
        texelFetch(dataBuffer, i + 1).x,
        texelFetch(dataBuffer, i + 2).x,
        texelFetch(dataBuffer, i + 3).x,
        texelFetch(dataBuffer, i + 4).x,
      )
      i += 4
    elif command == cmdz: z()
    elif command == cmdBoundCheck:
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

      if not overlap(minS, maxS, minP, maxP):
        i = label - 1

    elif command == cmdMaskFill:
      mask = fillMask
    elif command == cmdMaskClear:
      mask = 1.0
    elif command == cmdIndex:
      let index = texelFetch(dataBuffer, i + 1).x
      if fillMask * mask > 0:
        topIndex = index
      i += 1
    elif command == cmdLayerBlur:
      layerBlur = texelFetch(dataBuffer, i + 1).x
      i += 1

    i += 1

proc runPixel(xy: Vec2): Vec4 =
  screen = xy
  backdropColor = vec4(0, 0, 0, 0)
  runCommands()
  return backdropColor

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =
  ## Main entry point to this huge shader.

  x0 = 0
  y0 = 0
  x1 = 0
  y1 = 0
  topIndex = 0

  crossCountMat = mat4(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0)

  mat = mat3(0,0,0, 0,0,0, 0,0,0)

  gradientK = 0
  prevGradientK = 0
  prevGradientColor = vec4(0,0,0,0)

  layerBlur = 0.0

  let bias = 1E-4
  let offset = vec2(bias - 0.5, bias - 0.5)
  fragColor = runPixel(gl_FragCoord.xy + offset)

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
