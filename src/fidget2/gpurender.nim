import atlas, pixie, tables, print, chroma,
  math, opengl, staticglfw, vmath, glsl, gpushader, math,
  pixie, tables, typography, schema, bumpy, loader, layout, typography/textboxes

var
  # Window stuff.
  viewPortWidth*: int
  viewPortHeight*: int
  window*: Window
  offscreen* = false

  # Text edit.
  textBox*: TextBox
  textBoxFocus*: Node

  # Buffers.
  dataBufferSeq*: seq[float32]
  mat*: Mat3
  opacity*: float32
  framePos*: Vec2
  typefaceCache*: Table[string, Typeface]

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

  vertShaderSrc = toShader(basic2dVert, "300 es")
  #fragShaderSrc = readFile("bufferTest.glsl")
  #fragShaderSrc = readFile("svg4.glsl")
  fragShaderSrc = toShader(svgMain, "300 es")

  vertShaderArray = allocCStringArray([vertShaderSrc])  # dealloc'd at the end
  fragShaderArray = allocCStringArray([fragShaderSrc])  # dealloc'd at the end

  # Status variables
  isCompiled: GLint
  isLinked: GLint

proc updateGpuAtlas() =
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
  viewPortWidth = frameNode.absoluteBoundingBox.w.int
  viewPortHeight = frameNode.absoluteBoundingBox.h.int
  dataBufferSeq.setLen(0)

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

proc createWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true
) =

  setupRender(frameNode)
  dataBufferSeq.add(cmdExit)

  # init libraries
  if init() == 0:
    raise newException(Exception, "Failed to intialize GLFW")

  # Open a window
  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  windowHint(SAMPLES, 0)
  window = createWindow(
    viewPortWidth.cint, viewPortHeight.cint,
    "run_shaders",
    nil,
    nil)
  window.makeContextCurrent()

  # Load opengl
  loadExtensions()

  # The data for (and about) OpenGL
  # echo vertShaderSrc
  # echo fragShaderSrc

  writeFile("tmp.glsl", fragShaderSrc)

  glDisable(GL_MULTISAMPLE)

  # Bind the vertices
  glGenBuffers(1, vertexVBO.addr)
  glBindBuffer(GL_ARRAY_BUFFER, vertexVBO)
  glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, vertices.addr, GL_STATIC_DRAW)

  # The array object
  glGenVertexArrays(1, vao.addr)
  glBindVertexArray(vao)
  glBindBuffer(GL_ARRAY_BUFFER, vertexVBO);
  glVertexAttribPointer(0, 2, cGL_FLOAT, GL_FALSE, 0, nil)
  glEnableVertexAttribArray(0)

  glGenBuffers(1, dataBufferId.addr)
  glBindBuffer(GL_TEXTURE_BUFFER, dataBufferId)
  glBufferData(GL_TEXTURE_BUFFER, dataBufferSeq.len * 4, dataBufferSeq[0].addr, GL_STATIC_DRAW)

  glActiveTexture(GL_TEXTURE0)
  glGenTextures(1, dataBufferTextureId.addr)
  glBindTexture(GL_TEXTURE_BUFFER, dataBufferTextureId)
  glTexBuffer(GL_TEXTURE_BUFFER, GL_R32F, dataBufferId)

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

  # Compile shaders
  # Vertex
  vertShader = glCreateShader(GL_VERTEX_SHADER)
  glShaderSource(vertShader, 1, vertShaderArray, nil)
  glCompileShader(vertShader)
  glGetShaderiv(vertShader, GL_COMPILE_STATUS, isCompiled.addr)

  # Check vertex compilation status
  block:
    var logSize: GLint
    glGetShaderiv(vertShader, GL_INFO_LOG_LENGTH, logSize.addr)
    if logSize > 0:
      var
        logStr = cast[ptr GLchar](alloc(logSize))
        logLen: GLsizei
      glGetShaderInfoLog(vertShader, logSize.GLsizei, logLen.addr, logStr)
      echo $logStr
  if isCompiled == 0:
    quit "Vertex Shader wasn't compiled."

  # Fragment
  fragShader = glCreateShader(GL_FRAGMENT_SHADER)
  glShaderSource(fragShader, 1, fragShaderArray, nil)
  glCompileShader(fragShader)
  glGetShaderiv(fragShader, GL_COMPILE_STATUS, isCompiled.addr)

  # Check Fragment compilation status
  block:
    var logSize: GLint
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, logSize.addr)
    if logSize > 0:
      var
        logStr = cast[ptr GLchar](alloc(logSize))
        logLen: GLsizei
      glGetShaderInfoLog(fragShader, logSize.GLsizei, logLen.addr, logStr)
      echo($logStr)
  if isCompiled == 0:
    quit("Fragment Shader wasn't compiled.")

  # Attach to a GL program
  shaderProgram = glCreateProgram()
  glAttachShader(shaderProgram, vertShader);
  glAttachShader(shaderProgram, fragShader);

  # insert locations
  glBindAttribLocation(shaderProgram, 0, "vertexPos");

  glLinkProgram(shaderProgram);

  # Check for shader linking errors
  glGetProgramiv(shaderProgram, GL_LINK_STATUS, isLinked.addr)

  block:
    var logSize: GLint
    glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, logSize.addr)
    if logSize > 0:
      var
        logStr = cast[ptr GLchar](alloc(logSize))
        logLen: GLsizei
      glGetProgramInfoLog(shaderProgram, logSize.GLsizei, logLen.addr, logStr)
      echo($logStr)
  if isLinked == 0:
    quit("Wasn't able to link shaders.")

  echo "Shader compiled"

  glUseProgram(shaderProgram)

  var dataBufferLoc = glGetUniformLocation(shaderProgram, "dataBuffer")
  glUniform1i(dataBufferLoc, 0) # Set dataBuffer to 0th texture.

  var textureAtlasLoc = glGetUniformLocation(shaderProgram, "textureAtlasSampler")
  glUniform1i(textureAtlasLoc, 1) # Set textureAtlas to 1th texture.

  # Generate background frame buffer.
  glGenFramebuffers(1, backBufferId.addr)
  glBindFramebuffer(GL_FRAMEBUFFER, backBufferId)
  print "glBindFramebuffer", backBufferId

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

