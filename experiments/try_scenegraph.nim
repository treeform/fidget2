import
  chroma,
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

