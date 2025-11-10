import
  std/[tables],
  opengl, vmath, pixie,
  scenegraphs

const
  GlFloat = GLenum(0x1406) # GL_FLOAT

proc compileShader(kind: GLenum, src: string): GLuint =
  ## Compiles a shader and returns its id.
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
  ## Links a program from compiled shaders and returns its id.
  let program = glCreateProgram()
  glAttachShader(program, vs)
  glAttachShader(program, fs)
  # Bind attribute locations to match our VAO setup.
  glBindAttribLocation(program, 0, "aPos")
  glBindAttribLocation(program, 1, "aUv")
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

proc ensureProgram*(shader: SceneShader) =
  ## Ensures a default program exists for the shader if none provided.
  if shader == nil:
    return
  if shader.programId != 0:
    return
  # Require provided shader sources.
  if shader.vertSrc.len == 0 or shader.fragSrc.len == 0:
    raise newException(ValueError, "SceneShader missing vertSrc/fragSrc - a shader must be provided")
  let vertSrc = shader.vertSrc
  let fragSrc = shader.fragSrc
  let vs = compileShader(GL_VERTEX_SHADER, vertSrc)
  let fs = compileShader(GL_FRAGMENT_SHADER, fragSrc)
  shader.programId = linkProgram(vs, fs)

proc strideBytes(format: GeometryLayout): GLsizei =
  ## Returns the stride in bytes for a given geometry layout.
  GLsizei(
    case format:
    of XY: 2 * sizeof(float32)
    of XYUV: 4 * sizeof(float32)
    of XYUVRGBA: 4 * sizeof(float32) + 4 # RGBA as 4 bytes
    of XYWHUVR: 7 * sizeof(float32) # XY WH UV R
  )

proc configureAttributes(format: GeometryLayout, stride: GLsizei) =
  ## Configures vertex attributes for the bound VAO/VBO based on layout.
  # location 0: position (vec2 float) at offset 0
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 2, GlFloat, GL_FALSE, stride, cast[pointer](0))
  case format:
  of XY:
    discard
  of XYUV:
    # location 1: uv (vec2 float) at offset 8
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 2, GlFloat, GL_FALSE, stride, cast[pointer](8))
  of XYUVRGBA:
    # location 1: uv (vec2 float) at offset 8
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 2, GlFloat, GL_FALSE, stride, cast[pointer](8))
    # location 2: color (ubyte4 normalized) at offset 16
    glEnableVertexAttribArray(2)
    glVertexAttribPointer(2, 4, GL_UNSIGNED_BYTE, GL_TRUE, stride, cast[pointer](16))
  of XYWHUVR:
    # Only position and uv as a minimal default:
    # uv at offset 16 (after XY(8) + WH(8))
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 2, GlFloat, GL_FALSE, stride, cast[pointer](16))

proc ensureGeometry*(geom: Geometry) =
  ## Ensures VAO/VBO/EBO are created and data uploaded for the geometry.
  if geom == nil:
    return
  if geom.vaoId != 0 and geom.vboId != 0:
    return
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

  if geom.indexData.len > 0:
    glGenBuffers(1, geom.eboId.addr)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, geom.eboId)
    glBufferData(
      GL_ELEMENT_ARRAY_BUFFER,
      GLsizeiptr(geom.indexData.len),
      geom.indexData[0].addr,
      GL_STATIC_DRAW
    )

  let stride = strideBytes(geom.format)
  configureAttributes(geom.format, stride)
  glBindVertexArray(0)

proc ensureTexture*(tex: TextureNode) =
  ## Ensures a GL texture is created and uploaded from the Pixie image.
  if tex == nil or tex.image == nil:
    return
  if tex.textureId != 0:
    return
  # OpenGL expects the first row to be the bottom row; Pixie images are top-left origin.
  # Flip once before uploading.
  tex.image.flipVertical()
  glGenTextures(1, tex.textureId.addr)
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, tex.textureId)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
  let w = tex.image.width.GLsizei
  let h = tex.image.height.GLsizei
  let dataPtr = if tex.image.data.len == 0: nil else: cast[pointer](tex.image.data[0].addr)
  glTexImage2D(
    GL_TEXTURE_2D, 0, GLint(GL_RGBA8), w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, dataPtr
  )
  glGenerateMipmap(GL_TEXTURE_2D)

