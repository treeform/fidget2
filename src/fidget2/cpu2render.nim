import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie, typography, typography/textboxes

type Image = pixie.Image

var
  layer: Image
  layers: seq[Image]
  mat: Mat3
  imageCache: Table[string, Image]

proc transform(node: Node): Mat3 =
  ## Returns Mat3 transform of the node.
  result[0, 0] = node.relativeTransform[0][0]
  result[0, 1] = node.relativeTransform[1][0]
  result[0, 2] = 0
  result[1, 0] = node.relativeTransform[0][1]
  result[1, 1] = node.relativeTransform[1][1]
  result[1, 2] = 0
  result[2, 0] = node.box.x #node.relativeTransform[0][2]
  result[2, 1] = node.box.y #node.relativeTransform[1][2]
  result[2, 2] = 1

proc pos(mat: Mat3): Vec2 =
  result.x = mat[2*3+0]
  result.y = mat[2*3+1]

proc textFillGeometries(node: Node): seq[Geometry] =

  var font: Font
  if node.style.fontPostScriptName notin typefaceCache:
    if node.style.fontPostScriptName == "":
      node.style.fontPostScriptName = node.style.fontFamily & "-Regular"

    font = readFontTtf(figmaFontPath(node.style.fontPostScriptName))
    typefaceCache[node.style.fontPostScriptName] = font.typeface
  else:
    font = Font()
    font.typeface = typefaceCache[node.style.fontPostScriptName]
  font.size = node.style.fontSize
  font.lineHeight = node.style.lineHeightPx

  var wrap = false
  if node.style.textAutoResize == tarHeight:
    wrap = true

  let kern = node.style.opentypeFlags.KERN != 0

  let layout = font.typeset(
    text = if textBoxFocus == node:
        textBox.text
      else:
        node.characters,
    pos = vec2(0, 0),
    size = node.size,
    hAlign = node.style.textAlignHorizontal,
    vAlign = node.style.textAlignVertical,
    clip = false,
    wrap = wrap,
    kern = kern,
    textCase = node.style.textCase,
  )

  #TODO: curser and selection

  for i, gpos in layout:
    var font = gpos.font

    if gpos.character in font.typeface.glyphs:
      var glyph = font.typeface.glyphs[gpos.character]
      glyph.makeReady(font)

      if glyph.path.commands.len == 0:
        continue

      let characterMat = translate(vec2(
        gpos.rect.x + gpos.subPixelShift,
        gpos.rect.y
      )) * scale(vec2(font.scale, -font.scale))

      var geometry = Geometry()
      geometry.windingRule = wrNonZero
      geometry.path = glyph.path
      geometry.mat = characterMat
      result.add(geometry)

proc rectangleFillGeometry(node: Node): Geometry =
  ## Creates a fill geometry from a rectangle like node.
  result = Geometry()
  result.mat = mat3()
  result.windingRule = wrNonZero

  if node.cornerRadius > 0:
    # Rectangle with common corners.
    result.path.roundedRect(
      vec2(0, 0),
      node.size,
      nw = node.cornerRadius,
      ne = node.cornerRadius,
      se = node.cornerRadius,
      sw = node.cornerRadius
    )
  elif node.rectangleCornerRadii != nil:
    # Rectangle with different corners.
    result.path.roundedRect(
      vec2(0, 0),
      node.size,
      nw = node.rectangleCornerRadii[0],
      ne = node.rectangleCornerRadii[1],
      se = node.rectangleCornerRadii[2],
      sw = node.rectangleCornerRadii[3],
    )
  else:
    # Basic rectangle.
    result.path.rect(
      x = 0,
      y = 0,
      w = node.size.x,
      h = node.size.y,
    )

