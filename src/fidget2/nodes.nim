import
  std/[algorithm, random, sequtils, strutils],
  flatty, flatty/hashy2, vmath, pixie/common,
  loader, schema, inodes

# Extensions for the INode type. The getters are zero cost, but
# the setters set the dirty flag and sometimes mark the whole tree dirty.

type
  Node* = distinct INode ## A user-friendly node type.

template internal*(node: Node): INode =
  cast[INode](node)

proc `$`*(node: Node): string =
  $node.internal

proc `==`*(a, b: Node): bool {.inline.} =
  a.internal == b.internal

proc `!=`*(a, b: Node): bool {.inline.} =
  a.internal != b.internal

proc `==`*(a: Node, p: pointer): bool {.inline.} =
  cast[pointer](a.internal) == p

proc `!=`*(a: Node, p: pointer): bool {.inline.} =
  cast[pointer](a.internal) != p

proc isNil*(node: Node): bool {.inline.} =
  node.internal == nil

proc isNotNil*(node: Node): bool {.inline.} =
  node.internal != nil

proc kind*(node: Node): NodeKind {.inline.} =
  node.internal.kind

proc name*(node: Node): string {.inline.} =
  node.internal.name

proc id*(node: Node): string {.inline.} =
  node.internal.id

proc componentId*(node: Node): string {.inline.} =
  node.internal.componentId

proc position*(node: Node): Vec2 {.inline.} =
  node.internal.position

proc `position=`*(node: Node, value: Vec2) =
  node.internal.position = value
  node.internal.dirty = true

proc mat*(node: Node): Mat3 {.inline.} =
  node.internal.mat

type NodeSize* = distinct INode

proc size*(node: Node): Vec2 {.inline.} =
  node.internal.size

proc `size=`*(node: Node, value: Vec2) =
  node.internal.size = value
  node.internal.markTreeDirty()

proc scale*(node: Node): Vec2 {.inline.} =
  node.internal.scale

proc rotation*(node: Node): float32 {.inline.} =
  node.internal.rotation

proc flipHorizontal*(node: Node): bool {.inline.} =
  node.internal.flipHorizontal

proc flipVertical*(node: Node): bool {.inline.} =
  node.internal.flipVertical

proc fillGeometry*(node: Node): seq[Geometry] {.inline.} =
  node.internal.fillGeometry

proc strokeWeight*(node: Node): float32 {.inline.} =
  node.internal.strokeWeight

proc strokeAlign*(node: Node): StrokeAlign {.inline.} =
  node.internal.strokeAlign

proc strokeGeometry*(node: Node): seq[Geometry] {.inline.} =
  node.internal.strokeGeometry

proc cornerRadius*(node: Node): float32 {.inline.} =
  node.internal.cornerRadius

proc rectangleCornerRadii*(node: Node): array[4, float32] {.inline.} =
  node.internal.rectangleCornerRadii

proc blendMode*(node: Node): BlendMode {.inline.} =
  node.internal.blendMode

proc fills*(node: Node): seq[Paint] {.inline.} =
  node.internal.fills

proc strokes*(node: Node): seq[Paint] {.inline.} =
  node.internal.strokes

proc effects*(node: Node): seq[Effect] {.inline.} =
  node.internal.effects

proc children*(node: Node): seq[Node] {.inline.} =
  cast[seq[Node]](node.internal.children)

proc parent*(node: Node): Node {.inline.} =
  cast[Node](node.internal.parent)

proc wordWrap*(node: Node): bool {.inline.} =
  node.internal.wordWrap

proc `wordWrap=`*(node: Node, value: bool) =
  node.internal.wordWrap = value
  node.internal.markTreeDirty()

proc scrollable*(node: Node): bool {.inline.} =
  node.internal.scrollable

proc `scrollable=`*(node: Node, value: bool) =
  node.internal.scrollable = value
  node.internal.markTreeDirty()

proc scrollPos*(node: Node): Vec2 {.inline.} =
  node.internal.scrollPos

proc `scrollPos=`*(node: Node, value: Vec2) =
  node.internal.scrollPos = value
  node.internal.markTreeDirty()

proc editable*(node: Node): bool {.inline.} =
  node.internal.editable

proc `editable=`*(node: Node, value: bool) =
  node.internal.editable = value
  node.internal.markTreeDirty()

proc dirty*(node: Node): bool {.inline.} =
  node.internal.dirty

proc `dirty=`*(node: Node, value: bool) =
  node.internal.dirty = value

proc prototypeStartNodeID*(node: Node): string {.inline.} =
  node.internal.prototypeStartNodeID

proc path*(node: Node): string =
  ## Returns the full path of the node back to the root.
  node.internal.path()

proc markTreeDirty*(node: Node) =
  node.internal.markTreeDirty()

proc makeTextDirty*(node: Node) =
  node.internal.makeTextDirty()

proc text*(node: Node): string =
  ## Gets the text content of a text node.
  if node.kind != TextNode:
    echo "Trying to get text of non text node: '" & node.path & "'"
  return node.internal.characters

