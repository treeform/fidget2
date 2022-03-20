import bumpy, schema, vmath, internal, tables, pixie, perf

proc computeTextBounds(node: Node): Vec2 {.measure.} =
  node.computeArrangement()
  return node.arrangement.layoutBounds()

proc computeLayout*(parent, node: Node) {.measure.} =
  ## Computes constraints and auto-layout.

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
      let rightSpace = parent.orgSize.x - node.orgPosition.x
      node.position.x = parent.size.x - rightSpace
    of ScaleConstraint:
      let xScale = parent.size.x / parent.orgSize.x
      node.position.x = node.orgPosition.x * xScale
      node.size.x = node.orgSize.x * xScale
    of StretchConstraint:
      let rightSpace = parent.orgSize.x - node.orgSize.x
      node.size.x = parent.size.x - rightSpace
    of CenterConstraint:
      let offset = node.orgPosition.x - round(parent.orgSize.x / 2.0)
      node.position.x = round(parent.size.x / 2.0) + offset

  case node.constraints.vertical:
    of MinConstraint: discard
    of MaxConstraint:
      let bottomSpace = parent.orgSize.y - node.orgPosition.y
      node.position.y = parent.size.y - bottomSpace
    of ScaleConstraint:
      let yScale = parent.size.y / parent.orgSize.y
      node.position.y = node.orgPosition.y * yScale
      node.size.y = node.orgSize.y * yScale
    of StretchConstraint:
      let bottomSpace = parent.orgSize.y - node.orgSize.y
      node.size.y = parent.size.y - bottomSpace
    of CenterConstraint:
      let offset = node.orgPosition.y - round(parent.orgSize.y / 2.0)
      node.position.y = round(parent.size.y / 2.0) + offset

  # Fix scroll position when resizing.
  if node.kind == TextNode or node.overflowDirection == VerticalScrolling:
    let bounds = node.computeScrollBounds()
    node.scrollPos = clamp(node.scrollPos, bounds)
