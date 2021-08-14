import buffers, chroma, pixie, hashes, opengl, os, shaders, strformat,
    strutils, tables, textures, times, vmath, bumpy

const
  quadLimit = 10_921
  tileSize = 64

type
  TileInfo = object
    width: int                  ## Width of the image in pixels.
    height: int                 ## Height of the image in pixels.
    tiles: seq[int]             ## Tile indexes to look for tiles.
    oneColor: Color             ## If tiles = [] then its one color.

  Context* = ref object
    atlasShader, maskShader, activeShader: Shader
    atlasTexture: Texture
    maskTextureWrite: int       ## Index into max textures for writing.
    maskTextureRead: int        ## Index into max textures for rendering.
    maskTextures: seq[Texture]  ## Masks array for pushing and popping.
    atlasSize: int              ## Size x size dimensions of the atlas
    atlasMargin: int            ## Default margin between images
    quadCount: int              ## Number of quads drawn so far
    maxQuads: int               ## Max quads to draw before issuing an OpenGL call
    mat*: Mat4                  ## Current matrix
    mats: seq[Mat4]             ## Matrix stack
    entries*: Table[string, TileInfo] ## Mapping of image name to atlas UV position
    maxTiles: int
    tileRun: int
    takenTiles: seq[bool]        ## Height map of the free space in the atlas
    proj*: Mat4
    frameSize: Vec2             ## Dimensions of the window frame
    vertexArrayId, maskFramebufferId: GLuint
    frameBegun, maskBegun: bool
    pixelate*: bool             ## Makes texture look pixelated, like a pixel game.
    pixelScale*: float32        ## Multiple scaling factor.
    compacting*: bool           ## Are we currently compacting.

    # Buffer data for OpenGL
    positions: tuple[buffer: Buffer, data: seq[float32]]
    colors: tuple[buffer: Buffer, data: seq[uint8]]
    uvs: tuple[buffer: Buffer, data: seq[float32]]
    indices: tuple[buffer: Buffer, data: seq[uint16]]


proc tilesWidth(tileInfo: TileInfo ): int =
  ## Number of tiles wide.
  ceil(tileInfo.width / tileSize).int

proc tilesHeight(tileInfo: TileInfo ): int =
  ## Number of tiles high.
  ceil(tileInfo.height / tileSize).int

proc vec2(x, y: SomeNumber): Vec2 =
  ## Integer short cut for creating vectors.
  vec2(x.float32, y.float32)

proc isOneColor(image: Image): bool =
  ## True if image is fully one color, false otherwise.
  let c = image[0, 0]
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      if image[x, y] != c:
        return false
  return true

proc isTransparent(image: Image): bool =
  ## True if image is fully transparent, false otherwise.
  image.isOneColor() and image[0, 0].a == 0

proc readAtlasImage(ctx: Context): Image =
  # read old atlas content
  result = newImage(
    ctx.atlasTexture.width.GLsizei,
    ctx.atlasTexture.height.GLsizei,
  )
  glBindTexture(GL_TEXTURE_2D, ctx.atlasTexture.textureId)
  glGetTexImage(
    GL_TEXTURE_2D,
    0,
    GL_RGBA,
    GL_UNSIGNED_BYTE,
    result.data[0].addr
  )

proc writeAtlas*(ctx: Context, filePath: string) =
  ## Writes the current atlas to a file, used for debugging.
  var atlas = ctx.readAtlasImage()
  atlas.writeFile(filePath)

proc draw(ctx: Context)
proc putImage*(ctx: Context, imagePath: string, image: Image)

proc upload(ctx: Context) =
  ## When buffers change, uploads them to GPU.
  ctx.positions.buffer.count = ctx.quadCount * 4
  ctx.colors.buffer.count = ctx.quadCount * 4
  ctx.uvs.buffer.count = ctx.quadCount * 4
  ctx.indices.buffer.count = ctx.quadCount * 6
  bindBufferData(ctx.positions.buffer, ctx.positions.data[0].addr)
  bindBufferData(ctx.colors.buffer, ctx.colors.data[0].addr)
  bindBufferData(ctx.uvs.buffer, ctx.uvs.data[0].addr)

