import fidget2, pixie, os, strutils

#[
* Run each test app.
* Simulate events.
* Take screenshots.
* Create a diff report with master screenshots.
]#


proc makeDiffHtml(folder: string) =
  var html = """
  <style>
    body {background-color: gray; font-family: Sans-Serif;}
  </style>

  """
  for f in walkFiles(folder & "/masters/*.png"):
    echo f
    let
      f = folder & "/" & f.extractFilename
      fmaster = folder & "/masters/" & f.extractFilename
      fdiff = folder & "/diffs/" & f.extractFilename

    var a, b: Image
    if fileExists(f):
      a = readImage(f)
    else:
      a = newImage(1, 1)
    b = readImage(fmaster)
    let (score, c) = diff(a, b)

    html.add "<h2>" & f.extractFilename & "</h2>\n"
    html.add "<img src='" & f.extractFilename & "'>\n"
    html.add "<img src='masters/" & f.extractFilename & "'>\n"
    html.add "<img src='diffs/" & f.extractFilename & "'>\n"
    html.add "<p> score: " & $score & "</p>\n"
    c.writeFile(fdiff)

  writeFile(folder & "/index.html", html)

for f in walkFiles("tests/shots/*.png"):
  f.removeFile

block:
  clearAllEventHandlers()
  var numFrame = 0
  onFrame:
    if numFrame > 0:
      simulateClick("CounterFrame/Count1Up")
      var img = takeScreenShot()
      img.writeFile("tests/shots/Counter." & $numFrame & ".png")
    inc numFrame
    if numFrame > 4:
      running = false
include ../examples/the7gui/counter


block:
  clearAllEventHandlers()

  var numFrame = 0
  onFrame:
    echo "Layouts: ", numFrame
    case numFrame:
    of 0:
      discard
    of 1:
      resizeWindow(100, 100)
    of 2:
      takeScreenShot().writeFile("tests/shots/Layouts.100x100.png")
    of 3:
      resizeWindow(300, 200)
    of 4:
      takeScreenShot().writeFile("tests/shots/Layouts.300x200.png")
    of 5:
      resizeWindow(373, 111)
    of 6:
      takeScreenShot().writeFile("tests/shots/Layouts.373x111.png")
    else:
      running = false
    inc numFrame

  startFidget(
    figmaUrl = "https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs",
    windowTitle = "Layouts",
    entryFrame = "Layout1",
    resizable = true
  )


makeDiffHtml("tests/shots")
