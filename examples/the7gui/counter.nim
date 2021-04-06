import fidget2

# This is the count.
var count = 0

find "CounterFrame":
  # When some one clicks on the Count1Up button we increment the counter.
  find "Count1Up":
    onClick:
      inc count
      echo count

  # When text is displayed it grabs the value from the count variable.
  find "CounterDisplay/text":
    onDisplay:
      thisNode.characters = $count

# Starts the fidget main loop.
startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Counter",     # The title of the window.
  entryFrame = "CounterFrame", # Frame to use as the entry from.
  resizable = false,           # We want the window to resize to frame size.
)
