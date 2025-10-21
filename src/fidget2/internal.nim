import
  std/[options, os, tables, unicode, times],
  bumpy, chroma, pixie, pixie/fontformats/opentype, vmath, windy,
  common, loader, measure, schema

## Common vars shared across renderers.
var
  ## Cache of typefaces.
  typefaceCache*: Table[string, Typeface]
  ## Cache of images.
  imageCache*: Table[string, Image]
  fetchRequests*: Table[string, HttpRequestHandle]
  fetchResponses*: Table[string, HttpResponse]

  ## Current mat during the draw cycle.
  mat*: Mat3

  ## Node that is currently being hovered over.
  hoverNode*: Node

  running*: bool

  ## Sets Right-to-Left UI mode.
  rtl*: bool

  currentFigmaUrl*: string
  entryFramePath*: string

  ## Node that is focused and has the current text box.
  textBoxFocus*: Node

  ## Default text highlight color (blueish by default).
  defaultTextBackgroundHighlightColor* = rgbx(50, 150, 250, 255)
  defaultTextHighlightColor* = color(1, 1, 1, 1)

  ## Cursor blink duration in seconds.
  cursorBlinkDuration* = 0.530
  ## Current cursor blink state and timing.
  cursorBlinkTime*: float64
  ## Current cursor blink state.
  cursorVisible*: bool

proc resetCursorBlink*() =
  ## Resets cursor blink to visible state (called when typing).
  cursorBlinkTime = epochTime()
  cursorVisible = true

proc transform*(node: Node): Mat3 =
  ## Returns Mat3 transform of the node.
  result = translate(node.position)
  if node.flipHorizontal:
    result = result * scale(vec2(-1, 1))
  if node.flipVertical:
    result = result * scale(vec2(1, -1))
  if node.rotation != 0:
    result = result * rotate(node.rotation)
  if node.scale != vec2(1, 1):
    result = result * scale(node.scale)
  if node.parent != nil:
    result = translate(-node.parent.scrollPos) * result

iterator reverse*[T](a: seq[T]): T {.inline.} =
  ## Iterates over a sequence in reverse order.
  var i = a.len - 1
  while i > -1:
    yield a[i]
    dec i

iterator reversePairs*[T](a: seq[T]): (int, T) {.inline.} =
  ## Iterates over a sequence in reverse order with index.
  var i = a.len - 1
  while i > -1:
    yield (a.len - 1 - i, a[i])
    dec i

proc clamp*(v: Vec2, r: Rect): Vec2 =
  ## Returns a vec that stays in bounds of the rectangle.
  result = v
  if result.x < r.x: result.x = r.x
  if result.y < r.y: result.y = r.y
  if result.x > r.x + r.w: result.x = r.x + r.w
  if result.y > r.y + r.h: result.y = r.y + r.h

proc getFont*(fontName: string): Font =
  ## Gets a font from the cache or loads it from disk.
  if fontName notin typefaceCache:
    var typeface: Typeface
    if fileExists(userFontPath(fontName)):
      typeface = parseOtf(readFile(userFontPath(fontName)))
    else:
      typeface = parseOtf(readFile(figmaFontPath(fontName)))
    typeface.fallbacks.add readTypeface(figmaFontPath("NotoSansJP-Regular"))
    typefaceCache[fontName] = typeface
  newFont(typefaceCache[fontName])

