import vmath, chroma, schema, windy,
    tables, print, loader, bumpy, pixie, options,
    pixie/fontformats/opentype, puppy, perf, unicode

export print

## Common vars shared across renderers.
var
  ## Window stuff.
  viewportSize*: Vec2 = vec2(800, 600)
  window*: Window

  ## Cache of typefaces.
  typefaceCache*: Table[string, Typeface]
  ## Cache of images.
  imageCache*: Table[string, Image]

  ## Current mat during the draw cycle.
  mat*: Mat3

  ## Node that currently is being hovered over.
  hoverNode*: Node

  fullscreen* = false
  running*: bool

  rtl*: bool               ## Set Right-to-Left UI mode.

  ## Pixel multiplier user wants on the UI (used for for pixel indie games)
  pixelScale*: float32 = 1.0
  frameNum*: int

  currentFigmaUrl*: string
  entryFramePath*: string

  textImeEditLocation*: int
  textImeEditString*: string

  ## Nodes that is focused and has the current text box.
  textBoxFocus*: Node
  ## Default text highlight color (blueish by default).
  defaultTextBackgroundHighlightColor* = rgbx(50, 150, 250, 255)
  defaultTextHighlightColor* = color(1, 1, 1, 1)

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
  var i = a.len - 1
  while i > -1:
    yield a[i]
    dec i

iterator reversePairs*[T](a: seq[T]): (int, T) {.inline.} =
  var i = a.len - 1
  while i > -1:
    yield (a.len - 1 - i, a[i])
    dec i

proc clamp*(v: Vec2, r: Rect): Vec2 =
  ## Makes returns a vec that stays in bounds of the rectangle.
  result = v
  if result.x < r.x: result.x = r.x
  if result.y < r.y: result.y = r.y
  if result.x > r.x + r.w: result.x = r.x + r.w
  if result.y > r.y + r.h: result.y = r.y + r.h

proc getFont*(fontName: string): Font =
  if fontName notin typefaceCache:
    let typeface = parseOtf(readFile(figmaFontPath(fontName)))
    typeface.fallbacks.add readTypeface(figmaFontPath("NotoSansJP-Regular"))
    typefaceCache[fontName] = typeface
  newFont(typefaceCache[fontName])

proc rectangleFillGeometry(node: Node): Geometry =
  ## Creates a fill geometry from a rectangle like node.
  result = Geometry()
  result.path = newPath()
  result.mat = mat3()
  result.windingRule = wrNonZero

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
  ## Creates a fill geometry from a rectangle like node.
  result = Geometry()
  result.path = newPath()
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
  ## Either gets existing geometry (nkVector etc..)
  ## or generates it if (nkFrame, nkGroup...).
  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    node.fillGeometry = @[node.rectangleFillGeometry()]
  else:
    discard

proc genStrokeGeometry*(node: Node) {.measure.} =
  ## Either gets existing geometry (nkVector etc..)
  ## or generates it if (nkFrame, nkGroup...).
  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
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
  geom.windingRule = wrNonZero
  # Basic rectangle.
  geom.path.rect(
    x = 0,
    y = 0,
    w = node.size.x,
    h = node.size.y,
  )
  node.fillGeometry = @[geom]

proc getFont*(style: TypeStyle, backup: TypeStyle = nil): Font {.measure.} =
  ## Get the font!

  var fontName = style.fontPostScriptName

  if backup != nil:
    if fontName == "" and backup.fontPostScriptName != "":
      fontName = backup.fontPostScriptName

  if fontName == "":
    # if font name is still blak fall back to fall back font
    fontName = "NotoSansJP-Regular"

  # print style
  # print backup
  # print fontName
  let font = getFont(fontName)

  if style.fontSize != 0:
    font.size = style.fontSize
  elif backup != nil:
    font.size = backup.fontSize

  var lineStyle = style
  if style.lineHeightUnit.isNone and backup != nil:
    lineStyle = backup

  case lineStyle.lineHeightUnit.get()
  of lhuPixels:
    font.lineHeight = round(lineStyle.lineHeightPx)
  of lhuFontSizePercent:
    font.lineHeight = round(lineStyle.lineHeightPx)
  of lhuIntrinsicPercent:
    font.lineHeight = round(font.defaultLineHeight * lineStyle.lineHeightPercent / 100)

  font.noKerningAdjustments = not(style.opentypeFlags.KERN != 0)

  if style.textCase.isSome:
    font.textCase = style.textCase.get()
  elif backup != nil and backup.textCase.isSome:
    font.textCase = backup.textCase.get()

  return font

