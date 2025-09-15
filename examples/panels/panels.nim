# This example shows a draggable panel UI like in a large editor like VS Code or Blender.

import fidget2, bumpy

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

var
  areaTemplate: Node
  panelHeaderTemplate: Node
  panelTemplate: Node
  rootArea: Area

proc addPanel*(area: Area, name: string) =
  let panel = Panel(name: name)
  panel.header = panelHeaderTemplate.copy()
  panel.header.find("title").text = name
  panel.node = panelTemplate.copy()
  area.panels.add(panel)
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

proc doLayout*(area: Area) =
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
    subarea.doLayout()

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

    rootArea.doLayout()

    thisNode.addChild(rootArea.node)

  onFrame:
    rootArea.doLayout()

startFidget(
  figmaUrl = "https://www.figma.com/design/CvLIH2hh6B6V3rgxNV2gMD",
  windowTitle = "Panels Example",
  entryFrame = "UI/Main",
  windowStyle = DecoratedResizable
)
