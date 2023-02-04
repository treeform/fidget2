import schema, loader, random, algorithm, strutils,
    flatty/hashy2, vmath, sequtils, internal

proc path*(node: Node): string =
  ## Returns that full path of the node back to the root.
  var walkNode = node
  while walkNode != nil and walkNode.kind != DocumentNode:
    result = "/" & walkNode.name & result
    walkNode = walkNode.parent

proc deepClone[T](a: T): T =
  ## Deep copy of the object.
  deepCopy(result, a)

proc markTreeDirty*(node: Node) =
  ## Marks the entire tree dirty or not dirty.
  node.dirty = true
  for c in node.children:
    markTreeDirty(c)

proc markTreeClean*(node: Node) =
  ## Marks the entire tree dirty or not dirty.
  node.dirty = false
  for c in node.children:
    markTreeClean(c)

proc checkDirty*(node: Node) =
  ## Makes sure if children are dirty, parents are dirty too!
  for c in node.children:
    checkDirty(c)
    if c.dirty == true:
      node.dirty = true
      break

proc printDirtyStatus*(node: Node, indent = 0) =
  echo " ".repeat(indent), node.name, ":", node.dirty
  for child in node.children:
    printDirtyStatus(child, indent + 1)

proc makeTextDirty*(node: Node) =
  node.dirty = true
  if node.kind == TextNode:
    node.arrangement = nil
    node.computeArrangement()

proc setText*(node: Node, text: string) =
  if node.kind != TextNode:
    echo "trying to set text of non text node: " & node.path
  if node.characters != text:
    node.characters = text
    node.makeTextDirty()

proc show*(node: Node) =
  node.visible = true
  node.markTreeDirty()

proc hide*(node: Node) =
  node.visible = false
  node.markTreeDirty()

proc show*(nodes: seq[Node]) =
  for node in nodes:
    node.show()

proc hide*(nodes: seq[Node]) =
  for node in nodes:
    node.hide()

proc findNodeById*(id: string): Node =
  ## Finds a node by id (slow).
  proc recur(node: Node): Node =
    if node.id == id:
      return node
    for n in node.children:
      let c = recur(n)
      if c != nil:
        return c
  return recur(figmaFile.document)

proc removeChild*(parent, node: Node) =
  ## Removes the node from the document.
  for i, n in parent.children:
    if n == node:
      parent.children.delete(i)
      parent.markTreeDirty()
      node.parent = nil
      return

proc delete*(node: Node) =
  node.parent.removeChild(node)

proc delete*(nodes: seq[Node]) =
  for node in toSeq(nodes):
    node.delete()

proc assignIdsToTree(node: Node) =
  ## Walks the tree giving everyone a new id.
  node.id = $rand(int.high)
  for c in node.children:
    c.assignIdsToTree()

proc copy*(node: Node): Node =
  ## Copies a node creating new one.
  result = Node()

  template copyField(x: untyped) =
    result.x = node.x.deepClone()

  # Base
  copyField componentId
  copyField name
  copyField kind
  if node.kind == ComponentNode:
    result.kind = InstanceNode
  # Transform
  copyField position
  copyField orgPosition
  copyField size
  copyField orgSize
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

proc newInstance*(node: Node): Node =
  ## Creates a new instance of a master node.
  doAssert node != nil
  doAssert node.kind == ComponentNode
  result = node.copy()
  result.componentId = node.id

proc addChild*(parent, child: Node) =
  ## Adds a child to a parent node.
  parent.children.add(child)
  child.parent = parent
  parent.markTreeDirty()

proc inTree*(node, other: Node): bool =
  ## Returns true if node is a sub node of other.
  var node = node
  while node != nil:
    if node.id == other.id:
      return true
    node = node.parent

proc normalize(props: var seq[(string, string)]) =
  ## Makes sure that prop name is sorted.
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
  ## Get a key out of PropName.
  for (k, v) in query:
    if k == key:
      return v

