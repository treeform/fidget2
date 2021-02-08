
import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common

const
  white = rgba(255, 255, 255, 255)

var
  screen*: Image
  maskStack: seq[(Node, Image)]
  nodeStack: seq[Node]
  parentNode: Node
  imageCache: Table[string, Image]

proc drawNodeInternal*(node: Node)
proc drawNodeScreen*(node: Node)
proc drawNodeScreenSimple*(node: Node)
proc selfAndChildrenMask*(node: Node): Image

proc drawChildren(node: Node) =
  parentNode = node
  nodeStack.add(node)

  # Draw regular children:
  for child in node.children:
    drawNodeInternal(child)

  discard nodeStack.pop()
  if nodeStack.len > 0:
    parentNode = nodeStack[^1]

proc gradientPut(effects: Image, x, y: int, a: float32, paint: Paint) =
  var
    index = -1
  for i, stop in paint.gradientStops:
    if stop.position < a:
      index = i
    if stop.position > a:
      break
  var color: Color
  if index == -1:
    # first stop solid
    color = paint.gradientStops[0].color
  elif index + 1 >= paint.gradientStops.len:
    # last stop solid
    color = paint.gradientStops[index].color
  else:
    let
      gs1 = paint.gradientStops[index]
      gs2 = paint.gradientStops[index+1]
    color = mix(
      gs1.color,
      gs2.color,
      (a - gs1.position) / (gs2.position - gs1.position)
    )
  effects.setRgbaUnsafe(x, y, color.rgba)

