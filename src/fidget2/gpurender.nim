import atlas, bumpy, chroma, glsl, gpushader, layout, loader, math, opengl,
    pixie, print, schema, staticglfw, tables, typography, typography/textboxes,
    vmath, times, perf, common

var
  # Buffers.
  dataBufferSeq*: seq[float32]
  mat*: Mat3
  opacity*: float32

  # OpenGL stuff.
  dataBufferTextureId: GLuint
  textureAtlas*: CpuAtlas
  textureAtlasId: GLuint
  backBufferId: GLuint

  # Vertex data
  vertices: array[8, GLfloat] = [
    -1.float32, -1,
    -1, +1,
    +1, +1,
    +1, -1,
  ]

  # Index data
  indices: array[4, GLubyte] = [0.uint8, 1, 2, 3]

  # OpenGL data
  vertexVBO: GLuint
  vao: GLuint
  vertShader: GLuint
  fragShader: GLuint
  shaderProgram: GLuint
  dataBufferId: GLuint

  currentBlendMode: BlendMode
  currentBoolMode: BooleanOperation

  vertShaderSrc = toShader(basic2dVert, "300 es")
  fragShaderSrc = toShader(svgMain, "300 es")

  vertShaderArray = allocCStringArray([vertShaderSrc]) # dealloc'd at the end
  fragShaderArray = allocCStringArray([fragShaderSrc]) # dealloc'd at the end

  scissorOn = false
  currentFrameBufferId = 0
  viewportRect: Rect

proc dumpCommandStream*()

proc updateGpuAtlas() =
  ## Upload the atlas to the GPU (if its dirty).
  if textureAtlas.dirty:
    echo "upload atlas"
    glBindTexture(GL_TEXTURE_2D, textureAtlasId)
    glTexImage2D(
      GL_TEXTURE_2D,
      0,
      GL_RGBA.GLint,
      textureAtlas.image.width.GLsizei,
      textureAtlas.image.height.GLsizei,
      0,
      GL_RGBA,
      GL_UNSIGNED_BYTE,
      textureAtlas.image.data[0].addr
    )
    textureAtlas.dirty = false

proc setupRender*(frameNode: Node) =
  ## Setup the rendering of the frame.
  dataBufferSeq.setLen(0)

  viewportSize = frameNode.absoluteBoundingBox.wh

  if textureAtlas == nil:
    textureAtlas = newCpuAtlas(512, 1)

  # Number nodes
  var currentIndex = 1
  proc number(node: Node) =
    node.idNum = currentIndex
    inc currentIndex
    for c in node.children:
      number(c)
  number(frameNode)

proc errorWarningCheck(name: string, shaderId: GLuint, compile = true) =
  # Check vertex compilation error, warning and status.
  var isCompiled: GLint
  if compile:
    glGetShaderiv(shaderId, GL_COMPILE_STATUS, isCompiled.addr)
  else:
    glGetProgramiv(shaderId, GL_LINK_STATUS, isCompiled.addr)

  var logSize: GLint
  if compile:
    glGetShaderiv(shaderId, GL_INFO_LOG_LENGTH, logSize.addr)
  else:
    glGetProgramiv(shaderId, GL_INFO_LOG_LENGTH, logSize.addr)
  if logSize > 0:
    var
      logStr = cast[ptr GLchar](alloc(logSize))
      logLen: GLsizei
    if compile:
      glGetShaderInfoLog(shaderId, logSize.GLsizei, logLen.addr, logStr)
    else:
      glGetProgramInfoLog(shaderId, logSize.GLsizei, logLen.addr, logStr)
    echo $logStr
  if isCompiled == 0:
    quit "Shader " & name & " wasn't compiled."

