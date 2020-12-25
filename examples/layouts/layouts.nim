import fidget2, bumpy

use("https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs")

onDisplay "/Layout1":
  thisNode.box.wh = windowSize

startFidget(
  windowTitle = "Layouts",
  entryFrame = "Layout1",
  resizable = true
)
