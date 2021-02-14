import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie, opengl

import nimskia/[
  sk_canvas,
  gr_context,
  sk_surface,
  sk_imageinfo,
  sk_enums,
  sk_matrix,
  sk_color,
  sk_path,
  sk_paint,
  sk_colors,
]

var
  surface: SkSurface = nil
  ctx: SkCanvas = nil
  theGrContext: GrContext = nil

# Magic constant that makes spline circle work.
const splinyCirlce = 4.0 * (-1.0 + sqrt(2.0)) / 3

proc roundedRect2(path: var Path, pos, size: Vec2, nw, ne, se, sw: float32, clockwise = false) =
  ## Draw an rounded corner rectangle using cubic curves.
  let
    x = pos.x
    y = pos.y
    w = size.x
    h = size.y
    s = splinyCirlce

    maxRaidus = min(w/2, h/2)
    nw = min(nw, maxRaidus)
    ne = min(ne, maxRaidus)
    se = min(se, maxRaidus)
    sw = min(sw, maxRaidus)

    t1 = vec2(x + nw, y)
    t2 = vec2(x + w - ne, y)
    r1 = vec2(x + w, y + ne)
    r2 = vec2(x + w, y + h - se)
    b1 = vec2(x + w - se, y + h)
    b2 = vec2(x + sw, y + h)
    l1 = vec2(x, y + h - sw)
    l2 = vec2(x, y + nw)

    t1h = t1 + vec2(-nw*s, 0)
    t2h = t2 + vec2(+ne*s, 0)
    r1h = r1 + vec2(0, -ne*s)
    r2h = r2 + vec2(0, +se*s)
    b1h = b1 + vec2(+se*s, 0)
    b2h = b2 + vec2(-sw*s, 0)
    l1h = l1 + vec2(0, +sw*s)
    l2h = l2 + vec2(0, -nw*s)

  path.moveTo(t1.x, t1.y)
  path.lineTo(t2.x, t2.y)
  path.bezierCurveTo(t2h.x, t2h.y, r1h.x, r1h.y, r1.x, r1.y)
  path.lineTo(r2.x, r2.y)
  path.bezierCurveTo(r2h.x, r2h.y, b1h.x, b1h.y, b1.x, b1.y)
  path.lineTo(b2.x, b2.y)
  path.bezierCurveTo(b2h.x, b2h.y, l1h.x, l1h.y, l1.x, l1.y)
  path.lineTo(l2.x, l2.y)
  path.bezierCurveTo(l2h.x, l2h.y, t1h.x, t1h.y, t1.x, t1.y)


proc pathToSkPath(pixiePath: Path, wr: WindingRule): SkPath =
  var path = newSkPath()
  if wr == wrEvenOdd:
    path.fillType = EvenOdd
  else:
    path.fillType = Winding

  for command in pixiePath.commands:
    case command.kind
    of pixie.Move:
      discard path.moveTo(command.numbers[0], command.numbers[1])
    of pixie.Line:
      discard path.lineTo(command.numbers[0], command.numbers[1])
    of pixie.Cubic:
      discard path.cubicTo(
        command.numbers[0], command.numbers[1],
        command.numbers[2], command.numbers[3],
        command.numbers[4], command.numbers[5]
      )
    # of pixie.Arc:
    #   discard path.arcTo(
    #     command.numbers[0], command.numbers[1],
    #     command.numbers[2],
    #     SkPathArcSize.Small, SkPathDirection.Clockwise, # command.numbers[4], command.numbers[5],
    #     command.numbers[5], command.numbers[6],
    #   )
    of pixie.Close:
      path.close()
    else:
      echo($command.kind & " not supported command kind.")

  return path

proc drawGeometry(geometry: Geometry): SkPath =
  pathToSkPath(geometry.path, geometry.windingRule)


