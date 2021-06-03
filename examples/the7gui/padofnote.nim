import chroma, fidget2, strformat, strutils

find "PadOfNoteFrame":
  find "text":
    onEdit:
      discard

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Pad Of Note",
  entryFrame = "PadOfNoteFrame",
  resizable = false
)