proc setupWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true
) =
  ## Opens a new glfw window that is ready to draw into.
  ## Also setups all the shaders and buffers.

  setupRender(frameNode)
  dataBufferSeq.add(cmdExit.float32)

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

  ## Write shader file for debugging (very useful).
  writeFile("tmp.glsl", fragShaderSrc)

  glDisable(GL_MULTISAMPLE)

  # Bind the vertices.
  glGenBuffers(1, vertexVBO.addr)
  glBindBuffer(GL_ARRAY_BUFFER, vertexVBO)
  glBufferData(
    GL_ARRAY_BUFFER, vertices.sizeof, vertices.addr, GL_STATIC_DRAW)

  # The array to draw a single quad.
  glGenVertexArrays(1, vao.addr)
  glBindVertexArray(vao)
  glBindBuffer(GL_ARRAY_BUFFER, vertexVBO)
  glVertexAttribPointer(0, 2, cGL_FLOAT, GL_FALSE, 0, nil)
  glEnableVertexAttribArray(0)

  # Command buffer object and its "texture".
  glGenBuffers(1, dataBufferId.addr)
  glBindBuffer(GL_TEXTURE_BUFFER, dataBufferId)
  glBufferData(
    GL_TEXTURE_BUFFER,
    dataBufferSeq.len * 4,
    dataBufferSeq[0].addr,
    GL_STATIC_DRAW
  )
  glActiveTexture(GL_TEXTURE0)
  glGenTextures(1, dataBufferTextureId.addr)
  glBindTexture(GL_TEXTURE_BUFFER, dataBufferTextureId)
  glTexBuffer(GL_TEXTURE_BUFFER, GL_R32F, dataBufferId)

  # Atlas texture.
  glActiveTexture(GL_TEXTURE1)
  glGenTextures(1, textureAtlasId.addr)
  glBindTexture(GL_TEXTURE_2D, textureAtlasId)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glTexImage2D(
    GL_TEXTURE_2D,
    0,
    GL_RGBA.GLint,
    textureAtlas.image.width.GLsizei,
    textureAtlas.image.height.GLsizei,
    0,
    GL_RGBA,
    GL_UNSIGNED_BYTE,
    textureAtlas.image.data[0].addr
  )

  # Compile Vertex.
  vertShader = glCreateShader(GL_VERTEX_SHADER)
  glShaderSource(vertShader, 1, vertShaderArray, nil)
  glCompileShader(vertShader)
  errorWarningCheck("vertex", vertShader)

  # Compile Fragment.
  fragShader = glCreateShader(GL_FRAGMENT_SHADER)
  glShaderSource(fragShader, 1, fragShaderArray, nil)
  glCompileShader(fragShader)
  errorWarningCheck("fragment", fragShader)

  # Attach to a GL program.
  shaderProgram = glCreateProgram()
  glAttachShader(shaderProgram, vertShader)
  glAttachShader(shaderProgram, fragShader)

  # Insert locations.
  glBindAttribLocation(shaderProgram, 0, "vertexPos")

  # Link shader.
  glLinkProgram(shaderProgram)
  errorWarningCheck("linking", shaderProgram, compile = false)

  # Use the program.
  glUseProgram(shaderProgram)

  # Set dataBuffer to 0th texture.
  var dataBufferLoc = glGetUniformLocation(shaderProgram, "dataBuffer")
  glUniform1i(dataBufferLoc, 0)

  # Set textureAtlas to 1th texture.
  var textureAtlasLoc = glGetUniformLocation(shaderProgram, "textureAtlasSampler")
  glUniform1i(textureAtlasLoc, 1)

  # Generate background frame buffer.
  glGenFramebuffers(1, backBufferId.addr)
  glBindFramebuffer(GL_FRAMEBUFFER, backBufferId)

  # Set "backBufferTextureId" as our colour attachement #0
  glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, textureAtlasId, 0)

  # Set the list of draw buffers.
  var drawBuffers = [GL_COLOR_ATTACHMENT0]
  glDrawBuffers(drawBuffers.len.GLsizei, drawBuffers[0].addr)

  # Always check that our framebuffer is ok
  if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE:
    quit("some thing is wrong with frame buffer")

  # Bind back default frame buffer of the screen.
  glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc drawBuffers() =
  # Send commands to the CPU.
  glBindBuffer(GL_TEXTURE_BUFFER, dataBufferId)
  glBufferData(GL_TEXTURE_BUFFER, dataBufferSeq.len * 4, dataBufferSeq[0].addr, GL_STATIC_DRAW)

  # Clear and setup drawing.
  glClearColor(0, 1, 0, 1)
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  glUseProgram(shaderProgram)

  # Do the drawing.
  glBindVertexArray(vao)
  glDrawElements(GL_TRIANGLE_FAN, indices.len.GLsizei, GL_UNSIGNED_BYTE, indices.addr)

proc transform(node: Node): Mat3 =
  ## Returns Mat3 transform of the node.
  result[0, 0] = node.relativeTransform[0][0]
  result[0, 1] = node.relativeTransform[1][0]
  result[0, 2] = 0
  result[1, 0] = node.relativeTransform[0][1]
  result[1, 1] = node.relativeTransform[1][1]
  result[1, 2] = 0
  result[2, 0] = node.box.x #node.relativeTransform[0][2]
  result[2, 1] = node.box.y #node.relativeTransform[1][2]
  result[2, 2] = 1

proc strokeInnerOuter(node: Node): (float32, float32) =
  ## Based on node return inner and outer stroke distance.
  var
    inner: float32 = 0
    outer: float32 = 0
  case node.strokeAlign
  of saInside:
    inner = node.strokeWeight
  of saOutside:
    outer = node.strokeWeight
  of saCenter:
    inner = node.strokeWeight / 2
    outer = node.strokeWeight / 2
  return (inner, outer)

# Magic constant that makes spline circle work.
const splinyCirlce = 4.0 * (-1.0 + sqrt(2.0)) / 3

proc drawEllipse(pos, size: Vec2) =
  ## Draw an eclipse using cubic curves.
  let
    x = 0.0
    y = 0.0
    r = 1.0
    s = splinyCirlce
    matC = translate(pos) * scale(size)
  var
    t1 = vec2(x, y - r)
    r1 = vec2(x + r, y)
    b1 = vec2(x, y + r)
    l1 = vec2(x - r, y)
    t1h = t1 + vec2(-r*s, 0)
    t2h = t1 + vec2(+r*s, 0)
    r1h = r1 + vec2(0, -r*s)
    r2h = r1 + vec2(0, +r*s)
    b1h = b1 + vec2(+r*s, 0)
    b2h = b1 + vec2(-r*s, 0)
    l1h = l1 + vec2(0, +r*s)
    l2h = l1 + vec2(0, -r*s)

  t1 = matC * t1
  r1 = matC * r1
  b1 = matC * b1
  l1 = matC * l1
  t1h = matC * t1h
  t2h = matC * t2h
  r1h = matC * r1h
  r2h = matC * r2h
  b1h = matC * b1h
  b2h = matC * b2h
  l1h = matC * l1h
  l2h = matC * l2h

  dataBufferSeq.add @[
    cmdM.float32, t1.x, t1.y,
    cmdC.float32, t2h.x, t2h.y, r1h.x, r1h.y, r1.x, r1.y,
    cmdC.float32, r2h.x, r2h.y, b1h.x, b1h.y, b1.x, b1.y,
    cmdC.float32, b2h.x, b2h.y, l1h.x, l1h.y, l1.x, l1.y,
    cmdC.float32, l2h.x, l2h.y, t1h.x, t1h.y, t1.x, t1.y,
    cmdz.float32,
  ]

