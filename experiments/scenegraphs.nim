import
  std/[tables],
  chroma, pixie, vmath

when defined(useGL):
  import opengl

const
  DefaultNodeScale = vec2(1, 1)

type
  SceneShader* = ref object
    ## Opaque shader reference for the scene graph.
    key*: string
    vertSrc*: string
    fragSrc*: string
    when defined(useGL):
      ## OpenGL shader program handle.
      programId*: GLuint

  UniformKind* = enum
    BoolUniform, IntUniform, FloatUniform
    Vec2Uniform, Vec3Uniform, Vec4Uniform
    Mat3Uniform, Mat4Uniform
    ColorUniform

  Uniform* = object
    ## Variant uniform value for shader parameters.
    case kind*: UniformKind
    of BoolUniform:
      b*: bool
    of IntUniform:
      i*: int32
    of FloatUniform:
      f*: float32
    of Vec2Uniform:
      v2*: Vec2
    of Vec3Uniform:
      v3*: Vec3
    of Vec4Uniform:
      v4*: Vec4
    of Mat3Uniform:
      m3*: Mat3
    of Mat4Uniform:
      m4*: Mat4
    of ColorUniform:
      c*: Color

  GeometryLayout* = enum
    ## Vertex layout for the packed vertex buffer.
    # XYZ - vector of 3 floats
    # UV - vector of 2 floats
    # RGBA - vector of 4 bytes
    # WH - width and height vector of 2 floats (expanding quads)
    XY
    XYUV
    XYUVRGBA
    XYWHUVR

  GeometryIndexType* = enum
    ## Index format for the packed index buffer.
    Index16
    Index32

  Geometry* = ref object
    ## CPU-side geometry container with packed vertex buffer.
    name*: string
    format*: GeometryLayout
    vertexData*: seq[byte]
    indexFormat*: GeometryIndexType
    indexData*: seq[byte]
    when defined(useGL):
      ## OpenGL buffers for this geometry.
      vaoId*: GLuint
      vboId*: GLuint
      eboId*: GLuint

  TextureNode* = ref object
    ## Texture attachment using CPU image.
    name*: string
    image*: Image
    when defined(useGL):
      ## OpenGL texture handle.
      textureId*: GLuint

  SceneNode* = ref object
    ## Scene graph node with attachments and children.
    id*: int
    name*: string
    visible*: bool

    # Transform (local)
    position*: Vec2
    rotation*: float32
    scale*: Vec2
    flipHorizontal*: bool
    flipVertical*: bool

    # Hierarchy
    parent*: SceneNode
    children*: seq[SceneNode]

    # Attachments
    shader*: SceneShader
    uniforms*: Table[string, Uniform]
    geometries*: seq[Geometry]
    textures*: seq[TextureNode]

    # User data
    userKey*: string
    userId*: int

  Scene* = ref object
    ## Scene container holding the root and ID generator.
    root*: SceneNode
    nextId*: int

# Scene construction
proc newScene*(): Scene =
  ## Creates a new empty scene with a root node.
  let root = SceneNode(
    id: 0,
    name: "root",
    visible: true,
    position: vec2(0, 0),
    rotation: 0'f32,
    scale: DefaultNodeScale
  )
  Scene(root: root, nextId: 1)

proc newNode*(scene: Scene, name: string): SceneNode =
  ## Creates a new node with a unique id.
  let nid = scene.nextId
  inc scene.nextId
  SceneNode(
    id: nid,
    name: name,
    visible: true,
    position: vec2(0, 0),
    rotation: 0'f32,
    scale: DefaultNodeScale
  )

# Hierarchy
proc addChild*(parent: SceneNode, child: SceneNode) =
  ## Adds a child node and sets its parent.
  if child.parent != nil:
    var idx = -1
    for i, c in child.parent.children:
      if c == child:
        idx = i
        break
    if idx != -1:
      child.parent.children.delete(idx)
  child.parent = parent
  parent.children.add(child)

# Transforms
proc localTransform*(node: SceneNode): Mat3 =
  ## Returns local TRS (with flips) as Mat3.
  let sx =
    if node.flipHorizontal:
      -node.scale.x
    else:
      node.scale.x
  let sy =
    if node.flipVertical:
      -node.scale.y
    else:
      node.scale.y
  let flip = vec2(sx, sy)
  result = translate(node.position) * rotate(node.rotation) * scale(flip)

proc worldTransform*(node: SceneNode): Mat3 =
  ## Returns world transform by combining ancestors.
  let local = node.localTransform()
  if node.parent == nil:
    return local
  node.parent.worldTransform() * local

# Attachments
proc attachShader*(node: SceneNode, shader: SceneShader) =
  ## Attaches a shader reference to the node.
  node.shader = shader

proc setUniform*(node: SceneNode, name: string, value: Uniform) =
  ## Sets a uniform value by name.
  node.uniforms[name] = value

proc setUniform*(node: SceneNode, name: string, b: bool) =
  ## Convenience uniform setter (bool).
  node.setUniform(name, Uniform(kind: BoolUniform, b: b))

proc setUniform*(node: SceneNode, name: string, i: int32) =
  ## Convenience uniform setter (int).
  node.setUniform(name, Uniform(kind: IntUniform, i: i))

proc setUniform*(node: SceneNode, name: string, f: float32) =
  ## Convenience uniform setter (float).
  node.setUniform(name, Uniform(kind: FloatUniform, f: f))

proc setUniform*(node: SceneNode, name: string, v: Vec2) =
  ## Convenience uniform setter (vec2).
  node.setUniform(name, Uniform(kind: Vec2Uniform, v2: v))

proc setUniform*(node: SceneNode, name: string, v: Vec3) =
  ## Convenience uniform setter (vec3).
  node.setUniform(name, Uniform(kind: Vec3Uniform, v3: v))

proc setUniform*(node: SceneNode, name: string, v: Vec4) =
  ## Convenience uniform setter (vec4).
  node.setUniform(name, Uniform(kind: Vec4Uniform, v4: v))

proc setUniform*(node: SceneNode, name: string, m: Mat3) =
  ## Convenience uniform setter (mat3).
  node.setUniform(name, Uniform(kind: Mat3Uniform, m3: m))

proc setUniform*(node: SceneNode, name: string, m: Mat4) =
  ## Convenience uniform setter (mat4).
  node.setUniform(name, Uniform(kind: Mat4Uniform, m4: m))

proc setUniform*(node: SceneNode, name: string, c: Color) =
  ## Convenience uniform setter (color).
  node.setUniform(name, Uniform(kind: ColorUniform, c: c))

proc addGeometry*(node: SceneNode, geom: Geometry) =
  ## Attaches geometry to the node.
  node.geometries.add(geom)

proc addTexture*(node: SceneNode, tex: TextureNode) =
  ## Attaches a texture to the node.
  node.textures.add(tex)

proc newTextureNode*(name: string, image: Image): TextureNode =
  ## Creates a texture attachment from an image.
  TextureNode(name: name, image: image)

# Traversal
proc traversePre*(node: SceneNode, fn: proc(n: SceneNode)) =
  ## Pre-order traversal starting at node.
  fn(node)
  for child in node.children:
    traversePre(child, fn)

proc traversePost*(node: SceneNode, fn: proc(n: SceneNode)) =
  ## Post-order traversal starting at node.
  for child in node.children:
    traversePost(child, fn)
  fn(node)