proc cursorWidth*(font: Font): float =
  min(font.size / 12, 1)

proc selection*(node: Node): HSlice[int, int] =
  ## Returns current selection from.
  result.a = min(node.cursor, node.selector)
  result.b = max(node.cursor, node.selector)

proc copy*[T](f: T): T =
  result = T()
  result[] = f[]

proc cutRunes(s: string, start, stop: int): string =
  for i, r in s.toRunes:
    if i >= stop:
      break
    if i >= start:
      result.add r.toUTF8()


proc modifySpans(spans: var seq[Span], slice: HSlice[int, int]): seq[Span] =

  # TODO make this work for multiple spans.
  doAssert spans.len == 1

  var at = 0
  for idx, span in spans:
    let to = at + span.text.len
    let
      start = newSpan(span.text.cutRunes(0, slice.a), span.font)
      middle = newSpan(span.text.cutRunes(slice.a, slice.b), span.font)
      stop = newSpan(span.text.cutRunes(slice.b, span.text.len), span.font)

    middle.font = span.font.copy()
    result.add(middle)

    spans.delete(idx)
    spans.insert(stop, idx)
    spans.insert(middle, idx)
    spans.insert(start, idx)
    break

proc computeArrangement*(node: Node) {.measure.} =

  if node.arrangement != nil:
    return

  if node.characterStyleOverrides.len > 0:
    # The 0th style is node default style:
    node.spans.setLen(0)
    node.styleOverrideTable["0"] = node.style
    var prevStyle: int
    for i, styleKey in node.characterStyleOverrides:
      if i == 0 or node.characterStyleOverrides[i] != prevStyle:
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
      prevStyle = styleKey

  else:
    let font = getFont(node.style)
    font.paint = node.fills[0].color.rgbx
    node.spans = @[newSpan(node.characters, font)]

  let wrap =
    case node.style.textAutoResize:
      of tarFixed, tarHeight: true
      of tarWidthAndHeight: false

  if textBoxFocus == node:
    # If node is being editing we might have to add highlight or ime string.
    let selSlice = node.selection()
    if selSlice.a != selSlice.b:
      for modSpan in node.spans.modifySpans(node.selection()):
        modSpan.font.paint = defaultTextHighlightColor

    elif textImeEditString != "":
      let imeSlice = HSlice[int, int](a: node.cursor, b: node.cursor)
      for modSpan in node.spans.modifySpans(imeSlice):
        modSpan.font.underline = true
        modSpan.text = textImeEditString

    if node.spans.len == 1 and node.spans[0].text.len == 0:
      # When the text has nothing in it "", a bunch of things become 0.
      # To prevent this insert a fake space " ".
      node.spans[0].text = " "

  # for span in node.spans:
  #   print "---"
  #   print span.text
  #   print span.font.typeface.filePath
  #   print span.font.paint.color
  #   print span.font.size
  #   print span.font.lineHeight

  node.arrangement = typeset(
    node.spans,
    bounds = node.size,
    wrap = wrap,
    hAlign = node.style.textAlignHorizontal,
    vAlign = node.style.textAlignVertical,
  )

  # proc similar(a, b: Arrangement): bool =
  #   if a == nil and b == nil: return true
  #   if a == nil: return false
  #   if b == nil: return false
  #   if a.lines != b.lines: return false
  #   if a.spans != b.spans: return false
  #   if a.runes != b.runes: return false
  #   if a.positions != b.positions: return false
  #   if a.selectionRects != b.selectionRects: return false

  # if node.arrangement.similar(prevArrangment):
  #   echo "BAD"
  #   #print node.runes == prevArrangment.runes
  #   # print node.dirty, prevArrangment != nil

proc font*(node: Node): Font =
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
  geom.windingRule = wrNonZero

  node.computeArrangement()
  let bounds = node.arrangement.computeBounds()
  # Basic rectangle.
  geom.path.rect(
    x = -node.scrollPos.x,
    y = -node.scrollPos.y,
    w = bounds.x + node.font.cursorWidth,
    h = bounds.y,
  )
  node.fillGeometry = @[geom]

proc computeScrollBounds*(node: Node): Rect =
  if node.kind != nkText:
    for child in node.children:
      result = result or rect(child.position, child.size)
  else:
    node.computeArrangement()
    result.wh = node.arrangement.computeBounds()
  result.h = max(0, result.h - node.size.y)

proc overlaps*(node: Node, mouse: Vec2): bool =
  ## Does the mouse overlap the node.

  # Generate the geometry.
  if node.kind == nkText:
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