proc drawRect(pos, size: Vec2, nw, ne, se, sw: float32) =
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

  dataBufferSeq.add @[
    cmdM.float32, t1.x, t1.y,
    cmdL.float32, t2.x, t2.y,
    cmdC.float32, t2h.x, t2h.y, r1h.x, r1h.y, r1.x, r1.y,
    cmdL.float32, r2.x, r2.y,
    cmdC.float32, r2h.x, r2h.y, b1h.x, b1h.y, b1.x, b1.y,
    cmdL.float32, b2.x, b2.y,
    cmdC.float32, b2h.x, b2h.y, l1h.x, l1h.y, l1.x, l1.y,
    cmdL.float32, l2.x, l2.y,
    cmdC.float32, l2h.x, l2h.y, t1h.x, t1h.y, t1.x, t1.y,
    cmdz.float32,
  ]

proc drawRect(pos, size: Vec2) =
  ## Draw a simple rectangle using lines.
  let
    x = pos.x
    y = pos.y
    w = size.x
    h = size.y
  dataBufferSeq.add @[
    cmdM.float32, x, y,
    cmdL.float32, x, y,
    cmdL.float32, x + w, y,
    cmdL.float32, x + w, y + h,
    cmdL.float32, x, y + h,
    cmdz.float32,
  ]

proc drawPathCommands(commands: seq[PathCommand], windingRule: WindingRule) =
  ## Takes a path and turn it into commands.
  ## Including the windingRule.
  ## Inserts cmdStartPath/cmdEndPath.
  dataBufferSeq.add cmdStartPath.float32
  case windingRule
  of wrEvenOdd:
    dataBufferSeq.add 0
  of wrNonZero:
    dataBufferSeq.add 1

  for command in commands:
    case command.kind
    of pixie.Move:
      dataBufferSeq.add cmdM.float32
      var pos = vec2(command.numbers[0], command.numbers[1])
      dataBufferSeq.add pos.x
      dataBufferSeq.add pos.y
    of pixie.Line:
      dataBufferSeq.add cmdL.float32
      var pos = vec2(command.numbers[0], command.numbers[1])
      dataBufferSeq.add pos.x
      dataBufferSeq.add pos.y
    of pixie.Cubic:
      dataBufferSeq.add cmdC.float32
      for i in 0 ..< 3:
        var pos = vec2(
          command.numbers[i*2+0],
          command.numbers[i*2+1]
        )
        dataBufferSeq.add pos.x
        dataBufferSeq.add pos.y
    of pixie.Quad:
      assert command.numbers.len == 4
      dataBufferSeq.add cmdQ.float32
      for i in 0 ..< 2:
        var pos = vec2(
          command.numbers[i*2+0],
          command.numbers[i*2+1]
        )
        dataBufferSeq.add pos.x
        dataBufferSeq.add pos.y
    of pixie.Close:
      dataBufferSeq.add cmdz.float32
    else:
      quit($command.kind & " not supported command kind.")

  dataBufferSeq.add cmdEndPath.float32

proc drawGradientStops(paint: Paint) =
  # Add Gradient stops.
  dataBufferSeq.add @[
    cmdGradientStop.float32,
    -1E6,
    paint.gradientStops[0].color.r,
    paint.gradientStops[0].color.g,
    paint.gradientStops[0].color.b,
    paint.gradientStops[0].color.a
  ]
  for stop in paint.gradientStops:
    dataBufferSeq.add @[
      cmdGradientStop.float32,
      stop.position,
      stop.color.r,
      stop.color.g,
      stop.color.b,
      stop.color.a
    ]
  dataBufferSeq.add @[
    cmdGradientStop.float32,
    1E6,
    paint.gradientStops[^1].color.r,
    paint.gradientStops[^1].color.g,
    paint.gradientStops[^1].color.b,
    paint.gradientStops[^1].color.a
  ]

proc readyImages*(node: Node) =
  ## Walks the node tree making sure all images are in the atlas.
  proc readyImage(paint: Paint) =
    if paint.kind == pkImage:
      if paint.imageRef notin textureAtlas.entries:
        var image: pixie.Image
        try:
          image = readImage(figmaImagePath(paint.imageRef))
        except IOError, PixieError:
          echo "Issue loading image: ", node.name
          image = newImage(1, 1)
        textureAtlas.put(paint.imageRef, image)

  for paint in node.fills:
    paint.readyImage()
  for paint in node.strokes:
    paint.readyImage()
  for c in node.children:
    c.readyImages()

