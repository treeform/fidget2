import bumpy, math, opengl, pixie, schema, staticglfw, tables, vmath,
  boxy, common, cpurender, layout, os, perf, nodes, loader

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

proc isSimpleImage(node: Node): bool =
  ## Checks if node is a simple image and can be drawn purly with GPU and
  ## not go through CPU rendering path to resize it.
  node.strokes.len == 0 and
  node.fills.len == 1 and
  node.fills[0].kind == schema.PaintKind.pkImage

proc drawToAtlas(node: Node, level: int) {.measure.} =
  ## Draw the nodes into the atlas (and setup pixel box).
  ##

  if not node.visible or node.opacity == 0:
    node.markTreeClean()
    return

  let prevMat = mat
  mat = mat * node.transform()

  node.mat = mat # needed for picking

  var pixelBox = computeIntBounds(node, mat, node.kind == nkBooleanOperation)

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
    if node.kind == nkBooleanOperation:
      node.collapse = true

    # Can't draw blending layers on the GPU.
    for child in node.children:
      if child.blendMode != bmNormal:
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
        #print node.name
        var mask = node.maskSelfImage()
        #layer.writeFile("mask.png")
        layer.draw(mask, blendMode = bmMask)
        #layer.writeFile("layer.png")

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
  result[2, 0] = m[0][2]
  result[2, 1] = m[1][2]

proc mat4(m: Mat3): Mat4 =
  result = mat4()
  result[0, 0] = m[0][0]
  result[0, 1] = m[0][1]
  result[1, 0] = m[1][0]
  result[1, 1] = m[1][1]
  result[2, 0] = m[2][0]
  result[2, 1] = m[2][1]

proc drawWithAtlas(node: Node) {.measure.} =
  # Draw the nodes using atlas.
  if not node.visible or node.opacity == 0:
    return

  var pushedMasks = 0

  if node.isSimpleImage:
    let paint = node.fills[0]
    if paint.imageRef in bxy:
      let image = imageCache[paint.imageRef]
      case paint.scaleMode:
      of smFill:
        let
          ratioW = image.width.float32 / node.size.x
          ratioH = image.height.float32 / node.size.y
          scale = min(ratioW, ratioH)
        let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
        bxy.saveTransform()
        bxy.translate(node.pixelBox.xy)
        bxy.translate(topRight)
        bxy.scale(vec2(1/scale))
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        bxy.restoreTransform()

      of smFit:
        let
          ratioW = image.width.float32 / node.size.x
          ratioH = image.height.float32 / node.size.y
          scale = max(ratioW, ratioH)
        let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
        bxy.saveTransform()
        bxy.translate(node.pixelBox.xy)
        bxy.translate(topRight)
        bxy.scale(vec2(1/scale))
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        bxy.restoreTransform()
      of smStretch:
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
        bxy.translate(node.pixelBox.xy)
        bxy.applyTransform(mat.mat4)
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0))
        bxy.restoreTransform()
      of smTile:
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

    if node.clipsContent:
      bxy.beginMask()
      bxy.drawImage(node.id & ".mask", pos = node.pixelBox.xy)
      bxy.endMask()
      inc pushedMasks

    bxy.drawImage(node.id, pos = node.pixelBox.xy)

  if not node.collapse:
    for child in node.children:
      if child.isMask:
        bxy.beginMask()
        drawWithAtlas(child)
        bxy.endMask()
        inc pushedMasks
      else:
        drawWithAtlas(child)

  for i in 0 ..< pushedMasks:
    bxy.popMask()

proc drawToScreen*(screenNode: Node) {.measure.} =
  ## Draw the current node onto the screen.

  if windowSize != screenNode.size:
    if windowResizable:
      # Stretch the current frame to fit the window.
      screenNode.size = windowSize
    else:
      # Stretch the window to fit the current frame.
      window.setWindowSize(screenNode.size.x.cint, screenNode.size.y.cint)

  viewportSize = (screenNode.size * pixelRatio).ceil


  bxy.beginFrame(viewportSize.ivec2)

  for i in 0 ..< 2:
    # TODO: figure out how to call layout only once.
    computeLayout(nil, screenNode)

  # echo "before"
  # screenNode.printDirtyStatus()

  # Setup proper matrix for drawing.
  mat = scale(vec2(pixelRatio, pixelRatio))
  if rtl:
    mat = mat * scale(vec2(-1, 1)) * translate(vec2(-screenNode.size.x, 0))
  mat = mat * screenNode.transform().inverse()

  #mat = mat * scale(vec2(-1, 1)) #* translate(vec2(-screenNode.size.x/2, 0))

  drawToAtlas(screenNode, 0)

  drawWithAtlas(screenNode)
  bxy.endFrame()

  # echo "after"
  # screenNode.printDirtyStatus()

proc setupWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true,
  decorated = true,
) =
  ## Opens a new glfw window that is ready to draw into.
  ## Also setups all the shaders and buffers.

  # Init glfw.
  let tmp = getCurrentDir()
  if init() == 0:
    raise newException(Exception, "Failed to intialize GLFW")
  setCurrentDir(tmp)

  # Open a window.
  if not vSync:
    # Disable V-Sync
    windowHint(DOUBLEBUFFER, false.cint)

  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  windowHint(SAMPLES, 0)
  windowHint(CONTEXT_VERSION_MAJOR, 4)
  windowHint(CONTEXT_VERSION_MINOR, 1)
  windowHint(DECORATED, decorated.cint)

  window = createWindow(
    viewportSize.x.cint, viewportSize.y.cint,
    "run_shaders",
    nil,
    nil)
  if window == nil:
    raise newException(Exception, "Failed to create GLFW window.")
  window.makeContextCurrent()

  when not defined(emscripten):
    # Load opengl.
    loadExtensions()

  echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
  echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
  echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))
  echo "GL_SHADING_LANGUAGE_VERSION: ", cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))


  var maxLayers: GLint
  glGetIntegerv(GL_MAX_ARRAY_TEXTURE_LAYERS, maxLayers.addr)
  echo "GL_MAX_ARRAY_TEXTURE_LAYERS: ", maxLayers

  var textureSize: GLint
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, textureSize.addr)
  echo "GL_MAX_TEXTURE_SIZE: ", textureSize

  var texture3dSize: GLint
  glGetIntegerv(GL_MAX_3D_TEXTURE_SIZE, texture3dSize.addr)
  echo "GL_MAX_3D_TEXTURE_SIZE: ", texture3dSize

  # Setup bxy
  bxy = newBoxy()

proc readGpuPixelsFromScreen*(): pixie.Image =
  ## Read the GPU pixels from screen.
  ## Use for debugging and tests only.
  var screen = newImage(viewportSize.x.int, viewportSize.y.int)
  glReadPixels(
    0, 0,
    screen.width.Glint, screen.height.Glint,
    GL_RGBA, GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  screen.flipVertical()
  return screen
