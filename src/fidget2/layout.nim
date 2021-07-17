import bumpy, schema, vmath, common, options

proc computeLayout*(parent, node: Node) =
  ## Computes constraints and auto-layout.

  for n in node.children:
    computeLayout(node, n)

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
      let offset = floor((node.orgSize.x - parent.orgSize.x) / 2.0 + node.orgPosition.x)
      node.position.x = floor((parent.size.x - node.size.x) / 2.0) + offset

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
      let offset = floor((node.orgSize.y - parent.orgSize.y) / 2.0 + node.orgPosition.y)
      node.position.y = floor((parent.size.y - node.size.y) / 2.0) + offset

  # TODO: Implement more of the layout.
  # # Typeset text
  # if node.kind == nkText:
  #   computeTextLayout(node)
  #   case node.textStyle.autoResize:
  #     of tsNone:
  #       # Fixed sized text node.
  #       discard
  #     of tsHeight:
  #       # Text will grow down.
  #       node.size.y = node.textLayoutHeight
  #     of tsWidthAndHeight:
  #       # Text will grow down and wide.
  #       node.size.x = node.textLayoutWidth
  #       node.size.y = node.textLayoutHeight

  # Auto-layout code.
  if node.layoutMode == lmVertical:
    if node.counterAxisSizingMode == asAuto:
      # Resize to fit elements tightly.
      var maxW = 0.0
      for n in node.children:
        if n.layoutAlign != laStretch:
          maxW = max(maxW, n.size.x)
      node.size.x = maxW + node.paddingTop + node.paddingBottom

    var at = 0.0
    at += node.paddingTop
    for i, n in node.children:
      n.position.y = 0

      if i > 0:
        at += node.itemSpacing
      n.position.y = at
      case n.layoutAlign:
        of laStretch:
          n.position.x = node.paddingTop
          n.size.x = node.size.x - (node.paddingTop + node.paddingBottom)
          # Redo the layout for child node.
          computeLayout(node, n)
        of laInherit:
          discard

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
      node.size.y = maxH + node.paddingLeft + node.paddingRight

    var at = 0.0
    at += node.paddingLeft
    for i, n in node.children:
      if i > 0:
        at += node.itemSpacing
      n.position.x = at

      case n.layoutAlign:
        of laStretch:
          n.position.y = node.paddingLeft
          n.size.y = node.size.y - (node.paddingLeft + node.paddingRight)
          # Redo the layout for child node.
          computeLayout(node, n)
        of laInherit:
          discard

      at += n.size.x
    at += node.paddingRight
    node.size.x = at
