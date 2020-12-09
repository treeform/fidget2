import vmath, shadercompiler

var dataBuffer: Uniform[SamplerBuffer]

const
  cmdStartPath*: float32 = 1
  cmdEndPath*: float32 = 2
  cmdStyleFill*: float32 = 3
  cmdExit*: float32 = 4
  cmdM*: float32 = 10
  cmdL*: float32 = 11
  cmdC*: float32 = 12
  cmdz*: float32 = 20


var FILL = 1.0
var CONTOUR = 1.0

var COL: Vec4
var fill = 1.0
var S = 1.0
var contrast = 1.0
var d = 1e38
var x0, y0, x1, y1: float
var uv: Vec2

proc M(x, y: float) =
  x1 = x
  x0 = x
  y1 = y
  y0 = y

proc line(p, a, b: Vec2): float =
  let
    pa = p - a
    ba = b - a
    # distance to segment
    d = pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)
  if (a.y > p.y) != (b.y > p.y) and (pa.x < ba.x * pa.y / ba.y):
    S = -S # track interior vs exterior
  return dot(d, d) # optimization by deferring sqrt

proc L(x, y: float) =
  d = min(d, line(uv, vec2(x0, y0), vec2(x, y)))
  x0 = x
  y0 = y

proc interpolate(G1, G2, G3, G4: Vec2, t: float): Vec2 =
  let
    A = G4 - G1 + 3.0 * (G2 - G3)
    B = 3.0 * (G1 - 2.0 * G2 + G3)
    C = 3.0 * (G2 - G1)
    D = G1
  return t * (t * (t * A + B) + C) + D

proc bezier(uv, A, B, C, D: Vec2): float =
  var p = A
  let discretization = 10
  for t in 1 .. discretization:
    let
      q = interpolate(A, B, C, D, float(t)/float(discretization))
      l = line(uv, p, q)
    d = min(d, l)
    p = q
  return d

proc C(x1, y1, x2, y2, x, y: float) =
  d = min(d, bezier(uv, vec2(x0,y0), vec2(x1,y1), vec2(x2,y2), vec2(x,y)))
  x0 = x
  y0 = y

proc z() =
  d = min(d, line(uv, vec2(x0, y0), vec2(x1,y1)))

proc style(f, r, g, b, a: float) =
  fill = f
  S = 1.0
  COL = vec4(r, g, b, a)

proc startPath() =
  d = 1e38

proc draw(d0: float, O: var Vec4) =
  # optimization by deferring sqrt here
  let d = min(sqrt(d0) * contrast * 2.0, 1.0)
  var value = 0.0
  if fill > 0.0:
    value = 0.5 + 0.5 * S * d
  else:
    value = d
  O = mix(COL, O, value) # paint

proc endPath(O: var Vec4) =
  draw(d, O)
  discard

proc SVG(inUv: Vec2, O: var Vec4) =
  uv = inUv * 400.0 # scaling
  contrast = 1.0

  var i = 0
  while true:
    let command = texelFetch(dataBuffer, i)
    if command == cmdExit: break
    if command == cmdStartPath: startPath()
    if command == cmdEndPath: endPath(O)
    if command == cmdStyleFill:
      style(
        FILL,
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2),
        texelFetch(dataBuffer, i + 3),
        texelFetch(dataBuffer, i + 4)
      )
      i += 4
    if command == cmdM:
      M(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2)
      )
      i += 2
    if command == cmdL:
      L(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2)
      )
      i += 2
    if command == cmdC:
      C(
        texelFetch(dataBuffer, i + 1),
        texelFetch(dataBuffer, i + 2),
        texelFetch(dataBuffer, i + 3),
        texelFetch(dataBuffer, i + 4),
        texelFetch(dataBuffer, i + 5),
        texelFetch(dataBuffer, i + 6)
      )
      i += 6
    if command == cmdz: z()
    i += 1

proc mainImage(O: var Vec4, U0: Vec2) =
  O = vec4(1)
  let R = vec2(1000, 1000) # resolution
  var U = U0
  U.y = R.y - U.y
  U = U / R.x
  SVG(U, O)

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =

  mainImage(fragColor, gl_FragCoord.xy)

  #fragColor = vec4(0, 0, 0, 0)

  # let first = texelFetch(dataBuffer, 0)
  # if gl_FragCoord.x > first:
  #   fragColor = vec4(0.0, 1.0, 1.0, 1.0)
  # else:
  #   fragColor = vec4(1.0, 1.0, 1.0, 1.0)
