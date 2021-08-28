import bumpy, chroma, loader, math, pixie, schema, tables, vmath,
    common, staticglfw, pixie, textboxes, perf,
    layout

type Image = pixie.Image
type Paint = schema.Paint
type Font = pixie.Font

var
  layer*: Image
  layers: seq[Image]
  maskLayer*: Mask

proc newImage(w, h: int): Image {.measure.} =
  pixie.newImage(w, h)

proc draw(a, b: Image) {.measure.} =
  pixie.draw(a, b)

proc computeIntBounds*(node: Node, mat: Mat3, withChildren=false): Rect {.measure.} =
  ## Compute self bounds of a given node.

  # Generate the geometry.
  if node.kind == nkText:
    node.genHitRectGeometry()
  else:
    node.genFillGeometry()
    node.genStrokeGeometry()

  # Compute geometry bounds.
  var
    minV: Vec2
    maxV: Vec2
    first = true
  for geoms in [node.fillGeometry, node.strokeGeometry]:
    for geom in geoms:
      let bounds = geom.path.computeBounds(mat)
      if first:
        first = false
        minV.x = bounds.x
        minV.y = bounds.y
        maxV.x = bounds.x + bounds.w
        maxV.y = bounds.y + bounds.h
      else:
        minV.x = min(minV.x, bounds.x)
        minV.y = min(minV.y, bounds.y)
        maxV.x = max(maxV.x, bounds.x + bounds.w)
        maxV.y = max(maxV.y, bounds.y + bounds.h)

  # Add effects to bounds.
  var borderMinV, borderMaxV: Vec2
  for effect in node.effects:
    case effect.kind
    of ekLayerBlur, ekBackgroundBlur:
      borderMinV = min(borderMinV, vec2(-effect.radius))
      borderMaxV = max(borderMaxV, vec2(effect.radius))
    of ekDropShadow, ekInnerShadow:
      borderMinV = min(
        borderMinV,
        effect.offset - vec2(effect.radius+effect.spread)
      )
      borderMaxV = max(
        borderMaxV,
        effect.offset + vec2(effect.radius + effect.spread)
      )
  minV += borderMinV
  maxV += borderMaxV

  # Snap bounds to pixels.
  result = rect(minV.x, minV.y, maxV.x - minV.x, maxV.y - minV.y).snapToPixels()

  # Compute bounds on children.
  if withChildren:
    for child in node.children:
      result = result or child.computeIntBounds(
        mat * node.transform(),
        withChildren
      )

proc underMouse*(screenNode: Node, mousePos: Vec2): seq[Node] {.measure.} =
  ## Computes a list of nodes under the mouse.

  proc visit(node: Node, mat: Mat3, mousePos: Vec2, s: var seq[Node]): bool =
    ## Visits each node and sees if its geometry overlaps the mouse.

    let mat = mat * node.transform()
    var overlaps = false

    # Visit all children first, if any of them overlaps this node overlaps too.
    for child in node.children.reverse:
      if child.visit(
        mat,
        mousePos,
        s
      ) and not overlaps:
        overlaps = true
        break

    if not overlaps:
      # Check all geometry for overlaps.
      block all:
        for geoms in [node.fillGeometry, node.strokeGeometry]:
          for geom in geoms:
            if geom.path.fillOverlaps(mousePos, mat, geom.windingRule):
              overlaps = true
              break all

    if overlaps:
      s.add(node)
      return true

  discard screenNode.visit(screenNode.transform().inverse(), mousePos, result)

proc toPixiePaint(paint: schema.Paint, node: Node): pixie.Paint =
  let paintKind = case paint.kind:
    of schema.pkSolid: pixie.pkSolid
    of schema.pkImage: pixie.pkImage
    of schema.pkGradientLinear: pixie.pkGradientLinear
    of schema.pkGradientRadial: pixie.pkGradientRadial
    of schema.pkGradientAngular: pixie.pkGradientAngular
    of schema.pkGradientDiamond: pixie.pkGradientRadial

  result = newPaint(paintKind)
  result.opacity = paint.opacity
  for handle in paint.gradientHandlePositions:
    result.gradientHandlePositions.add(
      handle * node.size + mat.pos
    )
  if result.kind == pixie.pkGradientLinear:
    result.gradientHandlePositions.setLen(2)
  for stop in paint.gradientStops:
    var color = stop.color
    result.gradientStops.add(pixie.ColorStop(color: color, position: stop.position))

