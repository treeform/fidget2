import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie, typography, typography/textboxes

type Image = pixie.Image

var
  layer: Image
  layers: seq[Image]

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

proc drawInnerShadowEffect(effect: Effect, node: Node, fillMask: Mask) =
  ## Draws the inner shadow.
  var shadow = fillMask.copy()
  # Invert colors of the fill mask.
  shadow.invert()
  # Blur the inverted fill.
  shadow.blur(effect.radius, offBounds = 255)
  # Color the inverted blurred fill.
  var color = newImage(shadow.width, shadow.height)
  color.fill(effect.color.rgba.toPremultipliedAlpha())
  color.draw(shadow, blendMode = bmMask)
  # Only have the shadow be on the fill.
  color.draw(fillMask, blendMode = bmMask)
  # Draw it back.
  layer.draw(color)

proc drawDropShadowEffect(lowerLayer: Image, layer: Image, effect: Effect, node: Node) =
  ## Draws the drop shadow.
  var shadow = newImage(layer.width, layer.height)
  shadow.draw(layer, blendMode = bmOverwrite)
  shadow = shadow.shadow(
    effect.offset, effect.spread, effect.radius, effect.color.rgba.toPremultipliedAlpha())
  lowerLayer.draw(shadow)

proc maskSelfImage(node: Node): Mask =
  ## Returns a self mask (used for clips content).
  var mask = newMask(layer.width, layer.height)
  for geometry in node.fillGeometry:
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
  if node.effects.len > 0:
    needsLayer = true

  if needsLayer:
    layers.add(layer)
    layer = newImage(layer.width, layer.height)

  node.genFillGeometry()
  node.drawPaint(node.fills, node.fillGeometry)
  node.genStrokeGeometry()
  node.drawPaint(node.strokes, node.strokeGeometry)

  for effect in node.effects:
    if effect.kind == ekInnerShadow:
      drawInnerShadowEffect(effect, node, node.maskSelfImage())


  for child in node.children:
    drawNode(child)

  if node.clipsContent:
    var mask = node.maskSelfImage()
    layer.draw(mask, blendMode = bmMask)

  if needsLayer:
    var lowerLayer = layers.pop()
    if node.opacity != 1.0:
      layer.applyOpacity(node.opacity)
    for effect in node.effects:
      if effect.kind == ekDropShadow:
        lowerLayer.drawDropShadowEffect(layer, effect, node)
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
