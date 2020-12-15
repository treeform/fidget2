import chroma, os, fidget2, pixie, strutils, strformat, cligen, times,
    imagediff, fidget2/gpurender, fidget2/zpurender

proc main(w = "gpu", r = "", e = "", l = 10000) =

  var renderTime = 0.0

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

    let startTime = epochTime()

    var image: Image
    if w == "gpu":
      image = drawCompleteGpuFrame(frame)
    elif w == "cpu":
      image = drawCompleteFrame(frame)
    elif w == "zpu":
      image = drawCompleteZpuFrame(frame)

    let frameTime = epochTime() - startTime
    renderTime += frameTime
    image.writeFile("tests/frames/" & frame.name & ".png")


    var
      diffScore: float32 = -1
      diffImage: Image

    if fileExists(&"tests/frames/masters/{frame.name}.png"):
      var master = readImage(&"tests/frames/masters/{frame.name}.png")
      (diffScore, diffImage) = imageDiff(master, image)
      diffImage.writeFile("tests/frames/diffs/" & frame.name & ".png")
      count += 1

    echo &"  {w} {frameTime:0.3f}s {diffScore:0.3f}% diffpx"

    framesHtml.add(&"<h4>{frame.name}</h4>")
    framesHTML.add(&"<p>{w} {frameTime:0.3f}s {diffScore:0.3f}% diffpx</p>")
    framesHTML.add(&"<img src='{frame.name}.png'>")
    framesHTML.add(&"<img src='masters/{frame.name}.png'>")
    framesHTML.add(&"<img src='diffs/{frame.name}.png'><br>")

  framesHtml.add(&"<p>Total time: {renderTime}s</p>")
  writeFile("tests/frames/index.html", framesHtml)

dispatch(main)
