import
  std/[options, parseutils, strutils, tables],
  bumpy, chroma, jsony, pixie, vmath,
  common

type
  NodeKind* = enum
    DocumentNode, CanvasNode
    RectangleNode, FrameNode, GroupNode, ComponentNode, InstanceNode
    VectorNode, StarNode, EllipseNode, LineNode, RegularPolygonNode
    TextNode
    BooleanOperationNode
    ComponentSetNode
    SliceNode

  Component* = ref object
    key*: string
    name*: string
    description*: string

  ConstraintKind* = enum
    MinConstraint
    MaxConstraint
    ScaleConstraint
    StretchConstraint
    CenterConstraint

  LayoutConstraint* = ref object
    vertical*: ConstraintKind
    horizontal*: ConstraintKind

  LayoutAlign* = enum
    InheritLayout
    StretchLayout

  PaintKind* = enum
    pkSolid
    pkImage
    pkGradientLinear
    pkGradientRadial
    pkGradientAngular
    pkGradientDiamond

  ScaleMode* = enum
    FillScaleMode
    FitScaleMode
    StretchScaleMode
    TileScaleMode

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
    DropShadow
    InnerShadow
    LayerBlur
    BackgroundBlur

  Effect* = object
    kind*: EffectKind
    visible*: bool
    color*: Color
    blendMode*: BlendMode
    offset*: Vec2
    radius*: float32
    spread*: float32

  LayoutMode* = enum
    NoneLayout
    HorizontalLayout
    VerticalLayout

  LayoutPattern* = enum
    ColumnsLayoutPattern
    RowsLayoutPattern
    GridLayoutPattern

  GridAlign* = enum
    MinGridAlign
    StretchGridAlign
    CenterGridAlign

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
    FixedTextResize
    HeightTextResize
    WidthAndHeightTextResize

  TextDecoration* = enum
    Strikethrough
    Underline

  LineHeightUnit* = enum
    PixelUnit
    FontSizePercentUnit
    IntrinsicPercentUnit

  LeadingTrim* = enum
    NoLeadingTrim
    CapHeight

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
    leadingTrim*: LeadingTrim

  Geometry* = object
    path*: Path
    windingRule*: WindingRule

    mat*: Mat3 # NOT FROM FIGMA
    cached*: bool
    shapes*: seq[seq[Vec2]]
    shapesBounds*: Rect

  BooleanOperation* = enum
    UnionOperation
    SubtractOperation
    IntersectOperation
    ExcludeOperation

  StrokeAlign* = enum
    InsideStroke
    OutsideStroke
    CenterStroke

  AxisSizingMode* = enum
    AutoAxis
    FixedAxis

  OverflowDirection* = enum
    NoScrolling
    HorizontalScrolling
    VerticalScrolling
    HorizontalAndVerticalScrolling

  INode* = ref object
    ## Internal node object, only fidget uses this node directly,
    ## other code should use the Node type.

    # Basic Node properties
    id*: string     ## A string uniquely identifying this node.
    kind*: NodeKind ## The type of the node, refer to table below for details.
    name*: string   ## The name given to the node by the user in the tool.
    children*: seq[INode]
    parent*: INode
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
    singleline*: bool  # Single line mode (no wrapping, horizontal scroll).
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
    dirty*: bool = true ## Do the pixels need redrawing?
    pixels*: Image      ## Pixel image cache.
    pixelBox*: Rect     ## Pixel position and size.
    editable*: bool     ## Can the user edit the text?
    origPosition*: Vec2  ## Original position used by constraints.
    origSize*: Vec2      ## Original size used by constraints.
    idNum*: int         ## Integer ID of the node
    mat*: Mat3          ## Useful to get back to the node.
    collapse*: bool     ## Is the node drawn as a single texture (CPU internals)
    shown*: bool        ## for onShow/onHide events.
    scrollable*: bool   ## Can this node scroll.
    scrollPos*: Vec2    ## How does it scroll it's children.

    # Event handling
    onRenderCallback*: proc(thisNode: INode)

    # User defined data.
    userKey*: string
    userId*: int

  FigmaFile* = ref object
    document*: INode
    components*: Table[string, Component]
    schemaVersion*: int
    name*: string
    lastModified*: string
    thumbnailUrl*: string
    version*: string
    role*: string

proc `$`*(node: INode): string =
  ## Returns a string representation of a node.
  "<" & $node.kind & ": " & node.name & " (" & node.id & ")>"

