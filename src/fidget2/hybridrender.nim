import bumpy, math, opengl, pixie, schema, staticglfw, tables, vmath, times,
  perf, context, common, cpu2render, layout

var
  ctx*: context.Context
  viewportRect: Rect

proc computeIntBounds(node: Node, mat: Mat3): Rect =
  ## Compute self bounds of a given node.
  var
    minV: Vec2
    maxV: Vec2
    first = true
  for geoms in [node.fillGeometry, node.strokeGeometry]:
    for geom in geoms:
      for shape in geom.path.commandsToShapes():
        for vec in shape:
          let v = mat * vec
          if first:
            minV = v
            maxV = v
            first = false
          else:
            minV.x = min(minV.x, v.x)
            minV.y = min(minV.y, v.y)
            maxV.x = max(maxV.x, v.x)
            maxV.y = max(maxV.y, v.y)
  minV = minV.floor
  maxV = maxV.ceil
  rect(minV.x, minV.y, maxV.x - minV.x, maxV.y - minV.y)

proc drawToAtlas(node: Node) =
  ## Draw the nodes into the atlas (and setup pixel box).
  if not node.visible or node.opacity == 0:
    return

  let prevMat = mat
  mat = mat * node.transform()

  if node.dirty:
    node.dirty = false
    # compute bounds
    var bounds: Rect
    if node.kind == nkText:
      node.genHitRectGeometry()
    else:
      node.genFillGeometry()
      node.genStrokeGeometry()
    bounds = computeIntBounds(node, mat)
    node.pixelBox = bounds

    if bounds.w.int > 0 and bounds.h.int > 0:
      layer = newImage(bounds.w.int, bounds.h.int)
      let prevBoundsMat = mat
      mat = translate(-bounds.xy) * mat

      if node.kind == nkText:
        node.drawText()
      else:

        if node.strokeGeometry.len == 0:
          # No stroke just fill.
          node.drawPaint(node.fills, node.fillGeometry)
        else:
          # Draw stroke depending on stroke align.
          case node.strokeAlign
          of saInside:
            if node.fillGeometry.len == 0:
              node.drawPaint(node.strokes, node.strokeGeometry)

            else:
              # Deal with fill
              var fillLayer = layer
              node.drawPaint(node.fills, node.fillGeometry)
              # Deal with fill mask
              var fillMask = newMask(bounds.w.int, bounds.h.int)
              for geometry in node.fillGeometry:
                fillMask.fillPath(geometry.path, mat, geometry.windingRule)
              # Deal with stroke
              var strokeLayer = newImage(bounds.w.int, bounds.h.int)
              layer = strokeLayer
              node.drawPaint(node.strokes, node.strokeGeometry)
              layer = fillLayer
              strokeLayer.draw(fillMask, blendMode = bmMask)
              layer.draw(strokeLayer)

          of saCenter:
            node.drawPaint(node.fills, node.fillGeometry)
            node.drawPaint(node.strokes, node.strokeGeometry)
          of saOutside:
            node.drawPaint(node.strokes, node.strokeGeometry)
            node.drawPaint(node.fills, node.fillGeometry)

      for effect in node.effects:
        if effect.kind == ekInnerShadow:
          drawInnerShadowEffect(effect, node, node.maskSelfImage())

      ctx.putImage(node.id, layer)
      mat = prevBoundsMat

  for child in node.children:
    drawToAtlas(child)

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

  for child in node.children:
    drawWithAtlas(child)

proc drawToScreen*(screenNode: Node) =
  ## Draw the current node onto the screen.

  viewportSize = screenNode.absoluteBoundingBox.wh.ceil

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
  drawToAtlas(screenNode)

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
