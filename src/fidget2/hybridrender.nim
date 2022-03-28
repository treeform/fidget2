import bumpy, math, opengl, pixie, schema, windy, tables, vmath,
  boxy, internal, cpurender, layout, os, perf, nodes, loader, common

export cpurender.underMouse

var
  bxy*: Boxy

proc quasiEqual(a, b: Rect): bool =
  ## Quasi equal. Equal everything except integer translation.
  ## Used for redraw only if node changed positions in whole pixels.
  a.w == b.w and a.h == b.h and
    a.x.fractional == b.x.fractional and
    a.y.fractional == b.y.fractional

proc willDrawSomething(node: Node): bool =
  ## Checks if node will draw something, or its fully transparent with no fills
  ## or strokes.
  if not node.visible or node.opacity == 0:
    return false

  if node.pixelBox.w.int == 0 or node.pixelBox.h == 0:
    return false

  if node.collapse:
    # TODO do children
    return true

  if node.clipsContent:
    # draws clipping mask
    return true

  for fill in node.fills:
    if fill.kind != schema.PaintKind.pkSolid or fill.color.a != 0:
      return true

  for stroke in node.strokes:
    if stroke.kind != schema.PaintKind.pkSolid or stroke.color.a != 0:
      return true

  return false

proc isSimpleImage*(node: Node): bool =
  ## Checks if node is a simple image and can be drawn purly with GPU and
  ## not go through CPU rendering path to resize it.
  node.strokes.len == 0 and
  node.fills.len == 1 and
  node.fills[0].kind == schema.PaintKind.pkImage and
  node.cornerRadius == 0

proc drawToAtlas(node: Node, level: int) {.measure.} =
  ## Draw the nodes into the atlas (and setup pixel box).

  if not node.visible or node.opacity == 0:
    node.markTreeClean()
    return

  let prevMat = mat
  mat = mat * node.transform()

  node.mat = mat # needed for picking

  var pixelBox = computeIntBounds(node, mat, node.kind == BooleanOperationNode)

  if node.frozenId.len > 0:
    node.pixelBox = pixelBox
    mat = prevMat
    return

  if node.dirty or not quasiEqual(pixelBox, node.pixelBox):

    # if not quasiEqual(pixelBox, node.pixelBox):
    #   echo "node size changed"

    # if node.dirty:
    #   echo "drawToAtlas: ", node.name, " is dirty"

    node.dirty = false
    # compute bounds
    node.pixelBox = pixelBox

    ## Any special thing we can't do on the GPU
    ## we have to collapse the node so that CPU draws it all
    ## If we are looking to optimize some thing is to take
    ## more things away from CPU and give them to GPU

    # Can't draw booleans on the GPU.
    if node.kind == BooleanOperationNode:
      node.collapse = true

    # Can't draw blending layers on the GPU.
    for child in node.children:
      if child.blendMode != NormalBlend:
        node.collapse = true
        break

    # Can't draw masks on the GPU.
    # for child in node.children:
    #   if child.isMask:
    #     node.collapse = true
    #     break

    # Can't draw clips content on the GPU.
    # if level != 0 and node.clipsContent:
    #   node.collapse = true

    # Can't draw effects on the GPU.
    if node.effects.len != 0:
      node.collapse = true

    if node.willDrawSomething():

      if node.isSimpleImage:
        let paint = node.fills[0]
        if paint.imageRef notin bxy:
          var image: Image
          if paint.imageRef notin imageCache:
            try:
              image = readImage(figmaImagePath(paint.imageRef))
            except PixieError:
              return
            imageCache[paint.imageRef] = image
          else:
            image = imageCache[paint.imageRef]
          bxy.addImage(paint.imageRef, image)

      else:
        layer = newImage(node.pixelBox.w.int, node.pixelBox.h.int)
        let prevBoundsMat = mat
        mat = translate(-node.pixelBox.xy) * mat
        node.drawNodeInternal(withChildren=node.collapse)
        bxy.addImage(node.id, layer, genMipmaps=false)
        mat = prevBoundsMat

      if node.clipsContent:
        layer = newImage(node.pixelBox.w.int, node.pixelBox.h.int)
        layer.fill(color(1,1,1,1))
        let prevBoundsMat = mat
        mat = translate(-node.pixelBox.xy) * mat
        var mask = node.maskSelfImage()
        layer.draw(mask, blendMode = MaskBlend)

        bxy.addImage(node.id & ".mask", layer, genMipmaps=false)
        mat = prevBoundsMat
    else:
      bxy.removeImage(node.id)

  else:
    # Update pixel bounds even if no redraw was needed.
    node.pixelBox = pixelBox

  if not node.collapse:
    for child in node.children:
      drawToAtlas(child, level + 1)
  else:
    node.markTreeClean()

  mat = prevMat

