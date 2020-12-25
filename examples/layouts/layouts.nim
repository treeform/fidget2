import fidget2

use("https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs")

onDisplay "/Layout1":
  thisNode.size = windowSize

startFidget(
  windowTitle = "Layouts",
  entryFrame = "Layout1",
  resizable = true
)
