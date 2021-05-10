import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie, textboxes

type Image = pixie.Image
type Paint = schema.Paint
type Font = pixie.Font

var
  layer*: Image
  layers: seq[Image]

proc drawFill(node: Node, paint: Paint): Image =
  ## Creates a fill image based on the paint.

  proc toImageSpace(handle: Vec2): Vec2 =
    vec2(
      handle.x * node.absoluteBoundingBox.w + node.box.x,
      handle.y * node.absoluteBoundingBox.h + node.box.y,
    )

  proc gradientAdjust(stops: seq[schema.ColorStop], alpha: float32): seq[pixie.ColorStop] =
    for stop in stops:
      var color = stop.color
      color.a = color.a * alpha
      result.add(pixie.ColorStop(color: color.rgbx, position: stop.position))

  result = newImage(layer.width, layer.height)
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

  of schema.PaintKind.pkGradientLinear:
    result.fillLinearGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

  of schema.PaintKind.pkGradientRadial:
    result.fillRadialGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientHandlePositions[2].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

  of schema.PaintKind.pkGradientAngular:
    result.fillAngularGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientHandlePositions[2].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

  of schema.PaintKind.pkGradientDiamond:
    result.fillRadialGradient(
      paint.gradientHandlePositions[0].toImageSpace(),
      paint.gradientHandlePositions[1].toImageSpace(),
      paint.gradientHandlePositions[2].toImageSpace(),
      paint.gradientStops.gradientAdjust(paint.opacity)
    )

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
      layer.fillPath(
        geometry.path,
        color.rgbx,
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
  ## Returns a self mask (used for clips content).
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

  # Get the proper font.
  var font: Font
  if node.style.fontPostScriptName notin typefaceCache:
    if node.style.fontPostScriptName == "":
      node.style.fontPostScriptName = node.style.fontFamily & "-Regular"
    font = pixie.parseOtf(readFile(figmaFontPath(node.style.fontPostScriptName)))
    typefaceCache[node.style.fontPostScriptName] = font.typeface
  else:
    font = Font()
    font.typeface = typefaceCache[node.style.fontPostScriptName]
  font.size = node.style.fontSize
  font.lineHeight = node.style.lineHeightPx

  # Set text params.
  var wrap = false
  if node.style.textAutoResize == tarHeight:
    wrap = true
  let kern = node.style.opentypeFlags.KERN != 0

  # layer.fillText(
  #   font,
  #   node.characters,
  #   color.rgbx,
  #   mat
  # )

  let textCase = case node.style.textCase:
    of typography.tcNormal: pixie.tcNormal
    of typography.tcUpper: pixie.tcUpper
    of typography.tcLower: pixie.tcLower
    of typography.tcTitle: pixie.tcTitle

  let hAlign = case node.style.textAlignHorizontal:
    of typography.Left: pixie.haLeft
    of typography.Center: pixie.haCenter
    of typography.Right: pixie.haRight

  let vAlign = case node.style.textAlignVertical:
    of typography.Top: pixie.vaTop
    of typography.Middle: pixie.vaMiddle
    of typography.Bottom: pixie.vaBottom

  var arrangement = font.typeset(
    node.characters,
    #textCase = textCase,
    bounds = node.size,
    # wrap = wrap
    # kern = kern
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

  for i, rune in arrangement.runes:
    var
      selRect = arrangement.selectionRects[i]
      glyphPath = arrangement.getPath(i)
      glyphColor = node.fills[0].color

    if textBoxFocus == node:
      # If editing text and character is in selection range,
      # draw it white.
      let s = textBox.selection()
      if i >= s.a and i < s.b:
        glyphColor = color(1, 1, 1, 1)

    layer.fillPath(glyphPath, glyphColor, mat)
    var rectPath: Path

    # print selRect
    # rectPath.rect(selRect)
    # layer.strokePath(rectPath, rgba(255, 0, 0, 255), mat)


  # # Generate the layout.
  # var layout = font.typeset(
  #   text = if textBoxFocus == node:
  #       textBox.text
  #     else:
  #       node.characters,
  #   pos = vec2(0, 0),
  #   size = node.size,
  #   hAlign = node.style.textAlignHorizontal,
  #   vAlign = node.style.textAlignVertical,
  #   clip = false,
  #   wrap = wrap,
  #   kern = kern,
  #   textCase = node.style.textCase,
  # )
  # layoutCache[node.id] = layout

  # if textBoxFocus == node:
  #   # Don't recompute the layout twice,
  #   # Set the text layout to textBox layout.
  #   textBox.glyphs = layout

  #   # TODO: Draw selection outline by using a parent focus variant?
  #   # layer.fillRect(node.pixelBox, rgbx(255, 0, 0, 255))

  #   # Draw the selection ranges.
  #   for selectionRegion in textBox.selectionRegions():
  #     var s = selectionRegion
  #     var path: Path
  #     path.rect(s)
  #     layer.fillPath(path, defaultTextHighlightColor, mat)

  #   # Draw the typing cursor
  #   var s = textBox.cursorRect()
  #   var path: Path
  #   path.rect(s)
  #   layer.fillPath(path, node.fills[0].color.rgbx, mat)

  # for i, gpos in layout:
  #   # For every character in the layout draw it.
  #   var font = gpos.font

  #   if gpos.character in font.typeface.glyphs:
  #     var glyph = font.typeface.glyphs[gpos.character]
  #     glyph.makeReady(font)

  #     if glyph.path.commands.len == 0:
  #       continue

  #     let characterMat = translate(vec2(
  #       gpos.rect.x + gpos.subPixelShift,
  #       gpos.rect.y
  #     )) * scale(vec2(font.scale, -font.scale))

  #     # TODO: Better fill system?
  #     var color = node.fills[0].color

  #     if textBoxFocus == node:
  #       # If editing text and character is in selection range,
  #       # draw it white.
  #       let s = textBox.selection()
  #       if i >= s.a and i < s.b:
  #         color = color(1, 1, 1, 1)

  #     layer.fillPath(
  #       glyph.path,
  #       color.rgbx,
  #       mat * characterMat,
  #       wrNonZero,
  #       bmNormal
  #     )

proc drawNode*(node: Node, withChildren=true)

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
    node.drawPaint(node.fills, node.fillGeometry)
    node.genStrokeGeometry()
    node.drawPaint(node.strokes, node.strokeGeometry)

  for effect in node.effects:
    if effect.kind == ekInnerShadow:
      drawInnerShadowEffect(effect, node, node.maskSelfImage())

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
