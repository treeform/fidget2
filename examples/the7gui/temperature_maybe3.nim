import fidget2, strutils, chroma, strformat

type
  InputState = enum
    isEmpty, isNumber, isError,

var
  # TODO empty state?
  celsiusState = isEmpty
  celsius = 0.0
  fahrenheitState = isEmpty
  fahrenheit = 0.0

at CelsiusInput:
  at text:
    onDisplay:
      if celsiusState == isEmpty:
        thisNode.characters = ""
      elif celsiusState == isNumber:
        thisNode.characters = &"{celsius:0.2f}"
    onFocus:
      textBox.endOfLine()
    onEdit:
      if thisNode.characters == "":
        celsiusState = isEmpty
      else:
        try:
          celsius = parseFloat(thisNode.characters)
          celsiusState = isNumber
          fahrenheit = celsius * (9/5) + 32.0
          fahrenheitState = isNumber
        except ValueError:
          celsiusState = isError

...

startFidget(
  figmaFile = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa"
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
