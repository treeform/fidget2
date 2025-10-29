import
  std/[algorithm, random, sequtils, strutils],
  flatty, flatty/hashy2, vmath, pixie/common,
  internal, loader, schema

# INodes are the internal nodes of the tree, this file defines the API for them.

# proc markTreeDirty*(node: INode) =
#   ## Marks the entire tree dirty or not dirty.
#   node.dirty = true
#   for c in node.children:
#     markTreeDirty(c)

proc markTreeClean*(node: INode) =
  ## Marks the entire tree dirty or not dirty.
  node.dirtyLayout = false
  node.dirtyText = false
  node.dirtyRaster = false
  for c in node.children:
    markTreeClean(c)

# proc checkDirty*(node: INode) =
#   ## Makes sure that if children are dirty, parents are dirty too.
#   for c in node.children:
#     checkDirty(c)
#     if c.dirty == true:
#       node.dirty = true
#       break

# proc printDirtyStatus*(node: INode, indent = 0) =
#   ## Prints the dirty status of a node and its children.
#   echo " ".repeat(indent), node.name, ":", node.dirty
#   for child in node.children:
#     printDirtyStatus(child, indent + 1)

# proc makeTextDirty*(node: INode) =
#   ## Marks a text node as dirty and clears its arrangement.
#   node.dirty = true
#   if node.kind == TextNode:
#     node.arrangement = nil
#     node.computeArrangement()

proc `text=`*(node: INode, text: string) =
  ## Sets the text content of a text node.
  if node.kind != TextNode:
    echo "Trying to set text of non text node: '" & node.path & "'"
  if node.characters != text:
    node.characters = text
    node.dirtyText = true

proc findNodeById*(id: string): INode =
  ## Finds a node by ID (slow).
  proc search(node: INode): INode =
    if node.id == id:
      return node
    for n in node.children:
      let c = search(n)
      if c != nil:
        return c
  return search(figmaFile.document)

proc removeChild*(parent, node: INode) =
  ## Removes the node from the document.
  for i, n in parent.children:
    if n == node:
      parent.children.delete(i)
      node.parent = nil
      return

proc removeChildren*(node: INode) =
  ## Clears the node and its children.
  for child in toSeq(node.children):
    node.removeChild(child)

proc assignIdsToTree(node: INode) =
  ## Walks the tree giving everyone a new ID.
  node.id = $rand(int.high)
  for c in node.children:
    c.assignIdsToTree()

proc copy[T](a: T): T =
  ## Copies a value.
  toFlatty(a).fromFlatty(T)

proc copy*(node: INode): INode =
  ## Copies a node creating a new one.
  result = INode()

  template copyField(x: untyped) =
    result.x = node.x.copy()

  # Base
  copyField componentId
  copyField name
  copyField kind
  if node.kind == ComponentNode:
    result.kind = InstanceNode
  # Transform
  copyField position
  copyField origPosition
  copyField size
  copyField origSize
  copyField rotation
  copyField scale
  copyField flipHorizontal
  copyField flipVertical
  copyField size
  # Shape
  copyField fillGeometry
  copyField strokeWeight
  copyField strokeAlign
  copyField strokeGeometry
  copyField cornerRadius
  copyField rectangleCornerRadii
  # Visual
  copyField blendMode
  copyField fills
  copyField strokes
  copyField effects
  copyField opacity
  copyField visible
  # Masking
  copyField isMask
  copyField isMaskOutline
  copyField booleanOperation
  copyField clipsContent
  # Text
  copyField characters
  copyField style
  # Layout
  copyField constraints
  copyField layoutAlign
  copyField layoutGrids
  copyField layoutMode
  copyField itemSpacing
  copyField counterAxisSizingMode
  copyField paddingLeft
  copyField paddingRight
  copyField paddingTop
  copyField paddingBottom
  copyField overflowDirection

  for child in node.children:
    let childNode = child.copy()
    childNode.parent = result
    result.children.add(childNode)

  result.assignIdsToTree()

proc addChild*(parent, child: INode) =
  ## Adds a child to a parent node.
  if child.parent != nil:
    child.parent.removeChild(child)
  parent.children.add(child)
  child.parent = parent

proc inTree*(node, other: INode): bool =
  ## Returns true if node is a subnode of the other.
  var walkNode = node
  while walkNode != nil:
    if walkNode.id == other.id:
      return true
    walkNode = walkNode.parent

proc normalize(props: var seq[(string, string)]) =
  ## Makes sure that prop names are sorted.
  props.sort proc(a, b: (string, string)): int = cmp(a[0], b[0])

proc parseName(name: string): seq[(string, string)] =
  ## Parses a name like "State=Off,Color=blue" into PropName.
  for pair in name.split(","):
    let
      arr = pair.split("=")
    if arr.len >= 2:
      let
        k = arr[0]
        v = arr[1]
      result.add((k.strip(), v.strip()))
  result.normalize()

func `[]`*(query: seq[(string, string)], key: string): string =
  ## Gets a key out of PropName.
  for (k, v) in query:
    if k == key:
      return v

func contains*(query: seq[(string, string)], key: string): bool =
  ## Does the query contain this key?
  for (k, v) in query:
    if k == key:
      return true

func `[]=`*(query: var seq[(string, string)], key, value: string) =
  ## Sets a key in the PropName. If key is not there appends a
  ## new key-value pair at the end.
  for pair in query.mitems:
    if pair[0] == key:
      pair[1] = value
      return
  query.add((key, value))