proc setUpMaskFramebuffer(ctx: Context) =
  glBindFramebuffer(GL_FRAMEBUFFER, ctx.maskFramebufferId)
  glFramebufferTexture2D(
    GL_FRAMEBUFFER,
    GL_COLOR_ATTACHMENT0,
    GL_TEXTURE_2D,
    ctx.maskTextures[ctx.maskTextureWrite].textureId,
    0
  )

proc createAtlasTexture(ctx: Context, size: int): Texture =
  result = Texture()
  result.width = size.GLint
  result.height = size.GLint
  result.componentType = GL_UNSIGNED_BYTE
  result.format = GL_RGBA
  result.internalFormat = GL_RGBA8
  result.genMipmap = true
  result.minFilter = minLinearMipmapLinear
  if ctx.pixelate:
    result.magFilter = magNearest
  else:
    result.magFilter = magLinear
  bindTextureData(result, nil)

proc addMaskTexture(ctx: Context, frameSize = vec2(1, 1)) =
  # Must be >0 for framebuffer creation below
  # Set to real value in beginFrame
  var maskTexture = Texture()
  maskTexture.width = frameSize.x.int32
  maskTexture.height = frameSize.y.int32
  maskTexture.componentType = GL_UNSIGNED_BYTE
  maskTexture.format = GL_RGBA
  when defined(emscripten):
    maskTexture.internalFormat = GL_RGBA8
  else:
    maskTexture.internalFormat = GL_R8
  maskTexture.minFilter = minLinear
  if ctx.pixelate:
    maskTexture.magFilter = magNearest
  else:
    maskTexture.magFilter = magLinear
  bindTextureData(maskTexture, nil)
  ctx.maskTextures.add(maskTexture)

proc addSolidTile(ctx: Context) =
  # Insert solid color tile. (don't use putImage as its a solid color)
  var solidTile = newImage(tileSize, tileSize)
  solidTile.fill(color(1, 1, 1, 1))
  updateSubImage(
    ctx.atlasTexture,
    0,
    0,
    solidTile
  )
  ctx.takenTiles[0] = true

proc clearAtlas*(ctx: Context) =
  ctx.entries.clear()
  for index in 0 ..< ctx.maxTiles:
    ctx.takenTiles[index] = false
  ctx.addSolidTile()