proc applyPaint(
  mask: Image,
  paint: Paint,
  node: Node,
  mat: Mat3,
  paintNum: int,
  applyMask = true
) =

  if not paint.visible:
    return

  if mask == nil:
    return

  let pos = vec2(mat[2, 0], mat[2, 1])

  proc toImageSpace(handle: Vec2): Vec2 =
    vec2(
      handle.x * node.absoluteBoundingBox.w + pos.x,
      handle.y * node.absoluteBoundingBox.h + pos.y,
    )

  proc toLineSpace(at, to, point: Vec2): float32 =
    let
      d = to - at
      det = d.x*d.x + d.y*d.y
    return (d.y*(point.y-at.y)+d.x*(point.x-at.x))/det

  var effects = newImage(mask.width, mask.height)

  case paint.kind
  of pkImage:
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
      effects.draw(
        image,
        mat * translate(topRight) * scale(vec2(1/scale))
      )

    of smFit:
      let
        ratioW = image.width.float32 / node.size.x
        ratioH = image.height.float32 / node.size.y
        scale = max(ratioW, ratioH)
      let topRight = node.size / 2 - vec2(image.width/2, image.height/2) / scale
      effects.draw(
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
      mat[2, 0] = pos.x + mat[2, 0] * node.absoluteBoundingBox.w
      mat[2, 1] = pos.y + mat[2, 1] * node.absoluteBoundingBox.h
      let
        ratioW = image.width.float32 / node.absoluteBoundingBox.w
        ratioH = image.height.float32 / node.absoluteBoundingBox.h
        scale = min(ratioW, ratioH)
      mat = mat * scale(vec2(1/scale))
      effects.draw(image, mat)

    of smTile:
      image = image.resize(
        int(image.width.float32 * paint.scalingFactor),
        int(image.height.float32 * paint.scalingFactor))
      var x = 0.0
      while x < node.absoluteBoundingBox.w:
        var y = 0.0
        while y < node.absoluteBoundingBox.h:
          effects.draw(image, vec2(x, y))
          y += image.height.float32
        x += image.width.float32

  of pkGradientLinear:
    let
      at = paint.gradientHandlePositions[0].toImageSpace()
      to = paint.gradientHandlePositions[1].toImageSpace()
    for y in 0 ..< effects.height:
      for x in 0 ..< effects.width:
        let xy = vec2(x.float32, y.float32)
        let a = toLineSpace(at, to, xy)
        effects.gradientPut(x, y, a, paint)

  of pkGradientRadial:
    let
      at = paint.gradientHandlePositions[0].toImageSpace()
      to = paint.gradientHandlePositions[1].toImageSpace()
      distance = dist(at, to)
    for y in 0 ..< effects.height:
      for x in 0 ..< effects.width:
        let xy = vec2(x.float32, y.float32)
        let a = (at - xy).length() / distance
        effects.gradientPut(x, y, a, paint)

  of pkGradientAngular:
    let
      at = paint.gradientHandlePositions[0].toImageSpace()
      to = paint.gradientHandlePositions[1].toImageSpace()
      gradientAngle = normalize(to - at).angle().fixAngle()
    for y in 0 ..< effects.height:
      for x in 0 ..< effects.width:
        let
          xy = vec2(x.float32, y.float32)
          angle = normalize(xy - at).angle()
          a = (angle + gradientAngle + PI/2).fixAngle() / 2 / PI + 0.5
        effects.gradientPut(x, y, a, paint)

  of pkGradientDiamond:
    # TODO: implement GRADIENT_DIAMOND, now will just do GRADIENT_RADIAL
    let
      at = paint.gradientHandlePositions[0].toImageSpace()
      to = paint.gradientHandlePositions[1].toImageSpace()
      distance = dist(at, to)
    for y in 0 ..< effects.height:
      for x in 0 ..< effects.width:
        let xy = vec2(x.float32, y.float32)
        let a = (at - xy).length() / distance
        effects.gradientPut(x, y, a, paint)

  of pkSolid:
    var color = paint.color
    effects.fill(color.rgba)

  ## Apply opacity
  if paint.opacity != 1.0:
    var opacity = newImage(effects.width, effects.height)
    opacity.fill(color(0, 0, 0, paint.opacity).rgba)
    effects.draw(opacity, blendMode = bmMask)

  # Optimization: if mask it simple, skip mask!
  if applyMask:
    effects.draw(mask, blendMode = bmMask)
  # else:
  #   echo "skip mask!"

  # Optimization: if its the first paint and blend mode is normal,
  # pixels are just the effects.
  if paint.blendMode == bmNormal and paintNum == 0:
    node.pixels = effects
  else:
    node.pixels.draw(effects, blendMode = paint.blendMode)

proc applyDropShadowEffect(effect: Effect, node: Node) =
  ## Draws the drop shadow.
  var shadow = newImage(node.pixelBox.w.int, node.pixelBox.h.int)
  shadow.draw(node.selfAndChildrenMask(), -node.pixelBox.xy, bmOverwrite)
  shadow = shadow.shadow(
    effect.offset, effect.spread, effect.radius, effect.color.rgba)
  shadow.draw(node.pixels)
  node.pixels = shadow

proc applyInnerShadowEffect(effect: Effect, node: Node, fillMask: Image) =
  ## Draws the inner shadow.
  var shadow = fillMask.copy()
  # Invert colors of the fill mask.
  shadow.invert()
  # Blur the inverted fill.
  shadow.blurAlpha(effect.radius)
  # Color the inverted blurred fill.
  var color = newImage(shadow.width, shadow.height)
  color.fill(effect.color.rgba)
  color.draw(shadow, blendMode = bmMask)
  # Only have the shadow be on the fill.
  color.draw(fillMask, blendMode = bmMask)
  # Draw it back.
  node.pixels.draw(color)

proc roundRect(path: var Path, x, y, w, h, nw, ne, se, sw: float32) =
  ## Draw a round rectangle with different radius corners.
  let
    maxRaidus = min(w/2, h/2)
    nw = min(nw, maxRaidus)
    ne = min(ne, maxRaidus)
    se = min(se, maxRaidus)
    sw = min(sw, maxRaidus)
  path.moveTo(x+nw, y)
  path.arcTo(x+w, y, x+w, y+h, ne)
  path.arcTo(x+w, y+h, x, y+h, se)
  path.arcTo(x, y+h, x, y, sw)
  path.arcTo(x, y, x+w, y, nw)
  path.closePath()

proc roundRectRev(path: var Path, x, y, w, h, nw, ne, se, sw: float32) =
  ## Same as roundRect but in reverse order so that you can cut out a hole.
  let
    maxRaidus = min(w/2, h/2)
    nw = min(nw, maxRaidus)
    ne = min(ne, maxRaidus)
    se = min(se, maxRaidus)
    sw = min(sw, maxRaidus)
  path.moveTo(x+w+ne, y)
  path.arcTo(x, y, x, y+h, nw)
  path.arcTo(x, y+h, x+w, y+h, sw)
  path.arcTo(x+w, y+h, x+w, y, se)
  path.arcTo(x+w, y, x, y, ne)
  path.closePath()

const pixelBounds = true

proc computePixelBox*(node: Node) =

  when not pixelBounds:
    node.pixelBox.xy = vec2(0, 0)
    node.pixelBox.wh = vec2(screen.width.float32, screen.height.float32)
    return

  ## Computes pixel bounds.
  ## Takes into account width, height and shadow extent, and children.
  node.pixelBox.xy = node.absoluteBoundingBox.xy + framePos
  node.pixelBox.wh = node.absoluteBoundingBox.wh

  var s = 0.0

  # Takes stroke into account:
  if node.strokes.len > 0:
    s = max(s, node.strokeWeight)

  # Take drop shadow into account:
  for effect in node.effects:
    if effect.kind in {ekDropShadow, ekInnerShadow, ekLayerBlur}:
      # Note: INNER_SHADOW needs just as much area around as drop shadow
      # because it needs to blur in.
      s = max(
        s,
        effect.radius +
        effect.spread +
        abs(effect.offset.x) +
        abs(effect.offset.y)
      )

  node.pixelBox.xy = node.pixelBox.xy - vec2(s, s)
  node.pixelBox.wh = node.pixelBox.wh + vec2(s, s) * 2

  # Take children into account:
  for child in node.children:
    child.computePixelBox()

    if not node.clipsContent:
      # TODO: clips content should still respect shadows.
      node.pixelBox = node.pixelBox or child.pixelBox

  if node.pixelBox.x.fractional > 0:
    node.pixelBox.w += node.pixelBox.x.fractional
    node.pixelBox.x = node.pixelBox.x.floor

  if node.pixelBox.y.fractional > 0:
    node.pixelBox.h += node.pixelBox.y.fractional
    node.pixelBox.y = node.pixelBox.y.floor

  if node.pixelBox.w.fractional > 0:
    node.pixelBox.w = node.pixelBox.w.ceil

  if node.pixelBox.h.fractional > 0:
    node.pixelBox.h = node.pixelBox.h.ceil

proc drawCompleteCpuFrame*(node: Node): Image =
  ## Draws full frame that is ready to be displayed.

  checkDirty(node)

  if not node.dirty and node.pixels != nil:
    return screen

  framePos = -node.absoluteBoundingBox.xy
  screen = newImage(
    node.absoluteBoundingBox.w.int,
    node.absoluteBoundingBox.h.int
  )

  drawNodeInternal(node)
  drawNodeScreenSimple(node)

  return screen

proc drawNodeInternal*(node: Node) =
  ## Draws a node.
  ## Note: Must be called inside drawCompleteFrame.

  if not node.visible or node.opacity == 0:
    return

  if node.pixels != nil and node.dirty == false:
    # Nothing to do, node.pixels contains the cached version.
    return

  node.computePixelBox()

  # Make sure node.pixels is there and is the right size:
  let
    w = node.pixelBox.w.int
    h = node.pixelBox.h.int

  node.pixels = newImage(w, h)

  var
    fillMask: Image
    strokeMask: Image

  var mat = mat3()
  for i, node in nodeStack:
    var transform = node.relativeTransform.mat3()
    if i == 0:
      # root node
      transform = mat3()
    mat = mat * transform

  if nodeStack.len != 0:
    mat = mat * node.relativeTransform.mat3()

  mat[2, 0] = mat[2, 0] - node.pixelBox.x
  mat[2, 1] = mat[2, 1] - node.pixelBox.y

  # var s = ""
  # for node in nodeStack:
  #   s.add(" ")
  # echo s, node.name, "|", node.pixelBox, "...", repr(node.transform()).strip()

  var applyMask = true

  case node.kind
  of nkDocument, nkCanvas, nkComponentSet:
    quit($node.kind & " can't be drawn.")

  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    if node.fills.len > 0:
      fillMask = newImage(w, h)
      var path: Path
      if node.cornerRadius > 0:
        # Rectangle with common corners.
        path.roundRect(
          x = 0,
          y = 0,
          w = node.size.x,
          h = node.size.y,
          nw = node.cornerRadius,
          ne = node.cornerRadius,
          se = node.cornerRadius,
          sw = node.cornerRadius
        )
      elif node.rectangleCornerRadii.len == 4:
        # Rectangle with different corners.
        path.roundRect(
          x = 0,
          y = 0,
          w = node.size.x,
          h = node.size.y,
          nw = node.rectangleCornerRadii[0],
          ne = node.rectangleCornerRadii[1],
          se = node.rectangleCornerRadii[2],
          sw = node.rectangleCornerRadii[3],
        )
      else:
        # Basic rectangle.
        if node.pixelBox.x == 0 and
          node.pixelBox.y == 0 and
          node.pixelBox.wh == node.size:
          applyMask = false

        if node.name == "Layout1":
          print node.name, node.size

        if applyMask:
          path.rect(
            x = 0,
            y = 0,
            w = node.size.x,
            h = node.size.y,
          )

      if applyMask:
        fillMask.fillPath(
          path,
          white,
          mat,
        )

    if node.strokes.len > 0:
      strokeMask = newImage(w, h)
      let
        x = 0.0
        y = 0.0
        w = node.size.x
        h = node.size.y
      var
        inner = 0.0
        outer = 0.0
        path: Path
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
        path.roundRect(
          x-outer, y-outer,
          w+outer*2, h+outer*2,
          r+outer, r+outer, r+outer, r+outer
        )
        path.roundRectRev(
          x+inner, y+inner,
          w-inner*2, h-inner*2,
          r-inner, r-inner, r-inner, r-inner
        )

      elif node.rectangleCornerRadii.len == 4:
        # Rectangle with different corners.
        let
          nw = node.rectangleCornerRadii[0]
          ne = node.rectangleCornerRadii[1]
          se = node.rectangleCornerRadii[2]
          sw = node.rectangleCornerRadii[3]
        path.roundRect(
          x-outer, y-outer,
          w+outer*2, h+outer*2,
          nw+outer, ne+outer, se+outer, sw+outer
        )
        path.roundRectRev(
          x+inner, y+inner,
          w-inner*2, h-inner*2,
          nw-inner, ne-inner, se-inner, sw-inner
        )

      else:
        path.moveTo(x-outer, y-outer)
        path.lineTo(x+w+outer, y-outer, )
        path.lineTo(x+w+outer, y+h+outer, )
        path.lineTo(x-outer, y+h+outer, )
        path.lineTo(x-outer, y-outer, )
        path.closePath()

        path.moveTo(x+inner, y+inner)
        path.lineTo(x+inner, y+h-inner)
        path.lineTo(x+w-inner, y+h-inner)
        path.lineTo(x+w-inner, y+inner)
        path.lineTo(x+inner, y+inner)
        path.closePath()

      strokeMask.fillPath(
        path,
        white,
        mat
      )

  of nkVector, nkStar, nkEllipse, nkLine, nkRegularPolygon:
    if node.fills.len > 0:
      fillMask = newImage(w, h)
      for geom in node.fillGeometry:
        fillMask.fillPath(
          geom.path,
          white,
          mat,
          geom.windingRule
        )

    if node.strokes.len > 0:
      strokeMask = newImage(w, h)
      for geom in node.strokeGeometry:
        strokeMask.fillPath(
          geom.path,
          white,
          mat,
          geom.windingRule
        )

  of nkText:

    let pos = vec2(mat[2, 0], mat[2, 1])

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
      text = node.characters,
      pos = pos,
      size = node.size,
      hAlign = node.style.textAlignHorizontal,
      vAlign = node.style.textAlignVertical,
      clip = false,
      wrap = wrap,
      kern = kern,
      textCase = node.style.textCase,
    )
    fillMask = newImage(w, h)
    fillMask.drawText(layout)

    # if node.strokes.len > 0:
    #   strokeMask = fillMask.outlineBorder2(node.strokeWeight.int)

  of nkBooleanOperation:
    drawChildren(node)

    fillMask = newImage(w, h)
    for i, child in node.children:
      let blendMode =
        if i == 0:
          bmNormal
        else:
          case node.booleanOperation
            of boSubtract: bmSubtractMask
            of boIntersect: bmIntersectMask
            of boExclude: bmExcludeMask
            of boUnion: bmNormal
      fillMask.draw(
        child.pixels,
        child.pixelBox.xy - node.pixelBox.xy,
        blendMode
      )

  var paintNum = 0
  for fill in node.fills:
    applyPaint(fillMask, fill, node, mat, paintNum, applyMask = applyMask)
    inc paintNum

  for stroke in node.strokes:
    applyPaint(strokeMask, stroke, node, mat, paintNum)
    inc paintNum

  for effect in node.effects:
    if effect.kind == ekInnerShadow:
      applyInnerShadowEffect(effect, node, fillMask)

  if node.children.len > 0:
    drawChildren(node)

  for effect in node.effects:
    if effect.kind == ekDropShadow:
      if node.pixels != nil:
        applyDropShadowEffect(effect, node)

  # Apply node.opacity to alpha
  if node.opacity != 1.0:
    node.pixels.applyOpacity(node.opacity)

  # node.dirty = false
  assert node.pixels != nil

  #node.pixels.writeFile("tmp/" & node.name & ".png")

