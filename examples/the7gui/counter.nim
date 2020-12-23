import fidget2

# Connect a figma file to the code base.
use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

windowTitle = "Counter"
mainFrame = "Counter"      # We are going to use this frame as the main from.
windowSizeFixed = true     # We want the window to resize to frame size.

# This is where we store the count.
var count = 0

# When some one clicks on the Count1Up button we increment the counter.
onClick("Count1Up"):
  inc count
  # findByName("text").characters = $count
  # findByName("text").markDirty()

# When text is displayed it grabs the value from the count variable.
onDisplay("text", $count)

# Starts the fidget main loop.
startFidget()
