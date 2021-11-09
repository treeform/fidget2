import cligen, os, pixie, strformat, strutils, times
import fidget2/loader, fidget2/schema, fidget2/perf

when defined(benchy):
  import benchy

when defined(gpu):
  import fidget2/gpurender
  const w = "gpu"
elif defined(cpu):
  import fidget2/cpurender
  const w = "cpu"
elif defined(zpu):
  import fidget2/zpurender
  const w = "zpu"
elif defined(gpu_vs_zpu):
  import fidget2/gpurender, fidget2/zpurender
  const w = "gpu_vs_zpu"
elif defined(cpu_vs_hyb):
  import fidget2/cpurender
  import fidget2/hybridrender, fidget2/gl/context
  const w = "cpu_vs_hyb"
  proc setupWindow(frameNode: Node, offscreen: bool) =
    hybridrender.setupWindow(frameNode, offscreen)
elif defined(hyb):
  const w = "hyb"
  import fidget2/hybridrender, boxy

proc main(r = "", e = "", l = 10000) =

  if not existsDir("tests/frames/diffs"): createDir("tests/frames/diffs")
  if not existsDir("data/fonts"):
    createDir("data/fonts")
    copyFileToDir("tests/fonts/NotoSansJP-Regular.ttf", "data/fonts")

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

    if firstTime and w in [
      "gpu",
      "gpu_vs_zpu", "hyb", "cpu_vs_hyb"
    ]:
      setupWindow(frame, offscreen = true, resizable = false)
      firstTime = false

    proc drawFrame(frame: Node): Image =
      when defined(gpu):
        drawToScreen(frame)
        result = readGpuPixelsFromScreen()
      elif defined(zpu):
        result = drawCompleteZpuFrame(frame)
      elif defined(gpu_vs_zpu):
        drawGpuFrameToScreen(frame)
        result = readGpuPixelsFromScreen()
      elif defined(cpu):
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
    image.writeFile("tests/frames/" & frame.name & ".png")

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
    framesHTML.add(&"<img src='{frame.name}.png'>")
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
