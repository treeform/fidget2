import
  std/[tables, sets],
  boxy, bumpy, pixie, opengl, vmath, windy,
  common, cpurender, internal, layout, loader, inodes, measure, schema

export cpurender.underMouse

# Hybrid renderer is a renderer that uses the GPU for some things and the CPU for others.
# It tries to do fast work on the GPU and slow work on the CPU.
# It has a bunch of dirty flags to track what is dirty and needs to be redrawn.

var
  bxy*: Boxy
  usedImages: HashSet[string]

proc useImage(bxy: Boxy, name: string, image: Image) =
  ## Adds an image to the atlas.
  bxy.addImage(name, image, mipmaps=false)
  usedImages.incl(name)

proc quasiEqual(a, b: Rect): bool =
  ## Quasi-equal. Equals everything except integer translation.
  ## Used for redraw only if node changed positions in whole pixels.
  a.w == b.w and a.h == b.h and
    fract(a.x) == fract(b.x) and
    fract(a.y) == fract(b.y)

proc willDrawSomething(node: INode): bool =
  ## Checks if node will draw something, or it's fully transparent with no fills
  ## or strokes.
  if not node.visible or node.opacity == 0:
    return false

  if node.pixelBox.w.int == 0 or node.pixelBox.h == 0:
    return false

  if node.collapse:
    # TODO: Do children.
    return true

  if node.clipsContent:
    # Draws clipping mask.
    return true

  for fill in node.fills:
    if fill.kind != schema.PaintKind.pkSolid or fill.color.a != 0:
      return true

  for stroke in node.strokes:
    if stroke.kind != schema.PaintKind.pkSolid or stroke.color.a != 0:
      return true

  return false

proc isSimpleImage*(node: INode): bool =
  ## Checks if node is a simple image and can be drawn purely with GPU and
  ## not go through CPU rendering path to resize it.
  node.strokes.len == 0 and
  node.fills.len == 1 and
  node.fills[0].kind == schema.PaintKind.pkImage and
  node.fills[0].scaleMode == FitScaleMode and
  node.effects.len == 0 and
  node.blendMode == NormalBlend and
  node.cornerRadius == 0

proc rasterize(node: INode, level: int) {.measure.} =
  ## Draws the nodes into the atlas (and sets up the pixel box).

  if not node.visible or node.opacity == 0:
    node.markTreeClean()
    return

  # TODO: Move this to layout pass.
  let prevMat = mat
  mat = mat * node.transform()
  node.mat = mat # Needed for picking.
  node.pixelBox = computeIntBounds(node, mat, node.kind == BooleanOperationNode)

  if node.dirty:

    node.dirty = false

    ## Any special thing we can't do on the GPU
    ## we have to collapse the node so that CPU draws it all
    ## If we are looking to optimize some thing is to take
    ## more things away from CPU and give them to GPU

    # Can't draw booleans on the GPU.
    if node.kind == BooleanOperationNode:
      node.collapse = true

    # Can't draw blending layers on the GPU.
    # for child in node.children:
    #   if child.blendMode != NormalBlend:
    #     node.collapse = true
    #     break

    # Can't draw masks on the GPU.
    # for child in node.children:
    #   if child.isMask:
    #     node.collapse = true
    #     break

    # Can't draw clips content on the GPU.
    # if level != 0 and node.clipsContent:
    #   node.collapse = true

    # Can't draw effects on the GPU, except BackgroundBlur.
    if node.effects.len != 0:
      var onlyBackgroundBlur = true
      for e in node.effects:
        if e.visible and e.kind != BackgroundBlur:
          onlyBackgroundBlur = false
          break
      if not onlyBackgroundBlur:
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
          bxy.useImage(paint.imageRef, image)

      else:
        layer = newImage(node.pixelBox.w.int, node.pixelBox.h.int)
        let prevBoundsMat = mat
        mat = translate(-node.pixelBox.xy) * mat
        node.drawNodeInternal(withChildren=node.collapse)
        bxy.useImage(node.id, layer)
        mat = prevBoundsMat

      if node.clipsContent:
        layer = newImage(node.pixelBox.w.int, node.pixelBox.h.int)
        layer.fill(color(1,1,1,1))
        let prevBoundsMat = mat
        mat = translate(-node.pixelBox.xy) * mat
        var mask = node.maskSelfImage()
        layer.draw(mask, blendMode = MaskBlend)

        bxy.useImage(node.id & ".mask", layer)
        mat = prevBoundsMat

  if not node.collapse:
    for child in node.children:
      rasterize(child, level + 1)
  else:
    node.markTreeClean()

  mat = prevMat

