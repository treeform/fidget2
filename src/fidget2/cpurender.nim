import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie, textboxes

type Image = pixie.Image
type Paint = schema.Paint
type Font = pixie.Font

var
  layer*: Image
  layers: seq[Image]
  maskLayer*: Image

proc computeIntBounds*(node: Node, mat: Mat3, withChildren=false): Rect =
  ## Compute self bounds of a given node.
  var
    minV: Vec2
    maxV: Vec2
    first = true
  for geoms in [node.fillGeometry, node.strokeGeometry]:
    for geom in geoms:
      for shape in geom.path.commandsToShapes():
        for vec in shape:
          let v = mat * vec
          if first:
            minV = v
            maxV = v
            first = false
          else:
            minV.x = min(minV.x, v.x)
            minV.y = min(minV.y, v.y)
            maxV.x = max(maxV.x, v.x)
            maxV.y = max(maxV.y, v.y)

  minV = minV.floor
  maxV = maxV.ceil

  var borderMinV, borderMaxV: Vec2
  for effect in node.effects:
    if effect.kind == ekLayerBlur:
      borderMinV = min(borderMinV, vec2(-effect.radius))
      borderMaxV = max(borderMaxV, vec2(effect.radius))
    if effect.kind == ekDropShadow:
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

  result = rect(minV.x, minV.y, maxV.x - minV.x, maxV.y - minV.y)

  if withChildren:
    for child in node.children:
      result = result or child.computeIntBounds(
        mat * node.transform(),
        withChildren
      )

proc toPixiePaint(paint: schema.Paint, node: Node): pixie.Paint =
  let paintKind = case paint.kind:
    of schema.pkSolid: pixie.pkSolid
    of schema.pkImage: pixie.pkImage
    of schema.pkGradientLinear: pixie.pkGradientLinear
    of schema.pkGradientRadial: pixie.pkGradientRadial
    of schema.pkGradientAngular: pixie.pkGradientAngular
    of schema.pkGradientDiamond: pixie.pkGradientRadial

  result = pixie.Paint(kind: paintKind)
  for handle in paint.gradientHandlePositions:
    result.gradientHandlePositions.add(
      handle * node.absoluteBoundingBox.wh + mat.pos
    )
  if result.kind == pixie.pkGradientLinear:
    result.gradientHandlePositions.setLen(2)
  for stop in paint.gradientStops:
    var color = stop.color
    color.a = color.a * paint.opacity
    result.gradientStops.add(pixie.ColorStop(color: color.rgbx, position: stop.position))

