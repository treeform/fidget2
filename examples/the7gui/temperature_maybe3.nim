import chroma, fidget2, strformat, strutils

type
  InputState = enum
    EmptyState, NumberState, ErrorState,

var
  # TODO empty state?
  celsiusState = EmptyState
  celsius = 0.0
  fahrenheitState = EmptyState
  fahrenheit = 0.0

at CelsiusInput:
  at text:
    onDisplay:
      if celsiusState == EmptyState:
        thisNode.characters = ""
      elif celsiusState == NumberState:
        thisNode.characters = &"{celsius:0.2f}"
    onFocus:
      textBox.endOfLine()
    onEdit:
      if thisNode.characters == "":
        celsiusState = EmptyState
      else:
        try:
          celsius = parseFloat(thisNode.characters)
          celsiusState = NumberState
          fahrenheit = celsius * (9/5) + 32.0
          fahrenheitState = NumberState
        except ValueError:
          celsiusState = ErrorState

...

startFidget(
  figmaFile = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa"
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
