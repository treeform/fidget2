import atlas, chroma, os, fidget2, pixie, strutils, strformat, times,
  math, opengl, staticglfw, times, vmath, glsl, gpushader, print, math,
  pixie, tables, typography

var
  viewPortWidth*: int
  viewPortHeight*: int
  windowReady = false

  # Data Buffer Object

  dataBufferSeq*: seq[float32]
  mat*: Mat3
  opacity*: float32

  # OpenGL stuff.
  dataBufferTextureId: GLuint
  textureAtlas*: CpuAtlas
  textureAtlasId: GLuint

  typefaceCache: Table[string, Typeface]

proc setupRender*(frameNode: Node) =
  viewPortWidth = frameNode.absoluteBoundingBox.w.int
  viewPortHeight = frameNode.absoluteBoundingBox.h.int
  dataBufferSeq.setLen(0)

  if textureAtlas == nil:
    textureAtlas = newCpuAtlas(1024*2, 1)

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

proc updateGpuAtlas() =
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

    var textureAtlasLoc = glGetUniformLocation(shaderProgram, "textureAtlasSampler")
    glUniform1i(textureAtlasLoc, 1) # Set textureAtlas to 1th texture.

    windowReady = true

  # send texture to the CPU
  updateGpuAtlas()

  # send commands to the CPU
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

const splinyCirlce = 4.0 * (-1.0 + sqrt(2.0)) / 3.0

proc drawRect(pos, size: Vec2, nw, ne, se, sw: float32) =
  let
    x = pos.x
    y = pos.y
    w = size.x
    h = size.y
    s = splinyCirlce

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

proc drawGeom(node: Node, geom: Geometry) =
  dataBufferSeq.add cmdStartPath
  case geom.windingRule
  of wrEvenOdd:
    dataBufferSeq.add 0
  of wrNonZero:
    dataBufferSeq.add 1
  for command in parsePath(geom.path).commands:
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

proc drawPaint(node: Node, paint: Paint) =
  if not paint.visible:
    return

  proc toImageSpace(handle: Vec2): Vec2 =
    vec2(
      handle.x * node.absoluteBoundingBox.w,
      handle.y * node.absoluteBoundingBox.h,
    )

  case paint.kind
  of pkImage:

    if paint.imageRef notin textureAtlas.entries:
      var image: pixie.Image
      downloadImageRef(paint.imageRef)
      try:
        image = readImage("figma/images/" & paint.imageRef & ".png")
      except PixieError:
        echo "Issue loading image: ", node.name
      textureAtlas.put(paint.imageRef, image)
      #updateGpuAtlas()

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

proc drawNode*(node: Node, level: int) =

  if not node.visible or node.opacity == 0:
    return

  var prevMat = mat
  var prevOpacity = opacity

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
      if node.fills.len > 0:
        dataBufferSeq.add cmdStartPath
        dataBufferSeq.add 0
        if node.cornerRadius > 0:
          let r = node.cornerRadius
          drawRect(vec2(0, 0), node.size, r, r, r, r)
        elif node.rectangleCornerRadii.len == 4:
          let r = node.rectangleCornerRadii
          drawRect(vec2(0, 0), node.size, r[0], r[1], r[2], r[3])
        else:
          drawRect(vec2(0, 0), node.size)
        dataBufferSeq.add cmdEndPath
        for paint in node.fills:
          drawPaint(node, paint)

      if node.strokes.len > 0:
        var
          inner = 0.0
          outer = 0.0
        case node.strokeAlign
        of saInside:
          inner = node.strokeWeight
        of saOutside:
          outer = node.strokeWeight
        of saCenter:
          inner = node.strokeWeight / 2
          outer = node.strokeWeight / 2

        dataBufferSeq.add cmdStartPath
        dataBufferSeq.add 0
        if node.cornerRadius > 0:
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
        elif node.rectangleCornerRadii.len == 4:
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
        else:
          drawRect(vec2(-outer, -outer), node.size + vec2(outer*2, outer*2))
          drawRect(vec2(+inner, +inner), node.size - vec2(inner*2, inner*2))
        dataBufferSeq.add cmdEndPath

        for paint in node.strokes:
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
        text = node.characters,
        pos = vec2(0, 0),
        size = node.size,
        hAlign = node.style.textAlignHorizontal,
        vAlign = node.style.textAlignVertical,
        clip = false,
        wrap = wrap,
        kern = kern,
        textCase = node.style.textCase,
      )
      dataBufferSeq.add cmdStartPath
      dataBufferSeq.add 1

      for gpos in layout:
        var font = gpos.font
        var fontHeight = font.typeface.ascent - font.typeface.descent
        var scale = font.size / (fontHeight)
        proc trans(v: Vec2): Vec2 =
          result = v * scale
          result.y = -result.y

        if gpos.character in font.typeface.glyphs:
          var glyph = font.typeface.glyphs[gpos.character]
          glyph.makeReady(font)

          var prevPos: Vec2
          for shape in glyph.shapes:
            for segment in shape:

              let posM = segment.at.trans + gpos.rect.xy
              if posM != prevPos:
                dataBufferSeq.add cmdM
                dataBufferSeq.add posM.x
                dataBufferSeq.add posM.y

              dataBufferSeq.add cmdL
              let posL = segment.to.trans + gpos.rect.xy
              dataBufferSeq.add posL.x
              dataBufferSeq.add posL.y
              prevPos = posL

      dataBufferSeq.add cmdEndPath

      for paint in node.fills:
        drawPaint(node, paint)

    else:
      echo($node.kind & " not supported")

  for childNode in node.children:
    drawNode(childNode, level + 1)

  mat = prevMat
  opacity = prevOpacity

proc drawCompleteGpuFrame*(node: Node): pixie.Image =
  setupRender(node)

  drawNode(node, 0)

  dataBufferSeq.add(cmdExit)

  return readGpuPixels()
