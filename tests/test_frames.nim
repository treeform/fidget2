import os, pixie, strformat, strutils, times, windy,
    fidget2/loader, fidget2/schema, fidget2/perf, fidget2/internal, xrays

import fidget2/hybridrender, boxy

use("https://www.figma.com/file/TQOSRucXGFQpuOpyTkDYj1/")
assert figmaFile.document != nil, "Empty document?"

setupWindow(
  figmaFile.document.children[0].children[0],
  size = ivec2(800, 600),
  visible = false,
  style = Decorated
)

for frame in figmaFile.document.children[0].children:
  echo frame.name

  bxy.clearAtlas()
  drawToScreen(frame)
  let screenImage = readGpuPixelsFromScreen()

  screenImage.xray("tests/frames/masters/" & frame.name & ".png")
