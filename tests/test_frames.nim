import os, pixie, strformat, strutils, times, windy,
    fidget2/loader, fidget2/schema, fidget2/perf, fidget2/internal

# This test is similar to run_frames.nim but it does not
# save the frames to disk or does any diffing, so it is much faster to run.

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
  bxy.clearAtlas()
  drawToScreen(frame)
  let screenImage = readGpuPixelsFromScreen()
  echo frame.name, " ", screenImage.width, " ", screenImage.height
