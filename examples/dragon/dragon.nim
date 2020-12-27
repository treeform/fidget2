import fidget2

# Connect a figma file to the code base.
use("https://www.figma.com/file/Cto22A31tUso9On23AIpM7")

onFrame:
  echo "here"

startFidget(
  windowTitle = "Crew Dragon Flight Control UI",
  entryFrame = "Crew Dragon Flight Control UI",
  resizable = false
)
