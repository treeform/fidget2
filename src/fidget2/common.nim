import vmath, chroma, schema, staticglfw, textboxes,
    tables, print, loader, bumpy, pixie, options,
    pixie/fontformats/opentype, print, puppy, perf

export print

type Image = pixie.Image

## Common vars shared across renderers.
var
  ## Window stuff.
  viewportSize*: Vec2 = vec2(800, 600)
  ## GLFW Window.
  window*: Window
  ## Is the app running offscreen.
  offscreen* = false
  ## Can this app be resized by the user.
  windowResizable*: bool
  ## Is the vsync enabled.
  vSync*: bool = true

  ## Text box object
  ## (only single text box object exists for active text box).
  textBox*: TextBox
  ## Nodes that is focused and has the current text box.
  textBoxFocus*: Node
  ## Default text highlight color (blueish by default).
  defaultTextHighlightColor* = rgbx(50, 150, 250, 255)

  ## Cache of typefaces.
  typefaceCache*: Table[string, Typeface]
  ## Cache of images.
  imageCache*: Table[string, Image]
  ## Cache of text arguments.
  arrangementCache*: Table[string, Arrangement]

  ## Current mat during the draw cycle.
  mat*: Mat3

  ## Node that currently is being hovered over.
  hoverNode*: Node

  fullscreen* = false
  running*, focused*, minimized*: bool
  windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
  windowSize*: Vec2        ## Screen coordinates
  windowFrame*: Vec2       ## Pixel coordinates
  dpi*: float32
  pixelRatio*: float32     ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32     ## Pixel multiplier user wants on the UI
  frameNum*: int

proc transform*(node: Node): Mat3 =
  ## Returns Mat3 transform of the node.
  result = translate(node.position) * rotate(node.rotation)
  if node.flipHorizontal:
    result = result * scale(vec2(-1, 1))
  if node.flipVertical:
    result = result * scale(vec2(1, -1))

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

proc getFont*(fontName: string): Font =
  if fontName notin typefaceCache:
    typefaceCache[fontName] = readTypeface(figmaFontPath(fontName))
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
  elif node.rectangleCornerRadii.isSome:
    # Rectangle with different corners.
    let radii = node.rectangleCornerRadii.get()
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
  elif node.rectangleCornerRadii.isSome:
    # Rectangle with different corners.
    let
      radii = node.rectangleCornerRadii.get()
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

proc genHitRectGeometry*(node: Node) {.measure.} =
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

proc getFont(style: TypeStyle, backup: TypeStyle = nil): Font =
  ## Get the font!

  var fontName = style.fontPostScriptName

  if backup != nil:
    if fontName == "" and backup.fontFamily != "":
      fontName = backup.fontPostScriptName

  var font = getFont(fontName)

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

proc computeArrangement*(node: Node): Arrangement {.measure.} =
  var spans: seq[pixie.Span]
  if node.characterStyleOverrides.len > 0:
    # The 0th style is node default style:
    node.styleOverrideTable["0"] = node.style
    var prevStyle: int
    for i, styleKey in node.characterStyleOverrides:
      if i == 0 or node.characterStyleOverrides[i] != prevStyle:
        let style = node.styleOverrideTable[$styleKey]

        var font = getFont(style, node.style)

        var fillColor: Color
        if style.fills.len == 0:
          fillColor = node.fills[0].color
          fillColor.a = node.fills[0].opacity
        else:
          fillColor = style.fills[0].color
          fillColor.a = style.fills[0].opacity
        font.paint = fillColor.rgbx
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
    var font = getFont(node.style)
    font.paint = node.fills[0].color.rgbx
    spans = @[newSpan(node.characters, font)]

  var wrap =
    case node.style.textAutoResize:
      of tarFixed, tarHeight: true
      of tarWidthAndHeight: false

  var arrangement = typeset(
    spans,
    bounds = node.size,
    wrap = wrap,
    hAlign = node.style.textAlignHorizontal,
    vAlign = node.style.textAlignVertical,
  )
  #arrangementCache[node.id] = arrangement

  return arrangement
