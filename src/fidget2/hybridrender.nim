import algorithm, bumpy, globs, input, json, loader, math, opengl,
    pixie, schema, sequtils, staticglfw, strformat, tables, typography,
    typography/textboxes, unicode, vmath, times, perf, context

var
  # Window stuff.
  viewPortWidth*: int
  viewPortHeight*: int
  window*: Window
  offscreen* = false
  windowResizable*: bool
  vSync*: bool
  framePos*: Vec2

  # Text edit.
  textBox*: TextBox
  textBoxFocus*: Node
  typefaceCache*: Table[string, Typeface]

  ctx*: Context

proc drawHybridFrameToScreen*(thisFrame: Node) =
  glEnable(GL_BLEND)
  #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBlendFuncSeparate(
    GL_SRC_ALPHA,
    GL_ONE_MINUS_SRC_ALPHA,
    GL_ONE,
    GL_ONE_MINUS_SRC_ALPHA
  )

  glClearColor(0, 0, 0, 1)
  glClear(GL_COLOR_BUFFER_BIT)


  ctx.beginFrame(vec2(viewPortWidth.float32, viewPortHeight.float32))
  for x in 0 ..< 28:
    for y in 0 ..< 28:
      ctx.saveTransform()
      ctx.translate(vec2(x.float32*32, y.float32*32))
      ctx.drawImage("test.png", size = vec2(32, 32))
      ctx.restoreTransform()

  ctx.endFrame()
  perfMark "beginFrame/endFrame"

proc createWindow*(
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

  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  windowHint(SAMPLES, 0)
  window = createWindow(
    viewPortWidth.cint, viewPortHeight.cint,
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
