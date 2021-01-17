import chroma, glsl, gpurender, gpushader, math, pixie, schema, vmath

proc drawCompleteZpuFrame*(node: Node): pixie.Image =
  viewPortWidth = node.absoluteBoundingBox.w.int
  viewPortHeight = node.absoluteBoundingBox.h.int
  setupRender(node)
  node.readyImages()

  drawNode(node, 0)

  dataBufferSeq.add(cmdExit.float32)

  textureAtlasSampler.image = textureAtlas.image

  var image = newImage(viewPortWidth, viewPortHeight)
  dataBuffer.data = dataBufferSeq

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      # if x != 100 or y != 100:
      #   continue
      var color: Vec4
      svgMain(vec4(x.float32 + 0.5, y.float32 + 0.5, 0, 1), color)
      image.setRgbaUnsafe(x, y, rgba(
        (color.x * 255).uint8,
        (color.y * 255).uint8,
        (color.z * 255).uint8,
        (color.w * 255).uint8
      ))

  return image

proc getIndexAt*(node: Node, mousePos: Vec2): int =
  setupRender(node)
  drawNode(node, 0)

  dataBufferSeq.add(cmdExit.float32)

  textureAtlasSampler.image = textureAtlas.image

  dataBuffer.data = dataBufferSeq

  var color: Vec4
  svgMain(vec4(mousePos.x, mousePos.y, 0, 1), color)

  return topIndex.int
