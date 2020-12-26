import schema, vmath, bumpy

proc computeLayout*(parent, node: Node) =
  ## Computes constraints and auto-layout.

  for n in node.children:
    computeLayout(node, n)

  # Constraints code.
  case node.constraints.horizontal:
    of cMin: discard
    of cMax:
      let rightSpace = parent.orgBox.w - node.orgBox.x
      node.box.x = parent.box.w - rightSpace
    of cScale:
      let xScale = parent.box.w / parent.orgBox.w
      node.box.x = node.orgBox.x * xScale
      node.box.w = node.orgBox.w * xScale
    of cStretch:
      let rightSpace = parent.orgBox.w - node.orgBox.w
      node.box.w = parent.box.w - rightSpace
    of cCenter:
      let offset = floor((node.orgBox.w - parent.orgBox.w) / 2.0 + node.orgBox.x)
      node.box.x = floor((parent.box.w - node.box.w) / 2.0) + offset

  case node.constraints.vertical:
    of cMin: discard
    of cMax:
      let bottomSpace = parent.orgBox.h - node.orgBox.y
      node.box.y = parent.box.h - bottomSpace
    of cScale:
      let yScale = parent.box.h / parent.orgBox.h
      node.box.y = node.orgBox.y * yScale
      node.box.h = node.orgBox.h * yScale
    of cStretch:
      let bottomSpace = parent.orgBox.h - node.orgBox.h
      node.box.h = parent.box.h - bottomSpace
    of cCenter:
      let offset = floor((node.orgBox.h - parent.orgBox.h) / 2.0 + node.orgBox.y)
      node.box.y = floor((parent.box.h - node.box.h) / 2.0) + offset

  node.size = node.box.wh

  # # Typeset text
  # if node.kind == nkText:
  #   computeTextLayout(node)
  #   case node.textStyle.autoResize:
  #     of tsNone:
  #       # Fixed sized text node.
  #       discard
  #     of tsHeight:
  #       # Text will grow down.
  #       node.box.h = node.textLayoutHeight
  #     of tsWidthAndHeight:
  #       # Text will grow down and wide.
  #       node.box.w = node.textLayoutWidth
  #       node.box.h = node.textLayoutHeight

  # # Auto-layout code.
  # if node.layoutMode == lmVertical:
  #   if node.counterAxisSizingMode == csAuto:
  #     # Resize to fit elements tightly.
  #     var maxW = 0.0
  #     for n in node.children:
  #       if n.layoutAlign != laStretch:
  #         maxW = max(maxW, n.box.w)
  #     node.box.w = maxW + node.horizontalPadding * 2

  #   var at = 0.0
  #   at += node.verticalPadding
  #   for i, n in node.children.reversePairs:
  #     if i > 0:
  #       at += node.itemSpacing
  #     n.box.y = at
  #     case n.layoutAlign:
  #       of laMin:
  #         n.box.x = node.horizontalPadding
  #       of laCenter:
  #         n.box.x = node.box.w/2 - n.box.w/2
  #       of laMax:
  #         n.box.x = node.box.w - n.box.w - node.horizontalPadding
  #       of laStretch:
  #         n.box.x = node.horizontalPadding
  #         n.box.w = node.box.w - node.horizontalPadding * 2
  #         # Redo the layout for child node.
  #         computeLayout(node, n)
  #     at += n.box.h
  #   at += node.verticalPadding
  #   node.box.h = at

  # if node.layoutMode == lmHorizontal:
  #   if node.counterAxisSizingMode == csAuto:
  #     # Resize to fit elements tightly.
  #     var maxH = 0.0
  #     for n in node.children:
  #       if n.layoutAlign != laStretch:
  #         maxH = max(maxH, n.box.h)
  #     node.box.h = maxH + node.verticalPadding * 2

  #   var at = 0.0
  #   at += node.horizontalPadding
  #   for i, n in node.children.reversePairs:
  #     if i > 0:
  #       at += node.itemSpacing
  #     n.box.x = at
  #     case n.layoutAlign:
  #       of laMin:
  #         n.box.y = node.verticalPadding
  #       of laCenter:
  #         n.box.y = node.box.h/2 - n.box.h/2
  #       of laMax:
  #         n.box.y = node.box.h - n.box.h - node.verticalPadding
  #       of laStretch:
  #         n.box.y = node.verticalPadding
  #         n.box.h = node.box.h - node.verticalPadding * 2
  #         # Redo the layout for child node.
  #         computeLayout(node, n)
  #     at += n.box.w
  #   at += node.horizontalPadding
  #   node.box.w = at