func contains*(query: seq[(string, string)], key: string): bool =
  ## Does the query contains this key.
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

proc triMerge(current, prevMaster, currMaster: Node) =
  ## Does a tri merge of the node trees.
  # If current.x and prevMaster.x are same, we can change to currMaster.x
  # TODO: changes all the way back to the original restores maybe?

  template mergeField(x: untyped) =
    if hashy(current.x) == hashy(prevMaster.x):
      current.x = currMaster.x.deepClone()
      current.dirty = true

  # Ids
  mergeField componentId
  # Transform
  mergeField position
  mergeField orgPosition
  mergeField rotation
  mergeField scale
  mergeField flipHorizontal
  mergeField flipVertical
  # Shape
  mergeField fillGeometry
  mergeField strokeWeight
  mergeField strokeAlign
  mergeField strokeGeometry
  mergeField cornerRadius
  mergeField rectangleCornerRadii
  # Visual
  mergeField blendMode
  mergeField fills
  mergeField strokes
  mergeField effects
  mergeField opacity
  mergeField visible
  # Masking
  mergeField isMask
  mergeField isMaskOutline
  mergeField booleanOperation
  mergeField clipsContent
  # Text
  mergeField characters
  mergeField style
  # Layout
  mergeField constraints
  mergeField layoutAlign
  mergeField layoutGrids
  mergeField layoutMode
  mergeField itemSpacing
  mergeField counterAxisSizingMode
  mergeField paddingLeft
  mergeField paddingRight
  mergeField paddingTop
  mergeField paddingBottom
  mergeField overflowDirection

  let minChildLen = min(min(
    current.children.len,
    prevMaster.children.len),
    current.children.len
  )

  for i in 0 ..< minChildLen:
    if current.children[i].kind == InstanceNode and
      prevMaster.children[i].kind == InstanceNode and
      currMaster.children[i].kind == InstanceNode:
      # Don't do anything with instance nodes.
      continue
    elif current.children[i].name == prevMaster.children[i].name and
      current.children[i].name == currMaster.children[i].name:
      triMerge(
        current.children[i],
        prevMaster.children[i],
        currMaster.children[i]
      )
    else:
      echo "name error?", current.children[i].path
      echo "node.kind ", current.children[i].kind
      echo "current name     ", current.children[i].name
      echo "name prev master ", prevMaster.children[i].name
      echo "name curr master ", currMaster.children[i].name

proc setVariant*(node: Node, name, value: string) =
  ## Changes the variant of the node.
  var prevMaster = findNodeById(node.componentId)
  var props = prevMaster.name.parseName()
  if props[name] == value:
    # no change
    return
  props[name] = value
  props.normalize()

  var componentSet = prevMaster.parent
  for n in componentSet.children:
    var nProps = n.name.parseName()
    if nProps == props:
      var currMaster = n
      triMerge(node, prevMaster, currMaster)
      node.componentId = currMaster.id
      break

proc setVariant*(nodes: seq[Node], name, value: string) =
  ## Changes the variant of the nodes.
  for node in nodes:
    node.setVariant(name, value)

proc hasVariant*(node: Node, name, value: string): bool =
  ## Checks the variant exists for the node.
  var prevMaster = findNodeById(node.componentId)
  if prevMaster != nil:
    var props = prevMaster.name.parseName()
    props[name] = value
    props.normalize()
    var componentSet = prevMaster.parent
    for n in componentSet.children:
      var nProps = n.name.parseName()
      if nProps == props:
        return true

proc getVariant*(node: Node, name: string): string =
  ## Gets the variant for the node.
  var prevMaster = findNodeById(node.componentId)
  var props = prevMaster.name.parseName()
  if name in props:
    return props[name]

proc isInstance*(node: Node): bool =
  ## Checks if node is an instance node.
  ## And can have variants.
  node.componentId != ""

proc masterComponent*(node: Node): Node =
  ## Gets the master component if this is an instance and it exists.
  findNodeById(node.componentId)