proc selfAndChildrenMask(node: Node): Image =
  result = newImage(screen.width, screen.height)
  if node.pixels != nil:
    result.draw(
      node.pixels,
      node.pixelBox.xy,
      blendMode = bmNormal
    )
  if node.kind != nkBooleanOperation:
    for c in node.children:
      let childMask = selfAndChildrenMask(c)
      result.draw(
        childMask,
        blendMode = bmNormal
      )

proc nodeMergedMask(node: Node): (Vec2, Image) =
  ## Returns a mask of current node and its children.
  ## Used for shadows and background blurs.
  ## TODO return mask
  var boundingBox = node.pixelBox
  proc visitBounds(node: Node) =
    if node.pixels != nil:
      boundingBox = boundingBox or node.pixelBox
    if node.kind != nkBooleanOperation:
      for c in node.children:
        visitBounds(c)
  visitBounds(node)

  var image = newImage(boundingBox.w.int, boundingBox.h.int)
  proc drawInner(node: Node) =
    if node.pixels != nil:
      image.draw(
        node.pixels,
        node.pixelBox.xy - boundingBox.xy,
        blendMode = bmNormal
      )
    if node.kind != nkBooleanOperation:
      for c in node.children:
        drawInner(c)
  drawInner(node)

  return (boundingBox.xy, image)