proc path*(node: INode): string =
  ## Returns the full path of the node back to the root.
  var walkNode = node
  while walkNode != nil and walkNode.kind != DocumentNode:
    result = "/" & walkNode.name & result
    walkNode = walkNode.parent

proc similar*(a: Paint, b: Paint): bool =
  ## Checks if two Paint objects are similar.
  if a.isNil or b.isNil:
    return a == b
  result =
    a.kind == b.kind and
    a.visible == b.visible and
    a.opacity == b.opacity and
    a.color == b.color and
    a.scaleMode == b.scaleMode and
    a.imageRef == b.imageRef and
    a.imageTransform == b.imageTransform and
    a.scalingFactor == b.scalingFactor and
    a.rotation == b.rotation and
    a.gradientHandlePositions == b.gradientHandlePositions and
    a.gradientStops == b.gradientStops

proc newHook(v: var Paint) =
  ## Jsony hook to initialize a new Paint object.
  v = Paint()
  v.visible = true
  v.opacity = 1.0

proc newHook(v: var TypeStyle) =
  ## Jsony hook to initialize a new TypeStyle object.
  v = TypeStyle()
  v.lineHeightPercent = 100
  v.opentypeFlags.KERN = 1

proc newHook(v: var LayoutGrid) =
  ## Jsony hook to initialize a new LayoutGrid object.
  v.visible = true

proc newHook(v: var Geometry) =
  ## Jsony hook to initialize a new Geometry object.
  v.mat = mat3()

proc renameHook(v: var Paint, fieldName: var string) =
  ## Jsony hook to rename fields during JSON parsing for Paint objects.
  if fieldName == "type":
    fieldName = "kind"

proc renameHook(v: var Effect, fieldName: var string) =
  ## Jsony hook to rename fields during JSON parsing for Effect objects.
  if fieldName == "type":
    fieldName = "kind"

proc renameHook(v: var Rect, fieldName: var string) =
  ## Jsony hook to rename fields during JSON parsing for Rect objects.
  if fieldName == "width":
    fieldName = "w"
  if fieldName == "height":
    fieldName = "h"

proc enumHook(s: string, v: var BlendMode) =
  ## Jsony hook to convert string to BlendMode enum during JSON parsing.
  v = case s:
    of "PASS_THROUGH": NormalBlend
    of "NORMAL": NormalBlend
    of "DARKEN": DarkenBlend
    of "MULTIPLY": MultiplyBlend
    # of "LINEAR_BURN": bmLinearBurn
    of "COLOR_BURN": ColorBurnBlend
    of "LIGHTEN": LightenBlend
    of "SCREEN": ScreenBlend
    # of "LINEAR_DODGE": bmLinearDodge
    of "COLOR_DODGE": ColorDodgeBlend
    of "OVERLAY": OverlayBlend
    of "SOFT_LIGHT": SoftLightBlend
    of "HARD_LIGHT": HardLightBlend
    of "DIFFERENCE": DifferenceBlend
    of "EXCLUSION": ExclusionBlend
    of "HUE": HueBlend
    of "SATURATION": SaturationBlend
    of "COLOR": ColorBlend
    of "LUMINOSITY": LuminosityBlend
    else: raise newException(PixieError, "Unsupported blend mode: " & s)

proc enumHook(s: string, v: var TextCase) =
  ## Jsony hook to convert string to TextCase enum during JSON parsing.
  v = case s:
    of "UPPER": UpperCase
    of "LOWER": LowerCase
    of "TITLE": TitleCase
    # TODO add:
    # of "SMALL_CAPS": tcSmallCaps
    # of "SMALL_CAPS_FORCED": tcCapsForced
    else: NormalCase

proc enumHook(s: string, v: var NodeKind) =
  ## Jsony hook to convert string to NodeKind enum during JSON parsing.
  v = case s:
    of "DOCUMENT": DocumentNode
    of "CANVAS": CanvasNode
    of "RECTANGLE": RectangleNode
    of "FRAME": FrameNode
    of "GROUP": GroupNode
    of "COMPONENT": ComponentNode
    of "INSTANCE": InstanceNode
    of "VECTOR": VectorNode
    of "STAR": StarNode
    of "ELLIPSE": EllipseNode
    of "LINE": LineNode
    of "REGULAR_POLYGON": RegularPolygonNode
    of "TEXT": TextNode
    of "BOOLEAN_OPERATION": BooleanOperationNode
    of "COMPONENT_SET": ComponentSetNode
    of "SLICE": SliceNode
    else: raise newException(FidgetError, "Invalid node type:" & s)