proc drawFill(node: Node, paint: Paint): Image {.measure.} =
  ## Creates a fill image based on the paint.
  result = newImage(layer.width, layer.height)

  let nodeOffset =
    when defined(cpu):
      node.position
    else:
      vec2(0, 0)

  case paint.kind
  of schema.PaintKind.pkSolid:
    var color = paint.color
    color.a = color.a * paint.opacity
    if color.a == 0:
      return
    result.fill(color.rgbx)

  of schema.PaintKind.pkImage:
    var image: Image
    if paint.imageRef notin imageCache:
      try:
        image = readImage(figmaImagePath(paint.imageRef))
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
      mat[2, 0] = nodeOffset.x + mat[2, 0] * node.size.x
      mat[2, 1] = nodeOffset.y + mat[2, 1] * node.size.y
      let
        ratioW = image.width.float32 / node.size.x
        ratioH = image.height.float32 / node.size.y
        scale = min(ratioW, ratioH)
      mat = mat * scale(vec2(1/scale))
      result.draw(image, mat)

    of smTile:
      image = image.resize(
        int(image.width.float32 * paint.scalingFactor),
        int(image.height.float32 * paint.scalingFactor))
      var x = 0.0
      while x < node.size.x:
        var y = 0.0
        while y < node.size.y:
          result.draw(image, translate(nodeOffset + vec2(x, y)))
          y += image.height.float32
        x += image.width.float32

  of schema.PaintKind.pkGradientLinear:
    result.fillGradient(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientRadial:
    result.fillGradient(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientAngular:
    result.fillGradient(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientDiamond:
    result.fillGradient(paint.toPixiePaint(node))

proc drawPaint*(node: Node, paints: seq[Paint], geometries: seq[Geometry]) {.measure.} =
  if paints.len == 0 or geometries.len == 0:
    return

  if paints.len == 1 and paints[0].kind == schema.PaintKind.pkSolid:
    # Fast path for 1 solid paint (most common).
    let paint = paints[0]
    if not paint.visible or paint.opacity == 0:
      return
    var color = paint.color
    color.a = color.a * paint.opacity
    if color.a == 0:
      return
    for geometry in geometries:
      var paint = newPaint(pixie.PaintKind.pkSolid)
      paint.color = color
      paint.blendMode = paint.blendMode
      layer.fillPath(
        geometry.path,
        paint,
        mat * geometry.mat,
        geometry.windingRule
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

proc drawGeometry*(node: Node) {.measure.} =
  if node.strokeGeometry.len == 0:
    # No stroke just fill.
    node.drawPaint(node.fills, node.fillGeometry)
  else:
    # Draw stroke depending on stroke align.
    case node.strokeAlign
    of saInside:
      if node.fillGeometry.len == 0:
        node.drawPaint(node.strokes, node.strokeGeometry)

      else:
        # Deal with fill
        var fillLayer = layer
        node.drawPaint(node.fills, node.fillGeometry)
        # Deal with fill mask
        var fillMask = newMask(layer.width, layer.height)
        for geometry in node.fillGeometry:
          fillMask.fillPath(geometry.path, mat, geometry.windingRule)
        # Deal with stroke
        var strokeLayer = newImage(layer.width, layer.height)
        layer = strokeLayer
        node.drawPaint(node.strokes, node.strokeGeometry)
        layer = fillLayer
        strokeLayer.draw(fillMask, blendMode = bmMask)
        layer.draw(strokeLayer)

    of saCenter:
      node.drawPaint(node.fills, node.fillGeometry)
      node.drawPaint(node.strokes, node.strokeGeometry)

    of saOutside:
      # Deal with fill
      var fillLayer = layer
      node.drawPaint(node.fills, node.fillGeometry)
      # Deal with fill mask
      var fillMask = newMask(layer.width, layer.height)
      for geometry in node.fillGeometry:
        fillMask.fillPath(geometry.path, mat, geometry.windingRule)
      # Deal with stroke
      var strokeLayer = newImage(layer.width, layer.height)
      layer = strokeLayer
      node.drawPaint(node.strokes, node.strokeGeometry)
      layer = fillLayer
      strokeLayer.draw(fillMask, blendMode = bmSubtractMask)
      layer.draw(strokeLayer)

proc drawInnerShadowEffect*(effect: Effect, node: Node, fillMask: Mask) {.measure.} =
  ## Draws the inner shadow.
  var shadow = newMask(fillMask.width, fillMask.height)
  shadow.draw(fillMask, translate(effect.offset), blendMode = bmOverwrite)
  # Invert colors of the fill mask.
  shadow.invert()
  # Blur the inverted fill.
  shadow.blur(effect.radius, outOfBounds = 255)
  # Color the inverted blurred fill.
  var color = newImage(shadow.width, shadow.height)
  color.fill(effect.color.rgbx)
  color.draw(shadow, blendMode = bmMask)
  # Only have the shadow be on the fill.
  color.draw(fillMask, blendMode = bmMask)
  # Draw it back.
  layer.draw(color)

proc drawDropShadowEffect*(lowerLayer: Image, layer: Image, effect: Effect, node: Node) {.measure.} =
  ## Draws the drop shadow.
  var shadow = newImage(layer.width, layer.height)
  shadow.draw(layer, blendMode = bmOverwrite)
  shadow = shadow.shadow(
    effect.offset, effect.spread, effect.radius, effect.color.rgbx)
  lowerLayer.draw(shadow)

proc drawBackgroundBlur*(lowerLayer: Image, effect: Effect) {.measure.} =
  var blurLayer = lowerLayer.copy() # Maybe collapse bg?
  var blurMask = newMask(layer)
  blurMask.ceil()
  blurLayer.blur(effect.radius)
  blurLayer.draw(blurMask, blendMode = bmMask)
  blurLayer.draw(layer)
  layer = blurLayer

proc maskSelfImage*(node: Node): Mask {.measure.} =
  ## Returns a self mask (used for clips-content).
  var mask = newMask(layer.width, layer.height)
  for geometry in node.fillGeometry:
    mask.fillPath(
      geometry.path,
      mat * geometry.mat,
      geometry.windingRule
    )
  return mask

proc drawText*(node: Node) {.measure.} =
  ## Draws the text (including editing of text).

  var arrangement = node.computeArrangement()

  if textBoxFocus == node:
    # Don't recompute the layout twice,
    # Set the text layout to textBox layout.
    textBox.arrangement = arrangement

    # TODO: Draw selection outline by using a parent focus variant?
    # layer.fillRect(node.pixelBox, rgbx(255, 0, 0, 255))

    # Draw the selection ranges.
    for selectionRegion in textBox.selectionRegions():
      var s = selectionRegion
      var path = newPath()
      path.rect(s)
      layer.fillPath(path, defaultTextHighlightColor, mat)

    # Draw the typing cursor
    var s = textBox.cursorRect()
    var path = newPath()
    path.rect(s)
    layer.fillPath(path, node.fills[0].color.rgbx, mat)

  ## Fills the text arrangement.
  for spanIndex, (start, stop) in arrangement.spans:
    var font = arrangement.fonts[spanIndex]
    var normalPaint = font.paint
    var selectedPaint: type(normalPaint) = color(1, 1, 1, 1)

    for runeIndex in start .. stop:
      var path = font.typeface.getGlyphPath(arrangement.runes[runeIndex])
      path.transform(
        translate(arrangement.positions[runeIndex]) *
        scale(vec2(font.scale))
      )

      var paint = normalPaint
      if textBoxFocus == node:
        # If editing text and character is in selection range,
        # draw it white.
        let s = textBox.selection()
        if runeIndex >= s.a and runeIndex < s.b:
          paint = selectedPaint

      layer.fillPath(path, paint, mat)

proc drawNode*(node: Node, withChildren=true)

proc drawBooleanNode*(node: Node, blendMode: BlendMode) =
  let prevMat = mat
  mat = mat * node.transform()

  if node.children.len == 0:
    node.genFillGeometry()
    for geometry in node.fillGeometry:
      maskLayer.fillPath(
        geometry.path,
        mat,
        geometry.windingRule,
        blendMode
      )

  for i, child in node.children:
    let blendMode =
      if i == 0:
        bmNormal
      else:
        case node.booleanOperation:
          of boUnion: bmNormal
          of boSubtract: bmSubtractMask
          of boIntersect: bmMask
          of boExclude: bmExcludeMask
    drawBooleanNode(child, blendMode)

  mat = prevMat

proc drawBoolean*(node: Node) {.measure.} =
  ## Draws boolean
  maskLayer = newMask(layer.width, layer.height)
  mat = mat * node.transform().inverse()
  drawBooleanNode(node, bmNormal)
  for paint in node.fills:
    if not paint.visible or paint.opacity == 0:
      continue
    var fillImage = drawFill(node, paint)
    fillImage.draw(maskLayer, blendMode = bmMask)
    layer.draw(fillImage)

proc drawNodeInternal*(node: Node, withChildren=true) {.measure.} =

  if not node.visible or node.opacity == 0:
    return

  var hasMaskedChildren = false
  var needsLayer = false
  if node.opacity != 1.0:
    needsLayer = true
  if node.blendMode != bmNormal:
    needsLayer = true
  if node.clipsContent:
    needsLayer = true
  if node.effects.len > 0:
    needsLayer = true
  for child in node.children:
    if child.isMask and child.visible:
      needsLayer = true
      hasMaskedChildren = true
      maskLayer = newMask(layer.width, layer.height)
      break

  if needsLayer:
    layers.add(layer)
    layer = newImage(layer.width, layer.height)

  if node.kind == nkText:
    node.drawText()
  elif node.kind == nkBooleanOperation:
    node.drawBoolean()
  else:
    node.genFillGeometry()
    node.genStrokeGeometry()
    node.drawGeometry()

  for effect in node.effects:
    if effect.kind == ekInnerShadow:
      drawInnerShadowEffect(effect, node, node.maskSelfImage())

  if withChildren:
    if hasMaskedChildren:
      layers.add(layer)
      layer = newImage(layer.width, layer.height)
      var childLayer = layer
      for child in node.children:
        if child.isMask and child.visible:
          layers.add(layer)
          layer = newImage(layer.width, layer.height)
          drawNode(child)
          maskLayer.draw(layer, blendMode=bmNormal)
          layer = layers.pop()
        else:
          drawNode(child)
          layer.draw(maskLayer, blendMode=bmMask)
      layer = layers.pop()
      layer.draw(childLayer)
    elif node.kind == nkBooleanOperation:
      discard
    else:
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
      if effect.kind == ekLayerBlur:
        layer.blur(effect.radius)
      if effect.kind == ekBackgroundBlur:
        drawBackgroundBlur(lowerLayer, effect)

    measurePush("lowerLayer.draw") # & $node.blendMode)
    lowerLayer.draw(layer, blendMode = node.blendMode)
    layer = lowerLayer
    measurePop()

proc drawNode*(node: Node, withChildren=true) {.measure.} =

  let prevMat = mat
  mat = mat * node.transform()

  node.mat = mat
  node.pixelBox.xy = mat * vec2(0, 0)
  node.pixelBox.wh = node.size

  node.drawNodeInternal(withChildren)

  mat = prevMat

proc drawCompleteFrame*(node: Node): pixie.Image {.measure.} =
  let
    w = node.size.x.int
    h = node.size.y.int

  computeLayout(nil, node)

  layer = newImage(w, h)
  mat = translate(-node.position)
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
