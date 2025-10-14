import chroma, chrono, fidget2

find "/UI/CellsFrame":

  find "Cell/text":
    onEdit:
      discard

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Cells",
  entryFrame = "/UI/CellsFrame",
  windowStyle = Decorated
)
while isRunning():
  tickFidget()
closeFidget()