proc newContext*(
  atlasSize = 512,
  maxQuads = 1024,
  pixelate = false,
  pixelScale = 1.0
): Context =
  ## Creates a new context.
  if maxQuads > quadLimit:
    raise newException(ValueError, &"Quads cannot exceed {quadLimit}")

  result = Context()
  result.atlasSize = atlasSize
  result.maxQuads = maxQuads
  result.mat = mat4()
  result.mats = newSeq[Mat4]()
  result.pixelate = pixelate
  result.pixelScale = pixelScale

  result.tileRun = atlasSize div tileSize
  result.maxTiles = result.tileRun * result.tileRun
  result.takenTiles = newSeq[bool](result.maxTiles)
  result.atlasTexture = result.createAtlasTexture(atlasSize)

  result.addMaskTexture()

  when defined(emscripten):
    result.atlasShader = newShaderStatic("glsl/emscripten/atlas.vert", "glsl/emscripten/atlas.frag")
    result.maskShader = newShaderStatic("glsl/emscripten/atlas.vert", "glsl/emscripten/mask.frag")
  else:
    result.atlasShader = newShaderStatic("glsl/410/atlas.vert", "glsl/410/atlas.frag")
    result.maskShader = newShaderStatic("glsl/410/atlas.vert", "glsl/410/mask.frag")

  result.positions.buffer = Buffer()
  result.positions.buffer.componentType = cGL_FLOAT
  result.positions.buffer.kind = bkVEC2
  result.positions.buffer.target = GL_ARRAY_BUFFER
  result.positions.data = newSeq[float32](
    result.positions.buffer.kind.componentCount() * maxQuads * 4
  )

  result.colors.buffer = Buffer()
  result.colors.buffer.componentType = GL_UNSIGNED_BYTE
  result.colors.buffer.kind = bkVEC4
  result.colors.buffer.target = GL_ARRAY_BUFFER
  result.colors.buffer.normalized = true
  result.colors.data = newSeq[uint8](
    result.colors.buffer.kind.componentCount() * maxQuads * 4
  )

  result.uvs.buffer = Buffer()
  result.uvs.buffer.componentType = cGL_FLOAT
  result.uvs.buffer.kind = bkVEC2
  result.uvs.buffer.target = GL_ARRAY_BUFFER
  result.uvs.data = newSeq[float32](
    result.uvs.buffer.kind.componentCount() * maxQuads * 4
  )

  result.indices.buffer = Buffer()
  result.indices.buffer.componentType = GL_UNSIGNED_SHORT
  result.indices.buffer.kind = bkSCALAR
  result.indices.buffer.target = GL_ELEMENT_ARRAY_BUFFER
  result.indices.buffer.count = maxQuads * 6

  for i in 0 ..< maxQuads:
    let offset = i * 4
    result.indices.data.add([
      (offset + 3).uint16,
      (offset + 0).uint16,
      (offset + 1).uint16,
      (offset + 2).uint16,
      (offset + 3).uint16,
      (offset + 1).uint16,
    ])

  # Indices are only uploaded once
  bindBufferData(result.indices.buffer, result.indices.data[0].addr)

  result.upload()

  result.activeShader = result.atlasShader

  glGenVertexArrays(1, result.vertexArrayId.addr)
  glBindVertexArray(result.vertexArrayId)

  result.activeShader.bindAttrib("vertexPos", result.positions.buffer)
  result.activeShader.bindAttrib("vertexColor", result.colors.buffer)
  result.activeShader.bindAttrib("vertexUv", result.uvs.buffer)

  # Create mask framebuffer
  glGenFramebuffers(1, result.maskFramebufferId.addr)
  result.setUpMaskFramebuffer()

  let status = glCheckFramebufferStatus(GL_FRAMEBUFFER)
  if status != GL_FRAMEBUFFER_COMPLETE:
    quit(&"Something wrong with mask framebuffer: {toHex(status.int32, 4)}")

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  # Enable premultiplied alpha blending
  glEnable(GL_BLEND)
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

  result.addSolidTile()

proc grow(ctx: Context) =
  ## Grows the atlas size by 2 (growing area by 4).

  ctx.draw()

  # read old atlas content
  let
    oldAtlasImage = ctx.readAtlasImage()
    oldTileRun = ctx.tileRun

  ctx.atlasSize = ctx.atlasSize * 2

  echo "grow atlas: ", ctx.atlasSize

  ctx.tileRun = ctx.atlasSize div tileSize
  ctx.maxTiles = ctx.tileRun * ctx.tileRun
  ctx.takenTiles.setLen(ctx.maxTiles)
  ctx.atlasTexture = ctx.createAtlasTexture(ctx.atlasSize)

  ctx.addSolidTile()

  for y in 0 ..< oldTileRun:
    for x in 0 ..< oldTileRun:
      let
        imageTile = oldAtlasImage.superImage(
          x * tileSize,
          y * tileSize,
          tileSize,
          tileSize
        )
        index = x + y * oldTileRun
      updateSubImage(
        ctx.atlasTexture,
        (index mod ctx.tileRun) * tileSize,
        (index div ctx.tileRun) * tileSize,
        imageTile
      )

proc getFreeTile(ctx: Context): int =
  for index in 0 ..< ctx.maxTiles:
    if ctx.takenTiles[index] == false:
      ctx.takenTiles[index] = true
      return index
  ctx.grow()
  return ctx.getFreeTile()