const splinyCirlce = 4.0 * (-1.0 + sqrt(2.0)) / 3

proc drawEllipse(pos, size: Vec2) =
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
    cmdM, t1.x, t1.y,
    cmdC, t2h.x, t2h.y, r1h.x, r1h.y, r1.x, r1.y,
    cmdC, r2h.x, r2h.y, b1h.x, b1h.y, b1.x, b1.y,
    cmdC, b2h.x, b2h.y, l1h.x, l1h.y, l1.x, l1.y,
    cmdC, l2h.x, l2h.y, t1h.x, t1h.y, t1.x, t1.y,
    cmdz,
  ]


proc drawRect(pos, size: Vec2, nw, ne, se, sw: float32) =
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
    cmdM, t1.x, t1.y,
    cmdL, t2.x, t2.y,
    cmdC, t2h.x, t2h.y, r1h.x, r1h.y, r1.x, r1.y,
    cmdL, r2.x, r2.y,
    cmdC, r2h.x, r2h.y, b1h.x, b1h.y, b1.x, b1.y,
    cmdL, b2.x, b2.y,
    cmdC, b2h.x, b2h.y, l1h.x, l1h.y, l1.x, l1.y,
    cmdL, l2.x, l2.y,
    cmdC, l2h.x, l2h.y, t1h.x, t1h.y, t1.x, t1.y,
    cmdz,
  ]

proc drawRect(pos, size: Vec2) =
  let
    x = pos.x
    y = pos.y
    w = size.x
    h = size.y
  dataBufferSeq.add @[
    cmdM, x, y,
    cmdL, x, y,
    cmdL, x + w, y,
    cmdL, x + w, y + h,
    cmdL, x, y + h,
    cmdz,
  ]

proc drawPathCommands(commands: seq[PathCommand], windingRule: WindingRule) =
  dataBufferSeq.add cmdStartPath
  case windingRule
  of wrEvenOdd:
    dataBufferSeq.add 0
  of wrNonZero:
    dataBufferSeq.add 1

  for command in commands:
    case command.kind
    of pixie.Move:
      dataBufferSeq.add cmdM
      var pos = vec2(command.numbers[0], command.numbers[1])
      dataBufferSeq.add pos.x
      dataBufferSeq.add pos.y
    of pixie.Line:
      dataBufferSeq.add cmdL
      var pos = vec2(command.numbers[0], command.numbers[1])
      dataBufferSeq.add pos.x
      dataBufferSeq.add pos.y
    of pixie.Cubic:
      dataBufferSeq.add cmdC
      for i in 0 ..< 3:
        var pos = vec2(
          command.numbers[i*2+0],
          command.numbers[i*2+1]
        )
        dataBufferSeq.add pos.x
        dataBufferSeq.add pos.y
    of pixie.Quad:
      assert command.numbers.len == 4
      dataBufferSeq.add cmdQ
      for i in 0 ..< 2:
        var pos = vec2(
          command.numbers[i*2+0],
          command.numbers[i*2+1]
        )
        dataBufferSeq.add pos.x
        dataBufferSeq.add pos.y
    of pixie.End:
      dataBufferSeq.add cmdz
    else:
      quit($command.kind & " not supported command kind.")

  dataBufferSeq.add cmdEndPath

