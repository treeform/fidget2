import fidget2/ecs, vmath, fidget2/schema, random, benchy, tables

# Here is how to create a component.
type
  Base = object
    id*: string     ## A string uniquely identifying this node.
    kind*: NodeKind ## The type of the node, refer to table below for details.
    name*: string   ## The name given to the node by the user in the tool.
    children*: seq[Entity]
    parent*: Entity
    prototypeStartNodeID*: string
    componentId*: string

  #Transform = object
    position*: Vec2
    size*: Vec2   ## Size of the box in pixels.
    scale*: Vec2  ## Zoom/Scale of the node.
    rotation*: float32
    flipHorizontal*: bool
    flipVertical*: bool

  Shape = object
    fillGeometry*: seq[Geometry]
    strokeWeight*: float32
    strokeAlign*: StrokeAlign
    strokeGeometry*: seq[Geometry]
    cornerRadius*: float32                           ## For any shape.
    rectangleCornerRadii*: array[4, float32] ## Only for rectangles.

  Mask = object
    isMask*: bool                        ## Used by masking
    isMaskOutline*: bool                 ## ???
    booleanOperation*: BooleanOperation  ## Used by boolean nodes
    clipsContent*: bool

  Text = object
    characters*: string
    style*: TypeStyle
    characterStyleOverrides*: seq[int]
    styleOverrideTable*: Table[string, TypeStyle]

Base.attachAs(base)
Shape.attachAs(shape)
Mask.attachUncommonAs(mask)
Text.attachUncommonAs(text)

timeIt "ecs based":

  randomize(2022)
  var keep = 0

  Entity.clear()
  Base.clear()
  Shape.clear()
  Mask.clear()
  Text.clear()

  var nodes: seq[Entity]

  for i in 0 ..< 10000:
    var node = newEntity()
    var base = node.initBase()
    base.id = $i

    if rand(0..3) == 0:
      var shape = node.initShape()
      shape.strokeWeight = 1

    if rand(0..100) == 0:
      var m = node.initMask()
      m.isMask = true

    if rand(0..100) == 0:
      var t = node.initText()
      t.characters = "hello"

    nodes.add(node)

  for i in 0 ..< 100:

    for (node, base) in Base.mpairs:
      inc keep

    for (node, s) in Shape.mpairs:
      inc keep

    for (node, m) in Mask.mpairs:
      inc keep

    for (node, t) in Text.mpairs:
      inc keep

timeIt "obj based":

  randomize(2022)
  var keep = 0

  var nodes: seq[schema.Node]
  for i in 0 ..< 10000:
    var node = schema.Node()
    node.id = $i

    if rand(0..3) == 0:
        node.strokeWeight = 1

    if rand(0..100) == 0:
      node.isMask = true

    if rand(0..100) == 0:
      node.characters = "hello"

    nodes.add(node)

  for i in 0 ..< 100:

    for node in nodes:
      inc keep

    for node in nodes:
      if node.strokeWeight != 0:
        inc keep

    for node in nodes:
      if node.isMask:
        inc keep

    for node in nodes:
      if node.characters != "":
        inc keep
