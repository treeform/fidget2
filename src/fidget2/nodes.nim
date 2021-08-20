import schema, loader, random, algorithm, strutils,
    flatty/hashy2, vmath

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

proc printDirtyStatus*(node: Node, indent = 0) =
  echo " ".repeat(indent), node.name, ":", node.dirty
  for child in node.children:
    printDirtyStatus(child, indent + 1)

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

proc remove*(node: Node) =
  ## Removes the node from the document.
  let parent = node.parent
  for i, n in parent.children:
    if n == node:
      parent.children.delete(i)
      parent.markTreeDirty()
      node.parent = nil
      return

proc copy*(node: Node): Node =
  ## Copies a node creating new one.
  result = deepCopy(node)
  result.position = vec2(0, 0)
  result.id = $rand(int.high)
  #result.markTreeDirty()

proc newInstance*(node: Node): Node =
  ## Creates a new instance of a master node.
  doAssert node.kind == nkComponent
  result = node.copy()
  result.componentId = node.id

proc addChild*(parent, child: Node) =
  ## Adds a child to a parent node.
  parent.children.add(child)
  child.parent = parent
  parent.markTreeDirty()

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
      result.add((k, v))
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

proc deepClone[T](a: T): T =
  ## Deep copy of the object.
  deepCopy(result, a)

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
    if current.children[i].name == prevMaster.children[i].name and
      current.children[i].name == currMaster.children[i].name:
      triMerge(
        current.children[i],
        prevMaster.children[i],
        currMaster.children[i]
      )

proc setVariant*(node: Node, name, value: string) =
  ## Changes the variant of the node.
  var prevMaster = findNodeById(node.componentId)
  var props = prevMaster.name.parseName()
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

proc hasVariant*(node: Node, name, value: string): bool =
  ## Checks the variant exists for the node.
  var prevMaster = findNodeById(node.componentId)
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
