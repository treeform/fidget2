import vmath, shadercompiler

var FILL: float = 1.0
var CONTOUR: float = 1.0

var COL: Vec4
var fill: float = 1.0
var S: float = 1.0
var contrast: float = 1.0
var d: float = 1e38
var x0, y0, x1, y1: float
var uv: Vec2

proc M(x: float, y: float) =
  x1 = x
  x0 = x
  y1 = y
  y0 = y

proc line(p: Vec2, a: Vec2, b: Vec2): float =
  var
    pa: Vec2 = p - a
    ba: Vec2 = b - a
    # distance to segment
    d: Vec2 = pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)
  if (a.y > p.y) != (b.y > p.y) and pa.x < ba.x * pa.y / ba.y:
    S = -S    # track interior vs exterior
  return dot(d, d) # optimization by deferring sqrt

proc L(x: float, y: float) =
  d = min(d, line(uv, vec2(x0, y0), vec2(x, y)))
  x0 = x
  y0 = y

proc interpolate(G1: Vec2, G2: Vec2, G3: Vec2, G4: Vec2, t: float): Vec2 =
  var
    A: Vec2 = G4 - G1 + 3.0 * (G2 - G3)
    B: Vec2 = 3.0 * (G1 - 2.0 * G2 + G3)
    C: Vec2 = 3.0 * (G2 - G1)
    D: Vec2 = G1
  return t * (t * (t * A + B) + C) + D

proc bezier(uv: Vec2, A: Vec2, B: Vec2, C: Vec2, D: Vec2): float =
  var
    p: Vec2 = A
    discretization: int = 10
  for t in 1 .. discretization:
    var q: Vec2 = interpolate(A, B, C, D, float(t)/float(discretization))
    var l: float = line(uv, p, q)
    d = min(d, l)
    p = q
  return d

proc C(x1: float, y1: float, x2: float, y2: float, x: float, y: float) =
  d = min(d, bezier(uv, vec2(x0,y0), vec2(x1,y1), vec2(x2,y2), vec2(x,y)))
  x0 = x
  y0 = y

proc z() =
  d = min(d, line(uv, vec2(x0, y0), vec2(x1,y1)))

proc style(f: float, c: Vec4) =
  fill = f
  S = 1.0
  COL = c

proc startPath() =
  d = 1e38

proc draw(d0: float, O: var Vec4) =
  var d: float = min(sqrt(d0) * contrast * 2.0, 1.0) # optimization by deferring sqrt here
  var value: float = 0.0
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

  # startPath()
  # style(FILL, vec4(0.45, 0.71, 0.10, 1.0))
  # M(100.0, 100.0)
  # L(100.0, 200.0)
  # L(225.0, 225.0)
  # L(200.0, 100.0)
  # L(100.0, 100.0)
  # z()
  # endPath(O)

  startPath()
  # left exterior arc
  style(FILL, vec4(0.45, 0.71, 0.10, 1.0))
  M(82.2115, 102.414)
  C(82.2115,102.414, 104.7155,69.211, 149.6485,65.777)
  L(149.6485,53.73)
  C(99.8795,57.727, 56.7818,99.879,  56.7818,99.879)
  C(56.7818,99.879, 81.1915,170.445, 149.6485,176.906)
  L(149.6485,164.102)
  C(99.4105,157.781, 82.2115,102.414, 82.2115,102.414)
  z()
  endPath(O)

  startPath()
  # left interior arc
  style(FILL, vec4(0.45, 0.71, 0.10, 1.0))
  M(149.6485,138.637)
  L(149.6485,150.363)
  C(111.6805,143.594, 101.1415,104.125, 101.1415,104.125)
  C(101.1415,104.125, 119.3715,83.93,   149.6485,80.656)
  L(149.6485,93.523)
  C(149.6255,93.523, 149.6095,93.516,  149.5905,93.516)
  C(133.6995,91.609, 121.2855,106.453,  121.2855,106.453)
  C(121.2855,106.453, 128.2425,131.445, 149.6485,138.637)
  endPath(O)

  startPath()
  # right main plate
  style(FILL, vec4(0.45, 0.71, 0.10, 1.0))
  M(149.6485,31.512)
  L(149.6485,53.73)
  C(151.1095,53.617,  152.5705,53.523,  154.0395,53.473)
  C(210.6215,51.566,  247.4885,99.879,  247.4885,99.879)
  C(247.4885,99.879,  205.1455,151.367, 161.0315,151.367)
  C(156.9885,151.367, 153.2035,150.992, 149.6485,150.363)
  L(149.6485,164.102)
  C(152.6885,164.488, 155.8405,164.715, 159.1295,164.715)
  C(200.1805,164.715, 229.8675,143.75,  258.6135,118.937)
  C(263.3795,122.754, 282.8915,132.039, 286.9025,136.105)
  C(259.5705,158.988, 195.8715,177.434, 159.7585,177.434)
  C(156.2775,177.434, 152.9345,177.223, 149.6485,176.906)
  L(149.6485,196.211)
  L(305.6805,196.211)
  L(305.6805,31.512)
  L(149.6485,31.512)
  z()
  endPath(O)

  startPath()
  # right interior arc
  style(FILL, vec4(0.45, 0.71, 0.10, 1.0))
  M(149.6485,80.656)
  L(149.6485,65.777)
  C(151.0945,65.676, 152.5515,65.598, 154.0395,65.551)
  C(194.7275,64.273, 221.4225,100.516, 221.4225,100.516)
  C(221.4225,100.516, 192.5905,140.559, 161.6765,140.559)
  C(157.2275,140.559, 153.2385,139.844, 149.6485,138.637)
  L(149.6485,93.523)
  C(165.4885,95.437, 168.6765,102.434, 178.1995,118.309)
  L(199.3795,100.449)
  C(199.3795,100.449, 183.9185,80.172, 157.8555,80.172)
  C(155.0205,80.172, 152.3095,80.371, 149.6485,80.656)
  endPath(O)

proc mainImage(O: var Vec4, U0: Vec2) =
  O = vec4(1)
  var R = vec2(1000, 1000) # resolution
  var U = U0
  U.y = R.y - U.y
  U = U / R.x
  SVG(U, O)

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =

  mainImage(fragColor, gl_FragCoord.xy)

  # fragColor = vec4(0, 0, 0, 0)
