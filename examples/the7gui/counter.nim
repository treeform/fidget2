import fidget2

# Connect a figma file to the code base.
use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

# This is the count.
var count = 0

# When some one clicks on the Count1Up button we increment the counter.
onClick("Count1Up"):
  inc count

# When text is displayed it grabs the value from the count variable.
onDisplay "CounterDisplay/text":
  thisNode.characters = $count

# Starts the fidget main loop.
startFidget(
  windowTitle = "Counter",    # The title of the window.
  entryFrame = "Counter",     # We are going to use this frame as the main from.
  resizable = false,           # We want the window to resize to frame size.
)
