import fidget2, strutils, chroma, strformat

use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

type
  InputState = enum
    isEmpty, isNumber, isError

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
    thisNode.characters = &"{celsius:0.2f}"
onDisplay "CelsiusInput/bg":
  if celsiusState == isError:
    thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
  else:
    thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
onFocus "CelsiusInput/text":
  textBox.endOfLine()
onEdit "CelsiusInput/text":
  if thisNode.characters == "":
    celsiusState = isEmpty
  else:
    try:
      celsius = parseFloat(thisNode.characters)
      celsiusState = isNumber
    except ValueError:
      celsiusState = isError
    fahrenheit = celsius * (9/5) + 32.0
    fahrenheitState = isNumber

onDisplay "FahrenheitInput/text":
  if fahrenheitState == isEmpty:
    thisNode.characters = ""
  elif fahrenheitState == isNumber:
    thisNode.characters = &"{fahrenheit:0.2f}"
onDisplay "FahrenheitInput/bg":
  if fahrenheitState == isError:
    thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
  else:
    thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
onFocus "FahrenheitInput/text":
  textBox.endOfLine()
onEdit "FahrenheitInput/text":
  if thisNode.characters == "":
    fahrenheitState = isEmpty
  else:
    try:
      fahrenheit = parseFloat(thisNode.characters)
      fahrenheitState = isNumber
    except ValueError:
      fahrenheitState = isError
    celsius = (fahrenheit - 32.0) * (5/9)
    celsiusState = isNumber

startFidget(
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
