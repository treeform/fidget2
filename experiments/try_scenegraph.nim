import
  std/[tables],
  chroma,
  vmath,
  windy,
  opengl,
  scenegraph

proc compileShader(kind: GLenum, src: string): GLuint =
  let shader = glCreateShader(kind)
  var arr: array[1, cstring]
  arr[0] = cstring(src)
  glShaderSource(shader, 1, cast[cstringArray](arr.addr), nil)
  glCompileShader(shader)
  var status: GLint
  glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr)
  if status == 0:
    var logLen: GLint
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, logLen.addr)
    var buf = newString(logLen)
    glGetShaderInfoLog(shader, logLen, nil, buf.cstring)
    echo "Shader compile error:\n", buf
  shader

proc linkProgram(vs, fs: GLuint): GLuint =
  let program = glCreateProgram()
  glAttachShader(program, vs)
  glAttachShader(program, fs)
  glLinkProgram(program)
  var status: GLint
  glGetProgramiv(program, GL_LINK_STATUS, status.addr)
  if status == 0:
    var logLen: GLint
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, logLen.addr)
    var buf = newString(logLen)
    glGetProgramInfoLog(program, logLen, nil, buf.cstring)
    echo "Program link error:\n", buf
  glDeleteShader(vs)
  glDeleteShader(fs)
  program

proc appendFloat32(b: var seq[byte], f: float32) =
  let n = b.len
  b.setLen(n + 4)
  copyMem(b[n].addr, unsafeAddr f, 4)

proc appendUint16(b: var seq[byte], x: uint16) =
  let n = b.len
  b.setLen(n + 2)
  copyMem(b[n].addr, unsafeAddr x, 2)

when isMainModule:
  let scene = newScene()
  let node = newNode(scene, "triangle")
  scene.root.addChild(node)

  var v: seq[byte] = @[]
  # XY layout, three vertices
  appendFloat32(v, -0.5'f32); appendFloat32(v, -0.5'f32)
  appendFloat32(v,  0.5'f32); appendFloat32(v, -0.5'f32)
  appendFloat32(v,  0.0'f32); appendFloat32(v,  0.5'f32)

  var ib: seq[byte] = @[]
  appendUint16(ib, 0'u16)
  appendUint16(ib, 1'u16)
  appendUint16(ib, 2'u16)

  let geom = Geometry(
    name: "tri",
    format: XY,
    vertexData: v,
    indexFormat: Index16,
    indexData: ib
  )
  node.addGeometry(geom)

  let shader = SceneShader(key: "basic")
  node.attachShader(shader)
  node.setUniform("uColor", color(1, 0, 0, 1))

  # Create a window with Windy
  var window = newWindow("SceneGraph Triangle", ivec2(800, 600))
  window.makeContextCurrent()
  loadExtensions()

  # Create GL program and upload buffers, store in scenegraph objects
  let vertSrc = "#version 410 core\n" &
    "layout(location=0) in vec2 aPos;\n" &
    "void main(){ gl_Position = vec4(aPos, 0.0, 1.0); }\n"
  let fragSrc = "#version 410 core\n" &
    "out vec4 FragColor;\n" &
    "uniform vec4 uColor;\n" &
    "void main(){ FragColor = uColor; }\n"
  let vs = compileShader(GL_VERTEX_SHADER, vertSrc)
  let fs = compileShader(GL_FRAGMENT_SHADER, fragSrc)
  let program = linkProgram(vs, fs)
  shader.programId = program
  let uColorLoc = glGetUniformLocation(program, "uColor")

  glGenVertexArrays(1, geom.vaoId.addr)
  glBindVertexArray(geom.vaoId)

  glGenBuffers(1, geom.vboId.addr)
  glBindBuffer(GL_ARRAY_BUFFER, geom.vboId)
  glBufferData(
    GL_ARRAY_BUFFER,
    GLsizeiptr(geom.vertexData.len),
    if geom.vertexData.len == 0: nil else: geom.vertexData[0].addr,
    GL_STATIC_DRAW
  )

  glGenBuffers(1, geom.eboId.addr)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geom.eboId)
  glBufferData(
    GL_ELEMENT_ARRAY_BUFFER,
    GLsizeiptr(geom.indexData.len),
    if geom.indexData.len == 0: nil else: geom.indexData[0].addr,
    GL_STATIC_DRAW
  )

  # Attribute: location 0 -> vec2 position
  glEnableVertexAttribArray(0)
  let glFloat = GLenum(0x1406) # GL_FLOAT
  glVertexAttribPointer(
    0,                # index
    2,                # size
    glFloat,          # type
    GL_FALSE,         # normalized
    GLsizei(2 * sizeof(float32)), # stride
    cast[pointer](0)  # pointer
  )

  # Simple frame loop clearing the screen
  window.onFrame = proc() =
    glViewport(0, 0, window.size.x, window.size.y)
    glClearColor(0, 0, 0, 1)
    glClear(GL_COLOR_BUFFER_BIT)
    glUseProgram(program)
    # Set uniform color from scene node
    var col = color(1, 0, 0, 1)
    if node.uniforms.hasKey("uColor"):
      let u = node.uniforms["uColor"]
      if u.kind == ColorUniform:
        col = u.c
    glUniform4f(uColorLoc, col.r, col.g, col.b, col.a)
    glBindVertexArray(geom.vaoId)
    glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_SHORT, nil)
    window.swapBuffers()

  while not window.closeRequested:
    pollEvents()