proc drawNode(node: Node) =

  if node.visible == false:
    return

  if node.opacity != 1.0:
    let fillPaint = newSkPaint()
    fillPaint.color = newSkColorArgb(
      (node.opacity * 255).int,
      255,
      255,
      255,
    )
    fillPaint.style = Fill
    discard ctx.saveLayer(nil, fillPaint)
  else:
    discard ctx.save()

  var t = node.relativeTransform

  # var mat = mat3(
  #   t[0][0], t[0][1], 0,
  #   t[1][0], t[1][1], 0,
  #   t[0][2], t[1][2], 1)
  # mat = mat.inverse()
  # ctx.transform(
  #   mat[0, 0], mat[0, 1], mat[2, 0],
  #   mat[1, 0], mat[1, 1], mat[2, 1]
  # )

  # ctx.transform(
  #   1, 0, t[0][2],
  #   0, 1, t[1][2]
  # )
  # ctx.transform(
  #   t[0][0], t[0][1], t[0][2],
  #   t[1][0], t[1][1], t[1][2]
  # )

  ctx.translate(t[0][2], t[1][2])

  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    #print "group", node.name

    var path: Path
    if node.cornerRadius > 0:
      # Rectangle with common corners.
      path.roundedRect2(
        vec2(0, 0),
        node.size,
        nw = node.cornerRadius,
        ne = node.cornerRadius,
        se = node.cornerRadius,
        sw = node.cornerRadius
      )
    elif node.rectangleCornerRadii != nil:
      # Rectangle with different corners.
      path.roundedRect2(
        vec2(0, 0),
        node.size,
        nw = node.rectangleCornerRadii[0],
        ne = node.rectangleCornerRadii[1],
        se = node.rectangleCornerRadii[2],
        sw = node.rectangleCornerRadii[3],
      )
    else:
      # Basic rectangle.
      path.rect(
        x = 0,
        y = 0,
        w = node.size.x,
        h = node.size.y,
      )

    var skPath = pathToSkPath(path, wrNonZero)
    for paint in node.fills:
      if not paint.visible:
        continue
      let fillColor = paint.color.rgba
      let fillPaint = newSkPaint()
      fillPaint.antialias = true
      fillPaint.color = newSkColorArgb(
        (paint.opacity * fillColor.a.float).int,
        fillColor.r.int,
        fillColor.g.int,
        fillColor.b.int
      )
      fillPaint.style = Fill
      ctx.drawPath(skPath, fillPaint)
      fillPaint.dispose()

    if node.strokes.len > 0:
      let
        x = 0.0
        y = 0.0
        w = node.size.x
        h = node.size.y
      var
        inner = 0.0
        outer = 0.0
        path: Path
      case node.strokeAlign
      of saInside:
        inner = node.strokeWeight
      of saOutside:
        outer = node.strokeWeight
      of saCenter:
        inner = node.strokeWeight / 2
        outer = node.strokeWeight / 2

      if node.cornerRadius > 0:
        # Rectangle with common corners.
        let
          r = node.cornerRadius
        path.roundedRect2(
          vec2(x-outer, y-outer),
          vec2(w+outer*2, h+outer*2),
          r+outer, r+outer, r+outer, r+outer
        )
        path.roundedRect2(
          vec2(x+inner, y+inner),
          vec2(w-inner*2, h-inner*2),
          r-inner, r-inner, r-inner, r-inner,
          clockwise = false
        )

      elif node.rectangleCornerRadii != nil:
        # Rectangle with different corners.
        let
          nw = node.rectangleCornerRadii[0]
          ne = node.rectangleCornerRadii[1]
          se = node.rectangleCornerRadii[2]
          sw = node.rectangleCornerRadii[3]
        path.roundedRect2(
          vec2(x-outer, y-outer),
          vec2(w+outer*2, h+outer*2),
          nw+outer, ne+outer, se+outer, sw+outer
        )
        path.roundedRect2(
          vec2(x+inner, y+inner),
          vec2(w-inner*2, h-inner*2),
          nw-inner, ne-inner, se-inner, sw-inner,
          clockwise = false
        )

      else:
        path.moveTo(x-outer, y-outer)
        path.lineTo(x+w+outer, y-outer, )
        path.lineTo(x+w+outer, y+h+outer, )
        path.lineTo(x-outer, y+h+outer, )
        path.lineTo(x-outer, y-outer, )
        path.closePath()

        path.moveTo(x+inner, y+inner)
        path.lineTo(x+inner, y+h-inner)
        path.lineTo(x+w-inner, y+h-inner)
        path.lineTo(x+w-inner, y+inner)
        path.lineTo(x+inner, y+inner)
        path.closePath()

      var strokeColor: ColorRgba
      for paint in node.strokes:
        strokeColor = paint.color.rgba
      for geometry in node.strokeGeometry:
        var skPath = pathToSkPath(path, wrEvenOdd)
        let strokePaint = newSkPaint()
        strokePaint.antialias = true
        strokePaint.color = newSkColorArgb(
          strokeColor.a.int,
          strokeColor.r.int,
          strokeColor.g.int,
          strokeColor.b.int
        )
        strokePaint.style = Fill
        ctx.drawPath(skPath, strokePaint)
        strokePaint.dispose()

  of nkVector:
    #print "vec", node.name

    var fillColor: ColorRgba
    for paint in node.fills:
      fillColor = paint.color.rgba
    for geometry in node.fillGeometry:
      var path = geometry.drawGeometry()
      let fillPaint = newSkPaint()
      fillPaint.antialias = true
      fillPaint.color = newSkColorArgb(
        fillColor.a.int,
        fillColor.r.int,
        fillColor.g.int,
        fillColor.b.int
      )
      fillPaint.style = Fill
      ctx.drawPath(path, fillPaint)
      fillPaint.dispose()

    var strokeColor: ColorRgba
    for paint in node.strokes:
      strokeColor = paint.color.rgba
    for geometry in node.strokeGeometry:
      var path = geometry.drawGeometry()
      let strokePaint = newSkPaint()
      strokePaint.antialias = true
      strokePaint.color = newSkColorArgb(
        strokeColor.a.int,
        strokeColor.r.int,
        strokeColor.g.int,
        strokeColor.b.int
      )
      strokePaint.style = Fill
      ctx.drawPath(path, strokePaint)
      strokePaint.dispose()

    # var strokeColor: Color
    # for paint in node.strokes:
    #   strokeColor = paint.color.color()
    # for geometry in node.strokeGeometry:
    #   geometry.drawGeometry()
    #   ctx.setSourceRGBA(strokeColor.r, strokeColor.g, strokeColor.b, strokeColor.a)
    #   ctx.fill()

  else:
    discard

  for child in node.children:
    drawNode(child)

  ctx.restore()

