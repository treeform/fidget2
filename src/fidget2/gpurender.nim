import atlas, chroma, os, fidget2, pixie, strutils, strformat, times,
  math, opengl, staticglfw, times, vmath, glsl, gpushader, print, math,
  pixie

var
  viewPortWidth*: int
  viewPortHeight*: int
  windowReady = false

  # Data Buffer Object

  dataBufferSeq*: seq[float32]
  mat*, prevMat*: Mat3
  opacity*, prevOpacity*: float32

  # OpenGL stuff.
  dataBufferTextureId: GLuint
  textureAtlas: CpuAtlas
  textureAtlasId: GLuint

proc setupGpuRender(width, height: int) =
  viewPortWidth = width
  viewPortHeight = height
  dataBufferSeq.setLen(0)
  textureAtlas = newCpuAtlas(1024, 1)

proc basic2dVert(vertexPox: Vec2, gl_Position: var Vec4) =
  gl_Position.xy = vertexPox

var
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

  vertShaderSrc = toShader(basic2dVert, "300 es")
  #fragShaderSrc = readFile("bufferTest.glsl")
  #fragShaderSrc = readFile("svg4.glsl")
  fragShaderSrc = toShader(svgMain, "300 es")

  vertShaderArray = allocCStringArray([vertShaderSrc])  # dealloc'd at the end
  fragShaderArray = allocCStringArray([fragShaderSrc])  # dealloc'd at the end

  # Status variables
  isCompiled: GLint
  isLinked: GLint

  dataBufferId: GLuint

proc readGpuPixels(): pixie.Image =

  if not windowReady:

    # init libraries
    if init() == 0:
      raise newException(Exception, "Failed to intialize GLFW")

    # Open a window
    windowHint(VISIBLE, false.cint)
    var window = createWindow(
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

    var image = readImage("tests/test512.png")
    textureAtlas.put("test512", image)
    # textureAtlas.image.writeFile("atlas.png")

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
    if isCompiled == 0:
      echo "Vertex Shader wasn't compiled.  Reason:"
      var logSize: GLint
      glGetShaderiv(vertShader, GL_INFO_LOG_LENGTH, logSize.addr)
      var
        logStr = cast[ptr GLchar](alloc(logSize))
        logLen: GLsizei
      glGetShaderInfoLog(vertShader, logSize.GLsizei, logLen.addr, logStr)
      quit($logStr)

    # Fragment
    fragShader = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fragShader, 1, fragShaderArray, nil)
    glCompileShader(fragShader)
    glGetShaderiv(fragShader, GL_COMPILE_STATUS, isCompiled.addr)

    # Check Fragment compilation status
    if isCompiled == 0:
      echo "Fragment Shader wasn't compiled.  Reason:"
      var logSize: GLint
      glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, logSize.addr)
      var
        logStr = cast[ptr GLchar](alloc(logSize))
        logLen: GLsizei
      glGetShaderInfoLog(fragShader, logSize.GLsizei, logLen.addr, logStr)
      quit($logStr)

    # Attach to a GL program
    shaderProgram = glCreateProgram()
    glAttachShader(shaderProgram, vertShader);
    glAttachShader(shaderProgram, fragShader);

    # insert locations
    glBindAttribLocation(shaderProgram, 0, "vertexPos");

    glLinkProgram(shaderProgram);

    # Check for shader linking errors
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, isLinked.addr)
    if isLinked == 0:
      echo "Wasn't able to link shaders.  Reason:"
      var logSize: GLint
      glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, logSize.addr)
      var
        logStr = cast[ptr GLchar](alloc(logSize))
        logLen: GLsizei
      glGetProgramInfoLog(shaderProgram, logSize.GLsizei, logLen.addr, logStr)
      quit($logStr)

    glUseProgram(shaderProgram)

    var dataBufferLoc = glGetUniformLocation(shaderProgram, "dataBuffer")
    glUniform1i(dataBufferLoc, 0) # Set dataBuffer to 0th texture.

    var textureAtlasLoc = glGetUniformLocation(shaderProgram, "textureAtlas")
    print textureAtlasLoc
    glUniform1i(textureAtlasLoc, 1) # Set textureAtlas to 1th texture.

    windowReady = true

  glBindBuffer(GL_TEXTURE_BUFFER, dataBufferId)
  glBufferData(GL_TEXTURE_BUFFER, dataBufferSeq.len * 4, dataBufferSeq[0].addr, GL_STATIC_DRAW)

  # Clear and setup drawing
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  glUseProgram(shaderProgram)

  # Do the drawing
  glBindVertexArray(vao)
  glDrawElements(GL_TRIANGLE_FAN, indices.len.GLsizei, GL_UNSIGNED_BYTE, indices.addr)

  var screen = newImage(viewPortWidth, viewPortHeight)
  glReadPixels(
    0, 0,
    screen.width.Glint, screen.height.Glint,
    GL_RGBA, GL_UNSIGNED_BYTE,
    screen.data[0].addr
  )
  return screen