proc `text=`*(node: Node, value: string) =
  node.internal.text = value
  node.internal.markTreeDirty()

proc show*(node: Node) =
  ## Shows a node by making it visible.
  node.internal.visible = true
  node.internal.markTreeDirty()

proc hide*(node: Node) =
  ## Hides a node by making it invisible.
  node.internal.visible = false
  node.internal.markTreeDirty()

proc show*(nodes: seq[Node]) =
  ## Shows multiple nodes.
  for node in nodes:
    node.show()

proc hide*(nodes: seq[Node]) =
  ## Hides multiple nodes.
  for node in nodes:
    node.hide()

proc visible*(node: Node): bool =
  ## Checks if the node is visible.
  node.internal.visible

proc `visible=`*(node: Node, value: bool) =
  if value:
    node.show()
  else:
    node.hide()

proc opacity*(node: Node): float32 =
  node.internal.opacity

proc `opacity=`*(node: Node, value: float32) =
  node.internal.opacity = value
  node.internal.markTreeDirty()

proc addChild*(parent, child: Node) =
  ## Adds a child to a parent node.
  parent.internal.addChild(child.internal)
  parent.internal.markTreeDirty()

proc removeChild*(parent: Node, child: Node) =
  ## Removes a child from a parent.
  parent.internal.removeChild(child.internal)
  parent.internal.markTreeDirty()

proc removeChildren*(parent: Node, children: seq[Node]) =
  ## Removes multiple children from a parent.
  for child in toSeq(children):
    parent.internal.removeChild(child.internal)
  parent.internal.markTreeDirty()

proc remove*(node: Node) =
  ## Removes a node from its parent.
  node.parent.removeChild(node)

proc remove*(nodes: seq[Node]) =
  ## Removes multiple nodes.
  for node in toSeq(nodes):
    node.remove()

proc removeChildren*(node: Node) =
  ## Clears a node and its children.
  node.internal.removeChildren()
  node.internal.markTreeDirty()

proc copy*(node: Node): Node =
  Node(node.internal.copy())

proc newInstance*(node: Node): Node =
  ## Creates a new instance of a master node.
  doAssert node != nil
  doAssert node.kind == ComponentNode
  result = node.copy()
  result.internal.componentId = node.id

proc isInstance*(node: Node): bool =
  ## Checks if node is an instance node.
  ## And can have variants.
  node.internal.isInstance()

proc masterComponent*(node: Node): Node =
  ## Gets the master component if this is an instance and it exists.
  node.internal.masterComponent().Node()

proc hasVariant*(node: Node, name, value: string): bool =
  ## Checks if the node has a variant.
  node.internal.hasVariant(name, value)

proc getVariant*(node: Node, name: string): string =
  ## Gets the variant of the node.
  node.internal.getVariant(name)

proc setVariant*(node: Node, name, value: string) =
  ## Sets the variant of the node.
  node.internal.setVariant(name, value)
  node.internal.markTreeDirty()

proc setVariant*(nodes: seq[Node], name, value: string) =
  ## Changes the variant of the nodes.
  for node in nodes:
    node.setVariant(name, value)

proc setVariant*(node: Node, name: string, value: bool) =
  ## Changes the variant of the node to "True" or "False".
  if value:
    node.setVariant(name, "True")
  else:
    node.setVariant(name, "False")

proc childIndex*(node: Node): int =
  ## Gets the child index of the node.
  node.parent.internal.children.find(node.internal)

proc inTree*(node, other: Node): bool =
  ## Checks if the node is a subnode of the other.
  node.internal.inTree(other.internal)

proc sendToFront*(node: Node) =
  ## Sends the node to the front of the parent's children.
  node.parent.internal.removeChild(node.internal)
  node.parent.internal.children.add(node.internal)
  node.parent.markTreeDirty()

proc sendToBack*(node: Node) =
  ## Sends the node to the back of the parent's children.
  node.parent.internal.removeChild(node.internal)
  node.parent.internal.children.insert(node.internal, 0)
  node.parent.markTreeDirty()

proc sendForward*(node: Node) =
  ## Sends the node forward in the parent's children.
  let index = node.parent.children.find(node)
  node.parent.internal.children.delete(index)
  node.parent.internal.children.insert(node.internal, index + 1)
  node.parent.markTreeDirty()

proc sendBackward*(node: Node) =
  ## Sends the node backward in the parent's children.
  let index = node.parent.children.find(node)
  node.parent.internal.children.delete(index)
  node.parent.internal.children.insert(node.internal, index - 1)
  node.parent.markTreeDirty()

proc dumpTree*(node: Node): string =
  node.internal.dumpTree()

proc `onRenderCallback=`*(node: Node, callback: proc(thisNode: Node) {.closure.}) =
  ## Sets the on render callback for a node.
  let castedCallback = cast[proc(thisNode: INode) {.closure.}](callback)
  node.internal.onRenderCallback = castedCallback
