import vmath, schema, pixie, times, common, opengl, staticglfw, bumpy

var
  viewportRect: Rect

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
  windowHint(SAMPLES, 0)
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
