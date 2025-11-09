import
  std/[tables],
  chroma, opengl, vmath,
  scenegraph

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
  when defined(useGL):
    if shader == nil:
      return
    if shader.programId != 0:
      return
    let vertSrc = "#version 410 core\n" &
      "layout(location=0) in vec2 aPos;\n" &
      "uniform mat3 uModel;\n" &
      "void main(){\n" &
      "  vec3 p = uModel * vec3(aPos, 1.0);\n" &
      "  gl_Position = vec4(p.xy, 0.0, 1.0);\n" &
      "}\n"
    let fragSrc = "#version 410 core\n" &
      "out vec4 FragColor;\n" &
      "uniform vec4 uColor;\n" &
      "void main(){ FragColor = uColor; }\n"
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
  when defined(useGL):
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

proc setUniforms*(program: GLuint, uniforms: Table[string, Uniform]) =
  ## Sets known uniforms by name and type on the active program.
  # Color
  if uniforms.hasKey("uColor"):
    let u = uniforms["uColor"]
    if u.kind == ColorUniform:
      let loc = glGetUniformLocation(program, "uColor")
      glUniform4f(loc, u.c.r, u.c.g, u.c.b, u.c.a)
  # Common floats/vecs/mats by name (optional)
  if uniforms.hasKey("uFloat"):
    let u = uniforms["uFloat"]
    if u.kind == FloatUniform:
      let loc = glGetUniformLocation(program, "uFloat")
      glUniform1f(loc, u.f)
  if uniforms.hasKey("uVec2"):
    let u = uniforms["uVec2"]
    if u.kind == Vec2Uniform:
      let loc = glGetUniformLocation(program, "uVec2")
      glUniform2f(loc, u.v2.x, u.v2.y)
  if uniforms.hasKey("uVec3"):
    let u = uniforms["uVec3"]
    if u.kind == Vec3Uniform:
      let loc = glGetUniformLocation(program, "uVec3")
      glUniform3f(loc, u.v3.x, u.v3.y, u.v3.z)
  if uniforms.hasKey("uVec4"):
    let u = uniforms["uVec4"]
    if u.kind == Vec4Uniform:
      let loc = glGetUniformLocation(program, "uVec4")
      glUniform4f(loc, u.v4.x, u.v4.y, u.v4.z, u.v4.w)
  if uniforms.hasKey("uMat3"):
    let u = uniforms["uMat3"]
    if u.kind == Mat3Uniform:
      let loc = glGetUniformLocation(program, "uMat3")
      var m: array[9, float32]
      m[0] = u.m3[0, 0]; m[1] = u.m3[1, 0]; m[2] = u.m3[2, 0]
      m[3] = u.m3[0, 1]; m[4] = u.m3[1, 1]; m[5] = u.m3[2, 1]
      m[6] = u.m3[0, 2]; m[7] = u.m3[1, 2]; m[8] = u.m3[2, 2]
      glUniformMatrix3fv(loc, 1, GL_FALSE, m[0].addr)
  if uniforms.hasKey("uMat4"):
    let u = uniforms["uMat4"]
    if u.kind == Mat4Uniform:
      let loc = glGetUniformLocation(program, "uMat4")
      glUniformMatrix4fv(loc, 1, GL_FALSE, u.m4[0, 0].addr)

proc renderNode*(node: SceneNode) =
  ## Renders a node and its children using OpenGL.
  when defined(useGL):
    if node == nil or node.visible == false:
      return
    if node.shader != nil:
      ensureProgram(node.shader)
      glUseProgram(node.shader.programId)
      # uModel from worldTransform
      let wt = node.worldTransform()
      let loc = glGetUniformLocation(node.shader.programId, "uModel")
      var m: array[9, float32]
      m[0] = wt[0, 0]; m[1] = wt[1, 0]; m[2] = wt[2, 0]
      m[3] = wt[0, 1]; m[4] = wt[1, 1]; m[5] = wt[2, 1]
      m[6] = wt[0, 2]; m[7] = wt[1, 2]; m[8] = wt[2, 2]
      glUniformMatrix3fv(loc, 1, GL_FALSE, m[0].addr)
      # Other uniforms
      setUniforms(node.shader.programId, node.uniforms)

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


