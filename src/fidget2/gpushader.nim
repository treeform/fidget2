import vmath, fidget2/glsl

var dataBuffer*: Uniform[SamplerBuffer]
var textureAtlasSampler*: Uniform[Sampler2d]

const
  ## Command "enums"
  cmdExit*: float32 = 0
  cmdStartPath*: float32 = 1
  cmdEndPath*: float32 = 2
  cmdSolidFill*: float32 = 3
  cmdApplyOpacity*: float32 = 4
  cmdTextureFill*: float32 = 5
  cmdSetMat*: float32 = 6
  cmdM*: float32 = 10
  cmdL*: float32 = 11
  cmdC*: float32 = 12
  cmdQ*: float32 = 13
  cmdz*: float32 = 20

var
  crossCount: int = 0   # Number of line crosses (used to fill).
  x0, y0, x1, y1: float # Control points of lines and curves.
  screen: Vec2          # Location of were we are on screen.
  backdropColor: Vec4   # Current backdrop color.
  fillMask: float       # How much of the fill is visible.
  mat: Mat3             # Current transform matrix.
  tMat: Mat3            # Texture matrix.

proc line(a0, b0: Vec2) =
  ## Turn a line into inc/dec/ignore of the crossCount.

  let
    a = (mat * vec3(a0, 1)).xy
    b = (mat * vec3(b0, 1)).xy

  if a.y == b.y:
    # horizontal lines should not have effect
    return
  # Y check to see if we can be affected by the line:
  if screen.y >= min(a.y, b.y) and screen.y < max(a.y, b.y):
    var xIntersect: float32
    if b.x != a.x:
      # Find the xIntersect of the line.
      let
        m = (b.y - a.y) / (b.x - a.x)
        bb = a.y - m * a.x
      xIntersect = (screen.y - bb) / m
    else:
      # Line is vertical, xIntersect is at x.
      xIntersect = a.x
    if xIntersect <= screen.x:
      # Is the xIntersect is to the left, count cross.
      if a.y - b.y > 0.0:
        # Count up if line is going up.
        crossCount += 1
      else:
        # Count down if line is going down.
        crossCount -= 1

proc interpolate(G1, G2, G3, G4: Vec2, t: float): Vec2 =
  ## Solve the cubic bezier interpolation with 4 points.
  let
    A = G4 - G1 + 3.0 * (G2 - G3)
    B = 3.0 * (G1 - 2.0 * G2 + G3)
    C = 3.0 * (G2 - G1)
    D = G1
  return t * (t * (t * A + B) + C) + D

proc bezier(A, B, C, D: Vec2) =
  ## Turn a cubic curve into N lines.
  var p = A
  let discretization = 10
  for t in 1 .. discretization:
    let
      q = interpolate(A, B, C, D, float(t)/float(discretization))
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

proc solidFill(r, g, b, a: float) =
  ## Set the source color.
  if fillMask == 1.0:
    # backdropColor = vec4(r, g, b, a)
    backdropColor = blendNormalFloats(backdropColor, vec4(r, g, b, a))

proc textureFill(tMat: Mat3) =
  ## Set the source color.
  if fillMask == 1.0:
    # backdropColor = vec4(r, g, b, a)
    # echo tMat
    # echo screen
    # echo tMat * vec3(screen, 1)
    let textureColor = texture(textureAtlasSampler, (tMat * vec3(screen, 1)).xy)
    backdropColor = blendNormalFloats(backdropColor, textureColor)
    #quit()


proc startPath() =
  ## Clear the status of things and start a new path.
  crossCount = 0
  fillMask = 0.0

proc draw() =
  ## Use crossCount to apply color to backdrop.
  if crossCount mod 2 != 0: # Even-Odd or Non-zero rule
    fillMask = 1.0

proc endPath() =
  ## SVG style end path command.
  draw()

proc M(x, y: float) =
  ## SVG style Move command.
  x1 = x
  x0 = x
  y1 = y
  y0 = y

proc L(x, y: float) =
  ## SVG style Line command.
  line(vec2(x0, y0), vec2(x, y))
  x0 = x
  y0 = y

