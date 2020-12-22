import pixie, chroma, vmath, bumpy, print, random

var aaCount = 0

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

  print "--- line --- ", aaCount #, a, b

  var
    aI = a
    bI = b
    area: float32
    extraA: (float32, float32)
    extraB: (float32, float32)

  if a.y > b.y:
    let tmp = aI
    a = b
    b = tmp

  if b.y < 0 or a.y > 1:
    # Above or bellow, no effect
    aI = vec2(1, 0)
    bI = vec2(1, 1)

  elif a.x > 1 and b.x > 1:
    # To the right, no effect
    aI = vec2(1, 0)
    bI = vec2(1, 1)

  elif a.x < 0 and b.x < 0:
    # Both to the left
    aI = vec2(0, max(a.y, 0))
    bI = vec2(0, min(b.y, 1))

  elif a.x == b.x:
    # Vertical line
    aI = vec2(clamp(a.x, 0, 1), max(a.y, 0))
    bI = vec2(clamp(b.x, 0, 1), min(b.y, 1))

  else:

    # y = mm*x + bb
    let
      mm: float32 = (b.y - a.y) / (b.x - a.x)
      bb: float32 = a.y - mm * a.x

    aI = vec2((0 - bb) / mm, 0)
    bI = vec2((1 - bb) / mm, 1)

    if aI.x < 0:
      let y = mm * 0 + bb
      extraA[0] = max(a.y, 0)
      extraA[1] = min(bb, 1)
      if extraA[0] > extraA[1]:
        extraA[0] = 0
        extraA[1] = 0
      if y > 1:
        aI = vec2(0, 1)
      elif y < 0:
        aI = vec2(0, 0)
      else:
        aI = vec2(0, y)
    if aI.x > 1:
      let y = mm * 1 + bb
      if y > 1:
        aI = vec2(1, 1)
      elif y < 0:
        aI = vec2(1, 0)
      else:
        aI = vec2(1, y)
    if bI.x < 0:
      let y = mm * 0 + bb
      extraB[0] = max(bb, 0)
      extraB[1] = min(b.y, 1)
      if extraB[0] > extraB[1]:
        extraB[0] = 0
        extraB[1] = 0
      if y > 1:
        bI = vec2(0, 1)
      elif y < 0:
        bI = vec2(0, 0)
      else:
        bI = vec2(0, y)
    if bI.x > 1:
      let y = mm * 1 + bb
      if y > 1:
        bI = vec2(1, 1)
      elif y < 0:
        bI = vec2(1, 0)
      else:
        bI = vec2(1, y)


  #doAssert aI.y < bI.y
  if aI.y > bI.y:
    #print "flip A up"
    let tmp = aI
    aI = bI
    bI = tmp

  if a.x >= 0 and a.x <= 1 and a.y >= 0 and a.y <= 1:
    aI = a

  if b.x >= 0 and b.x <= 1 and b.y >= 0 and b.y <= 1:
    bI = b

  # if a.x < 0 and b.x < 0:
  #   print "both to the left"
  #   if a.y > b.y:
  #     let tmp = aI
  #     a = b
  #     b = tmp
  #   aI = vec2(0, max(a.y, 0))
  #   bI = vec2(0, min(b.y, 1))
  # elif a.x > 1 and b.x > 0:
  #   aI = vec2(1, 0)
  #   bI = vec2(1, 1)
  # else:
  #   for s in [
  #     segment(vec2(0, 0), vec2(0, 1)),
  #     segment(vec2(0, 1), vec2(1, 1)),
  #     segment(vec2(1, 1), vec2(1, 0)),
  #     segment(vec2(1, 0), vec2(0, 0))
  #   ]:
  #     var at: Vec2
  #     if intersects(s, segment(a, b), at):
  #       if hits == 0: aI = at
  #       if hits == 1: bI = at
  #       inc hits

  #   if hits == 0:
  #     aI = a
  #     bI = b

  #   if hits == 1:
  #     if a.x >= 0 and a.x < 1.0 and a.y > 0 and a.y < 1:
  #       bI = a
  #     else:
  #       bI = b

  #   if aI.y > bI.y:
  #     let tmp = aI
  #     aI = bI
  #     bI = tmp


  #print hits, aI, bI
  area += ((1 - aI.x) + (1 - bI.x)) / 2 * (bI.y - aI.y)
  area += extraA[1] - extraA[0]
  area += extraB[1] - extraB[0]

  # print extraA, extraB

  #print area

  a = aI * 100
  a = a + vec2(50, 50)
  b = bI * 100
  b = b + vec2(50, 50)

  p = newPath()
  p.moveTo(a.x, a.y)
  p.lineTo(150, a.y)
  p.lineTo(150, b.y)
  p.lineTo(b.x, b.y)
  p.closePath()
  pathImage = newImage(200, 200)
  pathImage.fillPath(p, rgba(0, 0, 0, 255))
  image.draw(pathImage)

  extraA[0] = extraA[0] * 100 + 50
  extraA[1] = extraA[1] * 100 + 50
  extraB[0] = extraB[0] * 100 + 50
  extraB[1] = extraB[1] * 100 + 50

  p = newPath()
  p.moveTo(50, extraA[0])
  p.lineTo(150, extraA[0])
  p.lineTo(150, extraA[1])
  p.lineTo(50, extraA[1])
  p.closePath()
  pathImage = newImage(200, 200)
  pathImage.fillPath(p, rgba(0, 0, 0, 255))
  image.draw(pathImage)

  p = newPath()
  p.moveTo(50, extraB[0])
  p.lineTo(150, extraB[0])
  p.lineTo(150, extraB[1])
  p.lineTo(50, extraB[1])
  p.closePath()
  pathImage = newImage(200, 200)
  pathImage.fillPath(p, rgba(0, 0, 0, 255))
  image.draw(pathImage)

  # var cover = 0
  # for x in 0 ..< 200:
  #   for y in 0 ..< 200:
  #     if image[x, y] == rgba(0,0,0,255):
  #       cover += 1
  # let coverF = cover/100/100

  var cover2 = 0.0
  for x in 0 ..< 100:
    for y in 0 ..< 100:
      if overlap(
        segment(a0, b0),
        segment(vec2(-1E6, y.float32 + 50), vec2(x.float32 + 50, y.float32 + 50))):
          cover2 += 1/100.0/100.0

  let
    aError = not(aI.x >= 0 and aI.x <= 1 and aI.y >= 0 and aI.y <= 1)
    bError = not(bI.x >= 0 and bI.x <= 1 and bI.y >= 0 and bI.y <= 1)

  if aError or bError or abs(area - cover2) > 0.015:
    print "*** fail *** "
    print area, cover2
    print abs(area - cover2), aError, bError
    print aI, bI
    print extraA, extraB

    p = newPath()
    p.moveTo(a.x, a.y)
    p.lineTo(b.x, b.y)
    pathImage = newImage(200, 200)
    pathImage.strokePath(p, rgba(0, 255, 0, 255), strokeWidth = 2.0)
    image.draw(pathImage)

    p = newPath()
    p.moveTo(50, extraA[0])
    p.lineTo(50, extraA[1])
    pathImage = newImage(200, 200)
    pathImage.strokePath(p, rgba(0, 255, 0, 255), strokeWidth = 2.0)
    image.draw(pathImage)

    p = newPath()
    p.moveTo(50, extraB[0])
    p.lineTo(50, extraB[1])
    pathImage = newImage(200, 200)
    pathImage.strokePath(p, rgba(0, 255, 0, 255), strokeWidth = 2.0)
    image.draw(pathImage)

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
