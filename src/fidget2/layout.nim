import
  pixie, vmath,
  internal, measure, schema

# Layout tries to match figma's layout engine.
# It is responsible for computing the layout of a node, both constraints and auto-layout.

proc fractional(v: Vec2): Vec2 =
  vec2(v.x.fractional, v.y.fractional)

proc computeTextBounds(node: INode): Vec2 {.measure.} =
  ## Computes the text bounds of a node.
  node.computeArrangement()
  result = node.arrangement.layoutBounds()

proc computeLayout*(parent, node: INode) {.measure.} =
  ## Computes constraints and auto-layout.

  doAssert not node.position.x.isNan
  doAssert not node.position.y.isNan

  let
    oldPosition = node.position
    oldSize = node.size

  for n in node.children:
    computeLayout(node, n)

  # Typeset text
  if node.kind == TextNode:
    case node.style.textAutoResize:
      of FixedTextResize:
        # Fixed sized text node.
        discard
      of HeightTextResize:
        # Text will grow down.
        let bounds = computeTextBounds(node)
        node.size.y = bounds.y
      of WidthAndHeightTextResize:
        # Text will grow down and wide.
        let bounds = computeTextBounds(node)
        node.size.x = bounds.x
        node.size.y = bounds.y

  # Auto-layout code.
  if node.layoutMode == VerticalLayout:

    if node.counterAxisSizingMode == AutoAxis:
      # Resize to fit elements tightly.
      var maxW = 0.0
      for n in node.children:
        if n.layoutAlign != StretchLayout:
          maxW = max(maxW, n.size.x)
      node.size.x = maxW + node.paddingLeft + node.paddingRight

    var
      first = true
      at: float32 = 0.0
    at += node.paddingTop
    for i, n in node.children:
      if n.visible == false:
        continue
      if first:
        first = false
      else:
        at += node.itemSpacing

      n.position.y = at

      at += n.size.y
    at += node.paddingBottom
    node.size.y = at

  if node.layoutMode == HorizontalLayout:
    if node.counterAxisSizingMode == AutoAxis:
      # Resize to fit elements tightly.
      var maxH = 0.0
      for n in node.children:
        if n.layoutAlign != StretchLayout:
          maxH = max(maxH, n.size.y)
      node.size.y = maxH + node.paddingTop + node.paddingBottom

    var
      first = true
      at: float32 = 0.0
    at += node.paddingLeft
    for i, n in node.children:
      if n.visible == false:
        continue
      if first:
        first = false
      else:
        at += node.itemSpacing

      n.position.x = at

      at += n.size.x
    at += node.paddingRight
    node.size.x = at

  # Constraints code.
  case node.constraints.horizontal:
    of MinConstraint: discard
    of MaxConstraint:
      let rightSpace = parent.origSize.x - node.origPosition.x
      node.position.x = parent.size.x - rightSpace
    of ScaleConstraint:
      doAssert parent.origSize.x != 0
      let xScale = parent.size.x / parent.origSize.x
      node.position.x = node.origPosition.x * xScale
      node.size.x = node.origSize.x * xScale
    of StretchConstraint:
      let rightSpace = parent.origSize.x - node.origSize.x
      node.size.x = parent.size.x - rightSpace
    of CenterConstraint:
      let offset = node.origPosition.x - round(parent.origSize.x / 2.0)
      node.position.x = round(parent.size.x / 2.0) + offset

  case node.constraints.vertical:
    of MinConstraint: discard
    of MaxConstraint:
      let bottomSpace = parent.origSize.y - node.origPosition.y
      node.position.y = parent.size.y - bottomSpace
    of ScaleConstraint:
      doAssert parent.origSize.y != 0
      let yScale = parent.size.y / parent.origSize.y
      node.position.y = node.origPosition.y * yScale
      node.size.y = node.origSize.y * yScale
    of StretchConstraint:
      let bottomSpace = parent.origSize.y - node.origSize.y
      node.size.y = parent.size.y - bottomSpace
    of CenterConstraint:
      let offset = node.origPosition.y - round(parent.origSize.y / 2.0)
      node.position.y = round(parent.size.y / 2.0) + offset

  # Fix scroll position when resizing.
  if node.kind == TextNode or node.overflowDirection == VerticalScrolling:
    let bounds = node.computeScrollBounds()
    node.scrollPos = clamp(node.scrollPos, bounds)

  doAssert not node.position.x.isNan
  doAssert not node.position.y.isNan

  if oldPosition.fractional != node.position.fractional or oldSize != node.size:
    echo "Layout made node dirty: ", node.path
    node.dirty = true
  elif oldPosition != node.position:
    echo "Only the integer part of the position changed: ", node.path
    if node.path == "/UI/Main/GlobalHeader/ShareButton":
      echo "  Position: ", node.position
      echo "  Old position: ", oldPosition
    node.pixelBox.xy = node.position
