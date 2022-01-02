import fidget2, puppy, pixie/fileformats/png, print, vmath, strformat, pixie
import fidget2/hybridrender, bumpy, fidget2/common, puppy/requestpools, tables

const
  domain1 = "https://c.tile.openstreetmap.org"
  domain2 = "https://t1.openseamap.org/seamark"

type
  Tile = ref object
    image: Image
    node: Node
    handle: ResponseHandle

var
  mapPos = vec2(0, 0)
  zoom = 1.0
  tiles: Table[(int, int, int), Tile]

find "/UI/Main":

  onDisplay:
    echo "onDisplay"

    if window.buttonDown[MouseMiddle] or window.buttonDown[KeySpace]:
      mapPos += window.mouseDelta.vec2

    if window.scrollDelta.y != 0:
      var prevZoomDelta = (window.mousePos.vec2 - mapPos) / zoom
      zoom = clamp(zoom * (1.0 + window.scrollDelta.y/10), 1.0 .. 1000000.0)
      var newZoomDelta = prevZoomDelta * zoom
      mapPos = window.mousePos.vec2 - newZoomDelta

    var mapNode = find("/UI/Main/Map")
    if mapNode.position != mapPos or mapNode.scale != vec2(zoom, zoom):
      mapNode.position = mapPos
      mapNode.scale = vec2(zoom, zoom)
      mapNode.dirty = true

    var tileNode = find("/UI/Main/Map/Tile")
    tileNode.visible = false

    let
      level = clamp(int(round(log2(zoom))), 0 .. 19)
      size = 2 ^ level
      m = 0.0
      screenRect = rect(
        -mapPos.x + m, -mapPos.y + m, window.size.x.float32 - m*2, window.size.y.float32 - m*2
      ) / zoom / 256.0 * size.float32
      xs = max(0, screenRect.x.int)
      xe = min(size - 1, (screenRect.x + screenRect.w).int)
      ys = max(0, screenRect.y.int)
      ye = min(size - 1, (screenRect.y + screenRect.h).int)

    #var i = 0
    #echo xs, "..", xe, " x ", ys, "..", ye
    for x in xs .. xe:
      for y in ys .. ye:
        let loc = (x, y, level)
        var tile: Tile
        if loc notin tiles:
          tile = Tile()
          tiles[loc] = tile
          tile.node = tileNode.copy()
          mapNode.addChild(tile.node)

          let imgUrl = &"{domain1}/{level}/{x}/{y}.png"
          tile.handle = requestPool.fetch(Request(
            url: parseUrl(imgUrl),
            verb: "get"
          ))

          let
            tilePos = vec2(x.float32, y.float32) / size.float32 * 256.0
            tileScale = vec2(1, 1) / size.float32
          tile.node.position = tilePos
          tile.node.scale = tileScale
          tile.node.visible = false
        else:
          tile = tiles[loc]

        if tile.image == nil and tile.handle.ready:
          let imgUrl = &"{domain1}/{level}/{x}/{y}.png"
          tile.image = decodePng(tile.handle.response.body)
          imageCache[imgUrl] = tile.image
          tile.node.fills[0].imageRef = imgUrl

          tile.node.visible = true
          tile.node.dirty = true


    for loc, tile in tiles:
      if loc[2] != level:
        tile.node.visible = false
      else:
        tile.node.visible = tile.image != nil


startFidget(
  figmaUrl = "https://www.figma.com/file/82plYn1ClhiSfhoZrrFVn3",
  windowTitle = "Open Sea Map",
  entryFrame = "/UI/Main",
  resizable = true
)