proc putImage*(ctx: Context, imagePath: string, image: Image) =
  # Reminder: This does not set mipmaps (used for text, should it?)
  if imagePath in ctx.entries:
    for index in ctx.entries[imagePath].tiles:
      ctx.takenTiles[index] = false

  var tileInfo = TileInfo()
  tileInfo.width = image.width
  tileInfo.height = image.height

  if image.isTransparent():
    tileInfo.oneColor = color(0, 0, 0, 0)
  elif image.isOneColor():
    tileInfo.oneColor = image[0, 0].color
  else:
    for x in 0 ..< tileInfo.tilesWidth:
      for y in 0 ..< tileInfo.tilesHeight:
        let index = ctx.getFreeTile()
        tileInfo.tiles.add(index)
        let imageTile = image.superImage(x * tileSize, y * tileSize, tileSize, tileSize)
        updateSubImage(
          ctx.atlasTexture,
          (index mod ctx.tileRun) * tileSize,
          (index div ctx.tileRun) * tileSize,
          imageTile
        )

  ctx.entries[imagePath] = tileInfo

proc draw(ctx: Context) =
  ## Flips - draws current buffer and starts a new one.
  if ctx.quadCount == 0:
    return

  ctx.upload()

  glUseProgram(ctx.activeShader.programId)
  glBindVertexArray(ctx.vertexArrayId)

  if ctx.activeShader.hasUniform("windowFrame"):
    ctx.activeShader.setUniform("windowFrame", ctx.frameSize.x, ctx.frameSize.y)
  ctx.activeShader.setUniform("proj", ctx.proj)

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, ctx.atlasTexture.textureId)
  ctx.activeShader.setUniform("atlasTex", 0)

  if ctx.activeShader.hasUniform("maskTex"):
    glActiveTexture(GL_TEXTURE1)
    glBindTexture(
      GL_TEXTURE_2D,
      ctx.maskTextures[ctx.maskTextureRead].textureId
    )
    ctx.activeShader.setUniform("maskTex", 1)

  ctx.activeShader.bindUniforms()

  glBindBuffer(
    GL_ELEMENT_ARRAY_BUFFER,
    ctx.indices.buffer.bufferId
  )
  glDrawElements(
    GL_TRIANGLES,
    ctx.indices.buffer.count.GLint,
    ctx.indices.buffer.componentType,
    nil
  )

  ctx.quadCount = 0

proc checkBatch(ctx: Context) =
  if ctx.quadCount == ctx.maxQuads:
    # ctx is full dump the images in the ctx now and start a new batch
    ctx.draw()

proc setVert2(buf: var seq[float32], i: int, v: Vec2) =
  buf[i * 2 + 0] = v.x
  buf[i * 2 + 1] = v.y

proc setVertColor(buf: var seq[uint8], i: int, color: ColorRGBA) =
  buf[i * 4 + 0] = color.r
  buf[i * 4 + 1] = color.g
  buf[i * 4 + 2] = color.b
  buf[i * 4 + 3] = color.a

func `*`*(m: Mat4, v: Vec2): Vec2 =
  (m * vec3(v.x, v.y, 0.0)).xy

proc drawQuad*(
  ctx: Context,
  verts: array[4, Vec2],
  uvs: array[4, Vec2],
  colors: array[4, ColorRGBA],
) =
  ctx.checkBatch()

  let offset = ctx.quadCount * 4
  ctx.positions.data.setVert2(offset + 0, verts[0])
  ctx.positions.data.setVert2(offset + 1, verts[1])
  ctx.positions.data.setVert2(offset + 2, verts[2])
  ctx.positions.data.setVert2(offset + 3, verts[3])

  ctx.uvs.data.setVert2(offset + 0, uvs[0])
  ctx.uvs.data.setVert2(offset + 1, uvs[1])
  ctx.uvs.data.setVert2(offset + 2, uvs[2])
  ctx.uvs.data.setVert2(offset + 3, uvs[3])

  ctx.colors.data.setVertColor(offset + 0, colors[0])
  ctx.colors.data.setVertColor(offset + 1, colors[1])
  ctx.colors.data.setVertColor(offset + 2, colors[2])
  ctx.colors.data.setVertColor(offset + 3, colors[3])

  inc ctx.quadCount

