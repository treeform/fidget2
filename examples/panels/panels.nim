# This example shows a draggable panel UI like in a large editor like VS Code or Blender.

import
  std/random,
  fidget2, bumpy

type
  AreaLayout = enum
    Horizontal
    Vertical

  Area = ref object
    node: Node              ## The node of the area.
    layout: AreaLayout      ## The layout of the area.
    areas: seq[Area]        ## The subareas in the area (0 or 2)
    panels: seq[Panel]      ## The panels in the area.
    rect: Rect              ## The position and size of the area in window percentages.
    split: float32          ## The split percentage of the area.
    selectedPanelNum: int   ## The index of the selected panel in the area.

  Panel = ref object
    name: string            ## The name of the panel.
    header: Node            ## The header of the panel.
    node: Node              ## The node of the panel.
    parentArea: Area        ## The parent area of the panel.

var
  areaTemplate: Node
  panelHeaderTemplate: Node
  panelTemplate: Node
  rootArea: Area

proc findPanelByHeader*(node: Node): Panel =
  ## Finds the panel that contains the given header node.
  proc visit(area: Area, node: Node): Panel =
    for panel in area.panels:
      if panel.header == node:
        return panel
    for subarea in area.areas:
      let panel = visit(subarea, node)
      if panel != nil:
        return panel
    return nil
  return visit(rootArea, node)

proc addPanel*(area: Area, name: string) =
  let panel = Panel(name: name)
  panel.header = panelHeaderTemplate.copy()
  panel.header.find("title").text = name
  panel.node = panelTemplate.copy()
  area.panels.add(panel)
  panel.parentArea = area
  area.node.find("Header").addChild(panel.header)
  area.node.addChild(panel.node)

proc split*(area: Area, layout: AreaLayout) =
  let
    area1 = Area(node: areaTemplate.copy())
    area2 = Area(node: areaTemplate.copy())
  area.layout = layout
  area.split = 0.5
  area.areas.add(area1)
  area.areas.add(area2)
  area.node.addChild(area1.node)
  area.node.addChild(area2.node)

proc clear*(area: Area) =
  ## Clears the area and all its subareas and panels.
  for panel in area.panels:
    if panel.node != nil:
      panel.node.remove()
      panel.node = nil
    panel.parentArea = nil
  for subarea in area.areas:
    subarea.clear()
  if area.node != nil:
    area.node.remove()
    area.node = nil
  area.panels.setLen(0)
  area.areas.setLen(0)

proc refresh*(area: Area) =
  let
    w = thisFrame.size.x.float32
    h = thisFrame.size.y.float32
  area.node.position = vec2(
    floor(area.rect.x/100 * w),
    floor(area.rect.y/100 * h)
  )
  area.node.size = vec2(
    ceil(area.rect.w/100 * w),
    ceil(area.rect.h/100 * h)
  )
  if area.areas.len > 0:
    if area.layout == Horizontal:
      area.areas[0].rect = rect(
        0,
        0,
        area.rect.w,
        area.rect.h * area.split
      )
      area.areas[1].rect = rect(
        0,
        area.rect.h * area.split,
        area.rect.w,
        area.rect.h * (1 - area.split)
      )
    else:
      area.areas[0].rect = rect(
        0,
        0,
        area.rect.w * area.split,
        area.rect.h
      )
      area.areas[1].rect = rect(
        area.rect.w * area.split,
        0,
        area.rect.w * (1 - area.split),
        area.rect.h
      )
  for subarea in area.areas:
    subarea.refresh()

  if area.panels.len > 0:
    # Set the state of the headers.
    for i, panel in area.panels:
      if i != area.selectedPanelNum:
        panel.header.setVariant("State", "Default")
      else:
        panel.header.setVariant("State", "Selected")

find "/UI/Main":
  onLoad:
    echo "onLoad"

    areaTemplate = find("Area").copy()
    panelHeaderTemplate = find("**/PanelHeader").copy()
    panelTemplate = find("**/Panel").copy()
    areaTemplate.findAll("**/Panel").remove()
    areaTemplate.findAll("**/PanelHeader").remove()

    echo areaTemplate
    echo panelHeaderTemplate
    echo panelTemplate

    find("Area").remove()

    rootArea = Area(node: areaTemplate.copy())
    rootArea.rect = Rect(x: 0, y: 0, w: 100, h: 100)
    thisNode.addChild(rootArea.node)

    rootArea.split(Vertical)
    rootArea.split = 0.20

    rootArea.areas[0].addPanel("Panel 1")
    rootArea.areas[0].addPanel("Panel 2")

    # rootArea.areas[1].addPanel("Panel 3")
    # rootArea.areas[1].addPanel("Panel 4")
    # rootArea.areas[1].addPanel("Panel 5")

    rootArea.areas[1].split(Horizontal)
    rootArea.areas[1].split = 0.5

    rootArea.areas[1].areas[0].addPanel("Panel 3")
    rootArea.areas[1].areas[0].addPanel("Panel 4")
    rootArea.areas[1].areas[0].addPanel("Panel 5")

    rootArea.areas[1].areas[1].addPanel("Panel 6")
    rootArea.areas[1].areas[1].addPanel("Panel 7")
    rootArea.areas[1].areas[1].addPanel("Panel 8")

    rootArea.refresh()

  onResize:
    echo "onResize"
    rootArea.refresh()

  onButtonPress:
    if window.buttonPressed[KeyR]:
      echo "Regenerating the root area and panels with random sizes and positions."
      # Regenerate the root area and panels with random sizes and positions.
      rootArea.clear()

      rootArea = Area(node: areaTemplate.copy())
      rootArea.rect = Rect(x: 0, y: 0, w: 100, h: 100)
      thisNode.addChild(rootArea.node)

      var panelNum = 1
      proc iterate(area: Area, depth: int) =
        if rand(0 .. depth) < 2:
          # Split the area.
          if rand(0 .. 1) == 0:
            area.split(Horizontal)
          else:
            area.split(Vertical)
          area.split = rand(0.2 .. 0.8)
          iterate(area.areas[0], depth + 1)
          iterate(area.areas[1], depth + 1)
        else:
          # Don't split the area.
          for i in 0 ..< rand(1 .. 3):
            area.addPanel("Panel " & $panelNum)
            panelNum += 1
      iterate(rootArea, 0)

      rootArea.refresh()

  find "**/PanelHeader":
    onClick:
      echo "Clicked: ", thisNode.name
      let panel = findPanelByHeader(thisNode)
      echo "Panel: ", panel != nil
      if panel != nil:

        panel.parentArea.selectedPanelNum = thisNode.childIndex
        echo "Selected panel: ", panel.parentArea.selectedPanelNum
        panel.parentArea.refresh()

startFidget(
  figmaUrl = "https://www.figma.com/design/CvLIH2hh6B6V3rgxNV2gMD",
  windowTitle = "Panels Example",
  entryFrame = "UI/Main",
  windowStyle = DecoratedResizable
)
