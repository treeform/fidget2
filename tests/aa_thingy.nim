import bumpy, chroma, pixie, print, random, vmath

var aaCount = 0

proc pixelCover(a0, b0: Vec2): float32 =
  ## Returns the amount of area a given segment sweeps to the right
  ## in a [0,0 to 1,1] box.
  var
    a = a0
    b = b0
    aI: Vec2
    bI: Vec2
    area: float32

  # Sort A on top.
  if a.y > b.y:
    let tmp = a
    a = b
    b = tmp

  if (b.y < 0 or a.y > 1) or # Above or bellow, no effect.
    (a.x > 1 and b.x > 1) or # To the right, no effect.
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

  doAssert aI.y <= bI.y
  # (side1 + side2) / 2 * height
  area += ((1 - aI.x) + (1 - bI.x)) / 2 * (bI.y - aI.y)

  return area

proc testCase(a0, b0: Vec2): float32 =
  var
    a = a0
    b = b0
  var image = newImage(200, 200)
  image.fill(rgba(255, 255, 255, 255))

  var p = newPath()
  p.moveTo(50, 50)
  p.lineTo(50, 150)
  p.lineTo(150, 150)
  p.lineTo(150, 50)
  p.closePath()
  var pathImage = newImage(200, 200)
  pathImage.fillPath(p, rgba(100, 100, 100, 255))
  image.draw(pathImage)

  p = newPath()
  p.moveTo(a.x, a.y)
  p.lineTo(b.x, b.y)
  pathImage = newImage(200, 200)
  pathImage.strokePath(p, rgba(255, 0, 0, 255), strokeWidth = 1.0)
  image.draw(pathImage)

  # Covnert to 0-1 cordiantes:
  a -= vec2(50, 50)
  a /= 100
  b -= vec2(50, 50)
  b /= 100

  print "--- line --- ", aaCount
  let area = pixelCover(a, b)

  p = newPath()
  p.moveTo(a0.x - 50, a0.y - 50)
  p.lineTo(1000, a0.y - 50)
  p.lineTo(1000, b0.y - 50)
  p.lineTo(b0.x - 50, b0.y - 50)
  p.closePath()
  pathImage = newImage(100, 100)
  pathImage.fillPath(p, rgba(0, 0, 0, 255))
  image.draw(pathImage, vec2(50, 50))

  var cover2 = 0.0
  for x in 0 ..< 100:
    for y in 0 ..< 100:
      if overlap(
        segment(a0, b0),
        segment(vec2(-1E6, y.float32 + 50), vec2(x.float32 + 50, y.float32 + 50))):
        cover2 += 1/100.0/100.0

  # let
  #   aError = not(aI.x >= 0 and aI.x <= 1 and aI.y >= 0 and aI.y <= 1)
  #   bError = not(bI.x >= 0 and bI.x <= 1 and bI.y >= 0 and bI.y <= 1)

  if abs(area - cover2) > 0.015: # pixelCover
    print "*** fail *** "
    print area, cover2
    # print abs(area - cover2), aError, bError
    # print aI, bI
    # print extraA, extraB

    image.writeFile("tests/aa/error.png")
    quit("broke!")

  #image.writeFile("tests/aa/aa_" & $aaCount & ".png")
  inc aaCount

  #print area
  return area

proc `~=`(a, b: float32): bool = abs(a - b) < 0.001

doAssert testCase(vec2(25, 25), vec2(175, 175)) ~= 0.5
doAssert testCase(vec2(115, 165), vec2(165, 115)) ~= 0.020
doAssert testCase(vec2(25, 25), vec2(175, 100)) ~= 0.140625
doAssert testCase(vec2(25, 25), vec2(100, 100)) ~= 0.375
doAssert testCase(vec2(25, 125), vec2(100, 100)) ~= 0.208
doAssert testCase(vec2(10, 0), vec2(10, 200)) ~= 1.0
doAssert testCase(vec2(200, 0), vec2(10, 200)) ~= 0.450

var r = initRand(2020)

for i in 0 .. 10000:
  discard testCase(
    vec2(r.rand(0.0 .. 200.0), r.rand(0.0 .. 200.0)),
    vec2(r.rand(0.0 .. 200.0), r.rand(0.0 .. 200.0)))
