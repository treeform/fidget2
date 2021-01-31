import bumpy, chroma, jsony, pixie, strutils, tables, typography, vmath

type
  FidgetError* = object of ValueError ## Raised if an operation fails.

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

  Device* = ref object
    `type`*: string
    rotation*: string

  ConstraintsKind* = enum
    cMin
    cMax
    cScale
    cStretch
    cCenter

  Constraints* = ref object
    vertical*: ConstraintsKind
    horizontal*: ConstraintsKind

  GradientStops* = ref object
    color*: Color
    position*: float32

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

  Paint* = ref object
    blendMode*: BlendMode
    kind*: PaintKind
    visible*: bool
    opacity*: float32
    color*: Color
    scaleMode*: ScaleMode
    imageRef*: string
    imageTransform*: seq[seq[float32]]
    scalingFactor*: float32
    gradientHandlePositions*: seq[Vec2]
    gradientStops*: seq[GradientStops]

  EffectKind* = enum
    ekDropShadow
    ekInnerShadow
    ekLayerBlur
    ekBackgroundBlur

  Effect* = ref object
    kind*: EffectKind
    visible*: bool
    color*: Color
    blendMode*: BlendMode
    offset*: Vec2
    radius*: float32
    spread*: float32

  Grid* = ref object
    `type`*: string

  CharacterStyleOverrides* = ref object
    `type`*: string

  OpenTypeFlags* = ref object
    KERN*: int

  TextAutoResize* = enum
    tarHeight
    tarWidthAndHeight

  TextStyle* = ref object
    fontFamily*: string
    fontPostScriptName*: string
    fontWeight*: float32
    textAutoResize*: TextAutoResize
    fontSize*: float32
    textAlignHorizontal*: HAlignMode
    textAlignVertical*: VAlignMode
    letterSpacing*: float32
    lineHeightPx*: float32
    lineHeightPercent*: float32
    lineHeightUnit*: string
    textCase*: TextCase
    opentypeFlags*: OpenTypeFlags

  Geometry* = ref object
    path*: string
    windingRule*: WindingRule

  BooleanOperation* = enum
    boUnion
    boSubtract
    boIntersect
    boExclude

  StrokeAlign* = enum
    saInside
    saOutside
    saCenter

  Node* = ref object
    id*: string     ## A string uniquely identifying this node within the document.
    name*: string   ## The name given to the node by the user in the tool.
    kind*: NodeKind ## The type of the node, refer to table below for details.
    opacity*: float32
    visible*: bool  ## default true, Whether or not the node is visible on the canvas.
    #pluginData: JsonNode ## Data written by plugins that is visible only to the plugin that wrote it. Requires the `pluginData` to include the ID of the plugin.
    #sharedPluginData: JsonNode ##  Data written by plugins that is visible to all plugins. Requires the `pluginData` parameter to include the string "shared".
    blendMode*: BlendMode
    children*: seq[Node]
    prototypeStartNodeID*: string
    prototypeDevice*: Device
    absoluteBoundingBox*: Rect
    size*: Vec2
    relativeTransform*: seq[seq[float32]]
    constraints*: Constraints
    layoutAlign*: string
    clipsContent*: bool
    background*: seq[Paint]
    fills*: seq[Paint]
    strokes*: seq[Paint]
    strokeWeight*: float32
    strokeAlign*: StrokeAlign
    backgroundColor*: Color
    layoutGrids*: seq[Grid]
    layoutMode*: string
    itemSpacing*: float32
    effects*: seq[Effect]
    isMask*: bool
    cornerRadius*: float32
    rectangleCornerRadii*: seq[float32]
    characters*: string
    style*: TextStyle
    #characterStyleOverrides: seq[CharacterStyleOverrides]
    #styleOverrideTable:
    fillGeometry*: seq[Geometry]
    strokeGeometry*: seq[Geometry]
    booleanOperation*: BooleanOperation

    # Non figma parameters:
    dirty*: bool     ## Do the pixels need redrawing?
    pixels*: Image   ## Pixel image cache.
    pixelBox*: Rect  ## Pixel position and size.
    editable*: bool  ## Can the user edit the text?
    box*: Rect       ## xy/size of the node.
    orgBox*: Rect    ## Original size needed for constraints.
    idNum*: int

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