proc enumHook(s: string, v: var PaintKind) =
  ## Jsony hook to convert string to PaintKind enum during JSON parsing.
  v = case s:
    of "SOLID": pkSolid
    of "IMAGE": pkImage
    of "GRADIENT_LINEAR": pkGradientLinear
    of "GRADIENT_RADIAL": pkGradientRadial
    of "GRADIENT_ANGULAR": pkGradientAngular
    of "GRADIENT_DIAMOND": pkGradientDiamond
    else: raise newException(FidgetError, "Invalid paint type:" & s)

proc enumHook(s: string, v: var EffectKind) =
  ## Jsony hook to convert string to EffectKind enum during JSON parsing.
  v = case s:
    of "DROP_SHADOW": DropShadow
    of "INNER_SHADOW": InnerShadow
    of "LAYER_BLUR": LayerBlur
    of "BACKGROUND_BLUR": BackgroundBlur
    else: raise newException(FidgetError, "Invalid effect type:" & s)

proc enumHook(s: string, v: var BooleanOperation) =
  ## Jsony hook to convert string to BooleanOperation enum during JSON parsing.
  v = case s:
    of "SUBTRACT": SubtractOperation
    of "INTERSECT": IntersectOperation
    of "EXCLUDE": ExcludeOperation
    of "UNION": UnionOperation
    else: raise newException(FidgetError, "Invalid boolean operation:" & s)

proc enumHook(s: string, v: var ScaleMode) =
  ## Jsony hook to convert string to ScaleMode enum during JSON parsing.
  v = case s:
    of "FILL": FillScaleMode
    of "FIT": FitScaleMode
    of "STRETCH": StretchScaleMode
    of "TILE": TileScaleMode
    else: raise newException(FidgetError, "Invalid scale mode:" & s)

proc enumHook(s: string, v: var TextAutoResize) =
  ## Jsony hook to convert string to TextAutoResize enum during JSON parsing.
  v = case s:
    of "HEIGHT": HeightTextResize
    of "WIDTH_AND_HEIGHT": WidthAndHeightTextResize
    else: raise newException(FidgetError, "Invalid text auto resize:" & s)

proc enumHook(s: string, v: var TextDecoration) =
  ## Jsony hook to convert string to TextDecoration enum during JSON parsing.
  v = case s:
    of "STRIKETHROUGH": Strikethrough
    of "UNDERLINE": Underline
    else: raise newException(FidgetError, "Invalid text decoration:" & s)

proc enumHook(s: string, v: var LineHeightUnit) =
  ## Jsony hook to convert string to LineHeightUnit enum during JSON parsing.
  v = case s:
    of "PIXELS": PixelUnit
    of "FONT_SIZE_%": FontSizePercentUnit
    of "INTRINSIC_%": IntrinsicPercentUnit
    else: raise newException(FidgetError, "Invalid text line height unit:" & s)

proc enumHook(s: string, v: var LeadingTrim) =
  ## Jsony hook to convert string to LeadingTrim enum during JSON parsing.
  v = case s:
    of "NONE": NoLeadingTrim
    of "CAP_HEIGHT": CapHeight
    else: raise newException(FidgetError, "Invalid leading trim:" & s)

proc enumHook(s: string, v: var StrokeAlign) =
  ## Jsony hook to convert string to StrokeAlign enum during JSON parsing.
  v = case s:
    of "INSIDE": InsideStroke
    of "OUTSIDE": OutsideStroke
    of "CENTER": CenterStroke
    else: raise newException(FidgetError, "Invalid stroke align:" & s)

proc enumHook(s: string, v: var HorizontalAlignment) =
  ## Jsony hook to convert string to HorizontalAlignment enum during JSON parsing.
  v = case s:
    of "CENTER": CenterAlign
    of "LEFT": LeftAlign
    of "RIGHT": RightAlign
    else: raise newException(FidgetError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var VerticalAlignment) =
  ## Jsony hook to convert string to VerticalAlignment enum during JSON parsing.
  v = case s:
    of "CENTER": MiddleAlign
    of "TOP": TopAlign
    of "BOTTOM": BottomAlign
    else: raise newException(FidgetError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var WindingRule) =
  ## Jsony hook to convert string to WindingRule enum during JSON parsing.
  v = case s:
    of "EVENODD": EvenOdd
    of "NONZERO": NonZero
    else: raise newException(FidgetError, "Invalid winding rule:" & s)