proc drawPaint(node: Node, paint: Paint) =
  ## Draws the paint for the node.
  if not paint.visible:
    return

  proc toImageSpace(handle: Vec2): Vec2 =
    vec2(
      handle.x * node.absoluteBoundingBox.w,
      handle.y * node.absoluteBoundingBox.h,
    )

  case paint.kind
  of pkImage:

    assert paint.imageRef in textureAtlas.entries, "Run readyImages first."
    let rect = textureAtlas.entries[paint.imageRef]
    let s = 1 / textureAtlas.size.float32

    var tileImage = 0.0
    var tMat: Mat3

    case paint.scaleMode

    of smFill, smFit:
      let
        ratioW = rect.w / node.size.x
        ratioH = rect.h / node.size.y
      var scalePx: float32
      if paint.scaleMode == smFill:
        scalePx = min(ratioW, ratioH)
      if paint.scaleMode == smFit:
        scalePx = max(ratioW, ratioH)
      let topRight = node.size / 2.0 - rect.wh / 2.0 / scalePx
      tMat = scale(vec2(s)) * translate(rect.xy) *
        (mat * translate(topRight) * scale(vec2(1/scalePx))).inverse()

    of smStretch: # Figma ui calls this "crop".
      var sMat: Mat3
      sMat[0, 0] = paint.imageTransform[0][0]
      sMat[0, 1] = paint.imageTransform[0][1]

      sMat[1, 0] = paint.imageTransform[1][0]
      sMat[1, 1] = paint.imageTransform[1][1]

      sMat[2, 0] = paint.imageTransform[0][2]
      sMat[2, 1] = paint.imageTransform[1][2]
      sMat[2, 2] = 1

      sMat = sMat.inverse()
      sMat[2, 0] = sMat[2, 0] * node.absoluteBoundingBox.w
      sMat[2, 1] = sMat[2, 1] * node.absoluteBoundingBox.h
      let
        ratioW = rect.w / node.absoluteBoundingBox.w
        ratioH = rect.h / node.absoluteBoundingBox.h
        scale = min(ratioW, ratioH)
      sMat = sMat * scale(vec2(1/scale))

      tMat = scale(vec2(s)) * translate(rect.xy) *
        (mat * sMat).inverse()

    of smTile:
      tileImage = 1.0
      tMat = scale(vec2(s)) * translate(rect.xy) *
        (mat * scale(vec2(paint.scalingFactor))).inverse()

    dataBufferSeq.add cmdTextureFill.float32
    dataBufferSeq.add tMat[0, 0]
    dataBufferSeq.add tMat[0, 1]
    dataBufferSeq.add tMat[1, 0]
    dataBufferSeq.add tMat[1, 1]
    dataBufferSeq.add tMat[2, 0]
    dataBufferSeq.add tMat[2, 1]
    dataBufferSeq.add tileImage
    dataBufferSeq.add rect.x * s
    dataBufferSeq.add rect.y * s
    dataBufferSeq.add rect.w * s
    dataBufferSeq.add rect.h * s

  of pkSolid:
    dataBufferSeq.add @[
      cmdSolidFill.float32,
      paint.color.r,
      paint.color.g,
      paint.color.b,
      paint.color.a * paint.opacity * opacity
    ]
  of pkGradientLinear:
    let
      at = paint.gradientHandlePositions[0].toImageSpace()
      to = paint.gradientHandlePositions[1].toImageSpace()
    # Setup the gradient location
    dataBufferSeq.add @[
      cmdGradientLinear.float32,
      at.x, at.y,
      to.x, to.y
    ]
    drawGradientStops(paint)

  of pkGradientRadial:
    let
      at = paint.gradientHandlePositions[0].toImageSpace()
      to = paint.gradientHandlePositions[1].toImageSpace()
    # Setup the gradient location
    dataBufferSeq.add @[
      cmdGradientRadial.float32,
      at.x, at.y,
      to.x, to.y
    ]
    drawGradientStops(paint)

  else:
    # debug pink
    dataBufferSeq.add @[
      cmdSolidFill.float32,
      1,
      0.5,
      0.5,
      1
    ]

  # dataBufferSeq.add @[
  #   cmdIndex.float32,
  #   node.idNum.float32
  # ]

proc computePixelBox*(node: Node) =
  ## Computes pixel bounds.
  ## Takes into account width, height and shadow extent, and children.
  ## In node's own coordinate system.

  node.pixelBox.xy = vec2(0, 0)
  node.pixelBox.wh = node.size

  var s = 1.0

  # Takes stroke into account:
  if node.strokes.len > 0:
    s = max(s, node.strokeWeight)

  # Take drop shadow into account:
  for effect in node.effects:
    if effect.kind in {ekDropShadow, ekInnerShadow, ekLayerBlur}:
      # Note: INNER_SHADOW needs just as much area around as drop shadow
      # because it needs to blur in.
      s = max(
        s,
        effect.radius +
        effect.spread +
        abs(effect.offset.x) +
        abs(effect.offset.y)
      )

  node.pixelBox.xy = node.pixelBox.xy - vec2(s, s)
  node.pixelBox.wh = node.pixelBox.wh + vec2(s, s) * 2

  # # Take children into account:
  # for child in node.children:
  #   child.computePixelBox()

  #   if not node.clipsContent:
  #     # TODO: clips content should still respect shadows.
  #     node.pixelBox = node.pixelBox or child.pixelBox

  # if node.pixelBox.x.fractional > 0:
  #   node.pixelBox.w += node.pixelBox.x.fractional
  #   node.pixelBox.x = node.pixelBox.x.floor

  # if node.pixelBox.y.fractional > 0:
  #   node.pixelBox.h += node.pixelBox.y.fractional
  #   node.pixelBox.y = node.pixelBox.y.floor

  # if node.pixelBox.w.fractional > 0:
  #   node.pixelBox.w = node.pixelBox.w.ceil

  # if node.pixelBox.h.fractional > 0:
  #   node.pixelBox.h = node.pixelBox.h.ceil