proc rectangleStrokeGeometry(node: Node): Geometry =
  ## Creates a fill geometry from a rectangle like node.
  result = Geometry()
  result.mat = mat3()
  result.windingRule = wrNonZero

  let
    x = 0.0
    y = 0.0
    w = node.size.x
    h = node.size.y
  var
    inner = 0.0
    outer = 0.0
  case node.strokeAlign
  of saInside:
    inner = node.strokeWeight
  of saOutside:
    outer = node.strokeWeight
  of saCenter:
    inner = node.strokeWeight / 2
    outer = node.strokeWeight / 2

  if node.cornerRadius > 0:
    # Rectangle with common corners.
    let
      r = node.cornerRadius
    result.path.roundedRect(
      vec2(x-outer, y-outer),
      vec2(w+outer*2, h+outer*2),
      r+outer, r+outer, r+outer, r+outer
    )
    result.path.roundedRect(
      vec2(x+inner, y+inner),
      vec2(w-inner*2, h-inner*2),
      r-inner, r-inner, r-inner, r-inner,
      clockwise = false
    )
  elif node.rectangleCornerRadii != nil:
    # Rectangle with different corners.
    let
      nw = node.rectangleCornerRadii[0]
      ne = node.rectangleCornerRadii[1]
      se = node.rectangleCornerRadii[2]
      sw = node.rectangleCornerRadii[3]
    result.path.roundedRect(
      vec2(x-outer, y-outer),
      vec2(w+outer*2, h+outer*2),
      nw+outer, ne+outer, se+outer, sw+outer
    )
    result.path.roundedRect(
      vec2(x+inner, y+inner),
      vec2(w-inner*2, h-inner*2),
      nw-inner, ne-inner, se-inner, sw-inner,
      clockwise = false
    )
  else:
    result.path.rect(
      vec2(x-outer, y-outer),
      vec2(w+outer*2, h+outer*2),
    )
    result.path.rect(
      vec2(x+inner, y+inner),
      vec2(w-inner*2, h-inner*2),
      clockwise = false
    )

proc getFillGeometry(node: Node): seq[Geometry] =
  ## Either gets existing geometry (nkVector etc..)
  ## or generates it if (nkFrame, nkGroup...).
  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    @[node.rectangleFillGeometry()]
  of nkText:
    node.textFillGeometries()
  else:
    node.fillGeometry

proc getStrokeGeometry(node: Node): seq[Geometry] =
  ## Either gets existing geometry (nkVector etc..)
  ## or generates it if (nkFrame, nkGroup...).
  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    @[node.rectangleStrokeGeometry()]
  else:
    node.strokeGeometry

proc drawFill(node: Node, paint: Paint): Image =
  ## Creates a fill image based on the paint.

  proc toImageSpace(handle: Vec2): Vec2 =
    vec2(
      handle.x * node.absoluteBoundingBox.w + node.box.x,
      handle.y * node.absoluteBoundingBox.h + node.box.y,
    )

  proc gradientAdjust(stops: seq[ColorStop], alpha: float32): seq[ColorStop] =
    result = stops
    for stop in result.mitems:
      stop.color.a *= alpha

  result = newImage(layer.width, layer.height)
  case paint.kind
  of pkSolid:
    var color = paint.color
    color.a = color.a * paint.opacity
    if color.a == 0:
      return
    result.fill(color.rgba.toPremultipliedAlpha())

  of pkImage:
    var image: Image
    if paint.imageRef notin imageCache:
      try:
        image = readImage(figmaImagePath(paint.imageRef))
        image.toPremultipliedAlpha()
      except PixieError:
        return
      imageCache[paint.imageRef] = image
    else:
      image = imageCache[paint.imageRef]

    case paint.scaleMode
    of smFill:
      let
        ratioW = image.width.float32 / node.size.x
        ratioH = image.height.float32 / node.size.y
        scale = min(ratioW, ratioH)
      let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
      result.draw(
        image,
        mat * translate(topRight) * scale(vec2(1/scale))
      )

    of smFit:
      let
        ratioW = image.width.float32 / node.size.x
        ratioH = image.height.float32 / node.size.y
        scale = max(ratioW, ratioH)
      let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
      result.draw(
        image,
        mat * translate(topRight) * scale(vec2(1/scale))
      )

    of smStretch: # Figma ui calls this "crop".
      var mat: Mat3
      mat[0, 0] = paint.imageTransform[0][0]
      mat[0, 1] = paint.imageTransform[0][1]

      mat[1, 0] = paint.imageTransform[1][0]
      mat[1, 1] = paint.imageTransform[1][1]

      mat[2, 0] = paint.imageTransform[0][2]
      mat[2, 1] = paint.imageTransform[1][2]
      mat[2, 2] = 1

      mat = mat.inverse()
      mat[2, 0] = node.box.x + mat[2, 0] * node.absoluteBoundingBox.w
      mat[2, 1] = node.box.y + mat[2, 1] * node.absoluteBoundingBox.h
      let
        ratioW = image.width.float32 / node.absoluteBoundingBox.w
        ratioH = image.height.float32 / node.absoluteBoundingBox.h
        scale = min(ratioW, ratioH)
      mat = mat * scale(vec2(1/scale))
      result.draw(image, mat)

    of smTile:
      image = image.resize(
        int(image.width.float32 * paint.scalingFactor),
        int(image.height.float32 * paint.scalingFactor))
      var x = 0.0
      while x < node.absoluteBoundingBox.w:
        var y = 0.0
        while y < node.absoluteBoundingBox.h:
          result.draw(image, node.box.xy + vec2(x, y))
          y += image.height.float32
        x += image.width.float32

  of pkGradientLinear:
    result.fillLinearGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

  of pkGradientRadial:
    result.fillRadialGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientHandlePositions[2].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

  of pkGradientAngular:
    result.fillAngularGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientHandlePositions[2].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

  of pkGradientDiamond:
    result.fillDiamondGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientHandlePositions[2].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