proc drawFill(node: Node, paint: Paint): Image =
  ## Creates a fill image based on the paint.
  result = newImage(layer.width, layer.height)

  let nodeOffset =
    when defined(cpu):
      node.box.xy
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
      mat[2, 0] = nodeOffset.x + mat[2, 0] * node.absoluteBoundingBox.w
      mat[2, 1] = nodeOffset.y + mat[2, 1] * node.absoluteBoundingBox.h
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
          result.draw(image, nodeOffset + vec2(x, y))
          y += image.height.float32
        x += image.width.float32

  of schema.PaintKind.pkGradientLinear:
    result.fillGradientLinear(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientRadial:
    result.fillGradientRadial(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientAngular:
    result.fillGradientAngular(paint.toPixiePaint(node))
  of schema.PaintKind.pkGradientDiamond:
    result.fillGradientRadial(paint.toPixiePaint(node))

proc drawPaint*(node: Node, paints: seq[Paint], geometries: seq[Geometry]) =
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
      var paint = pixie.Paint(
        kind: pixie.PaintKind.pkSolid,
        color: color.rgbx,
        blendMode: paint.blendMode
      )
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

proc drawGeometry*(node: Node) =
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

proc drawInnerShadowEffect*(effect: Effect, node: Node, fillMask: Mask) =
  ## Draws the inner shadow.
  var shadow = fillMask.copy()
  if effect.offset != vec2(0, 0):
    shadow.shift(effect.offset)
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

proc drawDropShadowEffect*(lowerLayer: Image, layer: Image, effect: Effect, node: Node) =
  ## Draws the drop shadow.
  var shadow = newImage(layer.width, layer.height)
  shadow.draw(layer, blendMode = bmOverwrite)
  shadow = shadow.shadow(
    effect.offset, effect.spread, effect.radius, effect.color.rgbx)
  lowerLayer.draw(shadow)

proc maskSelfImage*(node: Node): Mask =
  ## Returns a self mask (used for clips-content).
  var mask = newMask(layer.width, layer.height)
  for geometry in node.fillGeometry:
    mask.fillPath(
      geometry.path,
      mat * geometry.mat,
      geometry.windingRule
    )
  return mask

proc drawText*(node: Node) =
  ## Draws the text (including editing of text).

  let hAlign = case node.style.textAlignHorizontal:
    of typography.Left: pixie.haLeft
    of typography.Center: pixie.haCenter
    of typography.Right: pixie.haRight

  let vAlign = case node.style.textAlignVertical:
    of typography.Top: pixie.vaTop
    of typography.Middle: pixie.vaMiddle
    of typography.Bottom: pixie.vaBottom

  var spans: seq[pixie.Span]
  if node.characterStyleOverrides.len > 0:
    # The 0th style is node default style:
    node.styleOverrideTable["0"] = node.style
    var prevStyle: int
    for i, styleKey in node.characterStyleOverrides:
      if i == 0 or node.characterStyleOverrides[i] != prevStyle:
        let style = node.styleOverrideTable[$styleKey]
        if style.fontFamily == "":
          style.fontFamily = node.style.fontFamily

        if style.fontPostScriptName == "":
          style.fontPostScriptName = style.fontFamily & "-Regular"

        var font = getFont(node.style.fontPostScriptName)

        if style.fontSize == 0:
          style.fontSize = node.style.fontSize
        font.size = style.fontSize

        if style.lineHeightUnit == "":
          style.lineHeightUnit = node.style.lineHeightUnit

        # TODO
        # if style.lineHeightUnit ==
        # print style.lineHeightPercentFontSize
        # if style.lineHeightPx == 0:
        #   style.lineHeightPx = node.style.lineHeightPx
        # font.lineHeight = style.lineHeightPx

        font.lineHeight = AutoLineHeight

        font.noKerningAdjustments = not(style.opentypeFlags.KERN != 0)

        if style.fills.len == 0:
          font.paint = pixie.Paint(kind: pixie.PaintKind.pkSolid, color: rgbx(0,0,0,255))
        else:
          font.paint = pixie.Paint(kind: pixie.PaintKind.pkSolid, color: style.fills[0].color.rgbx)

        spans.add(newSpan("", font))

      spans[^1].text.add(node.characters[i])
      prevStyle = styleKey

    # for span in spans:
    #   print "---"
    #   print span.text
    #   print span.font.typeface.filePath
    #   print span.font.paint.color
    #   print span.font.size
    #   print span.font.lineHeight

  else:

    if node.style.fontPostScriptName == "":
      node.style.fontPostScriptName = node.style.fontFamily & "-Regular"

    var font = getFont(node.style.fontPostScriptName)
    font.size = node.style.fontSize
    font.lineHeight = node.style.lineHeightPx

    # Set text params.
    var wrap = false
    if node.style.textAutoResize == tarHeight:
      wrap = true
    font.noKerningAdjustments = not(node.style.opentypeFlags.KERN != 0)

    font.textCase = case node.style.textCase:
      of typography.tcNormal: pixie.tcNormal
      of typography.tcUpper: pixie.tcUpper
      of typography.tcLower: pixie.tcLower
      of typography.tcTitle: pixie.tcTitle

    font.paint = pixie.Paint(kind: pixie.PaintKind.pkSolid, color: node.fills[0].color.rgbx)
    spans = @[newSpan(node.characters, font)]

  var arrangement = typeset(
    spans,
    bounds = node.size,
    # wrap = wrap
    hAlign = hAlign,
    vAlign = vAlign,
  )

  arrangementCache[node.id] = arrangement

  if textBoxFocus == node:
    # Don't recompute the layout twice,
    # Set the text layout to textBox layout.
    textBox.arrangement = arrangement

    # TODO: Draw selection outline by using a parent focus variant?
    # layer.fillRect(node.pixelBox, rgbx(255, 0, 0, 255))

    # Draw the selection ranges.
    for selectionRegion in textBox.selectionRegions():
      var s = selectionRegion
      var path: Path
      path.rect(s)
      layer.fillPath(path, defaultTextHighlightColor, mat)

    # Draw the typing cursor
    var s = textBox.cursorRect()
    var path: Path
    path.rect(s)
    layer.fillPath(path, node.fills[0].color.rgbx, mat)

  ## Fills the text arrangement.
  for spanIndex, (start, stop) in arrangement.spans:
    var font = arrangement.fonts[spanIndex]
    for runeIndex in start .. stop:
      var path = font.typeface.getGlyphPath(arrangement.runes[runeIndex])
      path.transform(
        translate(arrangement.positions[runeIndex]) *
        scale(vec2(font.scale))
      )

      var paint = font.paint
      if textBoxFocus == node:
        # If editing text and character is in selection range,
        # draw it white.
        let s = textBox.selection()
        if runeIndex >= s.a and runeIndex < s.b:
          paint.color = color(1, 1, 1, 1).rgbx

      layer.fillPath(path, paint, mat)

proc drawNode*(node: Node, withChildren=true)

proc drawBooleanNode*(node: Node, blendMode: BlendMode) =
  let prevMat = mat
  mat = mat * node.transform()

  if node.children.len == 0:
    node.genFillGeometry()
    for geometry in node.fillGeometry:
      var paint = pixie.Paint(kind: pixie.pkSolid)
      paint.color = rgbx(255, 255, 255, 255)
      paint.blendMode = blendMode
      maskLayer.fillPath(
        geometry.path,
        paint,
        mat,
        geometry.windingRule
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

proc drawBoolean*(node: Node) =
  ## Draws boolean
  maskLayer = newImage(layer.width, layer.height)
  mat = mat * node.transform().inverse()
  drawBooleanNode(node, bmNormal)
  for paint in node.fills:
    if not paint.visible or paint.opacity == 0:
      continue
    var fillImage = drawFill(node, paint)
    fillImage.draw(maskLayer, blendMode = bmMask)
    layer.draw(fillImage)

proc drawNodeInternal*(node: Node, withChildren=true) =

  if not node.visible or node.opacity == 0:
    return

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

  if node.kind == nkText:
    node.drawText()
  else:
    node.genFillGeometry()
    node.genStrokeGeometry()
    node.drawGeometry()

  for effect in node.effects:
    if effect.kind == ekInnerShadow:
      drawInnerShadowEffect(effect, node, node.maskSelfImage())
    if effect.kind == ekLayerBlur:
      layer.blur(effect.radius)

  if withChildren:
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

proc drawNode*(node: Node, withChildren=true) =

  let prevMat = mat
  mat = mat * node.transform()

  node.mat = mat
  node.pixelBox.xy = mat * vec2(0, 0)
  node.pixelBox.wh = node.box.wh

  node.drawNodeInternal(withChildren)

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

import staticglfw, winim

proc GetWin32Window*(window: Window): pointer {.cdecl,
  importc: "glfwGetWin32Window".}

proc drawToScreen*(node: Node) =

  var screen = drawCompleteFrame(node)

  # Draw image pixels onto glfw-win32-window without openGL
  let
    w = screen.width.int32
    h = screen.height.int32
    hwnd = cast[HWND](GetWin32Window(window))
    dc = GetDC(hwnd)
  var info = BITMAPINFO()
  info.bmiHeader.biBitCount = 32
  info.bmiHeader.biWidth = w
  info.bmiHeader.biHeight = h
  info.bmiHeader.biPlanes = 1
  info.bmiHeader.biSize = DWORD sizeof(BITMAPINFOHEADER)
  info.bmiHeader.biSizeImage = w * h * 4
  info.bmiHeader.biCompression = BI_RGB
  var bgrBuffer = newSeq[uint8](screen.data.len * 4)
  for i, c in screen.data:
    bgrBuffer[i*4+0] = c.b
    bgrBuffer[i*4+1] = c.g
    bgrBuffer[i*4+2] = c.r
  discard StretchDIBits(
    dc,
    0,
    h - 1,
    w,
    -h,
    0,
    0,
    w,
    h,
    bgrBuffer[0].addr,
    info,
    DIB_RGB_COLORS,
    SRCCOPY
  )
  discard ReleaseDC(hwnd, dc)