proc rectangleFillGeometry(node: Node): Geometry =
  ## Creates a fill geometry from a rectangle-like node.
  result = Geometry()
  result.path = newPath()
  result.mat = mat3()
  result.windingRule = NonZero

  if node.cornerRadius > 0:
    # Rectangle with common corners.
    result.path.roundedRect(
      rect(0, 0, node.size.x, node.size.y),
      nw = node.cornerRadius,
      ne = node.cornerRadius,
      se = node.cornerRadius,
      sw = node.cornerRadius
    )
  elif node.rectangleCornerRadii != [0f, 0f, 0f, 0f]:
    # Rectangle with different corners.
    let radii = node.rectangleCornerRadii
    result.path.roundedRect(
      rect(0, 0, node.size.x, node.size.y),
      nw = radii[0],
      ne = radii[1],
      se = radii[2],
      sw = radii[3],
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
  ## Creates a stroke geometry from a rectangle-like node.
  result = Geometry()
  result.path = newPath()
  result.mat = mat3()
  result.windingRule = NonZero

  let
    x = 0.0
    y = 0.0
    w = node.size.x
    h = node.size.y
  var
    inner = 0.0
    outer = 0.0
  case node.strokeAlign
  of InsideStroke:
    inner = node.strokeWeight
  of OutsideStroke:
    outer = node.strokeWeight
  of CenterStroke:
    inner = node.strokeWeight / 2
    outer = node.strokeWeight / 2

  if node.cornerRadius > 0:
    # Rectangle with common corners.
    let
      r = node.cornerRadius
    result.path.roundedRect(
      rect(x-outer, y-outer, w+outer*2, h+outer*2),
      r+outer, r+outer, r+outer, r+outer
    )
    result.path.roundedRect(
      rect(x+inner, y+inner, w-inner*2, h-inner*2),
      r-inner, r-inner, r-inner, r-inner,
      clockwise = false
    )
  elif node.rectangleCornerRadii != [0f, 0f, 0f, 0f]:
    # Rectangle with different corners.
    let
      radii = node.rectangleCornerRadii
      nw = radii[0]
      ne = radii[1]
      se = radii[2]
      sw = radii[3]
    result.path.roundedRect(
      rect(x-outer, y-outer, w+outer*2, h+outer*2),
      nw+outer, ne+outer, se+outer, sw+outer
    )
    result.path.roundedRect(
      rect(x+inner, y+inner, w-inner*2, h-inner*2),
      nw-inner, ne-inner, se-inner, sw-inner,
      clockwise = false
    )
  else:
    result.path.rect(
      rect(x-outer, y-outer, w+outer*2, h+outer*2),
    )
    result.path.rect(
      rect(x+inner, y+inner, w-inner*2, h-inner*2),
      clockwise = false
    )

proc genFillGeometry*(node: Node) {.measure.} =
  ## Either gets existing geometry (VectorNode etc..)
  ## or generates it if (FrameNode, GroupNode...).
  case node.kind:
  of RectangleNode, FrameNode, GroupNode, ComponentNode, InstanceNode:
    node.fillGeometry = @[node.rectangleFillGeometry()]
  else:
    discard

proc genStrokeGeometry*(node: Node) {.measure.} =
  ## Either gets existing geometry (VectorNode etc..)
  ## or generates it if (FrameNode, GroupNode...).
  case node.kind:
  of RectangleNode, FrameNode, GroupNode, ComponentNode, InstanceNode:
    node.strokeGeometry = @[node.rectangleStrokeGeometry()]
  else:
    discard

proc genHitTestGeometry*(node: Node) {.measure.} =
  ## Generates geometry thats a simple rect over the node,
  ## no matter what kind of node it is.
  ## Used for simple mouse hit prediction
  var geom = Geometry()
  geom.path = newPath()
  geom.mat = mat3()
  geom.windingRule = NonZero
  # Basic rectangle.
  geom.path.rect(
    x = 0,
    y = 0,
    w = node.size.x,
    h = node.size.y,
  )
  node.fillGeometry = @[geom]

proc getFont*(style: TypeStyle, backup: TypeStyle = nil): Font {.measure.} =
  ## Gets a font from the cache or loads it from disk.
  var fontName = style.fontPostScriptName

  if backup != nil:
    if fontName == "" and backup.fontPostScriptName != "":
      fontName = backup.fontPostScriptName

  if fontName == "":
    # If font name is still blank fall back to fall back font.
    fontName = "NotoSansJP-Regular"

  let font = getFont(fontName)

  if style.fontSize != 0:
    font.size = style.fontSize
  elif backup != nil:
    font.size = backup.fontSize

  var lineStyle = style
  if style.lineHeightUnit.isNone and backup != nil:
    lineStyle = backup

  case lineStyle.lineHeightUnit.get()
  of PixelUnit:
    font.lineHeight = round(lineStyle.lineHeightPx)
  of FontSizePercentUnit:
    font.lineHeight = round(lineStyle.lineHeightPx)
  of IntrinsicPercentUnit:
    font.lineHeight = round(font.defaultLineHeight * lineStyle.lineHeightPercent / 100)

  font.noKerningAdjustments = not(style.opentypeFlags.KERN != 0)

  if style.textCase.isSome:
    font.textCase = style.textCase.get()
  elif backup != nil and backup.textCase.isSome:
    font.textCase = backup.textCase.get()

  return font

proc cursorWidth*(font: Font): float =
  ## Returns the width of the cursor.
  min(font.size / 12, 1)

proc selection*(node: Node): HSlice[int, int] =
  ## Returns the current selection from the node.
  result.a = min(node.cursor, node.selector)
  result.b = max(node.cursor, node.selector)


proc cutRunes(s: string, start, stop: int): string =
  ## Cuts runes from a string.
  for i, r in s.toRunes:
    if i >= stop:
      break
    if i >= start:
      result.add r.toUTF8()


proc modifySpans(spans: var seq[Span], slice: HSlice[int, int]): seq[Span] =
  ## Modifies spans.

  # TODO make this work for multiple spans.
  doAssert spans.len == 1

  for i, span in spans:
    let
      start = newSpan(span.text.cutRunes(0, slice.a), span.font)
      middle = newSpan(span.text.cutRunes(slice.a, slice.b), span.font)
      stop = newSpan(span.text.cutRunes(slice.b, span.text.len), span.font)

    middle.font = span.font.copy()
    result.add(middle)

    spans.delete(i)
    spans.insert(stop, i)
    spans.insert(middle, i)
    spans.insert(start, i)
    break

proc computeArrangement*(node: Node) {.measure.} =
  ## Computes the arrangement of a node.
  if node.arrangement != nil:
    return

  if node.characterStyleOverrides.len > 0:
    # The 0th style is node default style:
    node.spans.setLen(0)
    node.styleOverrideTable["0"] = node.style
    var previousStyle: int
    for i, styleKey in node.characterStyleOverrides:
      if i == 0 or node.characterStyleOverrides[i] != previousStyle:
        let style = node.styleOverrideTable[$styleKey]

        let font = getFont(style, node.style)

        var fillColor: Color
        if style.fills.len == 0:
          fillColor = node.fills[0].color
          fillColor.a = node.fills[0].opacity
        else:
          fillColor = style.fills[0].color
          fillColor.a = style.fills[0].opacity
        font.paint = fillColor.rgbx
        node.spans.add(newSpan("", font))

      node.spans[^1].text.add(node.characters[i])
      previousStyle = styleKey

  else:
    let font = getFont(node.style)
    font.paint = node.fills[0].color.rgbx
    node.spans = @[newSpan(node.characters, font)]

  let wrap =
    if node.singleline:
      # Single-line text boxes should never wrap.
      false
    else:
      case node.style.textAutoResize:
        of FixedTextResize, HeightTextResize: true
        of WidthAndHeightTextResize: false

  if textBoxFocus == node:
    # If node is being editing we might have to add highlight or ime string.
    let selection = node.selection()
    if selection.a != selection.b:
      for span in node.spans.modifySpans(node.selection()):
        span.font.paint = defaultTextHighlightColor

    elif window.imeCompositionString != "":
      let imeSlice = HSlice[int, int](a: node.cursor, b: node.cursor)
      for span in node.spans.modifySpans(imeSlice):
        span.font.underline = true
        span.text = window.imeCompositionString

    if node.spans.len == 1 and node.spans[0].text.len == 0:
      # When the text has nothing in it "", a bunch of things become 0.
      # To prevent this insert a fake space " ".
      node.spans[0].text = " "

  let bounds =
    if node.singleline:
      # Single-line don't have bounds in the X direction.
      vec2(0, node.size.y)
    else:
      node.size

  node.arrangement = typeset(
    node.spans,
    bounds = bounds,
    wrap = wrap,
    hAlign = node.style.textAlignHorizontal,
    vAlign = node.style.textAlignVertical,
  )

  if node.style.leadingTrim == CapHeight:
    # Apply leading trim to the arrangement.
    let
      font = node.spans[0].font
      ascent = font.typeface.ascent
      capHeight = font.typeface.capHeight
      leadingTrim = (ascent - capHeight) * font.scale()
    for i in 0 ..< node.arrangement.positions.len:
      node.arrangement.positions[i].y -= leadingTrim
      node.arrangement.selectionRects[i].y -= leadingTrim

proc font*(node: Node): Font =
  ## Gets the font of a node.
  node.computeArrangement()
  if node.spans.len > 0:
    node.spans[0].font
  else:
    node.style.getFont()

proc genTextGeometry*(node: Node) {.measure.} =
  ## Generates text bounds geometry, can be more or less then
  ## nodes hit area. Effected by internal scroll.
  var geom = Geometry()
  geom.path = newPath()
  geom.mat = mat3()
  geom.windingRule = NonZero

  node.computeArrangement()
  let bounds = node.arrangement.layoutBounds()
  # Basic rectangle.
  geom.path.rect(
    x = -node.scrollPos.x,
    y = -node.scrollPos.y,
    w = bounds.x + node.font.cursorWidth,
    h = bounds.y,
  )
  node.fillGeometry = @[geom]

proc computeScrollBounds*(node: Node): Rect =
  ## Computes the scroll bounds of a node.
  if node.kind != TextNode:
    for child in node.children:
      result = result or rect(child.position, child.size)
  else:
    node.computeArrangement()
    result.wh = node.arrangement.layoutBounds()
  result.h = max(0, result.h - node.size.y)

proc overlaps*(node: Node, mouse: Vec2): bool =
  ## Does the mouse overlap the node?
  # Generates the geometry.
  if node.kind == TextNode:
    node.genHitTestGeometry()
  else:
    node.genFillGeometry()
    node.genStrokeGeometry()

  for geom in node.fillGeometry:
    if geom.path.fillOverlaps(mouse, node.mat):
      return true
  for geom in node.strokeGeometry:
    if geom.path.strokeOverlaps(mouse, node.mat, strokeWidth=node.strokeWeight):
      return true
