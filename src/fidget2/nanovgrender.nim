import vmath, schema, pixie, times, common, opengl, staticglfw, bumpy, print

import nanovg
#import glad/gl

var
  vg: NVGContext
  viewportRect: Rect


proc drawGeometry(geometry: Geometry) =
  vg.beginPath()

  var start: Vec2
  #print fillColor
  for command in geometry.path.commands:

    case command.kind
    of pixie.Move:
      start = vec2(command.numbers[0], command.numbers[1])
      vg.moveTo(command.numbers[0], command.numbers[1])
    of pixie.Line:
      vg.lineTo(command.numbers[0], command.numbers[1])
    of pixie.Cubic:
      vg.bezierTo(
        command.numbers[0], command.numbers[1],
        command.numbers[2], command.numbers[3],
        command.numbers[4], command.numbers[5]
      )
    of pixie.Close:
      vg.lineTo(start.x, start.y)
    else:
      quit($command.kind & " not supported command kind.")


proc drawNode(node: Node) =

  vg.save()

  var t = node.relativeTransform

  # var mat = mat3(
  #   t[0][0], t[0][1], 0,
  #   t[1][0], t[1][1], 0,
  #   t[0][2], t[1][2], 1)
  # mat = mat.inverse()
  # vg.transform(
  #   mat[0, 0], mat[0, 1], mat[2, 0],
  #   mat[1, 0], mat[1, 1], mat[2, 1]
  # )

  # vg.transform(
  #   1, 0, t[0][2],
  #   0, 1, t[1][2]
  # )
  # vg.transform(
  #   t[0][0], t[0][1], t[0][2],
  #   t[1][0], t[1][1], t[1][2]
  # )

  vg.translate(t[0][2], t[1][2])

  case node.kind:
  of nkFrame, nkGroup:
    #print "group", node.name
    discard
  of nkVector:
    #print "vec", node.name

    var fillColor = rgba(28, 30, 34, 192)
    for paint in node.fills:
      fillColor = rgba(
        paint.color.r,
        paint.color.g,
        paint.color.b,
        paint.color.a
      )
    for geometry in node.fillGeometry:
      geometry.drawGeometry()
      vg.fillColor(fillColor)
      vg.fill()

    var strokeColor = rgba(28, 30, 34, 192)
    for paint in node.strokes:
      strokeColor = rgba(
        paint.color.r,
        paint.color.g,
        paint.color.b,
        paint.color.a
      )
    for geometry in node.strokeGeometry:
      geometry.drawGeometry()
      vg.fillColor(strokeColor)
      vg.fill()

  else:
    discard

  for child in node.children:
    drawNode(child)

  vg.restore()

proc drawToScreen*(node: Node) =

  viewportSize = node.absoluteBoundingBox.wh
  if viewportRect != rect(0, 0, viewportSize.x, viewportSize.y):
    viewportRect = rect(0, 0, viewportSize.x, viewportSize.y)
    window.setWindowSize(viewportSize.x.cint, viewportSize.y.cint)
    glViewport(
      viewportRect.x.cint,
      viewportRect.y.cint,
      viewportRect.w.cint,
      viewportRect.h.cint
    )


  glClear(GL_COLOR_BUFFER_BIT or
          GL_DEPTH_BUFFER_BIT or
          GL_STENCIL_BUFFER_BIT)

  vg.beginFrame(viewportSize.x, viewportSize.y, devicePixelRatio=1.0)

  # vg.beginPath()
  # vg.rect(100,100, 100,100)
  # vg.fillColor(rgba(255,0,0,255))
  # vg.fill()

  var t = node.relativeTransform
  vg.translate(-t[0][2], -t[1][2])
  drawNode(node)


  vg.endFrame()

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
  windowHint(SAMPLES, 4)
  print viewportSize.x.cint, viewportSize.y.cint
  window = createWindow(
    viewportSize.x.cint, viewportSize.y.cint,
    "nanovg",
    nil,
    nil)
  if window == nil:
    raise newException(Exception, "Failed to create GLFW window.")
  window.makeContextCurrent()

  # Load opengl.
  loadExtensions()

  nvgInit(getProcAddress)
  var flags = {nifStencilStrokes, nifAntialias, nifDebug}
  vg = nvgCreateContext(flags)

  #if not gladLoadGL(getProcAddress):
  #  quit "Error initialising OpenGL"
