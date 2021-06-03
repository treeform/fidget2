import bumpy, pixie, tables

type
  CpuAtlas* = ref object
    ## Texture atlas.
    entries*: Table[string, Rect]
    image*: Image
    heights*: seq[uint16]
    margin*: int
    dirty*: bool # Has the atlas changed and needs to be re-uploaded?

proc newCpuAtlas*(size, margin: int): CpuAtlas =
  ## Creates a new CPU based texture atlas.
  result = CpuAtlas()
  result.image = newImage(size, size)
  result.margin = margin
  result.heights = newSeq[uint16](size)

proc grow(atlas: CpuAtlas)

proc findEmptyRect*(atlas: CpuAtlas, width, height: int): Rect =
  ## Low level function to find an empty rectangle in the atlas,
  ## or resizes it.
  var imgWidth = width + atlas.margin * 2
  var imgHeight = height + atlas.margin * 2

  if imgWidth > atlas.image.width or imgHeight > atlas.image.height:
    atlas.grow()
    return atlas.findEmptyRect(width, height)

  var at: (int, int)
  block bothLoops:
    for y in 0 ..< atlas.image.height - imgHeight:
      for x in 0 ..< atlas.image.width:
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
            # Ran into the hights.
            fit = false
            break

        if fit:
          # found!
          at = (x, y)
          break bothLoops

    atlas.grow()
    return atlas.findEmptyRect(width, height)

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
  ## Adds an image to the atlas.
  let rect = atlas.findEmptyRect(image.width, image.height)
  atlas.entries[name] = rect
  atlas.image.draw(image, rect.xy, blendMode = bmOverwrite)
  atlas.dirty = true

proc size*(atlas: CpuAtlas): int =
  ## Returns the size of the atlas.
  atlas.image.width

proc grow(atlas: CpuAtlas) =
  ## Grows the atlas by 2. All current entries remain in their place.
  var image = newImage(atlas.size*2, atlas.size*2)
  image.draw(atlas.image)
  atlas.image = image
  atlas.heights.setLen(atlas.size*2)
