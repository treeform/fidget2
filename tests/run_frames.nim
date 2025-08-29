import cligen, os, pixie, strformat, strutils, times, windy
import fidget2/loader, fidget2/schema, fidget2/perf, fidget2/internal

when defined(benchy):
  import benchy

when defined(cpu):
  import fidget2/cpurender
  const w = "cpu"
elif defined(hyb):
  const w = "hyb"
  import fidget2/hybridrender, boxy
else:
  {.error: "Unsupported backend define -d:cpu or -d:hyb".}

proc main(r = "", e = "", l = 10000) =

  if not existsDir("tests/frames/diffs"):
    createDir("tests/frames/diffs")

  if not existsDir("tests/frames/rendered"):
    createDir("tests/frames/rendered")

  var renderTime = 0.0
  var totalDiff = 0.0
  var firstTime = true

  use("https://www.figma.com/file/TQOSRucXGFQpuOpyTkDYj1/")
  assert figmaFile.document != nil, "Empty document?"
  var framesHtml = """
  <style>
  * { font-family: sans-serif;}
  img { border: 1px solid #888; margin: 5px}
  body { background: url(../checkers.png) repeat; color: white }
  </style>
  """
  var count = 0

  echo "name.......................... render     time      diff"

  for frame in figmaFile.document.children[0].children:
    if count >= l: continue
    if r != "" and not frame.name.startsWith(r): continue
    if e != "" and frame.name != e: continue

    #when not defined(benchy):
    #  echo frame.name, " --------------------------------- "

    if firstTime and w in @[
      "gpu",
      "gpu_vs_zpu", "hyb", "cpu_vs_hyb"
    ]:
      setupWindow(frame, size = ivec2(800, 600), visible = false, style = Decorated)
      firstTime = false

    proc drawFrame(frame: Node): Image =
      when defined(cpu):
        result = drawCompleteFrame(frame)
      elif defined(hyb):
        bxy.clearAtlas()
        drawToScreen(frame)
        result = readGpuPixelsFromScreen()
      elif defined(cpu_vs_hyb):
        result = drawCompleteFrame(frame)

    when defined(benchy):
      var mainFrame = frame
      timeIt mainFrame.name, 100:
        keep drawFrame(mainFrame)

    let startTime = epochTime()
    #defaultBuffer.setLen(0)

    var image = drawFrame(frame)
    #perfMark "drawFrame"
    #perfDump()

    let frameTime = epochTime() - startTime

    renderTime += frameTime
    image.writeFile("tests/frames/rendered/" & frame.name & ".png")

    var
      diffScore: float32 = -1
      diffImage: Image

    if fileExists(&"tests/frames/masters/{frame.name}.png"):
      var master: Image
      when defined(gpu_vs_zpu):
        master = drawCompleteZpuFrame(frame)
        master.writeFile("tests/frames/zpu/" & frame.name & ".png")
      elif defined(cpu_vs_hyb):
        bxy.clearAtlas()
        hybridrender.drawToScreen(frame)
        master = readGpuPixelsFromScreen()
        master.writeFile("tests/frames/hyb/" & frame.name & ".png")
      else:
        master = readImage(&"tests/frames/masters/{frame.name}.png")
      (diffScore, diffImage) = diff(master, image)
      diffImage.writeFile("tests/frames/diffs/" & frame.name & ".png")
      count += 1

    echo &"{frame.name:.<30} {w} {frameTime*1000:>9.3f}ms {diffScore:>8.3f}%"

    totalDiff += diffScore

    framesHtml.add(&"<h4>{frame.name}</h4>")
    framesHTML.add(&"<p>{w} {frameTime*1000:0.3f}ms {diffScore:0.3f}% diffpx</p>")
    framesHTML.add(&"<img src='rendered/{frame.name}.png'>")
    if w == "gpu_vs_zpu":
      framesHTML.add(&"<img src='zpu/{frame.name}.png'>")
    elif w == "cpu_vs_hyb":
      framesHTML.add(&"<img src='hyb/{frame.name}.png'>")
    else:
      framesHTML.add(&"<img src='masters/{frame.name}.png'>")
    framesHTML.add(&"<img src='diffs/{frame.name}.png'><br>")

  framesHtml.add(&"<p>Total time: {renderTime*1000:0.3f}ms</p>")
  framesHtml.add(&"<p>Total diff: {totalDiff/count.float32:0.3f}%</p>")

  dumpMeasures()

  echo &"Total time: {renderTime*1000:0.3f}ms"
  echo &"Total diff: {totalDiff/count.float32:0.3f}%"

  writeFile("tests/frames/index.html", framesHtml)

dispatch(main)
