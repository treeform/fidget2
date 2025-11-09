import
  chroma, pixie,
  vmath,
  windy,
  opengl,
  scenegraph,
  glrender

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

  # Add a textured quad node
  let quadNode = newNode(scene, "texturedQuad")
  scene.root.addChild(quadNode)
  var qv: seq[byte] = @[]
  # XYUV for 4 vertices (two triangles). Place on the right side.
  # v0
  appendFloat32(qv, 0.1'f32); appendFloat32(qv, -0.5'f32)
  appendFloat32(qv, 0.0'f32); appendFloat32(qv, 0.0'f32)
  # v1
  appendFloat32(qv, 0.9'f32); appendFloat32(qv, -0.5'f32)
  appendFloat32(qv, 1.0'f32); appendFloat32(qv, 0.0'f32)
  # v2
  appendFloat32(qv, 0.9'f32); appendFloat32(qv, 0.5'f32)
  appendFloat32(qv, 1.0'f32); appendFloat32(qv, 1.0'f32)
  # v3
  appendFloat32(qv, 0.1'f32); appendFloat32(qv, 0.5'f32)
  appendFloat32(qv, 0.0'f32); appendFloat32(qv, 1.0'f32)
  var qi: seq[byte] = @[]
  appendUint16(qi, 0'u16); appendUint16(qi, 1'u16); appendUint16(qi, 2'u16)
  appendUint16(qi, 2'u16); appendUint16(qi, 3'u16); appendUint16(qi, 0'u16)
  let quadGeom = Geometry(
    name: "quad",
    format: XYUV,
    vertexData: qv,
    indexFormat: Index16,
    indexData: qi
  )
  quadNode.addGeometry(quadGeom)
  let img = readImage("testTexture.png")
  let quadTex = newTextureNode("quadTex", img)
  quadNode.addTexture(quadTex)
  let quadShader = SceneShader(key: "textured")
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

