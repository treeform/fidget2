import bumpy, math, opengl, pixie, schema, staticglfw, tables, vmath, times,
  perf, context, common, cpurender, layout

var
  ctx*: context.Context
  viewportRect: Rect

proc drawToAtlas(node: Node, level: int) =
  ## Draw the nodes into the atlas (and setup pixel box).
  if not node.visible or node.opacity == 0:
    return

  let prevMat = mat
  mat = mat * node.transform()

  if node.dirty:
    node.dirty = false
    # compute bounds
    var bounds = computeIntBounds(node, mat, node.kind == nkBooleanOperation)

    node.pixelBox = bounds

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

    # Can't draw effects with children.
    if node.effects.len != 0:
      node.collapse = true

    if bounds.w.int > 0 and bounds.h.int > 0:
      layer = newImage(bounds.w.int, bounds.h.int)
      let prevBoundsMat = mat
      mat = translate(-bounds.xy) * mat

      node.drawNodeInternal(withChildren=node.collapse)

      ctx.putImage(node.id, layer)
      mat = prevBoundsMat

  if not node.collapse:
    for child in node.children:
      drawToAtlas(child, level + 1)

  mat = prevMat

proc drawWithAtlas(node: Node) =
  # Draw the nodes using atlas.

  if not node.visible or node.opacity == 0:
    return

  if node.id in ctx.entries:
    doAssert node.pixelBox.x.fractional == 0
    doAssert node.pixelBox.y.fractional == 0
    ctx.drawImage(
      node.id,
      pos = node.pixelBox.xy,
      color = color(node.opacity, node.opacity, node.opacity, node.opacity)
    )

  if not node.collapse:
    for child in node.children:
      drawWithAtlas(child)

proc drawToScreen*(screenNode: Node) =
  ## Draw the current node onto the screen.

  viewportSize = screenNode.size.ceil

  # Resize the window if needed.
  if viewportRect != rect(0, 0, viewportSize.x, viewportSize.y):
    viewportRect = rect(0, 0, viewportSize.x, viewportSize.y)
    window.setWindowSize(viewportSize.x.cint, viewportSize.y.cint)
    glViewport(
      viewportRect.x.cint,
      viewportRect.y.cint,
      viewportRect.w.cint,
      viewportRect.h.cint
    )

  # Setup proper matrix for drawing.
  mat = mat3()
  mat = mat * screenNode.transform().inverse()

  drawToAtlas(screenNode, 0)

  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  ctx.beginFrame(viewportSize)
  drawWithAtlas(screenNode)
  ctx.endFrame()

  #ctx.writeAtlas("atlas.png")
  #perfDump()

proc setupWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true
) =
  ## Opens a new glfw window that is ready to draw into.
  ## Also setups all the shaders and buffers.

  # Init glfw.
  if init() == 0:
    raise newException(Exception, "Failed to intialize GLFW")

  # Open a window.
  if not vSync:
    # Disable V-Sync
    windowHint(DOUBLEBUFFER, false.cint)

  viewportSize = vec2(400, 400)

  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  windowHint(SAMPLES, 0)
  windowHint(CONTEXT_VERSION_MAJOR, 4)
  windowHint(CONTEXT_VERSION_MINOR, 1)

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
