# This example shows a draggable panel UI like in a large editor like VS Code or Blender.

import
  std/[random, sequtils],
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
    split: float32          ## The split percentage of the area.
    selectedPanelNum: int   ## The index of the selected panel in the area.

  Panel = ref object
    name: string            ## The name of the panel.
    header: Node            ## The header of the panel.
    node: Node              ## The node of the panel.
    parentArea: Area        ## The parent area of the panel.

const
  AreaHeaderHeight = 28

var
  areaTemplate: Node
  panelHeaderTemplate: Node
  panelTemplate: Node
  rootArea: Area
  dropHighlight: Node

proc clear*(area: Area) =
  ## Clears the area and all its subareas and panels.
  for panel in area.panels:
    if panel.node != nil:
      panel.header.remove()
      panel.header = nil
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

proc movePanels*(area: Area, panels: seq[Panel]) 
proc refresh*(area: Area) =
  if area.areas.len > 0:
    # Combine the areas if they have no panels.
    if area.areas[0].panels.len == 0 and area.areas[0].areas.len == 0:
      echo "Combining areas, 0 has no panels or areas"
      echo "1 has ", area.areas[1].panels.len, " panels and ", area.areas[1].areas.len, " areas"
      if area.areas[1].areas.len > 0:
        echo "Area 1 has areas, just copy over the Areas to this Area."
        let oldAreas = area.areas
        area.areas = area.areas[1].areas
        area.node.addChild(area.areas[0].node)
        area.node.addChild(area.areas[1].node)
        area.split = oldAreas[1].split
        area.layout = oldAreas[1].layout
        # oldAreas[1].clear()
        # oldAreas[0].clear()
        oldAreas[1].node.remove()
        oldAreas[0].node.remove()
      else:
        echo "Area 1 has only panels, move them over."
        area.movePanels(area.areas[1].panels)
        # area.areas[0].clear()
        # area.areas[1].clear()
        area.areas[1].node.remove()
        area.areas[0].node.remove()
        area.areas.setLen(0)
        
    if area.areas[1].panels.len == 0 and area.areas[1].areas.len == 0:
      echo "Combining areas, 1 has no panels or areas"
      echo "0 has ", area.areas[0].panels.len, " panels and ", area.areas[0].areas.len, " areas"
      if area.areas[0].areas.len > 0:
        echo "Area 0 has areas, just copy over the Areas to this Area."
        let oldAreas = area.areas
        area.areas = area.areas[0].areas
        area.node.addChild(area.areas[0].node)
        area.node.addChild(area.areas[1].node)
        area.split = oldAreas[0].split
        area.layout = oldAreas[0].layout
        oldAreas[0].node.remove()
        oldAreas[1].node.remove()
        # oldAreas[1].clear()
        # oldAreas[0].clear()
      else:
        echo "Area 0 has only panels, move them over."
        area.movePanels(area.areas[0].panels)
        # area.areas[0].clear()
        # area.areas[1].clear()
        area.areas[0].node.remove()
        area.areas[1].node.remove()
        area.areas.setLen(0)

  if area.areas.len > 0:
    # Layout according to the layout.
    if area.layout == Horizontal:
      # Split horizontally (top/bottom)
      let splitPos = area.node.size.y * area.split
      area.areas[0].node.position = vec2(0, 0)
      area.areas[0].node.size = vec2(area.node.size.x, splitPos)
      area.areas[1].node.position = vec2(0, splitPos)
      area.areas[1].node.size = vec2(area.node.size.x, area.node.size.y - splitPos)
    else:
      # Split vertically (left/right)
      let splitPos = area.node.size.x * area.split
      area.areas[0].node.position = vec2(0, 0)
      area.areas[0].node.size = vec2(splitPos, area.node.size.y)
      area.areas[1].node.position = vec2(splitPos, 0)
      area.areas[1].node.size = vec2(area.node.size.x - splitPos, area.node.size.y)
    
  for subarea in area.areas:
    subarea.refresh()

  if area.panels.len > 0:
    # Set the state of the headers.
    for i, panel in area.panels:
      if i != area.selectedPanelNum:
        panel.header.setVariant("State", "Default")
      else:
        panel.header.setVariant("State", "Selected")

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
  ## Adds a panel to the given area.
  let panel = Panel(name: name)
  panel.header = panelHeaderTemplate.copy()
  panel.header.find("title").text = name
  panel.node = panelTemplate.copy()
  area.panels.add(panel)
  panel.parentArea = area
  area.node.find("Header").addChild(panel.header)
  area.node.addChild(panel.node)

