import bumpy, math, opengl, pixie, schema, staticglfw, tables, vmath,
  context, common, cpurender, layout, os, perf, nodes

export cpurender.underMouse

var
  ctx*: context.Context

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

  for fill in node.fills:
    if fill.kind != schema.PaintKind.pkSolid or fill.color.a != 0:
      return true

  for stroke in node.strokes:
    if stroke.kind != schema.PaintKind.pkSolid or stroke.color.a != 0:
      return true

  return false

proc drawToAtlas(node: Node, level: int) {.measure.} =
  ## Draw the nodes into the atlas (and setup pixel box).
  if not node.visible or node.opacity == 0:
    node.markTreeClean()
    return

  let prevMat = mat
  mat = mat * node.transform()

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
    for child in node.children:
      if child.isMask:
        node.collapse = true
        break

    # Can't draw clips content on the GPU.
    if level != 0 and node.clipsContent:
      node.collapse = true

    # Can't draw effects on the GPU.
    if node.effects.len != 0:
      node.collapse = true

    if node.willDrawSomething():
      layer = newImage(node.pixelBox.w.int, node.pixelBox.h.int)
      let prevBoundsMat = mat
      mat = translate(-node.pixelBox.xy) * mat

      node.drawNodeInternal(withChildren=node.collapse)
      ctx.putImage(node.id, layer)
      mat = prevBoundsMat

  else:
    # Update pixel bounds even if no redraw was needed.
    node.pixelBox = pixelBox

  if not node.collapse:
    for child in node.children:
      drawToAtlas(child, level + 1)
  else:
    node.markTreeClean()

  mat = prevMat

proc drawWithAtlas(node: Node) {.measure.} =
  # Draw the nodes using atlas.
  if not node.visible or node.opacity == 0:
    return

  if node.id in ctx.entries:
    doAssert node.pixelBox.x.fractional == 0
    doAssert node.pixelBox.y.fractional == 0
    ctx.drawImage(
      node.id,
      pos = node.pixelBox.xy
    )

  if not node.collapse:
    for child in node.children:
      drawWithAtlas(child)

proc drawToScreen*(screenNode: Node) {.measure.} =
  ## Draw the current node onto the screen.

  if windowSize != screenNode.size:
    if windowResizable:
      # Stretch the current frame to fit the window.
      screenNode.size = windowSize
    else:
      # Stretch the window to fit the current frame.
      window.setWindowSize(screenNode.size.x.cint, screenNode.size.y.cint)

  viewportSize = screenNode.size.ceil

  ctx.beginFrame(viewportSize)

  for i in 0 ..< 2:
    # TODO: figure out how to call layout only once.
    computeLayout(nil, screenNode)

  # echo "before"
  # screenNode.printDirtyStatus()

  # Setup proper matrix for drawing.
  mat = mat3()
  mat = mat * screenNode.transform().inverse()
  drawToAtlas(screenNode, 0)

  drawWithAtlas(screenNode)
  ctx.endFrame()

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
  # Load opengl.
  loadExtensions()

  echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
  echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
  echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))
  echo "GL_SHADING_LANGUAGE_VERSION: ", cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

  # Setup Context
  ctx = newContext()

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
