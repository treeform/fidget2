import chroma, fidget2, strformat, strutils

use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

type
  InputState = enum
    EmptyState, NumberState, ErrorState, GrayState

var
  # TODO empty state?
  celsiusState = EmptyState
  celsius = 0.0
  fahrenheitState = EmptyState
  fahrenheit = 0.0

onDisplay "CelsiusInput/text":
  if celsiusState == EmptyState:
    thisNode.characters = ""
  elif celsiusState == NumberState:
    thisNode.characters = $celsius.int
onDisplay "CelsiusInput/bg":
  # thisNode.setVariation("State", $celsiusState)
  if celsiusState == ErrorState:
    thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
  elif celsiusState == GrayState:
    thisNode.fills[0].color = parseHtmlColor("#E0E0E0")
  else:
    thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
# onFocus "CelsiusInput/text":
#   textBox.endOfLine()
onEdit "CelsiusInput/text":
  # only call when text characters change
  if thisNode.characters == "":
    celsiusState = EmptyState
    fahrenheitState = GrayState
  else:
    try:
      celsius = parseFloat(thisNode.characters)
      celsiusState = NumberState
      fahrenheit = celsius * (9/5) + 32.0
      fahrenheitState = NumberState
    except ValueError:
      celsiusState = ErrorState
      fahrenheitState = GrayState

onDisplay "FahrenheitInput/text":
  if fahrenheitState == EmptyState:
    thisNode.characters = ""
  elif fahrenheitState == NumberState:
    thisNode.characters = $fahrenheit.int
onDisplay "FahrenheitInput/bg":
  if fahrenheitState == ErrorState:
    thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
  elif fahrenheitState == GrayState:
    thisNode.fills[0].color = parseHtmlColor("#E0E0E0")
  else:
    thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
onFocus "FahrenheitInput/text":
  textBox.endOfLine()
onEdit "FahrenheitInput/text":
  if thisNode.characters == "":
    fahrenheitState = EmptyState
    celsiusState = GrayState
  else:
    try:
      fahrenheit = parseFloat(thisNode.characters)
      fahrenheitState = NumberState
      celsius = (fahrenheit - 32.0) * (5/9)
      celsiusState = NumberState
    except ValueError:
      fahrenheitState = ErrorState
      celsiusState = GrayState

startFidget(
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
