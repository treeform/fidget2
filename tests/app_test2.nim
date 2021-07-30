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

for f in walkFiles("ss/*.png"):
  f.removeFile

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

makeDiffHtml("tests/shots")
