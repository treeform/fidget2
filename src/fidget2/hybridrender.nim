import algorithm, bumpy, globs, input, json, loader, math, opengl,
    pixie, schema, sequtils, staticglfw, strformat, tables, typography,
    typography/textboxes, unicode, vmath, times, perf, context, common,
    cpu2render, layout

var
  ctx*: Context

proc drawToAtlas(node: Node) =
  if not node.visible or node.opacity == 0:
    return

  # let prevMat = mat
  # mat = mat * node.transform()

  # node.mat = mat
  # node.pixelBox.xy = mat * vec2(0, 0)
  # node.pixelBox.wh = node.box.wh
  # print node.name, node.mat, node.pixelBox.xy

  layer = newImage(node.box.w.int, node.box.h.int)
  mat = mat3()
  node.drawNodeInternal(withChildren=false)

  ctx.putImage(node.id, layer)

  for child in node.children:
    drawToAtlas(child)

  # mat = prevMat

proc drawWithAtlas(node: Node) =

  let prevMat = mat
  mat = mat * node.transform()

  node.mat = mat
  node.pixelBox.xy = mat * vec2(0, 0)
  node.pixelBox.wh = node.box.wh
  #print node.name, node.pixelBox
  ctx.drawImage(node.id, pos=node.pixelBox.xy)

  for child in node.children:
    drawWithAtlas(child)

  mat = prevMat

proc drawToScreen*(screenNode: Node) =

  viewportSize = screenNode.absoluteBoundingBox.wh

  # node.box.xy = vec2(0, 0)
  # node.size = node.box.wh
  # for c in node.children:
  #   computeLayout(node, c)
  # perfMark "computeLayout"

  mat = mat3()
  # transform viewport to current node

  # print screenNode.transform()



  drawToAtlas(screenNode)

  #var nodeImage = drawCompleteFrame(node)
  #ctx.putImage(node.id, nodeImage)

  ctx.beginFrame(viewportSize)

  #print "---"

  mat = mat * screenNode.transform().inverse()
  drawWithAtlas(screenNode)

  ctx.endFrame()

  #ctx.writeAtlas("atlas.png")



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
