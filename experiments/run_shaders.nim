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
  #fragShaderSrc = readFile("bufferTest.glsl")
  #fragShaderSrc = readFile("svg4.glsl")
  fragShaderSrc = toShader(svgMain, "300 es")

  vertShaderArray = allocCStringArray([vertShaderSrc])  # dealloc'd at the end
  fragShaderArray = allocCStringArray([fragShaderSrc])  # dealloc'd at the end

  # Status variables
  isCompiled: GLint
  isLinked: GLint

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

# Data Buffer Object

var dataBufferSeq = @[
  # cmdStartPath,
  # cmdStyleFill, 1.0, 1.0, 0, 1,
  # cmdM, 100.0, 100.0,
  # cmdL, 100.0, 200.0,
  # cmdL, 225.0, 225.0,
  # cmdL, 200.0, 100.0,
  # cmdL, 100.0, 100.0,
  # cmdz,
  # cmdEndPath,

  cmdStartPath,
  # left exterior arc
  cmdStyleFill, 0.45, 0.71, 0.10, 1.0,
  cmdM, 82.2115, 102.414,
  cmdC, 82.2115,102.414, 104.7155,69.211, 149.6485,65.777,
  cmdL, 149.6485,53.73,
  cmdC, 99.8795,57.727, 56.7818,99.879,  56.7818,99.879,
  cmdC, 56.7818,99.879, 81.1915,170.445, 149.6485,176.906,
  cmdL, 149.6485,164.102,
  cmdC, 99.4105,157.781, 82.2115,102.414, 82.2115,102.414,
  cmdz,
  cmdEndPath,

  cmdStartPath,
  # left interior arc
  cmdStyleFill, 0.45, 0.71, 0.10, 1.0,
  cmdM, 149.6485,138.637,
  cmdL, 149.6485,150.363,
  cmdC, 111.6805,143.594, 101.1415,104.125, 101.1415,104.125,
  cmdC, 101.1415,104.125, 119.3715,83.93,   149.6485,80.656,
  cmdL, 149.6485,93.523,
  cmdC, 149.6255,93.523, 149.6095,93.516,  149.5905,93.516,
  cmdC, 133.6995,91.609, 121.2855,106.453,  121.2855,106.453,
  cmdC, 121.2855,106.453, 128.2425,131.445, 149.6485,138.637,
  cmdEndPath,

  cmdStartPath,
  # right main plate
  cmdStyleFill, 0.45, 0.71, 0.10, 1.0,
  cmdM, 149.6485,31.512,
  cmdL, 149.6485,53.73,
  cmdC, 151.1095,53.617,  152.5705,53.523,  154.0395,53.473,
  cmdC, 210.6215,51.566,  247.4885,99.879,  247.4885,99.879,
  cmdC, 247.4885,99.879,  205.1455,151.367, 161.0315,151.367,
  cmdC, 156.9885,151.367, 153.2035,150.992, 149.6485,150.363,
  cmdL, 149.6485,164.102,
  cmdC, 152.6885,164.488, 155.8405,164.715, 159.1295,164.715,
  cmdC, 200.1805,164.715, 229.8675,143.75,  258.6135,118.937,
  cmdC, 263.3795,122.754, 282.8915,132.039, 286.9025,136.105,
  cmdC, 259.5705,158.988, 195.8715,177.434, 159.7585,177.434,
  cmdC, 156.2775,177.434, 152.9345,177.223, 149.6485,176.906,
  cmdL, 149.6485,196.211,
  cmdL, 305.6805,196.211,
  cmdL, 305.6805,31.512,
  cmdL, 149.6485,31.512,
  cmdz,
  cmdEndPath,

  cmdStartPath,
  # right interior arc
  cmdStyleFill, 0.45, 0.71, 0.10, 1.0,
  cmdM, 149.6485,80.656,
  cmdL, 149.6485,65.777,
  cmdC, 151.0945,65.676, 152.5515,65.598, 154.0395,65.551,
  cmdC, 194.7275,64.273, 221.4225,100.516, 221.4225,100.516,
  cmdC, 221.4225,100.516, 192.5905,140.559, 161.6765,140.559,
  cmdC, 157.2275,140.559, 153.2385,139.844, 149.6485,138.637,
  cmdL, 149.6485,93.523,
  cmdC, 165.4885,95.437, 168.6765,102.434, 178.1995,118.309,
  cmdL, 199.3795,100.449,
  cmdC, 199.3795,100.449, 183.9185,80.172, 157.8555,80.172,
  cmdC, 155.0205,80.172, 152.3095,80.371, 149.6485,80.656,
  cmdEndPath,

  cmdExit
]

var dataBufferId: GLuint
glGenBuffers(1, dataBufferId.addr)
glBindBuffer(GL_TEXTURE_BUFFER, dataBufferId)
glBufferData(GL_TEXTURE_BUFFER, dataBufferSeq.len * 4, dataBufferSeq[0].addr, GL_STATIC_DRAW)

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

# glBindImageTexture(
#   0,
#   dataBufferTextureId,
#   0,
#   GL_FALSE,
#   0,
#   GL_READ_ONLY,
#   GL_R32F
# )

glUseProgram(shaderProgram)

var dataBufferLoc = glGetUniformLocation(shaderProgram, "dataBuffer")
print dataBufferLoc
glUniform1i(dataBufferLoc, 0) # Set dataBuffer to 0th texture.


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