proc drawNode*(node: Node, level: int, rootMat = mat3()) =

  if not node.visible or node.opacity == 0:
    return

  var prevMat = mat
  var prevOpacity = opacity

  if level == 0:
    # Outside supplies level0 matrix.
    # Identity if drawing to screen
    # Location in the atlas when drawing to atlas.
    mat = rootMat
    opacity = 1.0
    framePos = -node.absoluteBoundingBox.xy
  else:
    mat = mat * node.transform()
    opacity = opacity * node.opacity

  if node.isMask:
    dataBufferSeq.add cmdMaskStart.float32

  dataBufferSeq.add cmdSetMat.float32
  dataBufferSeq.add mat[0, 0]
  dataBufferSeq.add mat[0, 1]
  dataBufferSeq.add mat[1, 0]
  dataBufferSeq.add mat[1, 1]
  dataBufferSeq.add mat[2, 0]
  dataBufferSeq.add mat[2, 1]

  if node.clipsContent and level != 0:
    # Node frame needs to clip its children.
    # Create a mask.
    # All frames are rounded rectangles of some sort.
    dataBufferSeq.add cmdMaskStart.float32

    dataBufferSeq.add cmdStartPath.float32
    dataBufferSeq.add kNonZero.float32
    if node.rectangleCornerRadii != nil:
      let r = node.rectangleCornerRadii
      drawRect(vec2(0, 0), node.size, r[0], r[1], r[2], r[3])
    elif node.cornerRadius > 0:
      let r = node.cornerRadius
      drawRect(vec2(0, 0), node.size, r, r, r, r)
    else:
      drawRect(vec2(0, 0), node.size)
    dataBufferSeq.add cmdEndPath.float32

    dataBufferSeq.add @[
      cmdSolidFill.float32,
      1,
      0.5,
      0.5,
      1
    ]

    dataBufferSeq.add cmdMaskPush.float32

  if node.blendMode != currentBlendMode:
    currentBlendMode = node.blendMode
    dataBufferSeq.add cmdSetBlendMode.float32
    dataBufferSeq.add ord(node.blendMode).float32

  node.computePixelBox()

  var hasBoundsCheck = false
  var jmpOffset = 0
  if level != 0:
    hasBoundsCheck = true
    dataBufferSeq.add cmdBoundCheck.float32
    dataBufferSeq.add node.pixelBox.x
    dataBufferSeq.add node.pixelBox.y
    dataBufferSeq.add node.pixelBox.x + node.pixelBox.w
    dataBufferSeq.add node.pixelBox.y + node.pixelBox.h
    jmpOffset = dataBufferSeq.len
    dataBufferSeq.add 0

  for effect in node.effects:
    if effect.kind == ekLayerBlur:
      dataBufferSeq.add cmdLayerBlur.float32
      dataBufferSeq.add effect.radius
    if effect.kind == ekDropShadow:
      dataBufferSeq.add @[
        cmdDropShadow.float32,
        effect.color.r,
        effect.color.g,
        effect.color.b,
        effect.color.a,
        effect.offset.x,
        effect.offset.y,
        effect.radius,
        effect.spread
      ]

  case node.kind
    of nkGroup:
      discard

    of nkRectangle, nkFrame, nkInstance, nkComponent:
      if node.fills.len > 0:
        if level == 0:
          dataBufferSeq.add cmdFullFill.float32
          discard
        else:
          if node.rectangleCornerRadii != nil:
            let r = node.rectangleCornerRadii
            dataBufferSeq.add cmdStartPath.float32
            dataBufferSeq.add kNonZero.float32
            drawRect(vec2(0, 0), node.size, r[0], r[1], r[2], r[3])
            dataBufferSeq.add cmdEndPath.float32
          elif node.cornerRadius > 0:
            let r = node.cornerRadius
            dataBufferSeq.add cmdStartPath.float32
            dataBufferSeq.add kNonZero.float32
            drawRect(vec2(0, 0), node.size, r, r, r, r)
            dataBufferSeq.add cmdEndPath.float32
          else:
            dataBufferSeq.add cmdStartPath.float32
            dataBufferSeq.add kNonZero.float32
            drawRect(vec2(0, 0), node.size)
            dataBufferSeq.add cmdEndPath.float32
            #dataBufferSeq.add cmdFullFill.float32

        for paint in node.fills:
          drawPaint(node, paint)

      if node.strokes.len > 0:
        let (inner, outer) = node.strokeInnerOuter()

        dataBufferSeq.add cmdStartPath.float32
        dataBufferSeq.add kEvenOdd.float32
        if node.rectangleCornerRadii != nil:
          let r = node.rectangleCornerRadii
          drawRect(
            vec2(-outer, -outer),
            node.size + vec2(outer*2, outer*2),
            r[0] + outer, r[1] + outer, r[2] + outer, r[3] + outer
          )
          drawRect(
            vec2(+inner, +inner),
            node.size - vec2(inner*2, inner*2),
            r[0] - inner, r[1] - inner, r[2] - inner, r[3] - inner
          )
        elif node.cornerRadius > 0:
          let r = node.cornerRadius
          drawRect(
            vec2(-outer, -outer),
            node.size + vec2(outer*2, outer*2),
            r + outer, r + outer, r + outer, r + outer
          )
          drawRect(
            vec2(+inner, +inner),
            node.size - vec2(inner*2, inner*2),
            r - inner, r - inner, r - inner, r - inner
          )
        else:
          drawRect(vec2(-outer, -outer), node.size + vec2(outer*2, outer*2))
          drawRect(vec2(+inner, +inner), node.size - vec2(inner*2, inner*2))
        dataBufferSeq.add cmdEndPath.float32

        for paint in node.strokes:
          drawPaint(node, paint)

    of nkEllipse:
      dataBufferSeq.add cmdStartPath.float32
      dataBufferSeq.add kNonZero.float32
      drawEllipse(node.size/2, node.size/2)
      dataBufferSeq.add cmdEndPath.float32
      for paint in node.fills:
        drawPaint(node, paint)

      if node.strokes.len > 0:
        let (inner, outer) = node.strokeInnerOuter()
        dataBufferSeq.add kEvenOdd.float32
        dataBufferSeq.add kNonZero.float32
        drawEllipse(node.size/2, node.size/2 + vec2(outer))
        drawEllipse(node.size/2, node.size/2 - vec2(inner))
        dataBufferSeq.add cmdEndPath.float32
        for paint in node.strokes:
          drawPaint(node, paint)

    of nkRegularPolygon, nkVector, nkStar, nkLine:
      for geom in node.fillGeometry:
        drawPathCommands(geom.path.commands, geom.windingRule)
        for paint in node.fills:
          drawPaint(node, paint)

      for geom in node.strokeGeometry:
        drawPathCommands(geom.path.commands, geom.windingRule)
        for paint in node.strokes:
          drawPaint(node, paint)

    of nkBooleanOperation:
      discard
      # # Set the child nodes as boolean operations
      # for i, c in node.children:
      #   c.blendMode =
      #     if i == 0:
      #       bmNormal
      #     else:
      #       case node.booleanOperation
      #         of boSubtract: bmSubtractMask
      #         of boIntersect: bmIntersectMask
      #         of boExclude: bmExcludeMask
      #         of boUnion: bmNormal

      # dataBufferSeq.add cmdMaskStart.float32
      # for c in node.children:
      #   drawNode(c, level + 1)
      # dataBufferSeq.add cmdMaskPush.float32

      # if node.blendMode != currentBlendMode:
      #   currentBlendMode = node.blendMode
      #   dataBufferSeq.add cmdSetBlendMode.float32
      #   dataBufferSeq.add ord(node.blendMode).float32
      # dataBufferSeq.add cmdFullFill.float32
      # for paint in node.fills:
      #   drawPaint(node, paint)

      # dataBufferSeq.add cmdMaskPop.float32

    of nkText:

      var font: Font
      if node.style.fontPostScriptName notin typefaceCache:
        if node.style.fontPostScriptName == "":
          node.style.fontPostScriptName = node.style.fontFamily & "-Regular"

        font = readFontTtf(figmaFontPath(node.style.fontPostScriptName))
        typefaceCache[node.style.fontPostScriptName] = font.typeface
      else:
        font = Font()
        font.typeface = typefaceCache[node.style.fontPostScriptName]
      font.size = node.style.fontSize
      font.lineHeight = node.style.lineHeightPx

      var wrap = false
      if node.style.textAutoResize == tarHeight:
        wrap = true

      let kern = node.style.opentypeFlags.KERN != 0

      let layout = font.typeset(
        text = if textBoxFocus == node:
            textBox.text
          else:
            node.characters,
        pos = vec2(0, 0),
        size = node.size,
        hAlign = node.style.textAlignHorizontal,
        vAlign = node.style.textAlignVertical,
        clip = false,
        wrap = wrap,
        kern = kern,
        textCase = node.style.textCase,
      )

      if node == textBoxFocus:
        for i, gpos in layout:
          # Draw text cursor and selection.
          proc drawCursor(rect: Rect) =
            dataBufferSeq.add cmdStartPath.float32
            dataBufferSeq.add kNonZero.float32
            drawRect(
              rect.xy,
              rect.wh
            )
            dataBufferSeq.add cmdEndPath.float32
            dataBufferSeq.add @[
              cmdSolidFill.float32,
              0,
              0,
              0,
              1
            ]
          if textBox.cursor == 0 and i == 0:
            drawCursor(rect(
              gpos.selectRect.x - 1,
              gpos.selectRect.y,
              1,
              gpos.selectRect.h
            ))
          elif textBox.cursor == i + 1:
            drawCursor(rect(
              gpos.selectRect.x + gpos.selectRect.w,
              gpos.selectRect.y,
              1,
              gpos.selectRect.h
            ))

      for i, gpos in layout:
        var font = gpos.font

        if gpos.character in font.typeface.glyphs:
          var glyph = font.typeface.glyphs[gpos.character]
          glyph.makeReady(font)

          if glyph.path.commands.len == 0:
            continue

          let cMat = mat * translate(vec2(
            gpos.rect.x + gpos.subPixelShift,
            gpos.rect.y
          )) * scale(vec2(font.scale, -font.scale))
          dataBufferSeq.add cmdSetMat.float32
          dataBufferSeq.add cMat[0, 0]
          dataBufferSeq.add cMat[0, 1]
          dataBufferSeq.add cMat[1, 0]
          dataBufferSeq.add cMat[1, 1]
          dataBufferSeq.add cMat[2, 0]
          dataBufferSeq.add cMat[2, 1]

          dataBufferSeq.add cmdBoundCheck.float32
          dataBufferSeq.add glyph.bboxMin.x
          dataBufferSeq.add glyph.bboxMin.y
          dataBufferSeq.add glyph.bboxMax.x
          dataBufferSeq.add glyph.bboxMax.y
          let jmpOffset = dataBufferSeq.len
          dataBufferSeq.add 0

          drawPathCommands(glyph.path.commands, wrNonZero)

          for paint in node.fills:
            drawPaint(node, paint)

          dataBufferSeq[jmpOffset] = dataBufferSeq.len.float32

    else:
      echo($node.kind & " not supported")

  if hasBoundsCheck:
    dataBufferSeq[jmpOffset] = dataBufferSeq.len.float32

  if node.kind != nkBooleanOperation:
    # Draw the child nodes normally
    for c in node.children:
      drawNode(c, level + 1)

  # Pop all of the child mask nodes.
  for c in node.children:
    if c.isMask:
      dataBufferSeq.add cmdMaskPop.float32

  if node.clipsContent and level != 0:
    dataBufferSeq.add cmdMaskPop.float32

  if node.isMask:
    dataBufferSeq.add cmdMaskPush.float32

  mat = prevMat
  opacity = prevOpacity

