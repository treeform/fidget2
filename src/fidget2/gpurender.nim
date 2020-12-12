import chroma, os, fidget2, pixie, strutils, strformat, times
import math, opengl, staticglfw, times, vmath, glsl, gpushader, print, math
import pixie

var
  viewPortWidth*: int
  viewPortHeight*: int
  windowReady = false

  # Data Buffer Object

  dataBufferSeq*: seq[float32]
  mat*, prevMat*: Mat3

proc setupGpuRender(width, height: int) =
  viewPortWidth = width
  viewPortHeight = height

  dataBufferSeq.setLen(0)


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

    var dataBufferTextureId: GLuint
    glGenTextures(1, dataBufferTextureId.addr)
    glBindTexture(GL_TEXTURE_BUFFER, dataBufferTextureId)
    glTexBuffer(GL_TEXTURE_BUFFER, GL_R32F, dataBufferId)

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
    #glBindAttribLocation(shaderProgram, 0, "vertexClr");

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

proc drawNode*(node: Node, level: int) =

  if not node.visible or node.opacity == 0:
    return

  prevMat = mat
  if level != 0:
    mat = mat * node.transform()

  case node.kind
    of nkGroup:
      discard

    of nkFrame, nkInstance:
      var topColor: chroma.Color
      for paint in node.fills:
        if paint.visible:
          topColor = paint.color
          topColor.a *= paint.opacity * node.opacity

      let
        topLeft = mat * vec2(0, 0)
        bottomLeft = mat * node.size

      dataBufferSeq.add @[
        cmdStartPath,
        cmdStyleFill, topColor.r, topColor.g, topColor.b, topColor.a,
        cmdM, topLeft.x, topLeft.y,
        cmdL, bottomLeft.x, topLeft.y,
        cmdL, bottomLeft.x, bottomLeft.y,
        cmdL, topLeft.x, bottomLeft.y,
        cmdL, topLeft.x, topLeft.y,
        cmdz,
        cmdEndPath
      ]

    of nkVector, nkRectangle, nkStar, nkEllipse:

      for paint in node.fills:
        dataBufferSeq.add @[
          cmdStyleFill,
          paint.color.r,
          paint.color.g,
          paint.color.b,
          paint.color.a * paint.opacity * node.opacity
        ]

      for geom in node.fillGeometry:
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

      for paint in node.strokes:
        dataBufferSeq.add @[
          cmdStyleFill,
          paint.color.r,
          paint.color.g,
          paint.color.b,
          paint.color.a * paint.opacity * node.opacity
        ]

      for geom in node.strokeGeometry:
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


    else:
      echo($node.kind & " not supported")

  for childNode in node.children:
    drawNode(childNode, level + 1)

  mat = prevMat

proc drawCompleteGPUFrame*(node: Node): pixie.Image =
  let
    width = node.absoluteBoundingBox.w.int
    height = node.absoluteBoundingBox.h.int

  setupGpuRender(width, height)

  mat.identity()

  drawNode(node, 0)


  return readGpuPixels()