proc drawGradientStops(paint: Paint) =
  # Gradient stops
  dataBufferSeq.add @[
    cmdGradientStop,
    -1E6,
    paint.gradientStops[0].color.r,
    paint.gradientStops[0].color.g,
    paint.gradientStops[0].color.b,
    paint.gradientStops[0].color.a
  ]
  for stop in paint.gradientStops:
    dataBufferSeq.add @[
      cmdGradientStop,
      stop.position,
      stop.color.r,
      stop.color.g,
      stop.color.b,
      stop.color.a
    ]
  dataBufferSeq.add @[
    cmdGradientStop,
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
        downloadImageRef(paint.imageRef)
        try:
          image = readImage("figma/images/" & paint.imageRef & ".png")
        except IOError, PixieError:
          echo "Issue loading image: ", node.name
          image = newImage(1,1)
        textureAtlas.put(paint.imageRef, image)

  for paint in node.fills:
    paint.readyImage()
  for paint in node.strokes:
    paint.readyImage()
  for c in node.children:
    c.readyImages()

proc drawPaint(node: Node, paint: Paint) =
  if not paint.visible:
    return

  if node.isMask:
    dataBufferSeq.add @[
      cmdMaskFill
    ]
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
    let s = 1 / textureAtlas.image.width.float32

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

    dataBufferSeq.add cmdTextureFill
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
      cmdSolidFill,
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
      cmdGradientLinear,
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
      cmdGradientRadial,
      at.x, at.y,
      to.x, to.y
    ]
    drawGradientStops(paint)

  else:
    # debug pink
    dataBufferSeq.add @[
      cmdSolidFill,
      1,
      0.5,
      0.5,
      1
    ]

  dataBufferSeq.add @[
    cmdIndex,
    node.idNum.float32
  ]