proc drawToScreen*(node: Node) =
  ## Draws the GPU frame to screen.

  setupRender(node)
  perfMark "setupRender"
  node.readyImages()
  perfMark "readyImages"
  updateGpuAtlas()
  perfMark "updateGpuAtlas"

  if scissorOn:
    glDisable(GL_SCISSOR_TEST)
    scissorOn = false
  if currentFrameBufferId != 0:
    currentFrameBufferId = 0
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
  if viewportRect != rect(0, 0, viewportSize.x, viewportSize.y):
    viewportRect = rect(0, 0, viewportSize.x, viewportSize.y)
    window.setWindowSize(viewportSize.x.cint, viewportSize.y.cint)
    glViewport(
      viewportRect.x.cint,
      viewportRect.y.cint,
      viewportRect.w.cint,
      viewportRect.h.cint
    )

  node.box.xy = vec2(0, 0)
  node.size = node.box.wh
  for c in node.children:
    computeLayout(node, c)
  perfMark "computeLayout"

  drawNode(node, 0)
  perfMark "drawNode"

  #dataBufferSeq.setLen(0)
  dataBufferSeq.add(cmdExit.float32)
  #print dataBufferSeq.len
  drawBuffers()
  perfMark "drawBuffers"


proc drawGpuFrameToAtlas*(node: Node, name: string) =
  ## Draws the GPU frame to atlas.
  setupRender(node)

  if name notin textureAtlas.entries:
    # Add a spot for the screen to go
    var toImage = newImage(viewportSize.x.int, viewportSize.y.int)
    toImage.fill(rgba(255, 0, 0, 255))
    textureAtlas.put(name, toImage)

  node.readyImages()
  updateGpuAtlas()

  glBindFramebuffer(GL_FRAMEBUFFER, backBufferId)
  glEnable(GL_SCISSOR_TEST)

  let entry = textureAtlas.entries[name]
  let rootMat = translate(vec2(
    entry.x,
    textureAtlas.image.height.float32 - entry.y
  )) * scale(vec2(1, -1))
  glScissor(
    entry.x.cint,
    entry.y.cint,
    entry.w.cint,
    entry.h.cint,
  )
  glViewport(
    0,
    0,
    textureAtlas.image.width.cint,
    textureAtlas.image.width.cint
  )

  node.box.xy = vec2(0, 0)
  node.size = node.box.wh
  for c in node.children:
    computeLayout(node, c)

  drawNode(node, 0, rootMat)
  dataBufferSeq.add(cmdExit.float32)
  drawBuffers()