proc enumHook(s: string, v: var ConstraintKind) =
  ## Jsony hook to convert string to ConstraintKind enum during JSON parsing.
  v = case s:
    of "TOP": MinConstraint
    of "BOTTOM": MaxConstraint
    of "CENTER": CenterConstraint
    of "TOP_BOTTOM": StretchConstraint
    of "SCALE": ScaleConstraint
    of "LEFT": MinConstraint
    of "RIGHT": MaxConstraint
    of "LEFT_RIGHT": StretchConstraint
    else: raise newException(FidgetError, "Invalid constraint kind:" & s)

proc enumHook(s: string, v: var GridAlign) =
  ## Jsony hook to convert string to GridAlign enum during JSON parsing.
  v = case s:
    of "STRETCH": StretchGridAlign
    of "MIN": MinGridAlign
    of "CENTER": CenterGridAlign
    else: raise newException(FidgetError, "Invalid grid align:" & s)

proc enumHook(s: string, v: var LayoutAlign) =
  ## Jsony hook to convert string to LayoutAlign enum during JSON parsing.
  v = case s:
    of "INHERIT": InheritLayout
    of "STRETCH": StretchLayout
    else: raise newException(FidgetError, "Invalid layout align:" & s)

proc enumHook(s: string, v: var LayoutPattern) =
  ## Jsony hook to convert string to LayoutPattern enum during JSON parsing.
  v = case s:
    of "COLUMNS": ColumnsLayoutPattern
    of "ROWS": RowsLayoutPattern
    of "GRID": GridLayoutPattern
    else: raise newException(FidgetError, "Invalid layout pattern:" & s)

proc enumHook(s: string, v: var LayoutMode) =
  ## Jsony hook to convert string to LayoutMode enum during JSON parsing.
  v = case s:
    of "NONE": NoneLayout
    of "HORIZONTAL": HorizontalLayout
    of "VERTICAL": VerticalLayout
    else: raise newException(FidgetError, "Invalid layout mode:" & s)

proc enumHook(s: string, v: var AxisSizingMode) =
  ## Jsony hook to convert string to AxisSizingMode enum during JSON parsing.
  v = case s:
    of "AUTO": AutoAxis
    of "FIXED": FixedAxis
    else: raise newException(FidgetError, "Invalid axis sizing mode:" & s)

proc enumHook(s: string, v: var OverflowDirection) =
  ## Jsony hook to convert string to OverflowDirection enum during JSON parsing.
  v = case s:
    of "NONE": NoScrolling
    of "HORIZONTAL_SCROLLING": HorizontalScrolling
    of "VERTICAL_SCROLLING": VerticalScrolling
    of "HORIZONTAL_AND_VERTICAL_SCROLLING": HorizontalAndVerticalScrolling
    else: raise newException(FidgetError, "Invalid overflow direction:" & s)

proc parseHook(s: string, i: var int, v: var float32) =
  ## Parses float32 values, handling null values.
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
  ## Parses Vec2 values, handling null coordinates.
  # Handle vectors sometimes having {x: null, y: null}.
  type Vec2Obj = object
    x: ref float32
    y: ref float32
  var vec2Obj: Vec2Obj
  parseHook(s, i, vec2Obj)
  if vec2Obj.x != nil and vec2Obj.y != nil:
    v = vec2(vec2Obj.x[], vec2Obj.y[])

proc parseHook(s: string, i: var int, v: var Path) =
  ## Parses Path values from JSON.
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
  children: seq[INode]
  parent: INode
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
  ## Jsony hook to rename fields during JSON parsing for FigmaNode objects.
  if fieldName == "type":
    fieldName = "kind"

proc parseHook(s: string, i: var int, node: var INode) =
  ## Jsony hook to parse Node objects from JSON with special handling.
  # Handle vectors sometimes having {x: null, y: null}.

  var f: FigmaNode
  parseHook(s, i, f)
  node = INode()

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
  node.origPosition = node.position
  node.origSize = node.size

  # Figma API can give us \r\n -> \n
  # TODO: that might affect styles.
  # node.characters = node.characters.replace("\r\n", "\n")

  # Node has never been drawn.
  node.dirty = true


proc parseFigmaFile*(data: string): FigmaFile =
  ## Parses a Figma file from JSON data.
  data.fromJson(FigmaFile)
