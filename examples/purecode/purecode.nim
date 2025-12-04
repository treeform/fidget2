# This example shows how to construct your own nodes
# and attach handlers to them with pure code, no Figma needed.
# We will make a menu with a buttons.

import
  std/[options],
  fidget2,
  chroma, vmath, pixie

# Create helper procs to make Paint and TypeStyle objects
proc newSolidPaint(color: Color, opacity: float32 = 1.0): schema.Paint =
  result = schema.Paint()
  result.kind = pkSolid
  result.color = color
  result.opacity = opacity
  result.visible = true
  result.blendMode = NormalBlend

proc newButtonStyle(): TypeStyle =
  result = TypeStyle()
  result.fontFamily = "Jura"
  result.fontPostScriptName = "Jura-Bold"
  result.fontWeight = 700
  result.fontSize = 13.0
  result.textAlignHorizontal = CenterAlign
  result.textAlignVertical = MiddleAlign
  result.letterSpacing = 0.0
  result.lineHeightPx = 15.378999710083008
  result.lineHeightPercent = 100.0
  result.lineHeightUnit = some(IntrinsicPercentUnit)

proc newButtonConstraints(): LayoutConstraint =
  result = LayoutConstraint()
  result.vertical = MinConstraint
  result.horizontal = MinConstraint

var audoID = 0
proc newNode(name: string, kind: NodeKind): Node =
  ## Initialize common node properties
  var node = INode()
  node.id = "auto:" & $audoID
  inc audoID
  node.name = name
  node.kind = kind
  node.visible = true
  node.opacity = 1.0
  node.scale = vec2(1, 1)
  node.dirty = true
  node.strokeWeight = 1.0
  node.strokeAlign = InsideStroke
  node.blendMode = NormalBlend
  node.constraints = newButtonConstraints()
  return Node(node)

# Create the FigmaFile object and set it as the global figmaFile
figmaFile = FigmaFile()
figmaFile.name = "Purecode"

# Create the document structure manually
let documentNode = newNode("Document", DocumentNode)
figmaFile.document = documentNode.internal

let canvasNode = newNode("UI", CanvasNode)
documentNode.addChild(canvasNode)

let menuFrame = newNode("Menu", FrameNode)
menuFrame.origPosition = vec2(0.0, 0.0)
menuFrame.origSize = vec2(283.0, 338.0)
menuFrame.position = menuFrame.position
menuFrame.size = menuFrame.size
menuFrame.clipsContent = true
menuFrame.layoutMode = VerticalLayout
menuFrame.counterAxisSizingMode = FixedAxis
menuFrame.paddingLeft = 51.0
menuFrame.paddingRight = 51.0
menuFrame.paddingTop = 39.0
menuFrame.paddingBottom = 39.0
menuFrame.itemSpacing = 20.0
menuFrame.fills = @[newSolidPaint(color(0.55, 0.48, 0.87, 1.0))]
canvasNode.addChild(menuFrame)

# Create New Game button
let newGameButton = newNode("NewGame", FrameNode)
newGameButton.position = vec2(51.0, 39.0)
newGameButton.size = vec2(181.0, 50.0)
newGameButton.origPosition = newGameButton.position
newGameButton.origSize = newGameButton.size
newGameButton.clipsContent = true
newGameButton.fills = @[newSolidPaint(color(1.0, 1.0, 1.0, 0.7))]
newGameButton.strokes = @[newSolidPaint(color(1.0, 1.0, 1.0, 1.0))]
newGameButton.cornerRadius = 44.0
newGameButton.strokeWeight = 4.0
newGameButton.strokeAlign = InsideStroke
newGameButton.layoutAlign = StretchLayout
newGameButton.constraints = newButtonConstraints()
menuFrame.addChild(newGameButton)

let newGameText = newNode("text", TextNode)
newGameText.position = vec2(0.0, 0.0)
newGameText.size = vec2(180.0, 50.0)
newGameText.origPosition = newGameText.position
newGameText.origSize = newGameText.size
newGameText.style = newButtonStyle()
newGameText.fills = @[newSolidPaint(color(0.0, 0.0, 0.0, 1.0))]
newGameText.text = "New Game"
newGameText.strokeAlign = OutsideStroke
newGameText.constraints = newButtonConstraints()
newGameButton.addChild(newGameText)