proc newHook(v: var Node) =
  v = Node()
  v.visible = true
  v.opacity = 1.0

proc postHook(v: var Node) =
  if v.relativeTransform.len > 0:
    v.box.xy = vec2(v.relativeTransform[0][2], v.relativeTransform[1][2])
  v.box.wh = v.size
  v.orgBox = v.box

proc renameHook(v: var Node, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc newHook(v: var Paint) =
  v = Paint()
  v.visible = true
  v.opacity = 1.0

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
    of "LINEAR_BURN": bmLinearBurn
    of "COLOR_BURN": bmColorBurn
    of "LIGHTEN": bmLighten
    of "SCREEN": bmScreen
    of "LINEAR_DODGE": bmLinearDodge
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
    else: bmNormal

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
    else: raise newException(ValueError, "Invalid node type:" & s)

proc enumHook(s: string, v: var PaintKind) =
  v = case s:
    of "SOLID": pkSolid
    of "IMAGE": pkImage
    of "GRADIENT_LINEAR": pkGradientLinear
    of "GRADIENT_RADIAL": pkGradientRadial
    of "GRADIENT_ANGULAR": pkGradientAngular
    of "GRADIENT_DIAMOND": pkGradientDiamond
    else: raise newException(ValueError, "Invalid paint type:" & s)

proc enumHook(s: string, v: var EffectKind) =
  v = case s:
    of "DROP_SHADOW": ekDropShadow
    of "INNER_SHADOW": ekInnerShadow
    of "LAYER_BLUR": ekLayerBlur
    of "BACKGROUND_BLUR": ekBackgroundBlur
    else: raise newException(ValueError, "Invalid effect type:" & s)

proc enumHook(s: string, v: var BooleanOperation) =
  v = case s:
    of "SUBTRACT": boSubtract
    of "INTERSECT": boIntersect
    of "EXCLUDE": boExclude
    of "UNION": boUnion
    else: raise newException(ValueError, "Invalid effect type:" & s)

proc enumHook(s: string, v: var ScaleMode) =
  v = case s:
    of "FILL": smFill
    of "FIT": smFit
    of "STRETCH": smStretch
    of "TILE": smTile
    else: raise newException(ValueError, "Invalid effect type:" & s)

proc enumHook(s: string, v: var TextAutoResize) =
  v = case s:
    of "HEIGHT": tarHeight
    of "WIDTH_AND_HEIGHT": tarWidthAndHeight
    else: raise newException(ValueError, "Invalid text auto resize:" & s)

proc enumHook(s: string, v: var StrokeAlign) =
  v = case s:
    of "INSIDE": saInside
    of "OUTSIDE": saOutside
    of "CENTER": saCenter
    else: raise newException(ValueError, "Invalid stroke align:" & s)

proc enumHook(s: string, v: var HAlignMode) =
  v = case s:
    of "CENTER": Center
    of "LEFT": Left
    of "RIGHT": Right
    else: raise newException(ValueError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var VAlignMode) =
  v = case s:
    of "CENTER": Middle
    of "TOP": Top
    of "BOTTOM": Bottom
    else: raise newException(ValueError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var WindingRule) =
  v = case s:
    of "EVENODD": wrEvenOdd
    of "NONZERO": wrNonZero
    else: raise newException(ValueError, "Invalid text align mode:" & s)

proc enumHook(s: string, v: var ConstraintsKind) =
  v = case s:
    of "TOP": cMin
    of "BOTTOM": cMax
    of "CENTER": cCenter
    of "TOP_BOTTOM": cStretch
    of "SCALE": cScale
    of "LEFT": cMin
    of "RIGHT": cMax
    of "LEFT_RIGHT": cStretch
    else: raise newException(ValueError, "Invalid text align mode:" & s)

proc parseFigmaFile*(data: string): FigmaFile =
  data.fromJson(FigmaFile)

proc markDirty*(node: Node, value = true) =
  ## Marks the entire tree dirty or not dirty.
  node.dirty = value
  for c in node.children:
    markDirty(c, value)

proc checkDirty*(node: Node) =
  ## Makes sure if children are dirty, parents are dirty too!
  for c in node.children:
    checkDirty(c)
    if c.dirty == true:
      node.dirty = true
