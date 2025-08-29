import chroma, chrono, fidget2

find "/UI/CirclesFrame":

  find "Circles/Circle":
    onClick:
      echo "click circle"

  find "Buttons":

      find "Undo":
        onClick:
          echo "undo"

      find "Redo":
        onClick:
          echo "redo"

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Circles",
  entryFrame = "/UI/CirclesFrame",
  windowStyle = Decorated
)