proc movePanel*(area: Area, panel: Panel) =
  ## Moves the panel to the given area.
  panel.parentArea.panels.delete(panel.parentArea.panels.find(panel))
  area.panels.add(panel)
  panel.parentArea = area
  area.node.find("Header").addChild(panel.header)
  area.node.addChild(panel.node)

proc movePanels*(area: Area, panels: seq[Panel]) =
  ## Moves the panels to the given area.
  var panelList = panels.toSeq()
  for panel in panelList:
    area.movePanel(panel)

proc split*(area: Area, layout: AreaLayout) =
  ## Splits the area into two subareas.
  let
    area1 = Area(node: areaTemplate.copy())
    area2 = Area(node: areaTemplate.copy())
  area.layout = layout
  area.split = 0.5
  area.areas.add(area1)
  area.areas.add(area2)
  area.node.addChild(area1.node)
  area.node.addChild(area2.node)

type
  AreaScan = enum
    Header
    Body
    North
    South
    East
    West

proc scan*(area: Area): (Area,AreaScan, Rect) =
  let mousePos = window.mousePos.vec2
  var targetArea: Area
  var areaScan: AreaScan
  var rect: Rect
  proc visit(area: Area) =
    let areaRect = rect(area.node.absolutePosition, area.node.size)
    if mousePos.overlaps(areaRect):
      if area.areas.len > 0:
        for subarea in area.areas:
          visit(subarea)
      else:
        let 
          headerRect = rect(
            area.node.absolutePosition, 
            vec2(area.node.size.x, AreaHeaderHeight)
          )
          bodyRect = rect(
            area.node.absolutePosition + vec2(0, AreaHeaderHeight), 
            vec2(area.node.size.x, area.node.size.y - AreaHeaderHeight)
          )
          northRect = rect(
            area.node.absolutePosition + vec2(0, AreaHeaderHeight),
            vec2(area.node.size.x, area.node.size.y * 0.2)
          )
          southRect = rect(
            area.node.absolutePosition + vec2(0, area.node.size.y * 0.8),
            vec2(area.node.size.x, area.node.size.y * 0.2)
          )
          eastRect = rect(
            area.node.absolutePosition + vec2(area.node.size.x * 0.8, 0) + vec2(0, AreaHeaderHeight),
            vec2(area.node.size.x * 0.2, area.node.size.y - AreaHeaderHeight)
          )
          westRect = rect(
            area.node.absolutePosition + vec2(0, 0) + vec2(0, AreaHeaderHeight),
            vec2(area.node.size.x * 0.2, area.node.size.y - AreaHeaderHeight)
          )
        if mousePos.overlaps(headerRect):
          areaScan = Header
          rect = headerRect
        elif mousePos.overlaps(northRect):
          areaScan = North
          rect = northRect
        elif mousePos.overlaps(southRect):
          areaScan = South
          rect = southRect
        elif mousePos.overlaps(eastRect):
          areaScan = East
          rect = eastRect
        elif mousePos.overlaps(westRect):
          areaScan = West
          rect = westRect
        elif mousePos.overlaps(bodyRect):
          areaScan = Body
          rect = bodyRect
        targetArea = area
  visit(rootArea)
  return (targetArea, areaScan, rect)

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
    rootArea.node.position = vec2(0, 0)
    rootArea.node.size = thisFrame.size.vec2
    thisNode.addChild(rootArea.node)

    rootArea.split(Vertical)
    rootArea.split = 0.20

    rootArea.areas[0].addPanel("Super Panel 1")
    rootArea.areas[0].addPanel("Cool Panel 2")

    # rootArea.areas[1].addPanel("Panel 3")
    # rootArea.areas[1].addPanel("Panel 4")
    # rootArea.areas[1].addPanel("Panel 5")

    rootArea.areas[1].split(Horizontal)
    rootArea.areas[1].split = 0.5

    rootArea.areas[1].areas[0].addPanel("Nice Panel 3")
    rootArea.areas[1].areas[0].addPanel("The Other Panel 4")
    rootArea.areas[1].areas[0].addPanel("Panel 5")

    rootArea.areas[1].areas[1].addPanel("World classPanel 6")
    rootArea.areas[1].areas[1].addPanel("FUN Panel 7")
    rootArea.areas[1].areas[1].addPanel("Amazing Panel 8")

    rootArea.refresh()

    dropHighlight = find("/UI/DropHighlight")
    dropHighlight.remove()
    dropHighlight.position = vec2(100, 100)
    dropHighlight.size = vec2(500, 500)
    dropHighlight.visible = false
    thisNode.addChild(dropHighlight)

  onResize:
    echo "onResize"
    rootArea.node.size = thisFrame.size.vec2
    rootArea.refresh()

  onButtonPress:
    if window.buttonPressed[KeyR]:
      echo "Regenerating the root area and panels with random sizes and positions."
      # Regenerate the root area and panels with random sizes and positions.
      rootArea.clear()

      rootArea = Area(node: areaTemplate.copy())
      rootArea.node.position = vec2(0, 0)
      rootArea.node.size = thisFrame.size.vec2
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

      dropHighlight.sendToFront()

  find "**/PanelHeader":
    onClick:
      echo "Clicked: ", thisNode.name
      let panel = findPanelByHeader(thisNode)
      echo "Panel: ", panel != nil
      if panel != nil:

        panel.parentArea.selectedPanelNum = thisNode.childIndex
        echo "Selected panel: ", panel.parentArea.selectedPanelNum
        panel.parentArea.refresh()

    onDragStart:
      echo "onDragStart: ", thisNode.path
      dropHighlight.visible = true

    onDrag:
      echo "onDrag: ", thisNode.path
      let (_, _, rect) = rootArea.scan()
      dropHighlight.position = rect.xy
      dropHighlight.size = rect.wh

    onDragEnd:
      echo "onDragEnd: ", thisNode.path
      dropHighlight.visible = false
      let (targetArea, areaScan, _) = rootArea.scan()
      if targetArea != nil:
        let panel = findPanelByHeader(thisNode)
        if panel != nil:
          case areaScan:
            of Header:
              targetArea.movePanel(panel)
            of Body:
              targetArea.movePanel(panel)
            of North:
              targetArea.split(Horizontal)
              targetArea.areas[0].movePanel(panel)
              targetArea.areas[1].movePanels(targetArea.panels)
            of South:
              targetArea.split(Horizontal)
              targetArea.areas[1].movePanel(panel)
              targetArea.areas[0].movePanels(targetArea.panels)
            of East:
              targetArea.split(Vertical)
              targetArea.areas[1].movePanel(panel)
              targetArea.areas[0].movePanels(targetArea.panels)
            of West:
              targetArea.split(Vertical)
              targetArea.areas[0].movePanel(panel)
              targetArea.areas[1].movePanels(targetArea.panels)
        rootArea.refresh()

startFidget(
  figmaUrl = "https://www.figma.com/design/CvLIH2hh6B6V3rgxNV2gMD",
  windowTitle = "Panels Example",
  entryFrame = "UI/Main",
  windowStyle = DecoratedResizable
)
