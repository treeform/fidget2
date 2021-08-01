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
  echo "-------------------------------"
  echo "Layouts"
  echo "-------------------------------"

  clearAllEventHandlers()

  var numFrame = 0
  onFrame:
    echo "Frame: ", numFrame
    case numFrame:
    of 0:
      discard
    of 1:
      resizeWindow(100, 100)
    of 2:
      takeScreenShot().writeFile("tests/shots/Layouts.1.100x100.png")
    of 3:
      resizeWindow(300, 200)
    of 4:
      takeScreenShot().writeFile("tests/shots/Layouts.1.300x200.png")
    of 5:
      resizeWindow(373, 111)
    of 6:
      takeScreenShot().writeFile("tests/shots/Layouts.1.373x111.png")

    of 7:
      thisFrame = find("Layout2")
    of 8:
      takeScreenShot().writeFile("tests/shots/Layouts.2.png")
    of 9:
      resizeWindow(100, 100)
    of 10:
      takeScreenShot().writeFile("tests/shots/Layouts.2.100x100.png")
    of 11:
      resizeWindow(300, 200)
    of 12:
      takeScreenShot().writeFile("tests/shots/Layouts.2.300x200.png")
    of 13:
      resizeWindow(373, 111)
    of 14:
      takeScreenShot().writeFile("tests/shots/Layouts.2.373x111.png")

    of 15:
      thisFrame = find("Layout3")
    of 16:
      takeScreenShot().writeFile("tests/shots/Layouts.3.png")
    of 17:
      resizeWindow(100, 100)
    of 18:
      takeScreenShot().writeFile("tests/shots/Layouts.3.100x100.png")
    of 19:
      resizeWindow(300, 200)
    of 20:
      takeScreenShot().writeFile("tests/shots/Layouts.3.300x200.png")
    of 21:
      resizeWindow(373, 111)
    of 22:
      takeScreenShot().writeFile("tests/shots/Layouts.3.373x111.png")

    of 23:
      thisFrame = find("Layout4")
      resizeWindow(140, 140)
    of 24:
      takeScreenShot().writeFile("tests/shots/Layouts.4.1.png")
    of 25:
      var n = find("Layout4/Wrapper/Text")
      n.characters = "Let the text grow out!"
      n.dirty = true
    of 26:
      takeScreenShot().writeFile("tests/shots/Layouts.4.2.png")
    of 27:
      var n = find("Layout4/Wrapper/Text")
      n.characters = "And\nTo be:\nMultiline!"
      n.dirty = true
    of 28:
      takeScreenShot().writeFile("tests/shots/Layouts.4.3.png")

    of 29:
      thisFrame = find("Layout5")
      resizeWindow(140, 140)
    of 30:
      takeScreenShot().writeFile("tests/shots/Layouts.5.1.png")
    of 31:
      var n = find("Layout5/Slider/Wrapper1/Text")
      n.characters = "1234"
      n.dirty = true
    of 32:
      takeScreenShot().writeFile("tests/shots/Layouts.5.2.png")
    of 33:
      var n = find("Layout5/Slider/Wrapper2/Text")
      n.characters = ":"
      n.dirty = true
    of 34:
      takeScreenShot().writeFile("tests/shots/Layouts.5.3.png")

    of 35:
      thisFrame = find("Layout6")
      resizeWindow(140, 140)
    of 36:
      takeScreenShot().writeFile("tests/shots/Layouts.6.1.png")
    of 37:
      var n = find("Layout6/Slider/Wrapper1/Text")
      n.characters = "Hi:\n1234"
      n.dirty = true
    of 38:
      takeScreenShot().writeFile("tests/shots/Layouts.6.2.png")
    of 39:
      var n = find("Layout6/Slider/Wrapper2/Text")
      n.characters = "A\nB\nC"
      n.dirty = true
    of 40:
      takeScreenShot().writeFile("tests/shots/Layouts.6.3.png")

    else:
      if numFrame > 40:
        running = false
    inc numFrame

  startFidget(
    figmaUrl = "https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs",
    windowTitle = "Layouts",
    entryFrame = "Layout1",
    resizable = true
  )

block:
  clearAllEventHandlers()

  var numFrame = 0
  onFrame:
    echo "Layouts: ", numFrame
    case numFrame:
    of 0:
      discard
    of 1:
      resizeWindow(548, 610)
    of 2:
      takeScreenShot().writeFile("tests/shots/PB.548x610.png")
    of 3:
      resizeWindow(700, 800)
    of 4:
      takeScreenShot().writeFile("tests/shots/PB.700x800.png")
    of 5:
      resizeWindow(673, 311)
    of 6:
       takeScreenShot().writeFile("tests/shots/PB.673x311.png")
    else:
      running = false
    inc numFrame

  startFidget(
    figmaUrl = "https://www.figma.com/file/PRNHOO9xeHYkq5LskwDn33",
    windowTitle = "PB",
    entryFrame = "MainScreen",
    resizable = true
  )

makeDiffHtml("tests/shots")
