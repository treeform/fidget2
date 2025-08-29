import chroma, cligen, fidget2, os, pixie, strformat, strutils, times

var files = @[
  (
    "https://www.figma.com/file/livQgJR90bQW8KREsMigrX",
    "Driving - Navigation"
  ),
  (
    "https://www.figma.com/file/7leI8PHWQjsj5VwPpF7MsW",
    "Grada UI Widgets"
  ),
  (
    "https://www.figma.com/file/Cto22A31tUso9On23AIpM7",
    "Crew Dragon Flight Control UI"
  ),
  (
    "https://www.figma.com/file/2Xx3HqDhwVy4EuI68PjM2D",
    "TeamBuilder"
  ),
  (
    "https://www.figma.com/file/AzRTd8mpSIKbD8vgVg40RW",
    "Uber Light UI Kit"
  ),
  (
    "https://www.figma.com/file/WRPn7PZLpQXYDUlXEoyBZk",
    "T-1"
  )
]

when defined(hyb):
  import fidget2/hybridrender, boxy

proc drawScreen(frame: Node): Image =
  when defined(cpu):
    result = drawCompleteFrame(frame)
  elif defined(hyb):
    #bxy.clearAtlas()
    drawToScreen(frame)
    result = readGpuPixelsFromScreen()
  else:
    {.error: "Unsupported backend define -d:cpu or -d:hyb".}

var framesHtml = """
<style>
img { border: 2px solid gray; max-height: 500px; max-width: 500px}
</style>
"""
proc main(r = "", l = 10000) =
  var count = 0
  for (url, mainFrame) in files:
    if count >= l: continue
    if r != "" and not mainFrame.startsWith(r): continue

    use(url)
    let frame = figmaFile.document.children[0].find(mainFrame)
    let start = epochTime()
    let image = drawScreen(frame)
    echo epochTime() - start
    image.writeFile("tests/files/" & frame.name & ".png")
    echo " *** ", frame.name, " *** "
    count += 1

    if fileExists(&"tests/files/masters/{frame.name}.png"):
      var master = readImage(&"tests/files/masters/{frame.name}.png")
      let (diffScore, diffImage) = diff(master, image)
      diffImage.writeFile("tests/files/diffs/" & frame.name & ".png")
    else:
      echo &"tests/files/masters/{frame.name}.png does not exist!"

    framesHtml.add(&"""<h4>{frame.name}</h4><img src="{frame.name}.png"><img src="masters/{frame.name}.png"><img src="diffs/{frame.name}.png"><br>""")
  writeFile("tests/files/index.html", framesHtml)

dispatch(main)