proc setUniforms*(program: GLuint, uniforms: Table[string, Uniform]) =
  ## Sets known uniforms by name and type on the active program.
  for key, value in uniforms:
    case value.kind:
    of BoolUniform:
      let loc = glGetUniformLocation(program, key)
      glUniform1i(loc, if value.b: 1 else: 0)
    of IntUniform:
      let loc = glGetUniformLocation(program, key)
      glUniform1i(loc, value.i)
    of FloatUniform:
      let loc = glGetUniformLocation(program, key)
      glUniform1f(loc, value.f)
    of Vec2Uniform:
      let loc = glGetUniformLocation(program, key)
      glUniform2f(loc, value.v2.x, value.v2.y)
    of Vec3Uniform:
      let loc = glGetUniformLocation(program, key)
      glUniform3f(loc, value.v3.x, value.v3.y, value.v3.z)
    of Vec4Uniform:
      let loc = glGetUniformLocation(program, key)
      glUniform4f(loc, value.v4.x, value.v4.y, value.v4.z, value.v4.w)
    of Mat3Uniform:
      let loc = glGetUniformLocation(program, key)
      glUniformMatrix3fv(loc, 1, GL_FALSE, value.m3[0, 0].addr)
    of Mat4Uniform:
      let loc = glGetUniformLocation(program, key)
      glUniformMatrix4fv(loc, 1, GL_FALSE, value.m4[0, 0].addr)
    of ColorUniform:
      let loc = glGetUniformLocation(program, key)
      glUniform4f(loc, value.c.r, value.c.g, value.c.b, value.c.a)

proc renderNode*(node: SceneNode) =
  ## Renders a node and its children using OpenGL.
  if node == nil or node.visible == false:
    return
  # Save current program, bind this node's shader if it has one.
  var prevProgram: GLint = 0
  glGetIntegerv(GL_CURRENT_PROGRAM, prevProgram.addr)
  var boundHere = false
  if node.shader != nil:
    ensureProgram(node.shader)
    if node.shader.programId.GLint != prevProgram:
      glUseProgram(node.shader.programId)
      boundHere = true

  # Determine which program is currently active (parent's or this node's)
  var currentProgram: GLint = 0
  glGetIntegerv(GL_CURRENT_PROGRAM, currentProgram.addr)

  # Apply transforms/uniforms against the active program if any
  if currentProgram != 0:
    let wt = node.worldTransform()
    let loc = glGetUniformLocation(currentProgram.GLuint, "uModel")
    if loc != -1:
      var m: array[9, float32]
      m[0] = wt[0, 0]; m[1] = wt[1, 0]; m[2] = wt[2, 0]
      m[3] = wt[0, 1]; m[4] = wt[1, 1]; m[5] = wt[2, 1]
      m[6] = wt[0, 2]; m[7] = wt[1, 2]; m[8] = wt[2, 2]
      glUniformMatrix3fv(loc, 1, GL_FALSE, m[0].addr)
    setUniforms(currentProgram.GLuint, node.uniforms)
    if node.textures.len > 0:
      ensureTexture(node.textures[0])
      if node.textures[0].textureId != 0:
        glActiveTexture(GL_TEXTURE0)
        glBindTexture(GL_TEXTURE_2D, node.textures[0].textureId)
        let texLoc = glGetUniformLocation(currentProgram.GLuint, "uTex")
        if texLoc != -1:
          glUniform1i(texLoc, GLint(0))

  if node.geometries.len > 0 and currentProgram != 0:
    for geom in node.geometries:
      ensureGeometry(geom)
      glBindVertexArray(geom.vaoId)
      if geom.indexData.len > 0:
        let count =
          if geom.indexFormat == Index32:
            GLsizei(geom.indexData.len div 4)
          else:
            GLsizei(geom.indexData.len div 2)
        let indexType = (if geom.indexFormat == Index32: GL_UNSIGNED_INT else: GL_UNSIGNED_SHORT)
        glDrawElements(GL_TRIANGLES, count, indexType, nil)
      else:
        let stride = strideBytes(geom.format)
        let count = GLsizei(geom.vertexData.len div int(stride))
        glDrawArrays(GL_TRIANGLES, 0, count)
      glBindVertexArray(0)

  for child in node.children:
    renderNode(child)

  # Restore previous program if we bound here
  if boundHere:
    glUseProgram(prevProgram.GLuint)


