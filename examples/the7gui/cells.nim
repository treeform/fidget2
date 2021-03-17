import chroma, chrono, fidget2

find "CellsFrame":

  find "Cell/text":
    onEdit:
      discard

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Cells",
  entryFrame = "CellsFrame",
  resizable = false
)