proc C(x1, y1, x2, y2, x, y: float) =
  ## SVG cubic Curve command.
  bezier(vec2(x0,y0), vec2(x1,y1), vec2(x2,y2), vec2(x,y))
  x0 = x
  y0 = y

proc Q(x1, y1, x, y: float) =
  ## SVG Quadratic curve command.
  quadratic(vec2(x0,y0), vec2(x1,y1), vec2(x,y))
  x0 = x
  y0 = y

proc z() =
  ## SVG style end of shape command.
  line(vec2(x0, y0), vec2(x1,y1))

proc runCommands() =
  ## Runs a little command interpreter.
  var i = 0
  while true:
    let command = texelFetch(dataBuffer, i)
    if command == cmdExit: break
    elif command == cmdStartPath: startPath()
    elif command == cmdEndPath: endPath()
    elif command == cmdSolidFill:
      solidFill(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2),
        texelFetch(dataBuffer, i + 3),
        texelFetch(dataBuffer, i + 4)
      )
      i += 4
    elif command == cmdApplyOpacity:
      let opacity = texelFetch(dataBuffer, i + 1)
      backdropColor = backdropColor * opacity
      i += 1
    elif command == cmdTextureFill:
      #textureOn = texelFetch(dataBuffer, i + 1)
      tMat[0, 0] = texelFetch(dataBuffer, i + 1)
      tMat[0, 1] = texelFetch(dataBuffer, i + 2)
      tMat[0, 2] = 0.0
      tMat[1, 0] = texelFetch(dataBuffer, i + 3)
      tMat[1, 1] = texelFetch(dataBuffer, i + 4)
      tMat[1, 2] = 0.0
      tMat[2, 0] = texelFetch(dataBuffer, i + 5)
      tMat[2, 1] = texelFetch(dataBuffer, i + 6)
      tMat[2, 2] = 1.0
      textureFill(tMat)
      i += 6
    elif command == cmdSetMat:
      mat[0, 0] = texelFetch(dataBuffer, i + 1)
      mat[0, 1] = texelFetch(dataBuffer, i + 2)
      mat[0, 2] = 0.0
      mat[1, 0] = texelFetch(dataBuffer, i + 3)
      mat[1, 1] = texelFetch(dataBuffer, i + 4)
      mat[1, 2] = 0.0
      mat[2, 0] = texelFetch(dataBuffer, i + 5)
      mat[2, 1] = texelFetch(dataBuffer, i + 6)
      mat[2, 2] = 1.0
      i += 6
    elif command == cmdM:
      M(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2)
      )
      i += 2
    elif command == cmdL:
      L(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2)
      )
      i += 2
    elif command == cmdC:
      C(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2),
        texelFetch(dataBuffer, i + 3),
        texelFetch(dataBuffer, i + 4),
        texelFetch(dataBuffer, i + 5),
        texelFetch(dataBuffer, i + 6)
      )
      i += 6
    elif command == cmdQ:
      Q(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2),
        texelFetch(dataBuffer, i + 3),
        texelFetch(dataBuffer, i + 4),
      )
      i += 4
    elif command == cmdz: z()
    i += 1

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =
  ## Main entry point to this huge shader.

  crossCount = 0
  backdropColor = vec4(0, 0, 0, 0)

  screen = gl_FragCoord.xy
  runCommands()
  fragColor = backdropColor

  # fragColor += mainImage(gl_FragCoord.xy + vec2(0, 0.2)) / 4.0
  # fragColor += mainImage(gl_FragCoord.xy + vec2(0, 0.4)) / 4.0
  # fragColor += mainImage(gl_FragCoord.xy + vec2(0, 0.6)) / 4.0
  # fragColor += mainImage(gl_FragCoord.xy + vec2(0, 0.8)) / 4.0

  #fragColor = vec4(0, 0, 0, 0)

  # let first = texelFetch(dataBuffer, 0)
  # if gl_FragCoord.x > first:
  #   fragColor = vec4(0.0, 1.0, 1.0, 1.0)
  # else:
  #   fragColor = vec4(1.0, 1.0, 1.0, 1.0)

  #fragColor = fragColor * 0.5 + texture(textureAtlas, gl_FragCoord.xy / 100.0) * 0.5
