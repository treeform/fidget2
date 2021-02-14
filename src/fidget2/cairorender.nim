import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie, cairo

var
  ctx: ptr Context

proc drawGeometry(geometry: Geometry) =
  ctx.newPath()

  var start: Vec2
  #print fillColor
  for command in geometry.path.commands:

    case command.kind
    of pixie.Move:
      start = vec2(command.numbers[0], command.numbers[1])
      ctx.moveTo(command.numbers[0], command.numbers[1])
    of pixie.Line:
      ctx.lineTo(command.numbers[0], command.numbers[1])
    of pixie.Cubic:
      ctx.curveTo(
        command.numbers[0], command.numbers[1],
        command.numbers[2], command.numbers[3],
        command.numbers[4], command.numbers[5]
      )
    # of pixie.Quad:
    #   assert command.numbers.len == 4
    #   dataBufferSeq.add cmdQ.float32
    #   for i in 0 ..< 2:
    #     var pos = vec2(
    #       command.numbers[i*2+0],
    #       command.numbers[i*2+1]
    #     )
    #     dataBufferSeq.add pos.x
    #     dataBufferSeq.add pos.y
    of pixie.Close:
      ctx.lineTo(start.x, start.y)
    else:
      quit($command.kind & " not supported command kind.")


proc drawNode(node: Node) =

  ctx.save()

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
  of nkFrame, nkGroup:
    #print "group", node.name
    discard
  of nkVector:
    #print "vec", node.name

    var fillColor: Color
    for paint in node.fills:
      fillColor = paint.color.color()
    for geometry in node.fillGeometry:
      geometry.drawGeometry()
      ctx.setSourceRGBA(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
      ctx.fill()

    var strokeColor: Color
    for paint in node.strokes:
      strokeColor = paint.color.color()
    for geometry in node.strokeGeometry:
      geometry.drawGeometry()
      ctx.setSourceRGBA(strokeColor.r, strokeColor.g, strokeColor.b, strokeColor.a)
      ctx.fill()

  else:
    discard

  for child in node.children:
    drawNode(child)

  ctx.restore()

proc drawCompleteFrame*(node: Node): pixie.Image =

  let
    w = node.absoluteBoundingBox.w.int
    h = node.absoluteBoundingBox.h.int

  var
    surface = imageSurfaceCreate(FORMAT_ARGB32, w.int32, h.int32)
  ctx = surface.create()

  var
    xc = 128.0
    yc = 128.0
    radius = 100.0
    angle1 = 45.0  * PI / 180.0  # angles are specified
    angle2 = 180.0 * PI / 180.0  # in radians

  var t = node.relativeTransform
  ctx.translate(-t[0][2], -t[1][2])
  drawNode(node)

  var screen = newImage(w, h)
  var data = surface.getData()
  for i in 0 ..< screen.data.len:
    screen.data[i].r = data[i * 4 + 2].uint8
    screen.data[i].g = data[i * 4 + 1].uint8
    screen.data[i].b = data[i * 4 + 0].uint8
    screen.data[i].a = data[i * 4 + 3].uint8

  return screen

proc setupWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true
) =
  ## Opens a new glfw window that is ready to draw into.
  if init() == 0:
    raise newException(Exception, "Failed to intialize GLFW")
  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  windowHint(CLIENT_API, NO_API)
  window = createWindow(
    viewportSize.x.cint, viewportSize.y.cint,
    "loading...",
    nil,
    nil)
  if window == nil:
    raise newException(Exception, "Failed to create GLFW window.")
