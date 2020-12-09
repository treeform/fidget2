import math, opengl, staticglfw, times, vmath, shadercompiler, svg4, print

# init libraries
if init() == 0:
  raise newException(Exception, "Failed to intialize GLFW")

# Turn on anti-aliasing?
# windowHint(SAMPLES, 4)

# Open a window
var window = createWindow(
  1000, 1000,
  "run_shaders",
  nil,
  nil)
window.makeContextCurrent()

# Load opengl
loadExtensions()


proc basic2dVert(vertexPox: Vec2, gl_Position: var Vec4) =
  gl_Position.xy = vertexPox

# The data for (and about) OpenGL
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

  # Shader source
#   vertShaderSrc = """#version 300 es
# layout(location = 0) in vec2 vertexPos;
# void main() {
#   gl_Position.xy = vertexPos;
# }
# """

  vertShaderSrc = toShader(basic2dVert, "300 es")
  fragShaderSrc = readFile("bufferTest.glsl")
  #fragShaderSrc = toShader(svgMain, "300 es")

  vertShaderArray = allocCStringArray([vertShaderSrc])  # dealloc'd at the end
  fragShaderArray = allocCStringArray([fragShaderSrc])  # dealloc'd at the end

  # Status variables
  isCompiled: GLint
  isLinked: GLint

# echo vertShaderSrc
# echo fragShaderSrc

#writeFile("tmp.glsl", fragShaderSrc)

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

# Data Buffer Object

var dataBufferSeq = @[500.float32, 1, 2, 3, 4]

var dataBufferId: GLuint
glGenBuffers(1, dataBufferId.addr)
glBindBuffer(GL_ARRAY_BUFFER, dataBufferId)
glBufferData(GL_ARRAY_BUFFER, dataBufferSeq.len * 4, dataBufferSeq.addr, GL_STATIC_DRAW)

glActiveTexture(GL_TEXTURE0)

var dataBufferTextureId: GLuint
glGenTextures(1, dataBufferTextureId.addr)
glBindTexture(GL_TEXTURE_BUFFER, dataBufferTextureId)
glTexBuffer(GL_TEXTURE_BUFFER, GL_R32F, dataBufferId)

# texelFetch

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
  echo $logStr
  dealloc(logStr)
else:
  echo "Vertex Shader compiled successfully."

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
  echo $logStr
  dealloc(logStr)
else:
  echo "Fragment Shader compiled successfully."

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
  echo $logStr
  dealloc(logStr)
else:
  echo "Shader Program ready!"


# var dataBufferLoc = glGetUniformLocation(shaderProgram, "dataBuffer")
# print dataBufferLoc
# glUniform1i(dataBufferLoc, 0) # Set dataBuffer to 0th texture.


# If everything is linked, that means we're good to go!
if isLinked == 1:

  # Some other options
  # glEnable(GL_MULTISAMPLE)

  # Record the time
  var
    startTs = epochTime()
    frameCount = 0

  # Main loop
  while windowShouldClose(window) == 0:

    # Exit on `ESC` press
    if getKey(window, KEY_ESCAPE) == 1:
      setWindowShouldClose(window, 1)

    # Clear and setup drawing
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    glUseProgram(shaderProgram)

    # Do the drawing
    glBindVertexArray(vao)
    glDrawElements(GL_TRIANGLE_FAN, indices.len.GLsizei, GL_UNSIGNED_BYTE, indices.addr)

    # Unbind
    glBindVertexArray(0);
    glUseProgram(0);

    # Poll and swap
    pollEvents()
    swapBuffers(window)

    inc frameCount
    if frameCount mod 144 == 0:
      echo 1 / ((epochTime() - startTs) / frameCount.float64), "fps"

# Cleanup non-GC'd stuff
deallocCStringArray(vertShaderArray)
deallocCStringArray(fragShaderArray)

# Cleanup OpenGL Stuff
glDeleteProgram(shaderProgram)
glDeleteShader(vertShader)
glDeleteShader(fragShader)
glDeleteBuffers(1, vertexVBO.addr)
#glDeleteBuffers(1, colorVBO.addr)
glDeleteVertexArrays(1, vao.addr)

# cleanup GLFW
destroyWindow(window)
terminate()
