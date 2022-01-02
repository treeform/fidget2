import bumpy, chroma, common, jsony, strutils, tables, pixie, vmath, options, unicode

type
  NodeKind* = enum
    nkDocument, nkCanvas
    nkRectangle, nkFrame, nkGroup, nkComponent, nkInstance
    nkVector, nkStar, nkEllipse, nkLine, nkRegularPolygon
    nkText
    nkBooleanOperation
    nkComponentSet

  Component* = ref object
    key*: string
    name*: string
    description*: string

  ConstraintKind* = enum
    cMin
    cMax
    cScale
    cStretch
    cCenter

  LayoutConstraint* = ref object
    vertical*: ConstraintKind
    horizontal*: ConstraintKind

  LayoutAlign* = enum
    laInherit
    laStretch

  PaintKind* = enum
    pkSolid
    pkImage
    pkGradientLinear
    pkGradientRadial
    pkGradientAngular
    pkGradientDiamond

  ScaleMode* = enum
    smFill
    smFit
    smStretch
    smTile

  Transform* = array[2, array[3, float32]]
    ## A 2D affine transformation matrix that can be used to calculate the
    ## affine transforms applied to a layer, including scaling,
    ## rotation, shearing, and translation.

  Paint* = ref object
    blendMode*: BlendMode
    kind*: PaintKind
    visible*: bool
    opacity*: float32
    color*: Color
    scaleMode*: ScaleMode
    imageRef*: string
    imageTransform*: Transform
    scalingFactor*: float32
    rotation*: float32
    gradientHandlePositions*: seq[Vec2]
    gradientStops*: seq[ColorStop]

  EffectKind* = enum
    ekDropShadow
    ekInnerShadow
    ekLayerBlur
    ekBackgroundBlur

  Effect* = object
    kind*: EffectKind
    visible*: bool
    color*: Color
    blendMode*: BlendMode
    offset*: Vec2
    radius*: float32
    spread*: float32

  LayoutMode* = enum
    lmNone
    lmHorizontal
    lmVertical

  LayoutPattern* = enum
    lpColumns
    lpRows
    lpGrid

  GridAlign* = enum
    gaMin
    gaStretch
    gaCenter

  LayoutGrid* = object
    pattern*: LayoutPattern
    sectionSize*: float32
    visible*: bool
    color*: Color
    alignment*: GridAlign ## Only min, stretch and center
    gutterSize*: float32
    offset*: float32
    count*: int

  OpenTypeFlags* = object
    KERN*: int

  TextAutoResize* = enum
    tarFixed
    tarHeight
    tarWidthAndHeight

  TextDecoration* = enum
    tdStrikethrough
    tdUnderline

  LineHeightUnit* = enum
    lhuPixels
    lhuFontSizePercent
    lhuIntrinsicPercent

  TypeStyle* = ref object
    fontFamily*: string
    fontPostScriptName*: string
    paragraphSpacing*: float32
    paragraphIndent*: float32
    italic*: bool
    fontWeight*: float32
    fontSize*: float32
    textCase*: Option[TextCase]
    textDecoration*: TextDecoration
    textAutoResize*: TextAutoResize
    textAlignHorizontal*: HorizontalAlignment
    textAlignVertical*: VerticalAlignment
    letterSpacing*: float32
    fills*: seq[Paint]
    lineHeightPx*: float32
    lineHeightPercent*: float32
    lineHeightPercentFontSize*: float32
    lineHeightUnit*: Option[LineHeightUnit]
    opentypeFlags*: OpenTypeFlags

  Geometry* = object
    path*: Path
    windingRule*: WindingRule

    mat*: Mat3 # NOT FROM FIGMA
    cached*: bool
    shapes*: seq[seq[Vec2]]
    shapesBounds*: Rect

  BooleanOperation* = enum
    boUnion
    boSubtract
    boIntersect
    boExclude

  StrokeAlign* = enum
    saInside
    saOutside
    saCenter

  AxisSizingMode* = enum
    asAuto
    asFixed

  OverflowDirection* = enum
    odNone
    odHorizontalScrolling
    odVerticalScrolling
    odHorizontalAndVerticalScrolling

  Node* = ref object
    # Basic Node properties
    id*: string     ## A string uniquely identifying this node.
    kind*: NodeKind ## The type of the node, refer to table below for details.
    name*: string   ## The name given to the node by the user in the tool.
    children*: seq[Node]
    parent*: Node
    prototypeStartNodeID*: string
    componentId*: string

    # Transform
    position*: Vec2
    size*: Vec2   ## Size of the box in pixels.
    scale*: Vec2  ## Zoom/Scale of the node.
    rotation*: float32
    flipHorizontal*: bool
    flipVertical*: bool

    # Shape
    fillGeometry*: seq[Geometry]
    strokeWeight*: float32
    strokeAlign*: StrokeAlign
    strokeGeometry*: seq[Geometry]
    cornerRadius*: float32                           ## For any shape.
    rectangleCornerRadii*: array[4, float32] ## Only for rectangles.

    # Visual
    blendMode*: BlendMode   ## Blend modes such as darken, screen, overlay...
    fills*: seq[Paint]      ## Fill colors and gradients.
    strokes*: seq[Paint]    ## Stroke colors and gradients.
    effects*: seq[Effect]   ## Effects such as shadows and blurs.
    opacity*: float32       ## Opacity, 0 .. 1
    visible*: bool          ## Visibility on/off.

    # Masking
    isMask*: bool                        ## Used by masking
    isMaskOutline*: bool                 ## ???
    booleanOperation*: BooleanOperation  ## Used by boolean nodes
    clipsContent*: bool                  ## Used by frame nodes to cut children.

    # Text
    characters*: string
    style*: TypeStyle
    characterStyleOverrides*: seq[int]
    styleOverrideTable*: Table[string, TypeStyle]

    # Non-figma text parameters:
    spans*: seq[Span]
    arrangement*: Arrangement
    cursor*: int      # The typing cursor.
    selector*: int    # The selection cursor.
    multiline*: bool  # Single line only (good for input fields).
    wordWrap*: bool   # Should the lines wrap or not.
    savedX*: float     # X position affinity when moving cursor up or down.
    undoStack*: seq[(string, int)]
    redoStack*: seq[(string, int)]

    # Layout
    constraints*: LayoutConstraint
    layoutAlign*: LayoutAlign
    layoutGrids*: seq[LayoutGrid]
    layoutMode*: LayoutMode
    itemSpacing*: float32
    counterAxisSizingMode*: AxisSizingMode
    paddingLeft*: float32
    paddingRight*: float32
    paddingTop*: float32
    paddingBottom*: float32
    overflowDirection*: OverflowDirection

    # Non-figma parameters:
    dirty*: bool        ## Do the pixels need redrawing?
    pixels*: Image      ## Pixel image cache.
    pixelBox*: Rect     ## Pixel position and size.
    editable*: bool     ## Can the user edit the text?
    orgPosition*: Vec2  ## Original position used by constraints.
    orgSize*: Vec2      ## Original size used by constraints.
    idNum*: int         ## Integer ID of the node
    mat*: Mat3          ## Useful to get back to the node.
    collapse*: bool     ## Is the node drawn as a single texture (CPU internals)
    frozen*: bool
    frozenId*: string   ## If the node is frozen, points to its frozen image.
    shown*: bool        ## for onShow/onHide events.
    scrollable*: bool   ## Can this node scroll.
    scrollPos*: Vec2    ## How does it scroll it's children.

  FigmaFile* = ref object
    document*: Node
    components*: Table[string, Component]
    schemaVersion*: int
    name*: string
    lastModified*: string
    thumbnailUrl*: string
    version*: string
    role*: string

