import tables, chroma, vmath, pixie, jsony, json, bumpy,
    httpclient, strutils, os, typography, strformat

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

  Device* = ref object
    `type`*: string
    rotation*: string

  Constraints* = ref object
    vertical*: string
    horizontal*: string

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
    boSubtract
    boIntersect
    boExclude
    boUnion

  StrokeAlign* = enum
    saInside
    saOutside
    saCenter

  Node* = ref object
    id*: string ## A string uniquely identifying this node within the document.
    name*: string ## The name given to the node by the user in the tool.
    kind*: NodeKind ## The type of the node, refer to table below for details.
    opacity*: float32
    visible*: bool ## default true, Whether or not the node is visible on the canvas.
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
    pixelBox*: Rect ## Pixel position and size.
    editable*: bool  ## Can the user edit the text?

  FigmaFile* = ref object
    document*: Node
    components*: Table[string, Component]
    schemaVersion*: int
    name*: string
    lastModified*: string
    thumbnailUrl*: string
    version*: string
    role*: string

var
  figmaFile*: FigmaFile
  figmaFileKey*: string

var imageRefToUrl: Table[string, string]

proc downloadImageRef*(imageRef: string) =
  if not fileExists("figma/images/" & imageRef & ".png"):
    if imageRef in imageRefToUrl:
      if not dirExists("figma/images"):
        createDir("figma/images")
      let url = imageRefToUrl[imageRef]
      echo "Downloading ", url
      var client = newHttpClient()
      let data = client.getContent(url)
      writeFile("figma/images/" & imageRef & ".png", data)

proc getImageRefs*(fileKey: string) =
  if not dirExists("figma/images"):
    createDir("figma/images")

  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "*/*"})
  client.headers["User-Agent"] = "curl/7.58.0"
  client.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey")

  let data = client.getContent("https://api.figma.com/v1/files/" & fileKey & "/images")
  writeFile("figma/images/images.json", data)

  let json = parseJson(data)
  for imageRef, url in json["meta"]["images"].pairs:
    imageRefToUrl[imageRef] = url.getStr()

proc downloadFont*(fontPSName: string) =
  if fileExists("figma/fonts/" & fontPSName & ".ttf"):
    return

  if not dirExists("figma/fonts"):
    createDir("figma/fonts")

  if not fileExists("figma/fonts/fonts.csv"):
    var client = newHttpClient()
    let data = client.getContent("https://raw.githubusercontent.com/treeform/freefrontfinder/master/fonts.csv")
    writeFile("figma/fonts/fonts.csv", data)

  for line in readFile("figma/fonts/fonts.csv").split("\n"):
    var line = line.split(",")
    if line[0] == fontPSName:
      let url = line[1]
      echo "Downloading ", url
      try:
        var client = newHttpClient()
        let data = client.getContent(url)
        writeFile("figma/fonts/" & fontPSName & ".ttf", data)
      except HttpRequestError:
        echo getCurrentExceptionMsg()
        echo &"Please download figma/fonts/{fontPSName}.ttf"
      return

  echo &"Please download figma/fonts/{fontPSName}.ttf"

proc figmaClient(): HttpClient =
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "*/*"})
  client.headers["User-Agent"] = "curl/7.58.0"
  client.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey").strip()
  return client

proc download(figmaFileKey: string) =
  let jsonPath = &"figma/{figmaFileKey}.json"
  let modifiedPath = &"figma/{figmaFileKey}.lastModified"
  if fileExists(modifiedPath):
    ## Check if we really need to download the whole thing.
    let
      data1 = figmaClient().getContent("https://api.figma.com/v1/files/" & figmaFileKey & "?depth=1")
      figmaModified = parseJson(data1)["lastModified"].getStr()
      haveModified = readFile(modifiedPath)
    if figmaModified == haveModified:
      echo "Using cached"
      return
  let data = figmaClient().getContent("https://api.figma.com/v1/files/" & figmaFileKey & "?geometry=paths")
  let json = parseJson(data)
  writeFile(modifiedPath, json["lastModified"].getStr())
  writeFile(jsonPath, pretty(json))
  getImageRefs(figmaFileKey)

proc newHook(v: var Node) =
  v = Node()
  v.visible = true
  v.opacity = 1.0

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
    of "UPPER":  tcUpper
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


proc use*(url: string) =
  if not dirExists("figma"):
    createDir("figma")
  let figmaFileKey = url.split("/")[4]
  download(figmaFileKey)
  var data = readFile(&"figma/{figmaFileKey}.json")
  figmaFile = fromJson[FigmaFile](data)

proc useNodeFile*(filePath: string) =
  var data = readFile(filePath)
  echo data
  figmaFile = FigmaFile()
  figmaFile.document = Node()
  figmaFile.document.children = fromJson[seq[Node]](data)