proc mat4(m: Transform): Mat4 =
  result = mat4()
  result[0, 0] = m[0][0]
  result[0, 1] = m[1][0]
  result[1, 0] = m[0][1]
  result[1, 1] = m[1][1]
  result[3, 0] = m[0][2]
  result[3, 1] = m[1][2]

proc mat4(m: Mat3): Mat4 =
  result = mat4()
  result[0, 0] = m[0, 0]
  result[0, 1] = m[0, 1]
  result[1, 0] = m[1, 0]
  result[1, 1] = m[1, 1]
  result[3, 0] = m[2, 0]
  result[3, 1] = m[2, 1]

proc drawWithAtlas(node: Node) {.measure.} =
  # Draw the nodes using atlas.
  if not node.visible or node.opacity == 0:
    return

  var pushedMasks = 0

  if node.frozen:
    bxy.saveTransform()
    bxy.applyTransform(node.mat.mat4)
    let size = bxy.getImageSize(node.frozenId).vec2
    bxy.scale(vec2(
      node.size.x / size.x,
      node.size.y / size.y
    ))
    bxy.drawImage(node.frozenId, pos = vec2(0, 0))
    bxy.restoreTransform()

  elif node.isSimpleImage:
    let paint = node.fills[0]
    if paint.imageRef in bxy:
      let image = imageCache[paint.imageRef]
      case paint.scaleMode:
      of FillScaleMode:
        let
          ratioW = image.width.float32 / node.size.x
          ratioH = image.height.float32 / node.size.y
          scale = min(ratioW, ratioH)
        let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
        bxy.saveTransform()
        bxy.applyTransform(node.mat.mat4)
        bxy.translate(topRight)
        bxy.scale(vec2(1/scale))
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        bxy.restoreTransform()

      of FitScaleMode:
        let
          ratioW = image.width.float32 / node.size.x
          ratioH = image.height.float32 / node.size.y
          scale = max(ratioW, ratioH)
        let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
        bxy.saveTransform()
        bxy.applyTransform(node.mat.mat4)
        bxy.translate(topRight)
        bxy.scale(vec2(1/scale))
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        bxy.restoreTransform()
      of StretchScaleMode:
        var mat: Mat3
        mat[0, 0] = paint.imageTransform[0][0]
        mat[0, 1] = paint.imageTransform[0][1]
        mat[1, 0] = paint.imageTransform[1][0]
        mat[1, 1] = paint.imageTransform[1][1]
        mat[2, 0] = paint.imageTransform[0][2]
        mat[2, 1] = paint.imageTransform[1][2]
        mat[2, 2] = 1
        mat = mat.inverse()
        mat[2, 0] = mat[2, 0] * node.size.x
        mat[2, 1] = mat[2, 1] * node.size.y
        let
          ratioW = image.width.float32 / node.size.x
          ratioH = image.height.float32 / node.size.y
          scale = min(ratioW, ratioH)
        mat = mat * scale(vec2(1/scale))
        bxy.saveTransform()
        bxy.applyTransform(node.mat.mat4)
        bxy.applyTransform(mat.mat4)
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        bxy.restoreTransform()
      of TileScaleMode:
        discard
        # bxy.saveTransform()
        # bxy.translate(node.pixelBox.xy)
        # bxy.applyTransform(paint.imageTransform.mat4)
        # print node.name, node.pixelBox, paint.imageTransform
        # bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        # bxy.restoreTransform()

  elif node.id in bxy:
    doAssert node.pixelBox.x.fractional == 0
    doAssert node.pixelBox.y.fractional == 0
    doAssert node.willDrawSomething()
    bxy.drawImage(node.id, pos = node.pixelBox.xy)

  var hasMask = false
  for child in node.children:
    if child.isMask:
      hasMask = true

  if node.clipsContent or node.opacity < 1.0 or hasMask:
    bxy.pushLayer()
    inc pushedMasks

  if not node.collapse:
    var needsMask: seq[Node]
    for child in node.children:
      if child.isMask:
        needsMask.add(child)
      else:
        if needsMask.len == 0:
          drawWithAtlas(child)
        else:
          bxy.pushLayer()
          drawWithAtlas(child)
          bxy.pushLayer()
          for mask in needsMask:
            drawWithAtlas(mask)
          bxy.popLayer(blendMode = MaskBlend)
          bxy.popLayer()

  if node.clipsContent:
    bxy.pushLayer()
    bxy.drawImage(node.id & ".mask", pos = node.pixelBox.xy)
    bxy.popLayer(blendMode = MaskBlend)

  for i in 0 ..< pushedMasks:
    bxy.popLayer(tintColor = color(1, 1, 1, node.opacity))

