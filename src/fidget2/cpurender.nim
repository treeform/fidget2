import bumpy, chroma, loader, math, pixie, schema, tables, vmath,
    internal, windy, pixie, textboxes, perf,
    layout, common, nodes

type Paint = schema.Paint

var
  layer*: Image
  layers: seq[Image]
  maskLayer*: Image

proc newImage(w, h: int): Image {.measure.} =
  pixie.newImage(w, h)

proc draw(a, b: Image) {.measure.} =
  pixie.draw(a, b)

proc computeIntBounds*(node: Node, mat: Mat3, withChildren=false): Rect {.measure.} =
  ## Compute self bounds of a given node.

  # Generate the geometry.
  if node.kind == TextNode:
    #node.genTextGeometry()
    node.computeArrangement()
    var bounds = node.arrangement.computeBounds(mat)
    return bounds.snapToPixels()
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
    of LayerBlur, BackgroundBlur:
      borderMinV = min(borderMinV, vec2(-effect.radius))
      borderMaxV = max(borderMaxV, vec2(effect.radius))
    of DropShadow, InnerShadow:
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

    var overlapsNode = false
    # Check all geometry for overlaps.
    if node.kind == TextNode:
      node.genHitTestGeometry()
    for geom in node.fillGeometry & node.strokeGeometry:
      if node.fills.len == 0 and node.strokes.len == 0:
        continue
      if geom.path.fillOverlaps(mousePos, mat, geom.windingRule):
        overlapsNode = true
        break

    if node.clipsContent:
      if not overlapsNode:
        return

    var overlapsChild = false
    # Visit all children first, if any of them overlaps this node overlaps too.
    for child in node.children.reverse:
      if child.visible:
        if child.visit(mat, mousePos, s):
          overlapsChild = true
          break

    if overlapsNode or overlapsChild:
      s.add(node)
      return true

  discard screenNode.visit(screenNode.transform().inverse(), mousePos, result)

