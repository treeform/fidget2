import bumpy, chroma, loader, math, pixie, schema, tables, typography, vmath,
    common, staticglfw, pixie

type Image = pixie.Image

var
  screen: Image
  mat: Mat3

proc transform*(node: Node): Mat3 =
  ## Returns Mat3 transform of the node.
  result[0, 0] = node.relativeTransform[0][0]
  result[0, 1] = node.relativeTransform[1][0]
  result[0, 2] = 0

  result[1, 0] = node.relativeTransform[0][1]
  result[1, 1] = node.relativeTransform[1][1]
  result[1, 2] = 0

  result[2, 0] = node.relativeTransform[0][2]
  result[2, 1] = node.relativeTransform[1][2]
  result[2, 2] = 1

proc pos(mat: Mat3): Vec2 =
  result.x = mat[2*3+0]
  result.y = mat[2*3+1]

proc nodeRectFill(node: Node): Path =
  if node.cornerRadius > 0:
    # Rectangle with common corners.
    result.roundedRect(
      vec2(0, 0),
      node.size,
      nw = node.cornerRadius,
      ne = node.cornerRadius,
      se = node.cornerRadius,
      sw = node.cornerRadius
    )
  elif node.rectangleCornerRadii != nil:
    # Rectangle with different corners.
    result.roundedRect(
      vec2(0, 0),
      node.size,
      nw = node.rectangleCornerRadii[0],
      ne = node.rectangleCornerRadii[1],
      se = node.rectangleCornerRadii[2],
      sw = node.rectangleCornerRadii[3],
    )
  else:
    # Basic rectangle.
    result.rect(
      x = 0,
      y = 0,
      w = node.size.x,
      h = node.size.y,
    )

proc nodeRectStroke(node: Node): Path =
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
    path.roundedRect(
      vec2(x-outer, y-outer),
      vec2(w+outer*2, h+outer*2),
      r+outer, r+outer, r+outer, r+outer
    )
    path.roundedRect(
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
    path.roundedRect(
      vec2(x-outer, y-outer),
      vec2(w+outer*2, h+outer*2),
      nw+outer, ne+outer, se+outer, sw+outer
    )
    path.roundedRect(
      vec2(x+inner, y+inner),
      vec2(w-inner*2, h-inner*2),
      nw-inner, ne-inner, se-inner, sw-inner,
      clockwise = false
    )

  else:
    path.rect(
      vec2(x+inner, y+inner),
      vec2(w-inner*2, h-inner*2)
    )
    path.rect(
      vec2(x+inner, y+inner),
      vec2(w-inner*2, h-inner*2),
      clockwise = false
    )

proc drawNode(node: Node) =

  let prevMat = mat
  mat = mat * node.transform()

  case node.kind:
  of nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance:
    for paint in node.fills:
      # TODO: if there are multiple paints, create a mask instead.
      let fillColor = paint.color
      screen.fillPath(
        node.nodeRectFill(),
        fillColor.rgba,
        mat.pos,
        wrNonZero
      )

    for paint in node.strokes:
      # TODO: if there are multiple paints, create a mask instead.
      let strokeColor = paint.color
      screen.fillPath(
        node.nodeRectStroke,
        strokeColor.rgba,
        mat.pos,
        wrNonZero
      )

  of nkVector:

    for paint in node.fills:
      # TODO: if there are multiple paints, create a mask instead.
      let fillColor = paint.color
      for geometry in node.fillGeometry:
        screen.fillPath(
          geometry.path,
          fillColor.rgba,
          mat.pos,
          geometry.windingRule
        )

    for paint in node.strokes:
      # TODO: if there are multiple paints, create a mask instead.
      let strokeColor = paint.color
      for geometry in node.strokeGeometry:
        screen.fillPath(
          geometry.path,
          strokeColor.rgba,
          mat.pos,
          geometry.windingRule
        )

  else:
    discard

  for child in node.children:
    drawNode(child)

  mat = prevMat

proc drawCompleteFrame*(node: Node): pixie.Image =
  let
    w = node.absoluteBoundingBox.w.int
    h = node.absoluteBoundingBox.h.int

  screen = newImage(w, h)
  mat = mat3()
  var t = node.relativeTransform
  mat = mat * translate(vec2(-t[0][2], -t[1][2]))
  drawNode(node)

  return screen

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