proc drawToScreen*(screenNode: Node) {.measure.} =
  ## Draw the current node onto the screen.

  if window.size.vec2 != screenNode.size:
    if window.style == DecoratedResizable:
      # Stretch the current frame to fit the window.
      screenNode.size = window.size.vec2
    else:
      # Stretch the window to fit the current frame.
      window.size = screenNode.size.ivec2

  bxy.beginFrame(window.size, clearFrame=clearFrame)

  for i in 0 ..< 2:
    # TODO: figure out how to call layout only once.
    computeLayout(nil, screenNode)

  # Setup proper matrix for drawing.
  mat = scale(vec2(window.contentScale, window.contentScale))
  if rtl:
    mat = mat * scale(vec2(-1, 1)) * translate(vec2(-screenNode.size.x, 0))
  mat = mat * screenNode.transform().inverse()

  drawToAtlas(screenNode, 0)

  drawWithAtlas(screenNode)
  bxy.endFrame()

proc setupWindow*(
  frameNode: Node,
  size: IVec2,
  visible = true,
  style = DecoratedResizable
) =
  window = newWindow("loading...", size, visible=visible, msaa=msaa8x)
  window.style = style

  window.makeContextCurrent()

  when not defined(emscripten):
    # Load opengl.
    loadExtensions()

  echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
  echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
  echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))
  echo "GL_SHADING_LANGUAGE_VERSION: ", cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

  # Setup bxy
  bxy = newBoxy()

proc readGpuPixelsFromScreen*(): pixie.Image =
  ## Read the GPU pixels from screen.
  ## Use for debugging and tests only.
  var screen = newImage(window.size.x.int, window.size.y.int)
  glReadPixels(
    0, 0,
    screen.width.Glint, screen.height.Glint,
    GL_RGBA, GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  screen.flipVertical()
  return screen

proc freeze*(node: Node, scaleFactor = 1.0f) =
  let s = scaleFactor
  if node.isSimpleImage:
    return
  if node.isInstance:
    node.frozen = true
    node.frozenId = node.masterComponent.id & ".frozen"
    if node.frozenId notin bxy:
      mat = scale(vec2(s, s))
      layer = newImage((node.size.x * s).int, (node.size.y * s).int)
      node.drawNodeInternal(withChildren=true)
      bxy.addImage(node.frozenId, layer, genMipmaps=true)
  else:
    echo "Warning: Freezing non instance"
    node.frozen = true
    node.frozenId = node.id
    if node.frozenId notin bxy:
      mat = scale(vec2(s, s))
      layer = newImage((node.size.x * s).int, (node.size.y * s).int)
      node.drawNodeInternal(withChildren=true)
      bxy.addImage(node.frozenId, layer, genMipmaps=true)