proc transform(node: Node): Mat3 =
  ## Returns Mat3 transform of the node.
  result[0, 0] = node.relativeTransform[0][0]
  result[0, 1] = node.relativeTransform[1][0]
  result[0, 2] = 0

  result[1, 0] = node.relativeTransform[0][1]
  result[1, 1] = node.relativeTransform[1][1]
  result[1, 2] = 0

  result[2, 0] = node.relativeTransform[0][2]
  result[2, 1] = node.relativeTransform[1][2]
  result[2, 2] = 1

proc drawRect(pos, size: Vec2, nw, ne, se, sw: float32) =
  # ctx.beginPath();
  # ctx.moveTo(x + nw, y);
  # cmdL x + width - ne, y);
  # cmdQ x + width, y, x + width, y + ne);
  # cmdL x + width, y + height - se);
  # cmdQ x + width, y + height, x + width - se, y + height);
  # cmdL x + sw, y + height);
  # cmdQ x, y + height, x, y + height - sw);
  # cmdL x, y + nw);
  # cmdQ x, y, x + nw, y);
  # ctx.closePath();
  let
    x = pos.x
    y = pos.y
    width = size.x
    height = size.y
  dataBufferSeq.add @[
    cmdStartPath,
    cmdM, x + nw, y,
    cmdL, x + width - ne, y,
    cmdQ, x + width, y, x + width, y + ne,
    cmdL, x + width, y + height - se,
    cmdQ, x + width, y + height, x + width - se, y + height,
    cmdL, x + sw, y + height,
    cmdQ, x, y + height, x, y + height - sw,
    cmdL, x, y + nw,
    cmdQ, x, y, x + nw, y,
    cmdz,
    cmdEndPath
  ]

proc drawRect(pos, size: Vec2) =
  let
    x = pos.x
    y = pos.y
    w = size.x
    h = size.y
  dataBufferSeq.add @[
    cmdStartPath,
    cmdM, x, y,
    cmdL, x, y,
    cmdL, x + w, y,
    cmdL, x + w, y + h,
    cmdL, x, y + h,
    cmdz,
    cmdEndPath
  ]

proc drawGeom(node: Node, geom: Geometry) =
  dataBufferSeq.add cmdStartPath
  for command in parsePath(geom.path).commands:
    case command.kind
    of Move:
      dataBufferSeq.add cmdM
      var pos = mat * vec2(command.numbers[0], command.numbers[1])
      dataBufferSeq.add pos.x
      dataBufferSeq.add pos.y
    of Line:
      dataBufferSeq.add cmdL
      var pos = mat * vec2(command.numbers[0], command.numbers[1])
      dataBufferSeq.add pos.x
      dataBufferSeq.add pos.y
    of Cubic:
      dataBufferSeq.add cmdC
      for i in 0 ..< 3:
        var pos = mat * vec2(
          command.numbers[i*2+0],
          command.numbers[i*2+1]
        )
        dataBufferSeq.add pos.x
        dataBufferSeq.add pos.y
    of End:
      dataBufferSeq.add cmdz
    else:
      quit($command.kind & " not supported command kind.")

  dataBufferSeq.add cmdEndPath

proc drawPaint(node: Node, paint: Paint) =
  if paint.kind == pkImage:
    dataBufferSeq.add @[
      cmdTexture,
      1.0
    ]
  else:
    dataBufferSeq.add @[
      cmdSolidFill,
      paint.color.r,
      paint.color.g,
      paint.color.b,
      paint.color.a * paint.opacity * opacity
    ]

proc drawNode*(node: Node, level: int) =

  if not node.visible or node.opacity == 0:
    return

  prevMat = mat
  prevOpacity = opacity

  if level == 0:
    mat.identity()
    opacity = 1.0
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

  case node.kind
    of nkGroup:
      discard

    of nkRectangle, nkFrame, nkInstance:
      if node.cornerRadius > 0:
        let r = node.cornerRadius
        drawRect(vec2(0, 0), node.size, r, r, r, r)
      elif node.rectangleCornerRadii.len == 4:
        let r = node.rectangleCornerRadii
        drawRect(vec2(0, 0), node.size, r[0], r[1], r[2], r[3])
      else:
        drawRect(vec2(0, 0), node.size)
      for paint in node.fills:
        drawPaint(node, paint)

    of nkVector, nkStar, nkEllipse:

      for geom in node.fillGeometry:
        drawGeom(node, geom)
      for paint in node.fills:
        drawPaint(node, paint)

      for geom in node.strokeGeometry:
        drawGeom(node, geom)
      for paint in node.strokes:
        drawPaint(node, paint)

    else:
      echo($node.kind & " not supported")

  for childNode in node.children:
    drawNode(childNode, level + 1)

  mat = prevMat
  opacity = prevOpacity

proc drawCompleteGpuFrame*(node: Node): pixie.Image =
  let
    width = node.absoluteBoundingBox.w.int
    height = node.absoluteBoundingBox.h.int

  setupGpuRender(width, height)

  drawNode(node, 0)

  dataBufferSeq.add(cmdExit)


  return readGpuPixels()
