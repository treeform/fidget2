import vmath, fidget2/glsl

var dataBuffer*: Uniform[SamplerBuffer]
var textureAtlas*: Uniform[Sampler2d]

const
  cmdStartPath*: float32 = 1
  cmdEndPath*: float32 = 2
  cmdStyleFill*: float32 = 3
  #cmdMatrix*: float32 = 4
  cmdTexture*: float32 = 5
  cmdExit*: float32 = 0
  cmdM*: float32 = 10
  cmdL*: float32 = 11
  cmdC*: float32 = 12
  cmdz*: float32 = 20

var sourceColor: Vec4
var backdropColor: Vec4
# Stores the counting the number of path segments to
# figure out if pixel is in side or outside.
var crossCount: int = 0

var x0, y0, x1, y1: float
var uv: Vec2
var textureOn: float

proc M(x, y: float) =
  x1 = x
  x0 = x
  y1 = y
  y0 = y

proc line(a, b: Vec2) =
  if a.y == b.y:
    # horizontal lines should not have effect
    return
  # Y check to see if we can be affected by the line:
  if uv.y >= min(a.y, b.y) and uv.y < max(a.y, b.y):
    var xIntersect: float32
    if b.x != a.x:
      let
        m = (b.y - a.y) / (b.x - a.x)
        bb = a.y - m * a.x
      xIntersect = (uv.y - bb) / m
    else:
      xIntersect = a.x
    if xIntersect <= uv.x:
      # the x is to the left, count it
      if a.y - b.y > 0.0:
        crossCount += 1
      else:
        crossCount -= 1

proc L(x, y: float) =
  line(vec2(x0, y0), vec2(x, y))
  x0 = x
  y0 = y

proc interpolate(G1, G2, G3, G4: Vec2, t: float): Vec2 =
  let
    A = G4 - G1 + 3.0 * (G2 - G3)
    B = 3.0 * (G1 - 2.0 * G2 + G3)
    C = 3.0 * (G2 - G1)
    D = G1
  return t * (t * (t * A + B) + C) + D

proc bezier(A, B, C, D: Vec2) =
  var p = A
  let discretization = 10
  for t in 1 .. discretization:
    let
      q = interpolate(A, B, C, D, float(t)/float(discretization))
    line(p, q)

proc C(x1, y1, x2, y2, x, y: float) =
  bezier(vec2(x0,y0), vec2(x1,y1), vec2(x2,y2), vec2(x,y))
  x0 = x
  y0 = y

proc z() =
  line(vec2(x0, y0), vec2(x1,y1))

proc style(r, g, b, a: float) =
  sourceColor = vec4(r, g, b, a)

proc startPath() =
  crossCount = 0

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

proc draw() =
  if crossCount mod 2 != 0: # Even-Odd or Non-zero rule
    backdropColor = sourceColor

proc endPath() =
  draw()

proc SVG(inUv: Vec2) =
  uv = inUv * 400.0 # scaling

  var i = 0
  while true:
    let command = texelFetch(dataBuffer, i)
    if command == cmdExit: break
    elif command == cmdStartPath: startPath()
    elif command == cmdEndPath: endPath()
    elif command == cmdStyleFill:
      textureOn = 0.0
      style(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2),
        texelFetch(dataBuffer, i + 3),
        texelFetch(dataBuffer, i + 4)
      )
      i += 4
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
    elif command == cmdTexture:
      textureOn = texelFetch(dataBuffer, i + 1)
      i += 1
    elif command == cmdz: z()
    i += 1

proc mainImage(U0: Vec2) =
  let R = vec2(400, 400) # resolution
  var U = U0
  U = U / R.x
  SVG(U)

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =

  crossCount = 0
  backdropColor = vec4(0, 0, 0, 0)

  mainImage(gl_FragCoord.xy)
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

  # fragColor = fragColor * 0.5 + texture(textureAtlas, gl_FragCoord.xy / 100.0) * 0.5