proc nodeMerged(node: Node): (Vec2, Image) =
  ## Returns node and children merged.
  ## Used for layer blur.
  var boundingBox = node.pixelBox
  proc visitBounds(node: Node) =
    if node.pixels != nil:
      boundingBox = boundingBox or node.pixelBox
    if node.kind != nkBooleanOperation:
      for c in node.children:
        visitBounds(c)
  visitBounds(node)

  var image = newImage(boundingBox.w.int, boundingBox.h.int)
  proc drawInner(node: Node) =
    if node.pixels != nil:
      image.draw(
        node.pixels,
        node.pixelBox.xy - boundingBox.xy,
        blendMode = bmNormal
      )
    if node.kind != nkBooleanOperation:
      for c in node.children:
        drawInner(c)
  drawInner(node)

  return (boundingBox.xy, image)

proc drawNodeScreenSimple(node: Node) =

  var stopDraw = false

  for effect in node.effects:
    if effect.kind == ekLayerBlur:
      var (at, merged) = node.nodeMerged()
      merged.blur(effect.radius)
      screen.draw(
        merged,
        at
      )
      stopDraw = true
    if effect.kind == ekBackgroundBlur:
      let extraPx = effect.radius.ceil.int * 2
      var (at, mask) = node.nodeMergedMask()
      var blur = newImage(mask.width + extraPx * 2, mask.height + extraPx * 2)
      blur.draw(
        screen,
        -vec2(at.x - extraPx.float32, at.y - extraPx.float32),
        bmOverwrite
      )
      blur.blur(effect.radius)
      mask.sharpOpacity()
      blur.draw(
        mask,
        vec2(extraPx.float32, extraPx.float32),
        blendMode = bmIntersectMask
      )
      screen.draw(
        blur,
        at - vec2(extraPx.float32, extraPx.float32)
      )

  if stopDraw:
    return

  if node.pixels != nil:
    if node.isMask:
      var mask = node.selfAndChildrenMask()
      if maskStack.len > 0:
        mask = maskStack[0][1].copy()
        mask.draw(
          mask,
          blendMode = bmIntersectMask
        )
      maskStack.add((parentNode, mask))
    else:
      if maskStack.len > 0:
        var withMask = newImage(screen.width, screen.height)
        withMask.draw(
          node.pixels,
          node.pixelBox.xy,
          node.blendMode
        )
        withMask.draw(
          maskStack[0][1],
          blendMode = bmIntersectMask
        )
        screen.draw(
          withMask,
          blendMode = node.blendMode
        )
      else:
        screen.draw(
          node.pixels,
          node.pixelBox.xy,
          node.blendMode
        )
  if node.kind != nkBooleanOperation:
    parentNode = node
    nodeStack.add(node)

    for c in node.children:
      drawNodeScreenSimple(c)

    discard nodeStack.pop()
    if nodeStack.len > 0:
      parentNode = nodeStack[^1]

  while maskStack.len > 0 and maskStack[^1][0] == node:
    discard maskStack.pop()

