import chroma, fidget2, pixie, math, vmath, glsl, gpushader, gpurender, pixie

proc drawCompleteZpuFrame*(node: Node): pixie.Image =
  setupRender(node)

  drawNode(node, 0)

  dataBufferSeq.add(cmdExit)

  textureAtlasSampler.image = textureAtlas.image #readImage("tests/test512.png")

  var image = newImage(viewPortWidth, viewPortHeight)
  dataBuffer.data = dataBufferSeq

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      # if x != 197 or y != 79:
      #   continue

      var color: Vec4
      svgMain(vec4(x.float32, y.float32, 0, 1), color)
      image.setRgbaUnsafe(x, y, rgba(
        (color.x * 255).uint8,
        (color.y * 255).uint8,
        (color.z * 255).uint8,
        (color.w * 255).uint8
      ))

  return image
