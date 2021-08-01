import bumpy, schema, vmath, common, options, tables, pixie, unicode

proc computeTextBounds(node: Node): Vec2 =

  let arrangement = node.computeArrangement()
  return arrangement.computeBounds()

proc computeLayout*(parent, node: Node) =
  ## Computes constraints and auto-layout.

  for n in node.children:
    computeLayout(node, n)

  let
    orgPosition = node.position
    orgSize = node.size

  # Typeset text
  if node.kind == nkText:
    case node.style.textAutoResize:
      of tarFixed:
        # Fixed sized text node.
        discard
      of tarHeight:
        # Text will grow down.
        var bounds = computeTextBounds(node)
        node.size.y = bounds.y
      of tarWidthAndHeight:
        # Text will grow down and wide.
        var bounds = computeTextBounds(node)
        node.size.x = bounds.x
        node.size.y = bounds.y

  # Auto-layout code.
  if node.layoutMode == lmVertical:
    if node.counterAxisSizingMode == asAuto:
      # Resize to fit elements tightly.
      var maxW = 0.0
      for n in node.children:
        if n.layoutAlign != laStretch:
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

      if n.position.y != at:
        n.position.y = at
        n.markTreeDirty(true)

      at += n.size.y
    at += node.paddingBottom
    node.size.y = at

  if node.layoutMode == lmHorizontal:
    if node.counterAxisSizingMode == asAuto:
      # Resize to fit elements tightly.
      var maxH = 0.0
      for n in node.children:
        if n.layoutAlign != laStretch:
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

      if n.position.x != at:
        n.position.x = at
        n.markTreeDirty(true)

      at += n.size.x
    at += node.paddingRight
    node.size.x = at

  # Constraints code.
  case node.constraints.horizontal:
    of cMin: discard
    of cMax:
      let rightSpace = parent.orgSize.x - node.orgPosition.x
      node.position.x = parent.size.x - rightSpace
    of cScale:
      let xScale = parent.size.x / parent.orgSize.x
      node.position.x = node.orgPosition.x * xScale
      node.size.x = node.orgSize.x * xScale
    of cStretch:
      let rightSpace = parent.orgSize.x - node.orgSize.x
      node.size.x = parent.size.x - rightSpace
    of cCenter:

      let offset = node.orgPosition.x - round(parent.orgSize.x / 2.0)
      node.position.x = round(parent.size.x / 2.0) + offset

  case node.constraints.vertical:
    of cMin: discard
    of cMax:
      let bottomSpace = parent.orgSize.y - node.orgPosition.y
      node.position.y = parent.size.y - bottomSpace
    of cScale:
      let yScale = parent.size.y / parent.orgSize.y
      node.position.y = node.orgPosition.y * yScale
      node.size.y = node.orgSize.y * yScale
    of cStretch:
      let bottomSpace = parent.orgSize.y - node.orgSize.y
      node.size.y = parent.size.y - bottomSpace
    of cCenter:

      let offset = node.orgPosition.y - round(parent.orgSize.y / 2.0)
      node.position.y = round(parent.size.y / 2.0) + offset

      # let offset = floor((node.orgSize.y - parent.orgSize.y) / 2.0 + node.orgPosition.y)
      # node.position.y = floor((parent.size.y - node.size.y) / 2.0) + offset

  if orgPosition != node.position or orgSize != node.size:
    # If some thing change redraw all.
    node.markTreeDirty(true)
  node.markTreeDirty(true)
