import
  opengl,
  chroma, pixie, vmath, windy, shady, flatty/binny,
  scenegraphs, renders
  
var
  uModel: shady.Uniform[Mat3]
  uColor: shady.Uniform[Vec4]
  uTex: shady.Uniform[Sampler2D]

proc sceneVert*(aPos: Vec2, aUv: Vec2, vUv: var Vec2, gl_Position: var Vec4) =
  let p = uModel * vec3(aPos, 1.0)
  vUv = aUv
  gl_Position = vec4(p.x, p.y, 0.0, 1.0)

proc sceneFragColor*(vUv: Vec2, FragColor: var Vec4) =
  FragColor = uColor

proc sceneFragTextured*(vUv: Vec2, FragColor: var Vec4) =
  FragColor = texture(uTex, vUv)


let scene = newScene()
let node = newNode(scene, "triangle")
scene.root.addChild(node)

# Triangle vertices (XY), pre-sized and written with binny
var vU8: seq[uint8] = @[]
vU8.setLen(3 * 2 * 4)
var off = 0
vU8.writeFloat32(off, -0.5'f32); off += 4
vU8.writeFloat32(off, -0.5'f32); off += 4
vU8.writeFloat32(off,  0.5'f32); off += 4
vU8.writeFloat32(off, -0.5'f32); off += 4
vU8.writeFloat32(off,  0.0'f32); off += 4
vU8.writeFloat32(off,  0.5'f32)

var ibU8: seq[uint8] = @[]
ibU8.setLen(3 * 2)
off = 0
ibU8.writeUint16(off, 0'u16); off += 2
ibU8.writeUint16(off, 1'u16); off += 2
ibU8.writeUint16(off, 2'u16)

let geom = Geometry(
  name: "tri",
  format: XY,
  vertexData: cast[seq[byte]](vU8),
  indexFormat: Index16,
  indexData: cast[seq[byte]](ibU8)
)
node.addGeometry(geom)

# Define shaders with Shady (Nim → GLSL) and store on shader nodes
let vertSrc = toGLSL(sceneVert, "410", "")
let fragColorSrc = toGLSL(sceneFragColor, "410", "")
let fragTexSrc = toGLSL(sceneFragTextured, "410", "")

let shader = SceneShader(key: "basic", vertSrc: vertSrc, fragSrc: fragColorSrc)
node.attachShader(shader)
node.setUniform("uColor", color(1, 0, 0, 1))

# Add a textured quad node
let quadNode = newNode(scene, "texturedQuad")
scene.root.addChild(quadNode)
var qvU8: seq[uint8] = @[]
qvU8.setLen(4 * 4 * 4) # 4 vertices * (xyuv) * 4 bytes
off = 0
# v0
qvU8.writeFloat32(off, 0.1'f32); off += 4
qvU8.writeFloat32(off, -0.5'f32); off += 4
qvU8.writeFloat32(off, 0.0'f32); off += 4
qvU8.writeFloat32(off, 0.0'f32); off += 4
# v1
qvU8.writeFloat32(off, 0.9'f32); off += 4
qvU8.writeFloat32(off, -0.5'f32); off += 4
qvU8.writeFloat32(off, 1.0'f32); off += 4
qvU8.writeFloat32(off, 0.0'f32); off += 4
# v2
qvU8.writeFloat32(off, 0.9'f32); off += 4
qvU8.writeFloat32(off, 0.5'f32); off += 4
qvU8.writeFloat32(off, 1.0'f32); off += 4
qvU8.writeFloat32(off, 1.0'f32); off += 4
# v3
qvU8.writeFloat32(off, 0.1'f32); off += 4
qvU8.writeFloat32(off, 0.5'f32); off += 4
qvU8.writeFloat32(off, 0.0'f32); off += 4
qvU8.writeFloat32(off, 1.0'f32)

var qiU8: seq[uint8] = @[]
qiU8.setLen(6 * 2)
off = 0
qiU8.writeUint16(off, 0'u16); off += 2
qiU8.writeUint16(off, 1'u16); off += 2
qiU8.writeUint16(off, 2'u16); off += 2
qiU8.writeUint16(off, 2'u16); off += 2
qiU8.writeUint16(off, 3'u16); off += 2
qiU8.writeUint16(off, 0'u16)

let quadGeom = Geometry(
  name: "quad",
  format: XYUV,
  vertexData: cast[seq[byte]](qvU8),
  indexFormat: Index16,
  indexData: cast[seq[byte]](qiU8)
)
quadNode.addGeometry(quadGeom)

let img = readImage("testTexture.png")
let quadTex = newTextureNode("quadTex", img)
quadNode.addTexture(quadTex)

let quadShader = SceneShader(key: "textured", vertSrc: vertSrc, fragSrc: fragTexSrc)
quadNode.attachShader(quadShader)

# Create a window with Windy
var window = newWindow("SceneGraph Triangle", ivec2(800, 600))
window.makeContextCurrent()
loadExtensions()

# Simple frame loop clearing the screen
window.onFrame = proc() =
  glViewport(0, 0, window.size.x, window.size.y)
  glClearColor(0, 0, 0, 1)
  glClear(GL_COLOR_BUFFER_BIT)
  renderNode(scene.root)
  window.swapBuffers()

while not window.closeRequested:
  pollEvents() 

