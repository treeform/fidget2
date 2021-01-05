import chroma, fidget2, strformat, strutils

use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

type
  InputState = enum
    isEmpty, isNumber, isError, isGray

var
  # TODO empty state?
  celsiusState = isEmpty
  celsius = 0.0
  fahrenheitState = isEmpty
  fahrenheit = 0.0

onDisplay "CelsiusInput/text":
  if celsiusState == isEmpty:
    thisNode.characters = ""
  elif celsiusState == isNumber:
    thisNode.characters = $celsius.int
onDisplay "CelsiusInput/bg":
  # thisNode.setVariation("State", $celsiusState)
  if celsiusState == isError:
    thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
  elif celsiusState == isGray:
    thisNode.fills[0].color = parseHtmlColor("#E0E0E0")
  else:
    thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
# onFocus "CelsiusInput/text":
#   textBox.endOfLine()
onEdit "CelsiusInput/text":
  # only call when text characters change
  if thisNode.characters == "":
    celsiusState = isEmpty
    fahrenheitState = isGray
  else:
    try:
      celsius = parseFloat(thisNode.characters)
      celsiusState = isNumber
      fahrenheit = celsius * (9/5) + 32.0
      fahrenheitState = isNumber
    except ValueError:
      celsiusState = isError
      fahrenheitState = isGray

onDisplay "FahrenheitInput/text":
  if fahrenheitState == isEmpty:
    thisNode.characters = ""
  elif fahrenheitState == isNumber:
    thisNode.characters = $fahrenheit.int
onDisplay "FahrenheitInput/bg":
  if fahrenheitState == isError:
    thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
  elif fahrenheitState == isGray:
    thisNode.fills[0].color = parseHtmlColor("#E0E0E0")
  else:
    thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
onFocus "FahrenheitInput/text":
  textBox.endOfLine()
onEdit "FahrenheitInput/text":
  if thisNode.characters == "":
    fahrenheitState = isEmpty
    celsiusState = isGray
  else:
    try:
      fahrenheit = parseFloat(thisNode.characters)
      fahrenheitState = isNumber
      celsius = (fahrenheit - 32.0) * (5/9)
      celsiusState = isNumber
    except ValueError:
      fahrenheitState = isError
      celsiusState = isGray

startFidget(
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