proc computePixelBox*(node: Node) =

  ## Computes pixel bounds.
  ## Takes into account width, height and shadow extent, and children.
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
    mat = rootMat
    #mat.identity()
    #mat = mat * translate(rootOffset)
    # mat = mat * translate(vec2(
    #   0,
    #   (textureAtlas.image.height - viewPortHeight).float32
    # ))
    opacity = 1.0
    framePos = -node.absoluteBoundingBox.xy
  else:
    mat = mat * node.transform()
    opacity = opacity * node.opacity

  dataBufferSeq.add cmdSetMat
  dataBufferSeq.add mat[0, 0]
  dataBufferSeq.add mat[0, 1]
  dataBufferSeq.add mat[1, 0]
  dataBufferSeq.add mat[1, 1]
  dataBufferSeq.add mat[2, 0]
  dataBufferSeq.add mat[2, 1]

  node.computePixelBox()

  var jmpOffset = 0
  if not node.isMask:
    dataBufferSeq.add cmdBoundCheck
    dataBufferSeq.add node.pixelBox.x
    dataBufferSeq.add node.pixelBox.y
    dataBufferSeq.add node.pixelBox.x + node.pixelBox.w
    dataBufferSeq.add node.pixelBox.y + node.pixelBox.h
    jmpOffset = dataBufferSeq.len
    dataBufferSeq.add 0

  for effect in node.effects:
    if effect.kind == ekLayerBlur:
      dataBufferSeq.add cmdLayerBlur
      print effect.radius
      dataBufferSeq.add effect.radius
    if effect.kind == ekDropShadow:
      dataBufferSeq.add @[
        cmdDropShadow,
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

    of nkRectangle, nkFrame, nkInstance:
      if node.fills.len > 0:
        dataBufferSeq.add cmdStartPath
        dataBufferSeq.add 0
        if node.rectangleCornerRadii.len == 4:
          let r = node.rectangleCornerRadii
          drawRect(vec2(0, 0), node.size, r[0], r[1], r[2], r[3])
        elif node.cornerRadius > 0:
          let r = node.cornerRadius
          drawRect(vec2(0, 0), node.size, r, r, r, r)
        else:
          drawRect(vec2(0, 0), node.size)
        dataBufferSeq.add cmdEndPath
        for paint in node.fills:
          drawPaint(node, paint)

      if node.strokes.len > 0:
        let (inner, outer) = node.strokeInnerOuter()

        dataBufferSeq.add cmdStartPath
        dataBufferSeq.add 0
        if node.rectangleCornerRadii.len == 4:
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
        dataBufferSeq.add cmdEndPath

        for paint in node.strokes:
          drawPaint(node, paint)

    of nkEllipse:
      dataBufferSeq.add cmdStartPath
      dataBufferSeq.add 0
      drawEllipse(node.size/2, node.size/2)
      dataBufferSeq.add cmdEndPath
      for paint in node.fills:
        drawPaint(node, paint)

      if node.strokes.len > 0:
        let (inner, outer) = node.strokeInnerOuter()
        dataBufferSeq.add cmdStartPath
        dataBufferSeq.add 0
        drawEllipse(node.size/2, node.size/2 + vec2(outer))
        drawEllipse(node.size/2, node.size/2 - vec2(inner))
        dataBufferSeq.add cmdEndPath
        for paint in node.strokes:
          drawPaint(node, paint)

    of nkRegularPolygon, nkVector, nkStar, nkLine:
      for geom in node.fillGeometry:
        drawPathCommands(parsePath(geom.path).commands, geom.windingRule)
        for paint in node.fills:
          drawPaint(node, paint)

      for geom in node.strokeGeometry:
        drawPathCommands(parsePath(geom.path).commands, geom.windingRule)
        for paint in node.strokes:
          drawPaint(node, paint)

    of nkText:

      var font: Font
      if node.style.fontPostScriptName notin typefaceCache:
        if node.style.fontPostScriptName == "":
          node.style.fontPostScriptName = node.style.fontFamily & "-Regular"

        downloadFont(node.style.fontPostScriptName)
        font = readFontTtf("figma/fonts/" & node.style.fontPostScriptName & ".ttf")
        typefaceCache[node.style.fontPostScriptName] = font.typeface
      else:
        font = Font()
        font.typeface = typefaceCache[node.style.fontPostScriptName]
      font.size = node.style.fontSize
      font.lineHeight = node.style.lineHeightPx

      var wrap = false
      if node.style.textAutoResize == tarHeight:
        wrap = true

      var kern = true
      if node.style.opentypeFlags != nil:
        if node.style.opentypeFlags.KERN == 0:
          kern = false

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
            dataBufferSeq.add cmdStartPath
            dataBufferSeq.add kNonZero
            drawRect(
              rect.xy,
              rect.wh
            )
            dataBufferSeq.add cmdEndPath
            dataBufferSeq.add @[
              cmdSolidFill,
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

          if glyph.commands.len == 0:
            continue

          let cMat = mat * translate(vec2(
            gpos.rect.x + gpos.subPixelShift,
            gpos.rect.y
          )) * scale(vec2(font.scale, -font.scale))
          dataBufferSeq.add cmdSetMat
          dataBufferSeq.add cMat[0, 0]
          dataBufferSeq.add cMat[0, 1]
          dataBufferSeq.add cMat[1, 0]
          dataBufferSeq.add cMat[1, 1]
          dataBufferSeq.add cMat[2, 0]
          dataBufferSeq.add cMat[2, 1]

          dataBufferSeq.add cmdBoundCheck
          dataBufferSeq.add glyph.bboxMin.x
          dataBufferSeq.add glyph.bboxMin.y
          dataBufferSeq.add glyph.bboxMax.x
          dataBufferSeq.add glyph.bboxMax.y
          let jmpOffset = dataBufferSeq.len
          dataBufferSeq.add 0

          drawPathCommands(glyph.commands, wrNonZero)

          for paint in node.fills:
            drawPaint(node, paint)

          dataBufferSeq[jmpOffset] = dataBufferSeq.len.float32

    else:
      echo($node.kind & " not supported")

  if not node.isMask:
    dataBufferSeq[jmpOffset] = dataBufferSeq.len.float32

  for childNode in node.children:
    drawNode(childNode, level + 1)

  mat = prevMat
  opacity = prevOpacity

proc drawGpuFrameToScreen*(node: Node) =
  setupRender(node)
  node.readyImages()
  updateGpuAtlas()

  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  glViewport(
    0,
    0,
    viewPortWidth.cint,
    viewPortHeight.cint
  )

  node.box.xy = vec2(0, 0)
  node.size = node.box.wh
  for c in node.children:
    computeLayout(node, c)

  drawNode(node, 0)
  dataBufferSeq.add(cmdExit)
  drawBuffers()

proc drawGpuFrameToAtlas*(node: Node, name: string) =
  setupRender(node)

  if name notin textureAtlas.entries:
    # var dummyImage = newImage(1000, 212)
    # dummyImage.fill(rgba(255, 0, 0, 255))
    # textureAtlas.put("dummpy", dummyImage)

    ## Add a spot for the screen to go
    var toImage = newImage(viewPortWidth, viewPortHeight)
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
  dataBufferSeq.add(cmdExit)
  drawBuffers()

proc readGpuPixelsFromScreen*(): pixie.Image =
  var screen = newImage(viewPortWidth, viewPortHeight)
  glReadPixels(
    0, 0,
    screen.width.Glint, screen.height.Glint,
    GL_RGBA, GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  screen.flipVertical()
  return screen

proc readGpuPixelsFromAtlas*(name: string, crop=true): pixie.Image =
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
