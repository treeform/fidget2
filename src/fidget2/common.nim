import vmath, chroma, schema, staticglfw, typography, typography/textboxes,
    tables, print, loader, bumpy, pixie

export print

type Image = pixie.Image

## Common vars shared across renderers.
var
  # Window stuff.
  viewportSize*: Vec2
  window*: Window
  offscreen* = false
  windowResizable*: bool
  vSync*: bool
  framePos*: Vec2

  # Text edit.
  textBox*: TextBox
  textBoxFocus*: Node
  typefaceCache*: Table[string, Typeface]

  mat*: Mat3
  imageCache*: Table[string, Image]

proc transform*(node: Node): Mat3 =
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

proc genFillGeometry*(node: Node) =
  ## Either gets existing geometry (nkVector etc..)
  ## or generates it if (nkFrame, nkGroup...).
  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    node.fillGeometry = @[node.rectangleFillGeometry()]
  of nkText:
    node.fillGeometry = node.textFillGeometries()
  else:
    discard

proc genStrokeGeometry*(node: Node) =
  ## Either gets existing geometry (nkVector etc..)
  ## or generates it if (nkFrame, nkGroup...).
  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    node.strokeGeometry = @[node.rectangleStrokeGeometry()]
  else:
    discard