proc drawToScreen*(node: Node) =

  # let
  #   w = node.absoluteBoundingBox.w.int
  #   h = node.absoluteBoundingBox.h.int

  # const
  #   w = 640
  #   h = 480

  ctx = surface.canvas
  ctx.clear(0x00_00_00_00.uint32)
  discard ctx.save()

  # var path = newSkPath()
  # path.moveTo(0.5f * w, 0.1f * h) # Define the first contour
  #     .lineTo(0.2f * w, 0.4f * h)
  #     .lineTo(0.8f * w, 0.4f * h)
  #     .lineTo(0.5f * w, 0.1f * h)
  #     .moveTo(0.5f * w, 0.6f * h) # Define the second contour
  #     .lineTo(0.2f * w, 0.9f * h)
  #     .lineTo(0.8f * w, 0.9f * h)
  #     .close()

  # let fillPaint = newSkPaint()
  # fillPaint.color = Cyan
  # fillPaint.style = Fill
  # defer: fillPaint.dispose()

  # ctx.drawPath(path, fillPaint)

  var t = node.relativeTransform
  ctx.translate(-t[0][2], -t[1][2])
  drawNode(node)


  ctx.restore()
  theGrContext.flush()

proc readGpuPixelsFromScreen*(): pixie.Image =
  ## Read the GPU pixels from screen.
  ## Use for debugging and tests only.
  var screen = newImage(viewportSize.x.int, viewportSize.x.int)
  glReadPixels(
    0, 0,
    screen.width.Glint, screen.height.Glint,
    GL_RGBA, GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  screen.flipVertical()
  return screen

proc setupRender*(frameNode: Node) =
  ## Setup the rendering of the frame.
  viewportSize = frameNode.absoluteBoundingBox.wh

proc setupWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true
) =
  ## Opens a new glfw window that is ready to draw into.
  ## Also setups all the shaders and buffers.

  setupRender(frameNode)

  # Init glfw.
  if init() == 0:
    raise newException(Exception, "Failed to intialize GLFW")

  # Open a window.
  if not vSync:
    # Disable V-Sync
    windowHint(DOUBLEBUFFER, false.cint)

  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  #windowHint(SAMPLES, 4)
  print viewportSize.x.cint, viewportSize.y.cint
  window = createWindow(
    viewportSize.x.cint, viewportSize.y.cint,
    "skia",
    nil,
    nil)
  if window == nil:
    raise newException(Exception, "Failed to create GLFW window.")
  window.makeContextCurrent()

  # Load opengl.
  loadExtensions()

  #glEnable(GL_MULTISAMPLE)

  theGrContext = createGL()
  var info = newSkFrameBufferInfo(0, GL_RGBA8.uint32)
  let numStencilBits = 8
  var target = createBackendRenderTarget(
    viewportSize.x.int32, viewportSize.y.int32, 0, numStencilBits.int32, info
  )
  surface = newSkSurface(
    theGrContext,
    target,
    BottomLeft,
    Rgba8888,
    nil,
    nil
  )