proc drawUvRect(ctx: Context, at, to: Vec2, uvAt, uvTo: Vec2, color: Color) =
  ## Adds an image rect with a path to an ctx
  ctx.checkBatch()

  assert ctx.quadCount < ctx.maxQuads

  let
    at = ctx.mat * at
    to = ctx.mat * to

    posQuad = [
      vec2(at.x, to.y),
      vec2(to.x, to.y),
      vec2(to.x, at.y),
      vec2(at.x, at.y),
    ]

    uvAt = (uvAt + vec2(0.0, 0.0)) / ctx.atlasSize.float32
    uvTo = (uvTo + vec2(0.0, 0.0)) / ctx.atlasSize.float32

    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]

  let offset = ctx.quadCount * 4
  ctx.positions.data.setVert2(offset + 0, posQuad[0])
  ctx.positions.data.setVert2(offset + 1, posQuad[1])
  ctx.positions.data.setVert2(offset + 2, posQuad[2])
  ctx.positions.data.setVert2(offset + 3, posQuad[3])

  ctx.uvs.data.setVert2(offset + 0, uvQuad[0])
  ctx.uvs.data.setVert2(offset + 1, uvQuad[1])
  ctx.uvs.data.setVert2(offset + 2, uvQuad[2])
  ctx.uvs.data.setVert2(offset + 3, uvQuad[3])

  let rgba = color.rgba()
  ctx.colors.data.setVertColor(offset + 0, rgba)
  ctx.colors.data.setVertColor(offset + 1, rgba)
  ctx.colors.data.setVertColor(offset + 2, rgba)
  ctx.colors.data.setVertColor(offset + 3, rgba)

  inc ctx.quadCount

proc drawImage*(
  ctx: Context,
  imagePath: string,
  pos: Vec2 = vec2(0, 0),
  tintColor = color(1, 1, 1, 1),
  scale = 1.0
) =
  ## Draws image the UI way - pos at top-left.
  let tileInfo = ctx.entries[imagePath]
  if tileInfo.tiles.len == 0:
    if tileInfo.oneColor == color(0, 0, 0, 0):
      return # Don't draw anything if its transparent.
    else:
      # Draw a single 1 color rect
      var finalColor = color(
        tileInfo.oneColor.r * tintColor.r,
        tileInfo.oneColor.g * tintColor.g,
        tileInfo.oneColor.b * tintColor.b,
        tileInfo.oneColor.a * tintColor.a,
      )
      #print finalColor, tileInfo.oneColor, tintColor
      ctx.drawUvRect(
        pos,
        pos + vec2(tileInfo.width, tileInfo.height),
        vec2(2, 2),
        vec2(2, 2),
        finalColor
      )
  else:
    var i = 0
    for x in 0 ..< tileInfo.tilesWidth:
      for y in 0 ..< tileInfo.tilesHeight:
        let
          index = tileInfo.tiles[i]
          posAt = pos + vec2(x * tileSize, y * tileSize)
          uvAt = vec2(
            (index mod ctx.tileRun) * tileSize,
            (index div ctx.tileRun) * tileSize
          )
        ctx.drawUvRect(
          posAt,
          posAt + vec2(tileSize, tileSize),
          uvAt,
          uvAt + vec2(tileSize, tileSize),
          tintColor
        )
        inc i
    assert i == tileInfo.tiles.len