proc composite(node: INode) {.measure.} =
  ## Draws the nodes from the atlas to the screen.
  if not node.visible or node.opacity == 0:
    return

  var pushedLayers = 0

  var hasMask = false
  for child in node.children:
    if child.isMask:
      hasMask = true

  if node.clipsContent or
    node.opacity < 1.0 or
    hasMask or
    node.blendMode != NormalBlend:
      bxy.pushLayer()
      inc pushedLayers

  # GPU BackgroundBlur: sample lower, blur, mask by this node, then composite.
  if node.effects.len > 0:
    var hasBackgroundBlur = false
    var bgRadius: float32
    for e in node.effects:
      if e.visible and e.kind == BackgroundBlur:
        hasBackgroundBlur = true
        bgRadius = e.radius
        break
    if hasBackgroundBlur:
      # Create a new layer and copy lower into it.
      bxy.pushLayer()
      bxy.copyLowerToCurrent()
      # Blur the copied layer in place.
      bxy.blurEffect(bgRadius)

      # Mask the blurred content by the node's transformed rectangle bounds.
      bxy.pushLayer()
      bxy.saveTransform()
      bxy.applyTransform(node.mat)
      bxy.drawRect(rect(vec2(0, 0), node.size), color(1, 1, 1, 1))
      bxy.restoreTransform()
      bxy.popLayer(blendMode = MaskBlend)

      # Composite masked blur over lower.
      bxy.popLayer()

  if node.isSimpleImage:
    let paint = node.fills[0]
    var color = color(1, 1, 1, paint.opacity)

    if paint.imageRef in bxy:
      let image = imageCache[paint.imageRef]
      case paint.scaleMode:
      # of FillScaleMode:
      #   let
      #     ratioW = image.width.float32 / node.size.x
      #     ratioH = image.height.float32 / node.size.y
      #     scale = min(ratioW, ratioH)
      #   let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
      #   bxy.saveTransform()
      #   bxy.applyTransform(node.mat)
      #   bxy.translate(topRight)
      #   bxy.scale(vec2(1/scale))
      #   bxy.drawImage(paint.imageRef, pos = vec2(0, 0), tint = color)
      #   bxy.restoreTransform()

      of FitScaleMode:
        let
          ratioW = image.width.float32 / node.size.x
          ratioH = image.height.float32 / node.size.y
          scale = max(ratioW, ratioH)
        let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
        bxy.saveTransform()
        bxy.applyTransform(node.mat)
        bxy.translate(topRight)
        bxy.scale(vec2(1/scale))
        bxy.drawImage(paint.imageRef, pos = vec2(0, 0), tint = color)
        bxy.restoreTransform()

      # of StretchScaleMode:
      #   var m: Mat3
      #   m[0, 0] = paint.imageTransform[0][0]
      #   m[0, 1] = paint.imageTransform[0][1]
      #   m[1, 0] = paint.imageTransform[1][0]
      #   m[1, 1] = paint.imageTransform[1][1]
      #   m[2, 0] = paint.imageTransform[0][2]
      #   m[2, 1] = paint.imageTransform[1][2]
      #   m[2, 2] = 1
      #   m = m.inverse()
      #   m[2, 0] = m[2, 0] * node.size.x
      #   m[2, 1] = m[2, 1] * node.size.y
      #   let
      #     ratioW = image.width.float32 / node.size.x
      #     ratioH = image.height.float32 / node.size.y
      #     scale = min(ratioW, ratioH)
      #   m = m * scale(vec2(1/scale))
      #   bxy.saveTransform()
      #   bxy.applyTransform(node.mat)
      #   bxy.applyTransform(m)
      #   bxy.drawImage(paint.imageRef, pos = vec2(0, 0), tint = color)
      #   bxy.restoreTransform()

      # of TileScaleMode:
      #   var x = 0.0
      #   while x < node.size.x:
      #     var y = 0.0
      #     while y < node.size.y:
      #       bxy.saveTransform()
      #       bxy.applyTransform(
      #         (node.mat * translate(vec2(x, y)) *
      #         scale(vec2(paint.scalingFactor, paint.scalingFactor)))
      #       )
      #       bxy.drawImage(paint.imageRef, pos = vec2(0, 0), tint = color)
      #       bxy.restoreTransform()
      #       y += image.height.float32 * paint.scalingFactor
      #     x += image.width.float32 * paint.scalingFactor
      else:
        assert false, "Unknown unsupported scale mode: " & $paint.scaleMode

  elif node.id in bxy:
    doAssert fract(node.pixelBox.x) == 0
    doAssert fract(node.pixelBox.y) == 0
    if node.willDrawSomething():
      bxy.drawImage(node.id, pos = node.pixelBox.xy)

  if node.onRenderCallback != nil:
    node.onRenderCallback(node)

  if not node.collapse:
    var masks: seq[INode]
    for child in node.children:
      if child.isMask:
        masks.add(child)
      else:
        if masks.len == 0:
          composite(child)
        else:
          bxy.pushLayer()
          composite(child)
          bxy.pushLayer()
          for mask in masks:
            composite(mask)
          bxy.popLayer(blendMode = MaskBlend)
          bxy.popLayer(
            tint = color(1, 1, 1, child.opacity),
            blendMode = child.blendMode
          )

  if node.clipsContent:
    bxy.pushLayer()
    bxy.drawImage(node.id & ".mask", pos = node.pixelBox.xy)
    bxy.popLayer(blendMode = MaskBlend)

  for i in 0 ..< pushedLayers:
    bxy.popLayer(tint = color(1, 1, 1, node.opacity), blendMode = node.blendMode)

