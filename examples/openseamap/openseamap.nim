import fidget2, puppy, pixie/fileformats/png, print, vmath, fidget2/input, strformat
import fidget2/hybridrender, bumpy, fidget2/common

const
  domain1 = "https://c.tile.openstreetmap.org"
  domain2 = "https://t1.openseamap.org/seamark"

var
  mapPos = vec2(0, 0)
  zoom = 1.0

find "/UI/Main":

  onDisplay:

    if buttonDown[MOUSE_MIDDLE] or buttonDown[SPACE]:
      mapPos += mouse.delta

    if mouse.wheelDelta != 0:
      var prevZoomDelta = (mouse.pos - mapPos) / zoom
      zoom = clamp(zoom * (1.0 + mouse.wheelDelta/10), 1.0 .. 1000000.0)
      var newZoomDelta = prevZoomDelta * zoom
      mapPos = mouse.pos - newZoomDelta

    var mapNode = find("/UI/Main/Map")
    mapNode.position = mapPos
    mapNode.scale = vec2(zoom, zoom)
    mapNode.dirty = true

    var tileNodes = findAll("/UI/Main/Map/*")
    var tileNode = find("/UI/Main/Map/Tile")

    let
      level = clamp(int(round(log2(zoom))), 0 .. 19)
      size = 2 ^ level
      m = 0.0
      screenRect = rect(
        -mapPos.x + m, -mapPos.y + m, windowFrame.x - m*2, windowFrame.y - m*2
      ) / zoom / 256.0 * size.float32
      xs = max(0, screenRect.x.int)
      xe = min(size - 1, (screenRect.x + screenRect.w).int)
      ys = max(0, screenRect.y.int)
      ye = min(size - 1, (screenRect.y + screenRect.h).int)
    var i = 0
    for x in xs .. xe:
      for y in ys .. ye:
        let
          tilePos = vec2(x.float32, y.float32) / size.float32 * 256.0
          tileScale = vec2(1, 1) / size.float32

        # layer one streamaps
        if tileNodes.len == i:
          let newTile = tileNode.copy()
          mapNode.addChild(newTile)
          tileNodes.add(tileNodes)

        if tileNodes[i].visible != true or
          tileNodes[i].position != tilePos or
          tileNodes[i].scale != tileScale:

          let imgUrl = &"{domain1}/{level}/{x}/{y}.png"
          echo imgUrl
          tileNodes[i].fills[0].imageUrl = imgUrl
          tileNodes[i].position = tilePos
          tileNodes[i].scale = tileScale
          tileNodes[i].visible = true
          tileNodes[i].dirty = true
        inc i

        # layer two seamaps
        if tileNodes.len == i:
          let newTile = tileNode.copy()
          mapNode.addChild(newTile)
          tileNodes.add(tileNodes)

        if tileNodes[i].visible != true or
          tileNodes[i].position != tilePos or
          tileNodes[i].scale != tileScale:

          let imgUrl = &"{domain2}/{level}/{x}/{y}.png"
          echo imgUrl
          tileNodes[i].fills[0].imageUrl = imgUrl
          tileNodes[i].position = tilePos
          tileNodes[i].scale = tileScale
          tileNodes[i].visible = true
          tileNodes[i].dirty = true
        inc i

    for j in i ..< tileNodes.len:
      tileNodes[j].visible = false

startFidget(
  figmaUrl = "https://www.figma.com/file/82plYn1ClhiSfhoZrrFVn3",
  windowTitle = "Open Sea Map",
  entryFrame = "/UI/Main",
  resizable = true
)