type
  ScreenDrawRegion = object
    draw: bool
    x, y: int32
    w, h: int32
    image: Image
    blendMode: BlendMode
    maskUntil: int

proc drawNodeScreen(node: Node) =

  var regions = newSeq[ScreenDrawRegion]()

  proc drawNodeScreenRegion(node: Node) =
    var maskIndex = 0
    if node.pixels != nil:
      if node.isMask:
        maskIndex = regions.len
        #node.pixels = node.selfAndChildrenMask()

      regions.add(ScreenDrawRegion(
        x: node.pixelBox.x.int32,
        y: node.pixelBox.y.int32,
        w: node.pixels.width.int32,
        h: node.pixels.height.int32,
        image: node.pixels,
        blendMode: node.blendMode,
      ))

    if node.kind != nkBooleanOperation and not node.isMask:
      for c in node.children:
        drawNodeScreenRegion(c)

    if node.isMask:
      let currentIndex = regions.len
      regions[maskIndex].maskUntil = currentIndex

  drawNodeScreenRegion(node)

  for i, r in regions:
    echo i, ": ", r.x, ",", r.y, " ", r.w, "x", r.h, " ", r.blendMode, " m:", r.maskUntil

  var maskStack: seq[(uint8, int)]

  for y in 0 ..< screen.height:
    for region in regions.mitems:
      region.draw = (y.int32 >= region.y) and (y.int32 < region.y + region.h)

    for x in 0 ..< screen.width:

      maskStack.setLen(0)

      var rgba: ColorRGBA

      # reverse/early return when no blending
      # maybe optimization?
      # for r in countDown(regions.len - 1, 0):
      #   let region = regions[r]

      #   if region.draw and ((x.int32 >= region.x) and (x.int32 < region.x + region.w)):
      #     let
      #       atX = x - region.x
      #       atY = y - region.y
      #     let rgba2 = region.image.getRgbaUnsafe(atX, atY)
      #     rgba = mix2(region.blendMode, rgba2, rgba)
      #     if rgba.a == 255 and region.blendMode == bmNormal:
      #       break

      for regionIdx, region in regions:
        #if x == 100 and y == 100:
          #print region.maskUntil
        let
          atX = x - region.x.int
          atY = y - region.y.int

        if region.maskUntil > 0:
          var mask: uint8
          if region.draw and ((x.int32 >= region.x) and (x.int32 < region.x + region.w)):
            mask = region.image.getRgbaUnsafe(atX, atY).a
          maskStack.add((mask, region.maskUntil))

        elif region.draw and ((x.int32 >= region.x) and (x.int32 < region.x + region.w)):

          var rgba2 = region.image.getRgbaUnsafe(atX, atY)

          if maskStack.len > 0:
            #if x == 100 and y == 100:
            #  echo "masking!"
            rgba2.a = ((rgba2.a.int32 * maskStack[^1][0].int32) div 255).uint8

          rgba = region.blendMode.blender()(rgba, rgba2)

        #while maskStack[^1][1] < regionIdx:
          #echo "pop mask!"
        #  discard maskStack.pop()

        #if x == 100 and y == 100:
        #  print maskStack

      screen.setRgbaUnsafe(x, y, rgba)

import staticglfw, winim

proc GetWin32Window*(window: Window): pointer {.cdecl,
  importc: "glfwGetWin32Window".}

proc drawToScreen*(node: Node) =

  var screen = drawCompleteCpuFrame(node)

  let
    w = screen.width
    h = screen.height
    dataPtr = screen.data[0].addr

  # draw image pixels onto glfw-win32-window without openGL
  var hwnd = cast[HWND](GetWin32Window(window))
  var dc = GetDC(hwnd)
  var info = BITMAPINFO()
  info.bmiHeader.biBitCount = 32
  info.bmiHeader.biWidth = int32 w
  info.bmiHeader.biHeight = int32 h
  info.bmiHeader.biPlanes = 1
  info.bmiHeader.biSize = DWORD sizeof(BITMAPINFOHEADER)
  info.bmiHeader.biSizeImage = int32(w * h * 4)
  info.bmiHeader.biCompression = BI_RGB
  discard StretchDIBits(dc, 0, int32 h - 1, int32 w, int32 -h, 0, 0, int32 w,
      int32 h, dataPtr, info, DIB_RGB_COLORS, SRCCOPY)
  discard ReleaseDC(hwnd, dc)

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
