import cligen, fidget2, fidget2/gpurender, fidget2/render, fidget2/zpurender,
    imagediff, os, pixie, strformat, strutils, times

proc main(w = "gpu", r = "", e = "", l = 10000) =

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
  for frame in figmaFile.document.children[0].children:
    if count >= l: continue
    if r != "" and not frame.name.startsWith(r): continue
    if e != "" and frame.name != e: continue

    echo frame.name, " --------------------------------- "

    if firstTime and w in ["gpu_atlas", "gpu_atlas_full", "gpu", "vs"]:
      createWindow(frame, offscreen = true)
      firstTime = false

    let startTime = epochTime()

    var image: Image
    if w == "gpu":
      drawGpuFrameToScreen(frame)
      image = readGpuPixelsFromScreen()
    elif w == "gpu_atlas":
      drawGpuFrameToAtlas(frame, "screen")
      image = readGpuPixelsFromAtlas("screen")
    elif w == "gpu_atlas_full":
      drawGpuFrameToAtlas(frame, "screen")
      image = readGpuPixelsFromAtlas("screen", crop = false)
    elif w == "cpu":
      image = drawCompleteCpuFrame(frame)
    elif w == "zpu":
      image = drawCompleteZpuFrame(frame)
    elif w == "vs":
      drawGpuFrameToScreen(frame)
      image = readGpuPixelsFromScreen()

    let frameTime = epochTime() - startTime
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

    echo &"  {w} {frameTime:0.3f}s {diffScore:0.3f}% diffpx"

    totalDiff += diffScore

    framesHtml.add(&"<h4>{frame.name}</h4>")
    framesHTML.add(&"<p>{w} {frameTime:0.3f}s {diffScore:0.3f}% diffpx</p>")
    framesHTML.add(&"<img src='{frame.name}.png'>")
    if w == "vs":
      framesHTML.add(&"<img src='zpu/{frame.name}.png'>")
    else:
      framesHTML.add(&"<img src='masters/{frame.name}.png'>")
    framesHTML.add(&"<img src='diffs/{frame.name}.png'><br>")

  framesHtml.add(&"<p>Total time: {renderTime}s</p>")
  framesHtml.add(&"<p>Total diff: {totalDiff}</p>")

  echo &"Total time: {renderTime}"
  echo &"Total diff: {totalDiff}"

  writeFile("tests/frames/index.html", framesHtml)

dispatch(main)
