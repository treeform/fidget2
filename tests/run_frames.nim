import cligen, fidget2, fidget2/gpurender, fidget2/cpurender, fidget2/zpurender,
    imagediff, os, pixie, strformat, strutils, times

proc main(w = "gpu", r = "", e = "", l = 10000) =

  var renderTime = 0.0
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
  for frame in figmaFile.document.children[0].children:
    if count >= l: continue
    if r != "" and not frame.name.startsWith(r): continue
    if e != "" and frame.name != e: continue

    echo frame.name, " --------------------------------- "

    if firstTime and w in ["gpu_atlas", "gpu_atlas_full", "gpu", "vs"]:
      createWindow(frame, offscreen = true)
      firstTime = false

    let startTime = epochTime()


    proc drawFrame(frame: Node): Image =
      if w == "gpu":
        drawGpuFrameToScreen(frame)
        result = readGpuPixelsFromScreen()
      elif w == "gpu_atlas":
        drawGpuFrameToAtlas(frame, "screen")
        result = readGpuPixelsFromAtlas("screen")
      elif w == "gpu_atlas_full":
        drawGpuFrameToAtlas(frame, "screen")
        result = readGpuPixelsFromAtlas("screen", crop = false)
      elif w == "cpu":
        result = drawCompleteCpuFrame(frame)
      elif w == "zpu":
        result = drawCompleteZpuFrame(frame)
      elif w == "vs":
        drawGpuFrameToScreen(frame)
        result = readGpuPixelsFromScreen()

    var image = drawFrame(frame)

    let frameTime = epochTime() - startTime

    let startTime2 = epochTime()
    discard drawFrame(frame)
    let frameTime2 = epochTime() - startTime2

    renderTime += frameTime
    image.writeFile("tests/frames/" & frame.name & ".png")

    var
      diffScore: float32 = -1
      diffImage: Image

    if fileExists(&"tests/frames/masters/{frame.name}.png"):
      var master: Image
      if w == "vs":
        master = drawCompleteZpuFrame(frame)
        master.writeFile("tests/frames/zpu/" & frame.name & ".png")
      else:
        master = readImage(&"tests/frames/masters/{frame.name}.png")
      (diffScore, diffImage) = imageDiff(master, image)
      diffImage.writeFile("tests/frames/diffs/" & frame.name & ".png")
      count += 1

    echo &"  {w} {frameTime:0.3f}s {frameTime2:0.3f}s {diffScore:0.3f}% diffpx"

    framesHtml.add(&"<h4>{frame.name}</h4>")
    framesHTML.add(&"<p>{w} {frameTime:0.3f}s {diffScore:0.3f}% diffpx</p>")
    framesHTML.add(&"<img src='{frame.name}.png'>")
    if w == "vs":
      framesHTML.add(&"<img src='zpu/{frame.name}.png'>")
    else:
      framesHTML.add(&"<img src='masters/{frame.name}.png'>")
    framesHTML.add(&"<img src='diffs/{frame.name}.png'><br>")

  framesHtml.add(&"<p>Total time: {renderTime}s</p>")
  writeFile("tests/frames/index.html", framesHtml)

dispatch(main)