proc rasterPass*(node: INode) {.measure.} =
  ## Performs a raster pass on a node.
  rasterize(node, 0)

  # Walk all nodes and find images to remove.
  var inUse: HashSet[string]
  proc walk(node: INode) =
    for fill in node.fills:
      if fill.imageRef != "":
        inUse.incl(fill.imageRef)
    for stroke in node.strokes:
      if stroke.imageRef != "":
        inUse.incl(stroke.imageRef)
    if node.willDrawSomething():
      inUse.incl(node.id)
    if node.clipsContent:
      inUse.incl(node.id & ".mask")
    for child in node.children:
      walk(child)
  walk(node)

  let usedImages2 = usedImages
  for name in usedImages2:
    if name notin inUse:
      if name in bxy:
        bxy.removeImage(name)
      usedImages.excl(name)

proc compositePass*(node: INode) {.measure.} =
  ## Performs a compositing pass on a node.
  composite(node)

proc drawToScreen*(screenNode: INode) {.measure.} =
  ## Draws the current node onto the screen.

  if window.size.vec2 != screenNode.size:
    if window.style == DecoratedResizable:
      # Stretch the current frame to fit the window.
      if screenNode.size != window.size.vec2 / window.contentScale:
        screenNode.dirty = true
        screenNode.size = window.size.vec2 / window.contentScale
    else:
      # Stretch the window to fit the current frame.
      window.size = (screenNode.size.vec2 * window.contentScale).ivec2

  bxy.beginFrame(window.size, clearFrame=clearFrame)

  layoutPass(screenNode)

  # Setup proper matrix for drawing.
  mat = scale(vec2(window.contentScale, window.contentScale))
  if rtl:
    mat = mat * scale(vec2(-1, 1)) * translate(vec2(-screenNode.size.x, 0))
  mat = mat * screenNode.transform().inverse()

  if screenNode.dirty:
    rasterPass(screenNode)

  compositePass(screenNode)

  bxy.endFrame()

proc setupWindow*(
  size: IVec2,
  visible = true,
  style = DecoratedResizable
) =
  ## Sets up the window.
  window = newWindow(
    "loading...",
    size,
    visible=visible,
    msaa=msaa8x
  )
  # Adjust size to account for content scale.
  if window.contentScale != 1.0:
    window.size = (window.size.vec2 * window.contentScale).ivec2
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
  bxy = newBoxy(atlasSize = 1024, tileSize = 64, tileMargin = 2)

proc readGpuPixelsFromScreen*(): pixie.Image =
  ## Reads the GPU pixels from the screen.
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