proc `$`*(node: Node): string =
  "<" & $node.kind & ": " & node.name & " (" & node.id & ")>"

proc newHook(v: var Paint) =
  v = Paint()
  v.visible = true
  v.opacity = 1.0

proc newHook(v: var TypeStyle) =
  v = TypeStyle()
  v.lineHeightPercent = 100
  v.opentypeFlags.KERN = 1

proc newHook(v: var LayoutGrid) =
  v.visible = true

proc newHook(v: var Geometry) =
  v.mat = mat3()

proc renameHook(v: var Paint, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc renameHook(v: var Effect, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc renameHook(v: var Rect, fieldName: var string) =
  if fieldName == "width":
    fieldName = "w"
  if fieldName == "height":
    fieldName = "h"

proc enumHook(s: string, v: var BlendMode) =
  v = case s:
    of "PASS_THROUGH": bmNormal
    of "NORMAL": bmNormal
    of "DARKEN": bmDarken
    of "MULTIPLY": bmMultiply
    # of "LINEAR_BURN": bmLinearBurn
    of "COLOR_BURN": bmColorBurn
    of "LIGHTEN": bmLighten
    of "SCREEN": bmScreen
    # of "LINEAR_DODGE": bmLinearDodge
    of "COLOR_DODGE": bmColorDodge
    of "OVERLAY": bmOverlay
    of "SOFT_LIGHT": bmSoftLight
    of "HARD_LIGHT": bmHardLight
    of "DIFFERENCE": bmDifference
    of "EXCLUSION": bmExclusion
    of "HUE": bmHue
    of "SATURATION": bmSaturation
    of "COLOR": bmColor
    of "LUMINOSITY": bmLuminosity
    else: raise newException(PixieError, "Unsupported blend mode: " & s)

proc enumHook(s: string, v: var TextCase) =
  v = case s:
    of "UPPER": tcUpper
    of "LOWER": tcLower
    of "TITLE": tcTitle
    # TODO add:
    #of "SMALL_CAPS": tcSmallCaps
    #of "SMALL_CAPS_FORCED": tcCapsForced
    else: tcNormal

proc enumHook(s: string, v: var NodeKind) =
  v = case s:
    of "DOCUMENT": nkDocument
    of "CANVAS": nkCanvas
    of "RECTANGLE": nkRectangle
    of "FRAME": nkFrame
    of "GROUP": nkGroup
    of "COMPONENT": nkComponent
    of "INSTANCE": nkInstance
    of "VECTOR": nkVector
    of "STAR": nkStar
    of "ELLIPSE": nkEllipse
    of "LINE": nkLine
    of "REGULAR_POLYGON": nkRegularPolygon
    of "TEXT": nkText
    of "BOOLEAN_OPERATION": nkBooleanOperation
    of "COMPONENT_SET": nkComponentSet
    else: raise newException(FidgetError, "Invalid node type:" & s)

proc enumHook(s: string, v: var PaintKind) =
  v = case s:
    of "SOLID": pkSolid
    of "IMAGE": pkImage
    of "GRADIENT_LINEAR": pkGradientLinear
    of "GRADIENT_RADIAL": pkGradientRadial
    of "GRADIENT_ANGULAR": pkGradientAngular
    of "GRADIENT_DIAMOND": pkGradientDiamond
    else: raise newException(FidgetError, "Invalid paint type:" & s)

proc enumHook(s: string, v: var EffectKind) =
  v = case s:
    of "DROP_SHADOW": ekDropShadow
    of "INNER_SHADOW": ekInnerShadow
    of "LAYER_BLUR": ekLayerBlur
    of "BACKGROUND_BLUR": ekBackgroundBlur
    else: raise newException(FidgetError, "Invalid effect type:" & s)

proc enumHook(s: string, v: var BooleanOperation) =
  v = case s:
    of "SUBTRACT": boSubtract
    of "INTERSECT": boIntersect
    of "EXCLUDE": boExclude
    of "UNION": boUnion
    else: raise newException(FidgetError, "Invalid boolean operation:" & s)

proc enumHook(s: string, v: var ScaleMode) =
  v = case s:
    of "FILL": smFill
    of "FIT": smFit
    of "STRETCH": smStretch
    of "TILE": smTile
    else: raise newException(FidgetError, "Invalid scale mode:" & s)

proc enumHook(s: string, v: var TextAutoResize) =
  v = case s:
    of "HEIGHT": tarHeight
    of "WIDTH_AND_HEIGHT": tarWidthAndHeight
    else: raise newException(FidgetError, "Invalid text auto resize:" & s)

proc enumHook(s: string, v: var TextDecoration) =
  v = case s:
    of "STRIKETHROUGH": tdStrikethrough
    of "UNDERLINE": tdUnderline
    else: raise newException(FidgetError, "Invalid text decoration:" & s)

proc enumHook(s: string, v: var LineHeightUnit) =
  v = case s:
    of "PIXELS": lhuPixels
    of "FONT_SIZE_%": lhuFontSizePercent
    of "INTRINSIC_%": lhuIntrinsicPercent
    else: raise newException(FidgetError, "Invalid text line height unit:" & s)

proc enumHook(s: string, v: var StrokeAlign) =
  v = case s:
    of "INSIDE": saInside
    of "OUTSIDE": saOutside
    of "CENTER": saCenter
    else: raise newException(FidgetError, "Invalid stroke align:" & s)

proc enumHook(s: string, v: var HorizontalAlignment) =
  v = case s:
    of "CENTER": haCenter
    of "LEFT": haLeft
    of "RIGHT": haRight
    else: raise newException(FidgetError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var VerticalAlignment) =
  v = case s:
    of "CENTER": vaMiddle
    of "TOP": vaTop
    of "BOTTOM": vaBottom
    else: raise newException(FidgetError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var WindingRule) =
  v = case s:
    of "EVENODD": wrEvenOdd
    of "NONZERO": wrNonZero
    else: raise newException(FidgetError, "Invalid winding rule:" & s)

proc enumHook(s: string, v: var ConstraintKind) =
  v = case s:
    of "TOP": cMin
    of "BOTTOM": cMax
    of "CENTER": cCenter
    of "TOP_BOTTOM": cStretch
    of "SCALE": cScale
    of "LEFT": cMin
    of "RIGHT": cMax
    of "LEFT_RIGHT": cStretch
    else: raise newException(FidgetError, "Invalid constraint kind:" & s)

proc enumHook(s: string, v: var GridAlign) =
  v = case s:
    of "STRETCH": gaStretch
    of "MIN": gaMin
    of "CENTER": gaCenter
    else: raise newException(FidgetError, "Invalid grid align:" & s)

proc enumHook(s: string, v: var LayoutAlign) =
  v = case s:
    of "INHERIT": laInherit
    of "STRETCH": laStretch
    else: raise newException(FidgetError, "Invalid layout align:" & s)

proc enumHook(s: string, v: var LayoutPattern) =
  v = case s:
    of "COLUMNS": lpColumns
    of "ROWS": lpRows
    of "GRID": lpGrid
    else: raise newException(FidgetError, "Invalid layout pattern:" & s)

proc enumHook(s: string, v: var LayoutMode) =
  v = case s:
    of "NONE": lmNone
    of "HORIZONTAL": lmHorizontal
    of "VERTICAL": lmVertical
    else: raise newException(FidgetError, "Invalid layout mode:" & s)

proc enumHook(s: string, v: var AxisSizingMode) =
  v = case s:
    of "AUTO": asAuto
    of "FIXED": asFixed
    else: raise newException(FidgetError, "Invalid axis sizing mode:" & s)

proc enumHook(s: string, v: var OverflowDirection) =
  v = case s:
    of "NONE": odNone
    of "HORIZONTAL_SCROLLING": odHorizontalScrolling
    of "VERTICAL_SCROLLING": odVerticalScrolling
    of "HORIZONTAL_AND_VERTICAL_SCROLLING": odHorizontalAndVerticalScrolling
    else: raise newException(FidgetError, "Invalid overflow direction:" & s)

import parseutils
proc parseHook(s: string, i: var int, v: var float32) =
  if i + 3 < s.len and s[i+0] == 'n' and s[i+1] == 'u' and s[i+2] == 'l' and s[i+3] == 'l':
    i += 4
    return
  var f: float
  eatSpace(s, i)
  let chars = parseutils.parseFloat(s, f, i)
  if chars == 0:
    echo s[i - 10 .. i + 10]
    echo "float error"
  i += chars
  v = f

proc parseHook(s: string, i: var int, v: var Vec2) =
  # Handle vectors some times having {x: null, y: null}.
  type Vec2Obj = object
    x: ref float32
    y: ref float32
  var vec2Obj: Vec2Obj
  parseHook(s, i, vec2Obj)
  if vec2Obj.x != nil and vec2Obj.y != nil:
    v = vec2(vec2Obj.x[], vec2Obj.y[])

proc parseHook(s: string, i: var int, v: var Path) =
  # Note: we parse more paths here than we use, keep this in mind
  # Also, Figma files can reference other files which may have tons of unused
  # paths in them
  var pathString: string
  parseHook(s, i, pathString)
  v = parsePath(pathString)

type FigmaNode = ref object
  # Basic Node properties
  id: string
  kind: NodeKind
  name: string
  children: seq[Node]
  parent: Node
  prototypeStartNodeID: string
  componentId: string

  # Transform
  size: Vec2
  relativeTransform: Option[Transform]

  # Shape
  fillGeometry: seq[Geometry]
  strokeWeight: float32
  strokeAlign: StrokeAlign
  strokeGeometry: seq[Geometry]
  cornerRadius: float32
  rectangleCornerRadii: Option[array[4, float32]]

  # Visual
  blendMode: BlendMode
  fills: seq[Paint]
  strokes: seq[Paint]
  effects: seq[Effect]
  opacity: Option[float32]
  visible: Option[bool]

  # Masking
  isMask: bool
  isMaskOutline: bool
  booleanOperation: BooleanOperation
  clipsContent: bool

  # Text
  characters: string
  style: TypeStyle
  characterStyleOverrides: seq[int]
  styleOverrideTable: Table[string, TypeStyle]

  # Layout
  constraints: LayoutConstraint
  layoutAlign: LayoutAlign
  layoutGrids: seq[LayoutGrid]
  layoutMode: LayoutMode
  itemSpacing: float32
  counterAxisSizingMode: AxisSizingMode
  paddingLeft: float32
  paddingRight: float32
  paddingTop: float32
  paddingBottom: float32
  overflowDirection: OverflowDirection

proc renameHook(node: var FigmaNode, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc parseHook(s: string, i: var int, node: var Node) =
  # Handle vectors some times having {x: null, y: null}.

  var f: FigmaNode
  parseHook(s, i, f)
  node = Node()

  node.visible = true
  node.opacity = 1.0

  node.id = f.id
  node.kind = f.kind

  node.name = f.name
  node.children = f.children
  node.parent = f.parent
  node.prototypeStartNodeID = f.prototypeStartNodeID
  node.componentId = f.componentId
  node.fillGeometry = f.fillGeometry
  node.strokeWeight = f.strokeWeight
  node.strokeAlign = f.strokeAlign
  node.strokeGeometry = f.strokeGeometry
  node.cornerRadius = f.cornerRadius
  if f.rectangleCornerRadii.isSome:
    node.rectangleCornerRadii = f.rectangleCornerRadii.get()
  node.blendMode = f.blendMode
  node.fills = f.fills
  node.strokes = f.strokes
  node.effects = f.effects
  if f.opacity.isSome:
    node.opacity = f.opacity.get()
  if f.visible.isSome:
    node.visible = f.visible.get()
  node.isMask = f.isMask
  node.isMaskOutline = f.isMaskOutline
  node.booleanOperation = f.booleanOperation
  node.clipsContent = f.clipsContent
  node.characters = f.characters
  node.style = f.style
  node.characterStyleOverrides = f.characterStyleOverrides
  node.styleOverrideTable = f.styleOverrideTable
  node.constraints = f.constraints
  node.layoutAlign = f.layoutAlign
  node.layoutGrids = f.layoutGrids
  node.layoutMode = f.layoutMode
  node.itemSpacing = f.itemSpacing
  node.counterAxisSizingMode = f.counterAxisSizingMode
  node.paddingLeft = f.paddingLeft
  node.paddingRight = f.paddingRight
  node.paddingTop = f.paddingTop
  node.paddingBottom = f.paddingBottom
  node.overflowDirection = f.overflowDirection

  if f.relativeTransform.isSome:
    # Take figma matrix transform and extract trs from it.
    let transform = f.relativeTransform.get()
    node.position = vec2(transform[0][2], transform[1][2])
    node.rotation = arctan2(transform[0][1], transform[0][0])
    node.scale = vec2(1, 1)
    # Extract the flips from the matrix:
    let
      actual = rotate(node.rotation)
      original = mat3(
        transform[0][0], transform[1][0], 0,
        transform[0][1], transform[1][1], 0,
        0, 0, 1,
      )
      residual = actual.inverse() * original
    if residual[0, 0] < 0:
      node.flipHorizontal = true
    if residual[1, 1] < 0:
      node.flipVertical = true
  node.size = f.size

  # Setup the child-parent relationship.
  for child in node.children:
    child.parent = node

  # Knowing original position and size is important for layout.
  node.orgPosition = node.position
  node.orgSize = node.size

  # Figma API can give us \r\n -> \n
  # TODO: that might effect styles.
  # node.characters = node.characters.replace("\r\n", "\n")

  # Node has never been drawn.
  node.dirty = true

proc parseFigmaFile*(data: string): FigmaFile =
  data.fromJson(FigmaFile)