proc toPixiePaint(paint: schema.Paint, node: Node): pixie.Paint =
  let paintKind = case paint.kind:
    of schema.pkSolid: SolidPaint
    of schema.pkImage: ImagePaint
    of schema.pkGradientLinear: LinearGradientPaint
    of schema.pkGradientRadial: RadialGradientPaint
    of schema.pkGradientAngular: AngularGradientPaint
    of schema.pkGradientDiamond: RadialGradientPaint

  result = newPaint(paintKind)
  result.opacity = paint.opacity
  for handle in paint.gradientHandlePositions:
    result.gradientHandlePositions.add(
      mat * (handle * node.size)
    )
  if result.kind == LinearGradientPaint:
    result.gradientHandlePositions.setLen(2)
  result.gradientStops = paint.gradientStops

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
    of FillScaleMode:
      let
        ratioW = image.width.float32 / node.size.x
        ratioH = image.height.float32 / node.size.y
        scale = min(ratioW, ratioH)
      let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
      result.draw(
        image,
        mat * translate(topRight) * scale(vec2(1/scale))
      )

    of FitScaleMode:
      let
        ratioW = image.width.float32 / node.size.x
        ratioH = image.height.float32 / node.size.y
        scale = max(ratioW, ratioH)
      let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
      result.draw(
        image,
        mat * translate(topRight) * scale(vec2(1/scale))
      )

    of StretchScaleMode: # Figma ui calls this "crop".
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

    of TileScaleMode:
      var x = 0.0
      while x < node.size.x:
        var y = 0.0
        while y < node.size.y:
          result.draw(
            image,
            mat * translate(vec2(x, y)) *
            scale(vec2(paint.scalingFactor, paint.scalingFactor))
          )
          y += image.height.float32 * paint.scalingFactor
        x += image.width.float32 * paint.scalingFactor

  of schema.PaintKind.pkGradientLinear:
    result.fillGradient(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientRadial:
    result.fillGradient(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientAngular:
    result.fillGradient(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientDiamond:
    result.fillGradient(paint.toPixiePaint(node))

proc drawPaint*(node: Node, paints: seq[Paint], geometries: seq[Geometry]) {.measure.} =

  echo "draw paint", node.path

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
      var paint = newPaint(SolidPaint)
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
    var mask = newImage(layer.width, layer.height)
    let paint = newPaint(SolidPaint)
    paint.color = color(1, 1, 1, 1)
    for geometry in geometries:
      mask.fillPath(
        geometry.path,
        paint,
        mat * geometry.mat,
        geometry.windingRule
      )
    for paint in paints:
      if not paint.visible or paint.opacity == 0:
        continue
      var fillImage = drawFill(node, paint)
      fillImage.draw(mask, blendMode = MaskBlend)
      layer.draw(fillImage, blendMode = paint.blendMode)

proc drawInnerShadowEffect*(effect: Effect, node: Node, fillMask: Image) {.measure.} =
  ## Draws the inner shadow.
  var shadow = newImage(fillMask.width, fillMask.height)
  shadow.draw(fillMask, translate(effect.offset), blendMode = OverwriteBlend)
  # Invert colors of the fill mask.
  shadow.invert()
  # Blur the inverted fill.
  shadow.blur(effect.radius, outOfBounds = color(1, 1, 1, 1))
  # Color the inverted blurred fill.
  var color = newImage(shadow.width, shadow.height)
  color.fill(effect.color.rgbx)
  color.draw(shadow, blendMode = MaskBlend)
  # Only have the shadow be on the fill.
  color.draw(fillMask, blendMode = MaskBlend)
  # Draw it back.
  layer.draw(color)

proc maskSelfImage*(node: Node): Image {.measure.} =
  ## Returns a self mask (used for clips-content).
  var mask = newImage(layer.width, layer.height)
  let paint = newPaint(SolidPaint)
  paint.color = color(1, 1, 1, 1)
  for geometry in node.fillGeometry:
    mask.fillPath(
      geometry.path,
      paint,
      mat * geometry.mat,
      geometry.windingRule
    )
  return mask

proc drawInnerShadow(node: Node) =
  for effect in node.effects:
    if effect.visible:
      if effect.kind == InnerShadow:
        drawInnerShadowEffect(effect, node, node.maskSelfImage())

proc drawGeometry*(node: Node) {.measure.} =
  if node.strokeGeometry.len == 0:
    # No stroke just fill.
    node.drawPaint(node.fills, node.fillGeometry)
  else:
    # Draw stroke depending on stroke align.
    case node.strokeAlign
    of InsideStroke:
      if node.fillGeometry.len == 0:
        node.drawPaint(node.strokes, node.strokeGeometry)

      else:
        # Deal with fill
        var fillLayer = layer
        node.drawPaint(node.fills, node.fillGeometry)
        # Deal with fill mask
        var fillMask = newImage(layer.width, layer.height)
        let paint = newPaint(SolidPaint)
        paint.color = color(1, 1, 1, 1)
        for geometry in node.fillGeometry:
          fillMask.fillPath(geometry.path, paint, mat, geometry.windingRule)
          node.drawInnerShadow()

        # Deal with stroke
        var strokeLayer = newImage(layer.width, layer.height)
        layer = strokeLayer
        node.drawPaint(node.strokes, node.strokeGeometry)
        layer = fillLayer
        strokeLayer.draw(fillMask, blendMode = MaskBlend)
        layer.draw(strokeLayer)

    of CenterStroke:
      node.drawPaint(node.fills, node.fillGeometry)
      node.drawInnerShadow()
      node.drawPaint(node.strokes, node.strokeGeometry)

    of OutsideStroke:
      # Deal with fill
      var fillLayer = layer
      node.drawPaint(node.fills, node.fillGeometry)
      node.drawInnerShadow()
      # Deal with fill mask
      var fillMask = newImage(layer.width, layer.height)
      let paint = newPaint(SolidPaint)
      paint.color = color(1, 1, 1, 1)
      for geometry in node.fillGeometry:
        fillMask.fillPath(geometry.path, paint, mat, geometry.windingRule)
      # Deal with stroke
      var strokeLayer = newImage(layer.width, layer.height)
      layer = strokeLayer
      node.drawPaint(node.strokes, node.strokeGeometry)
      layer = fillLayer
      strokeLayer.draw(fillMask, blendMode = SubtractMaskBlend)
      layer.draw(strokeLayer)

proc drawDropShadowEffect*(lowerLayer: Image, layer: Image, effect: Effect, node: Node) {.measure.} =
  ## Draws the drop shadow.
  var shadow = newImage(layer.width, layer.height)
  shadow.draw(layer, blendMode = OverwriteBlend)
  let shadow2 = shadow.shadow(
    effect.offset, effect.spread, effect.radius, effect.color.rgbx)
  lowerLayer.draw(shadow2)

proc drawBackgroundBlur*(lowerLayer: Image, effect: Effect) {.measure.} =
  var blurLayer = lowerLayer.copy() # Maybe collapse bg?
  var blurMask = layer.copy()
  blurMask.ceil()
  blurLayer.blur(effect.radius)
  blurLayer.draw(blurMask, blendMode = MaskBlend)
  blurLayer.draw(layer)
  layer = blurLayer


proc drawText*(node: Node) {.measure.} =
  ## Draws the text (including editing of text).

  node.computeArrangement()

  # Scroll inside the text box
  mat = mat * translate(-node.scrollPos)

  if rtl:
    mat = mat * scale(vec2(-1, 1)) * translate(vec2(-node.size.x, 0))

  if textBoxFocus == node:

    # TODO: Draw selection outline by using a parent focus variant?
    # layer.fillRect(node.pixelBox, rgbx(255, 0, 0, 255))

    # draw arrangement squares for debugging
    # block:
    #   var path = newPath()
    #   for rect in arrangement.selectionRects:
    #     path.rect(rect)
    #   layer.strokePath(path, color(1, 0, 0, 1), mat)

    # Draw the selection ranges.
    let selectionRegions = node.selectionRegions()
    if selectionRegions.len > 0:
      for selectionRegion in selectionRegions:
        var s = selectionRegion
        var path = newPath()
        path.rect(s)
        layer.fillPath(path, defaultTextBackgroundHighlightColor, mat)

    # Draw the typing cursor
    if selectionRegions.len == 0:
      var s = node.cursorRect()
      var path = newPath()
      path.rect(s)
      layer.fillPath(path, node.fills[0].color.rgbx, mat)

  ## Fills the text arrangement.
  layer.fillText(node.arrangement, mat)

proc drawNode*(node: Node, withChildren=true)

proc drawBooleanNode*(node: Node, blendMode: BlendMode) =
  let prevMat = mat
  mat = mat * node.transform()

  if node.children.len == 0:
    node.genFillGeometry()
    let paint = newPaint(SolidPaint)
    paint.color = color(1, 1, 1, 1)
    paint.blendMode = blendMode
    for geometry in node.fillGeometry:
      maskLayer.fillPath(
        geometry.path,
        paint,
        mat,
        geometry.windingRule
      )

  for i, child in node.children:
    let blendMode =
      if i == 0:
        NormalBlend
      else:
        case node.booleanOperation:
          of UnionOperation: NormalBlend
          of SubtractOperation: SubtractMaskBlend
          of IntersectOperation: MaskBlend
          of ExcludeOperation: ExcludeMaskBlend
    drawBooleanNode(child, blendMode)

  mat = prevMat

proc drawBoolean*(node: Node) {.measure.} =
  ## Draws boolean
  maskLayer = newImage(layer.width, layer.height)
  mat = mat * node.transform().inverse()
  drawBooleanNode(node, NormalBlend)
  for paint in node.fills:
    if not paint.visible or paint.opacity == 0:
      continue
    var fillImage = drawFill(node, paint)
    fillImage.draw(maskLayer, blendMode = MaskBlend)
    layer.draw(fillImage)

proc drawNodeInternal*(node: Node, withChildren=true) {.measure.} =

  if not node.visible or node.opacity == 0:
    return

  var hasMaskedChildren = false
  var needsLayer = false
  if node.opacity != 1.0:
    needsLayer = true
  if node.blendMode != NormalBlend:
    needsLayer = true
  if node.clipsContent:
    needsLayer = true
  if node.effects.len > 0:
    needsLayer = true
  for child in node.children:
    if child.isMask and child.visible:
      needsLayer = true
      hasMaskedChildren = true
      maskLayer = newImage(layer.width, layer.height)
      break

  if needsLayer:
    layers.add(layer)
    layer = newImage(layer.width, layer.height)

  if node.kind == TextNode:
    node.drawText()
  elif node.kind == BooleanOperationNode:
    node.drawBoolean()
  else:
    node.genFillGeometry()
    node.genStrokeGeometry()
    node.drawGeometry()

  if withChildren:
    if hasMaskedChildren:
      # Every mask creates its own pair of layer and mask layer.
      var maskLayers: seq[Image]

      for child in node.children:
        if child.isMask and child.visible:
          # A mask layer creates a new pair of layer and mask layer.s
          layers.add(layer)
          layer = newImage(layer.width, layer.height)
          drawNode(child)
          maskLayers.add(layer)
          layer = newImage(layer.width, layer.height)
        else:
          # Regular nodes are just drawn into current layer.
          drawNode(child)

      while maskLayers.len > 0:
        # Pop pair of layer and mask layer and apply them.
        let maskLayer = maskLayers.pop()
        layer.draw(maskLayer, blendMode = MaskBlend)
        layers[^1].draw(layer)
        layer = layers.pop()

    elif node.kind == BooleanOperationNode:
      discard
    else:
      for child in node.children:
        drawNode(child)

  if node.clipsContent:
    var mask = node.maskSelfImage()
    layer.draw(mask, blendMode = MaskBlend)

  if needsLayer:
    var lowerLayer = layers.pop()
    if node.opacity != 1.0:
      layer.applyOpacity(node.opacity)

    for effect in node.effects:
      if effect.visible:
        if effect.kind == DropShadow:
          lowerLayer.drawDropShadowEffect(layer, effect, node)
        if effect.kind == LayerBlur:
          layer.blur(effect.radius)
        if effect.kind == BackgroundBlur:
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
  size: IVec2,
  visible = true,
  style = Decorated
) =
  window = newWindow("loading..", size, visible=visible)
  window.style = style