proc triMerge*(current, previousMaster, currentMaster: INode) =
  ## Does a tri-merge of the node trees.

  # How does it work? Just like Figma.
  # Components have master components. The nodes are very similar their master.
  # But different in some key ways. Well we want to preserve the differences.
  # So when we change the master component, to a different one, we want to
  # preserve the differences only, but change the similar properties.

  # If current.x and previousMaster.x are same, we can change to currentMaster.x
  template mergeField(x: untyped, dirty: untyped) =
    if current.x == previousMaster.x:
      current.x = currentMaster.x
      current.dirty = true

  template mergeArray(x: untyped, dirty: untyped) =
    for i in 0 ..< current.x.len:
      if current.x[i].similar(previousMaster.x[i]):
        current.x[i] = currentMaster.x[i]
        current.dirty = true

  # Ids
  current.componentId = currentMaster.componentId
  # Transform
  mergeField position, dirtyLayout
  mergeField origPosition, dirtyLayout
  mergeField rotation, dirtyRaster
  mergeField scale, dirtyLayout
  mergeField flipHorizontal, dirtyRaster
  mergeField flipVertical, dirtyRaster
  # Shape
  mergeField fillGeometry, dirtyRaster
  mergeField strokeWeight, dirtyRaster
  mergeField strokeAlign, dirtyRaster
  mergeField strokeGeometry, dirtyRaster
  mergeField cornerRadius, dirtyRaster
  mergeField rectangleCornerRadii, dirtyRaster
  # Visual
  mergeField blendMode, dirtyRaster
  mergeArray fills, dirtyRaster
  mergeArray strokes, dirtyRaster
  mergeField effects, dirtyRaster
  mergeField opacity, dirtyRaster
  mergeField visible, dirtyRaster
  # Masking
  mergeField isMask, dirtyRaster
  mergeField isMaskOutline, dirtyRaster
  mergeField booleanOperation, dirtyRaster
  mergeField clipsContent, dirtyLayout
  # Text
  mergeField characters, dirtyText
  mergeField style, dirtyText
  # Layout
  mergeField constraints, dirtyLayout
  mergeField layoutAlign, dirtyLayout
  mergeField layoutGrids, dirtyLayout
  mergeField layoutMode, dirtyLayout
  mergeField itemSpacing, dirtyLayout
  mergeField counterAxisSizingMode, dirtyLayout
  mergeField paddingLeft, dirtyLayout
  mergeField paddingRight, dirtyLayout
  mergeField paddingTop, dirtyLayout
  mergeField paddingBottom, dirtyLayout
  mergeField overflowDirection, dirtyLayout

  let minChildren = min(min(
    current.children.len,
    previousMaster.children.len),
    current.children.len
  )

  for i in 0 ..< minChildren:
    if current.children[i].kind == InstanceNode and
      previousMaster.children[i].kind == InstanceNode and
      currentMaster.children[i].kind == InstanceNode:
      # Don't do anything with instance nodes.
      continue
    elif current.children[i].name == previousMaster.children[i].name and
      current.children[i].name == currentMaster.children[i].name:
      triMerge(
        current.children[i],
        previousMaster.children[i],
        currentMaster.children[i]
      )
    else:
      echo "name error?", current.children[i].path
      echo "node.kind ", current.children[i].kind
      echo "current name     ", current.children[i].name
      echo "name prev master ", previousMaster.children[i].name
      echo "name curr master ", currentMaster.children[i].name

proc isInstance*(node: INode): bool =
  ## Checks if node is an instance node.
  ## And can have variants.
  node.componentId != ""

proc setVariant*(node: INode, name, value: string) =
  ## Changes the variant of the node.
  var previousMaster = findNodeById(node.componentId)
  if previousMaster == nil:
    echo "Previous master not found for node: '" & node.path & "'"
    return
  var props = previousMaster.name.parseName()
  if props[name] == value:
    # no change
    return
  props[name] = value
  props.normalize()

  var componentSet = previousMaster.parent
  var foundNode: INode
  for n in componentSet.children:
    var nodeProps = n.name.parseName()
    if nodeProps == props:
      foundNode = n
      break

  if foundNode != nil:
    var currentMaster = foundNode
    var currentPos = node.position
    triMerge(node, previousMaster, currentMaster)
    node.position = currentPos
    node.componentId = currentMaster.id
  else:
    var needName = ""
    for (k, v) in props:
      needName &= k & "=" & v & ","
    needName.removeSuffix(",")
    echo "Node '", needName, "' not found in component set: ", node.path

proc hasVariant*(node: INode, name, value: string): bool =
  ## Checks if the variant exists for the node.
  var previousMaster = findNodeById(node.componentId)
  if previousMaster != nil:
    var props = previousMaster.name.parseName()
    props[name] = value
    props.normalize()
    var componentSet = previousMaster.parent
    for n in componentSet.children:
      var nodeProps = n.name.parseName()
      if nodeProps == props:
        return true

proc getVariant*(node: INode, name: string): string =
  ## Gets the variant for the node.
  var previousMaster = findNodeById(node.componentId)
  var props = previousMaster.name.parseName()
  if name in props:
    return props[name]

proc masterComponent*(node: INode): INode =
  ## Gets the master component if this is an instance and it exists.
  findNodeById(node.componentId)

proc dumpTree*(node: INode, indent: string = ""): string =
  ## Dumps the tree to a string.
  result = indent & node.name & "\n"
  for child in node.children:
    result &= dumpTree(child, indent & "  ")
  return result