# Create Continue Game button
let continueButton = newNode("ContinueGame", FrameNode)
continueButton.position = vec2(51.0, 109.0)
continueButton.size = vec2(181.0, 50.0)
continueButton.origPosition = continueButton.position
continueButton.origSize = continueButton.size
continueButton.clipsContent = true
continueButton.fills = @[newSolidPaint(color(1.0, 1.0, 1.0, 0.7))]
continueButton.strokes = @[newSolidPaint(color(1.0, 1.0, 1.0, 1.0))]
continueButton.cornerRadius = 44.0
continueButton.strokeWeight = 4.0
continueButton.strokeAlign = InsideStroke
continueButton.layoutAlign = StretchLayout
menuFrame.addChild(continueButton)

let continueText = newNode("text", TextNode)
continueText.position = vec2(0.0, 0.0)
continueText.size = vec2(180.0, 50.0)
continueText.origPosition = continueText.position
continueText.origSize = continueText.size
continueText.style = newButtonStyle()
continueText.fills = @[newSolidPaint(color(0.0, 0.0, 0.0, 1.0))]
continueText.text = "Continue"
continueText.strokeAlign = OutsideStroke
continueButton.addChild(continueText)

# Create Settings button
let settingsButton = newNode("Settings", FrameNode)
settingsButton.position = vec2(51.0, 179.0)
settingsButton.size = vec2(181.0, 50.0)
settingsButton.origPosition = settingsButton.position
settingsButton.origSize = settingsButton.size
settingsButton.clipsContent = true
settingsButton.fills = @[newSolidPaint(color(1.0, 1.0, 1.0, 0.7))]
settingsButton.strokes = @[newSolidPaint(color(1.0, 1.0, 1.0, 1.0))]
settingsButton.cornerRadius = 44.0
settingsButton.strokeWeight = 4.0
settingsButton.strokeAlign = InsideStroke
settingsButton.layoutAlign = StretchLayout
menuFrame.addChild(settingsButton)

let settingsText = newNode("text", TextNode)
settingsText.position = vec2(0.0, 0.0)
settingsText.size = vec2(180.0, 50.0)
settingsText.origPosition = settingsText.position
settingsText.origSize = settingsText.size
settingsText.style = newButtonStyle()
settingsText.fills = @[newSolidPaint(color(0.0, 0.0, 0.0, 1.0))]
settingsText.text = "Settings"
settingsText.strokeAlign = OutsideStroke
settingsButton.addChild(settingsText)

# Create Quit button
let quitButton = newNode("Quit", FrameNode)
quitButton.position = vec2(51.0, 249.0)
quitButton.size = vec2(181.0, 50.0)
quitButton.origPosition = quitButton.position
quitButton.origSize = quitButton.size
quitButton.clipsContent = true
quitButton.fills = @[newSolidPaint(color(1.0, 1.0, 1.0, 0.7))]
quitButton.strokes = @[newSolidPaint(color(1.0, 1.0, 1.0, 1.0))]
quitButton.cornerRadius = 44.0
quitButton.strokeWeight = 4.0
quitButton.strokeAlign = InsideStroke
quitButton.layoutAlign = StretchLayout
menuFrame.addChild(quitButton)

let quitText = newNode("text", TextNode)
quitText.position = vec2(0.0, 0.0)
quitText.size = vec2(180.0, 50.0)
quitText.origPosition = quitText.position
quitText.origSize = quitText.size
quitText.style = newButtonStyle()
quitText.fills = @[newSolidPaint(color(0.0, 0.0, 0.0, 1.0))]
quitText.text = "Quit"
quitText.strokeAlign = OutsideStroke
quitButton.addChild(quitText)

# Set up event handlers
find "/UI/Menu":
  find "NewGame":
    onClick:
      echo "Play button clicked"
  find "ContinueGame":
    onClick:
      echo "Options button clicked"
  find "Settings":
    onClick:
      echo "Settings button clicked"
  find "Quit":
    onClick:
      echo "Quit button clicked"
      quit()

# Start fidget with the manually created document using the new API
startFidget(
  figmaFile = figmaFile,
  windowTitle = "Menu",
  entryFrame = "/UI/Menu",
  windowStyle = Decorated
)
while isRunning():
  tickFidget()
closeFidget()
