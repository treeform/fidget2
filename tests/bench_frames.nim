import benchy, chroma, cligen, fidget2, os, pixie, strformat, strutils, times

proc main(r = "", e = "", l = 10000) =

  var renderTime = 0.0

  use("https://www.figma.com/file/TQOSRucXGFQpuOpyTkDYj1/")
  assert figmaFile.document != nil, "Empty document?"
  var framesHtml = """
  <style>
  img { border: 2px solid gray; }
  </style>
  """
  var count = 0
  for frame in figmaFile.document.children[0].children:
    if count >= l: continue
    if r != "" and not frame.name.startsWith(r): continue
    if e != "" and frame.name != e: continue

    #echo " *** ", frame.name, " *** "
    # discard drawCompleteFrame(frame)
    # frame.markDirty()

    let name = frame.name
    var image: Image
    timeIt name:
      frame.markDirty()
      image = drawCompleteFrame(frame)
    #let frameTime = epochTime() - startTime
    #renderTime += frameTime
    image.writeFile("tests/frames/" & frame.name & ".png")

    var diffScore = 0

    if fileExists(&"tests/frames/masters/{frame.name}.png"):
      var master = readImage(&"tests/frames/masters/{frame.name}.png")
      for x in 0 ..< master.width:
        for y in 0 ..< master.height:
          let
            m = master.getRgbaUnsafe(x, y)
            u = image.getRgbaUnsafe(x, y)
          var
            c: ColorRGBA
          let diff = (m.r.int - u.r.int) + (m.g.int - u.g.int) + (m.b.int - u.b.int)
          c.r = abs(m.a.int - u.a.int).clamp(0, 255).uint8
          c.g = (diff).clamp(0, 255).uint8
          c.b = (-diff).clamp(0, 255).uint8
          c.a = 255
          let diffPixel = abs(m.r.int - u.r.int) + abs(m.g.int - u.g.int) + abs(
              m.b.int - u.b.int) + abs(m.a.int - u.a.int)
          diffScore += diffPixel
          # if diffPixel == 0:
          #   c.a = 0

          image.setRgbaUnsafe(x, y, c)
      image.writeFile("tests/frames/diffs/" & frame.name & ".png")
      count += 1
    framesHtml.add(&"""<h4>{frame.name}</h4><p>{diffScore} diffpx</p><img src="{frame.name}.png"><img src="masters/{frame.name}.png"><img src="diffs/{frame.name}.png"><br>""")

  framesHtml.add(&"<p>Total time: {renderTime}s</p>")
  writeFile("tests/frames/index.html", framesHtml)

dispatch(main)
