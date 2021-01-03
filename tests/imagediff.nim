import pixie, chroma

proc imageDiff*(master, image: Image): (float32, Image) =
  var
    diffImage = newImage(master.width, master.height)
    diffScore = 0
    diffTotal = 0

  var image = image.subImage(1, 1, master.width, master.height)

  for x in 0 ..< min(image.width, master.width):
    for y in 0 ..< min(image.height, master.height):
      let
        m = master.getRgbaUnsafe(x, y)
        u = image.getRgbaUnsafe(x, y)
      var
        c: ColorRGBA
      let diff = (m.r.int - u.r.int) +
        (m.g.int - u.g.int) +
        (m.b.int - u.b.int)
      c.r = abs(m.a.int - u.a.int).clamp(0, 255).uint8
      c.g = (diff).clamp(0, 255).uint8
      c.b = (-diff).clamp(0, 255).uint8
      c.a = 255
      diffScore += abs(m.r.int - u.r.int) +
        abs(m.g.int - u.g.int) +
        abs(m.b.int - u.b.int) +
        abs(m.a.int - u.a.int)
      diffTotal += 255 * 4
      diffImage.setRgbaUnsafe(x, y, c)
  return (100 * diffScore.float32 / diffTotal.float32, diffImage)
