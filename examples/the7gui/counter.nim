import fidget2

# This is the count.
var count = 0

find "/UI/CounterFrame":
  # When some one clicks on the Count1Up button we increment the counter.
  find "Count1Up":
    onClick:
      inc count

  # When text is displayed it grabs the value from the count variable.
  find "CounterDisplay/text":
    onDisplay:
      thisNode.setText($count)

# Starts the fidget main loop.
startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Counter",     # The title of the window.
  entryFrame = "/UI/CounterFrame", # Frame to use as the entry from.
  windowStyle = Decorated
)
