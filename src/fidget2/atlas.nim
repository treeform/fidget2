import tables, bumpy, pixie, print

type
  CpuAtlas* = ref object
    entires*: Table[string, Rect]
    image*: Image
    heights*: seq[uint16]
    margin*: int

proc newCpuAtlas*(size, margin: int): CpuAtlas =
  result = CpuAtlas()
  result.image = newImage(size, size)
  result.margin = margin
  result.heights = newSeq[uint16](size)

proc findEmptyRect(atlas: CpuAtlas, width, height: int): Rect =
  var imgWidth = width + atlas.margin * 2
  var imgHeight = height + atlas.margin * 2

  var at: (int, int)
  block bothLoops:
    for y in 0 ..< atlas.image.height:
      for x in 0 ..< atlas.image.width:
        #print x, atlas.heights[x]
        if y < atlas.heights[x].int:
          continue

        # Is it consecutive?
        var fit = true
        for x1 in 0 ..< imgWidth:
          if x + x1 >= atlas.image.width:
            # Stick out on the right
            fit = false
            break
          if y < atlas.heights[x + x1].int:
            # Stick out at the top.
            fit = false
            break

        if fit:
          # found!
          at = (x, y)
          break bothLoops

  if at[1] + imgHeight > atlas.image.height:
    raise newException(Exception, "Context Atlas is full")
    #ctx.grow()
    #return ctx.findEmptyRect(width, height)

  let top = uint16(at[1] + imgHeight)
  for x in at[0] ..< at[0] + imgWidth:
    atlas.heights[x] = top

  var rect = rect(
    float32(at[0] + atlas.margin),
    float32(at[1] + atlas.margin),
    float32(width),
    float32(height),
  )

  return rect

proc put*(atlas: CpuAtlas, name: string, image: Image) =
  let r = atlas.findEmptyRect(image.height, image.width)
  atlas.image.draw(image, r.xy, blendMode = bmOverwrite)