proc clearMask*(ctx: Context) =
  ## Sets mask off (actually fills the mask with white).
  assert ctx.frameBegun == true, "ctx.beginFrame has not been called."

  ctx.draw()

  ctx.setUpMaskFramebuffer()

  glClearColor(1, 1, 1, 1)
  glClear(GL_COLOR_BUFFER_BIT)

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc beginMask*(ctx: Context) =
  ## Starts drawing into a mask.
  assert ctx.frameBegun == true, "ctx.beginFrame has not been called."
  assert ctx.maskBegun == false, "ctx.beginMask has already been called."
  ctx.maskBegun = true

  ctx.draw()

  inc ctx.maskTextureWrite
  ctx.maskTextureRead = ctx.maskTextureWrite - 1
  if ctx.maskTextureWrite >= ctx.maskTextures.len:
    ctx.addMaskTexture(ctx.frameSize)

  ctx.setUpMaskFramebuffer()
  glViewport(0, 0, ctx.frameSize.x.GLint, ctx.frameSize.y.GLint)

  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  ctx.activeShader = ctx.maskShader

proc endMask*(ctx: Context) =
  ## Stops drawing into the mask.
  assert ctx.maskBegun == true, "ctx.maskBegun has not been called."
  ctx.maskBegun = false

  ctx.draw()

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  ctx.maskTextureRead = ctx.maskTextureWrite

  ctx.activeShader = ctx.atlasShader

proc popMask*(ctx: Context) =
  ctx.draw()

  dec ctx.maskTextureWrite
  ctx.maskTextureRead = ctx.maskTextureWrite

proc beginFrame*(ctx: Context, frameSize: Vec2, proj: Mat4) =
  ## Starts a new frame.
  assert ctx.frameBegun == false, "ctx.beginFrame has already been called."
  ctx.frameBegun = true

  ctx.proj = proj

  if ctx.maskTextures[0].width != frameSize.x.int32 or
    ctx.maskTextures[0].height != frameSize.y.int32:
    # Resize all of the masks.
    ctx.frameSize = frameSize
    for i in 0 ..< ctx.maskTextures.len:
      ctx.maskTextures[i].width = frameSize.x.int32
      ctx.maskTextures[i].height = frameSize.y.int32
      if i > 0:
        # Never resize the 0th mask because its just white.
        bindTextureData(ctx.maskTextures[i], nil)

  glViewport(0, 0, ctx.frameSize.x.GLint, ctx.frameSize.y.GLint)

  ctx.clearMask()

proc beginFrame*(ctx: Context, frameSize: Vec2) =
  beginFrame(
    ctx,
    frameSize,
    ortho(0.float32, frameSize.x, frameSize.y, 0, -1000, 1000)
  )

proc endFrame*(ctx: Context) =
  ## Ends a frame.
  assert ctx.frameBegun == true, "ctx.beginFrame was not called first."
  assert ctx.maskTextureRead == 0, "Not all masks have been popped."
  assert ctx.maskTextureWrite == 0, "Not all masks have been popped."
  ctx.frameBegun = false

  ctx.draw()

proc translate*(ctx: Context, v: Vec2) =
  ## Translate the internal transform.
  ctx.mat = ctx.mat * translate(vec3(v))

proc rotate*(ctx: Context, angle: float32) =
  ## Rotates the internal transform.
  ctx.mat = ctx.mat * rotateZ(angle)

proc scale*(ctx: Context, scale: float32) =
  ## Scales the internal transform.
  ctx.mat = ctx.mat * scale(vec3(scale))

proc scale*(ctx: Context, scale: Vec2) =
  ## Scales the internal transform.
  ctx.mat = ctx.mat * scale(vec3(scale.x, scale.y, 1))

proc saveTransform*(ctx: Context) =
  ## Pushes a transform onto the stack.
  ctx.mats.add ctx.mat

proc restoreTransform*(ctx: Context) =
  ## Pops a transform off the stack.
  ctx.mat = ctx.mats.pop()

proc clearTransform*(ctx: Context) =
  ## Clears transform and transform stack.
  ctx.mat = mat4()
  ctx.mats.setLen(0)

proc fromScreen*(ctx: Context, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from screen and translates it to point inside the current transform.
  (ctx.mat.inverse() * vec3(v.x, windowFrame.y - v.y, 0)).xy

proc toScreen*(ctx: Context, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from current transform and translates it to screen.
  result = (ctx.mat * vec3(v.x, v.y, 1)).xy
  result.y = -result.y + windowFrame.y