proc readGpuPixelsFromScreen*(): pixie.Image =
  ## Read the GPU pixels from screen.
  ## Use for debugging and tests only.
  #dumpCommandStream()
  let start = epochTime()
  var screen = newImage(viewportSize.x.int, viewportSize.x.int)
  glReadPixels(
    0, 0,
    screen.width.Glint, screen.height.Glint,
    GL_RGBA, GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  screen.flipVertical()
  echo "readGpuPixelsFromScreen: ", (epochTime() - start)*1000, "ms"
  return screen

proc readGpuPixelsFromAtlas*(name: string, crop = true): pixie.Image =
  ## Read the GPU pixels from atlas
  ## Note: Very slow even for debugging and tests as it needs to read
  ## the whole atlas back into memory.
  var screen = newImage(
    textureAtlas.image.width.GLsizei,
    textureAtlas.image.height.GLsizei,
  )
  glBindTexture(GL_TEXTURE_2D, textureAtlasId)
  glGetTexImage(
    GL_TEXTURE_2D,
    0,
    GL_RGBA,
    GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  if crop:
    let rect = textureAtlas.entries[name]
    let cutout = screen.subImage(
      rect.x.int,
      rect.y.int,
      rect.w.int,
      rect.h.int
    )
    return cutout
  else:
    return screen

proc dumpCommandStream*() =
  ## Prints commands stream in a readable format:
  var i = 0
  while true:
    let command = dataBufferSeq[i].int

    if command == cmdExit:
      print i, "cmdExit"
      break

    elif command == cmdStartPath:
      let rule = dataBufferSeq[i + 1]
      print i, "cmdStartPath", rule
      i += 1

    elif command == cmdEndPath:
      print i, "cmdEndPath"

    elif command == cmdSolidFill:
      let c = chroma.color(
        dataBufferSeq[i + 1],
        dataBufferSeq[i + 2],
        dataBufferSeq[i + 3],
        dataBufferSeq[i + 4]
      )
      i += 4
      print i, "cmdSolidFill", c

    elif command == cmdApplyOpacity:
      let opacity = dataBufferSeq[i + 1]
      print i, "cmdApplyOpacity", opacity
      i += 1

    elif command == cmdTextureFill:
      var tMat: Mat3
      tMat[0, 0] = dataBufferSeq[i + 1]
      tMat[0, 1] = dataBufferSeq[i + 2]
      tMat[0, 2] = 0
      tMat[1, 0] = dataBufferSeq[i + 3]
      tMat[1, 1] = dataBufferSeq[i + 4]
      tMat[1, 2] = 0
      tMat[2, 0] = dataBufferSeq[i + 5]
      tMat[2, 1] = dataBufferSeq[i + 6]
      tMat[2, 2] = 1
      let tile = dataBufferSeq[i + 7]
      var pos: Vec2
      pos.x = dataBufferSeq[i + 8]
      pos.y = dataBufferSeq[i + 9]
      var size: Vec2
      size.x = dataBufferSeq[i + 10]
      size.y = dataBufferSeq[i + 11]
      i += 11
      print i, "cmdTextureFill", tMat, tile, pos, size

    elif command == cmdGradientLinear:
      var at, to: Vec2
      at.x = dataBufferSeq[i + 1]
      at.y = dataBufferSeq[i + 2]
      to.x = dataBufferSeq[i + 3]
      to.y = dataBufferSeq[i + 4]
      i += 4
      print i, "cmdGradientLinear", at, to

    elif command == cmdGradientRadial:
      var at, to: Vec2
      at.x = dataBufferSeq[i + 1]
      at.y = dataBufferSeq[i + 2]
      to.x = dataBufferSeq[i + 3]
      to.y = dataBufferSeq[i + 4]
      i += 4
      print i, "cmdGradientRadial", at, to

    elif command == cmdGradientStop:
      print i, "cmdGradientStop", (
        dataBufferSeq[i + 1],
        dataBufferSeq[i + 2],
        dataBufferSeq[i + 3],
        dataBufferSeq[i + 4],
        dataBufferSeq[i + 5]
      )
      i += 5

    elif command == cmdSetMat:
      var mat: Mat3
      mat[0, 0] = dataBufferSeq[i + 1]
      mat[0, 1] = dataBufferSeq[i + 2]
      mat[0, 2] = 0
      mat[1, 0] = dataBufferSeq[i + 3]
      mat[1, 1] = dataBufferSeq[i + 4]
      mat[1, 2] = 0
      mat[2, 0] = dataBufferSeq[i + 5]
      mat[2, 1] = dataBufferSeq[i + 6]
      mat[2, 2] = 1
      i += 6
      print i, "cmdSetMat", mat

    elif command == cmdM:
      let to = vec2(
        dataBufferSeq[i + 1],
        dataBufferSeq[i + 2]
      )
      i += 2
      print i, "cmdM", to

    elif command == cmdL:
      let to = vec2(
        dataBufferSeq[i + 1],
        dataBufferSeq[i + 2]
      )
      i += 2
      print i, "cmdL", to

    elif command == cmdC:
      let args = (
        dataBufferSeq[i + 1],
        dataBufferSeq[i + 2],
        dataBufferSeq[i + 3],
        dataBufferSeq[i + 4],
        dataBufferSeq[i + 5],
        dataBufferSeq[i + 6]
      )
      i += 6
      print i, "cmdC", args

    elif command == cmdQ:
      let args = (
        dataBufferSeq[i + 1],
        dataBufferSeq[i + 2],
        dataBufferSeq[i + 3],
        dataBufferSeq[i + 4],
      )
      i += 4
      print i, "cmdQ", args

    elif command == cmdz:
      print i, "cmdz"

    elif command == cmdBoundCheck:
      # Jump over code if screen not in bounds
      var
        minP: Vec2
        maxP: Vec2
      minP.x = dataBufferSeq[i + 1]
      minP.y = dataBufferSeq[i + 2]
      maxP.x = dataBufferSeq[i + 3]
      maxP.y = dataBufferSeq[i + 4]
      let label = dataBufferSeq[i + 5].int
      i += 5
      print i, "cmdBoundCheck", minP, maxP, label

    elif command == cmdMaskStart:
      print i, "cmdMaskStart"

    elif command == cmdMaskPush:
      print i, "cmdMaskPush"

    elif command == cmdMaskPop:
      print i, "cmdMaskPop"

    elif command == cmdIndex:
      let index = dataBufferSeq[i + 1]
      i += 1
      print i, "cmdIndex", index

    elif command == cmdLayerBlur:
      let layerBlur = dataBufferSeq[i + 1]
      i += 1
      print i, "cmdLayerBlur", layerBlur

    elif command == cmdDropShadow:
      var shadowColor: Vec4
      shadowColor.x = dataBufferSeq[i + 1]
      shadowColor.y = dataBufferSeq[i + 2]
      shadowColor.z = dataBufferSeq[i + 3]
      shadowColor.w = dataBufferSeq[i + 4]
      var shadowOffset: Vec2
      shadowOffset.x = dataBufferSeq[i + 5]
      shadowOffset.y = dataBufferSeq[i + 6]
      let shadowRadius = dataBufferSeq[i + 7]
      let shadowSpread = dataBufferSeq[i + 8]
      i += 8
      print i, "cmdDropShadow", shadowColor, shadowOffset, shadowRadius, shadowSpread

    elif command == cmdSetBlendMode:
      let blendMode = dataBufferSeq[i + 1]
      print i, "cmdSetBlendMode", blendMode
      i += 1

    elif command == cmdSetBoolMode:
      let boolMode = dataBufferSeq[i + 1]
      print i, "cmdSetBoolMode", boolMode
      i += 1

    elif command == cmdFullFill:
      print i, "cmdFullFill"

    else:
      quit("Unknown command?")

    i += 1