proc drawPaint(node: Node, paints: seq[Paint], geometries: seq[Geometry]) =
  if paints.len == 0 or geometries.len == 0:
    return

  if paints.len == 1 and paints[0].kind == pkSolid:
    # Fast path for 1 solid paint (most common).
    let paint = paints[0]
    if not paint.visible or paint.opacity == 0:
      return
    var color = paint.color
    color.a = color.a * paint.opacity
    if color.a == 0:
      return
    for geometry in geometries:
      layer.fillPath(
        geometry.path,
        color.rgba.toPremultipliedAlpha(),
        mat * geometry.mat,
        geometry.windingRule,
        blendMode = paint.blendMode
      )
  else:
    # Mask + fill based on paint.
    var mask = newMask(layer.width, layer.height)
    for geometry in geometries:
      mask.fillPath(
        geometry.path,
        mat * geometry.mat,
        geometry.windingRule
      )
    for paint in paints:
      if not paint.visible or paint.opacity == 0:
        continue
      var fillImage = drawFill(node, paint)
      fillImage.draw(mask, blendMode = bmMask)
      layer.draw(fillImage, blendMode = paint.blendMode)

proc maskSelfImage(node: Node): Mask =
  ## Returns a self mask (used for clips content).
  var mask = newMask(layer.width, layer.height)
  for geometry in node.getFillGeometry():
    mask.fillPath(
      geometry.path,
      mat * geometry.mat,
      geometry.windingRule
    )
  return mask

proc drawNode(node: Node) =
  if not node.visible or node.opacity == 0:
    return

  let prevMat = mat
  mat = mat * node.transform()

  var needsLayer = false
  if node.opacity != 1.0:
    needsLayer = true
  if node.blendMode != bmNormal:
    needsLayer = true
  if node.clipsContent:
    needsLayer = true

  if needsLayer:
    layers.add(layer)
    layer = newImage(layer.width, layer.height)

  node.drawPaint(node.fills, node.getFillGeometry())
  node.drawPaint(node.strokes, node.getStrokeGeometry())

  for child in node.children:
    drawNode(child)

  if node.clipsContent:
    var mask = node.maskSelfImage()
    layer.draw(mask, blendMode = bmMask)

  if needsLayer:
    var lowerLayer = layers.pop()
    if node.opacity != 1.0:
      layer.applyOpacity(node.opacity)
    lowerLayer.draw(layer, blendMode = node.blendMode)
    layer = lowerLayer

  mat = prevMat

proc drawCompleteFrame*(node: Node): pixie.Image =
  let
    w = node.absoluteBoundingBox.w.int
    h = node.absoluteBoundingBox.h.int

  layer = newImage(w, h)
  mat = mat3()
  var t = node.relativeTransform
  mat = mat * translate(vec2(-t[0][2], -t[1][2]))
  drawNode(node)

  doAssert layers.len == 0

  return layer

proc setupWindow*(
  frameNode: Node,
  offscreen = false,
  resizable = true
) =
  ## Opens a new glfw window that is ready to draw into.
  if init() == 0:
    raise newException(Exception, "Failed to intialize GLFW")
  windowHint(VISIBLE, (not offscreen).cint)
  windowHint(RESIZABLE, resizable.cint)
  windowHint(CLIENT_API, NO_API)
  window = createWindow(
    viewportSize.x.cint, viewportSize.y.cint,
    "loading...",
    nil,
    nil)
  if window == nil:
    raise newException(Exception, "Failed to create GLFW window.")
