import fidget2, strutils, chroma, strformat

use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

var
  # TODO empty state?
  celsius = 0.0
  fahrenheit = 0.0

onDisplay "CelsiusInput/text":
  thisNode.characters = &"{celsius:0.2f}"
onFocus "CelsiusInput/text":
  textBox.endOfLine()
onEdit "CelsiusInput/text":
  try:
    celsius = parseFloat(thisNode.characters)
    find("**/CelsiusInput/bg").fills[0].color = parseHtmlColor("#FFFFFF")
    find("**/FahrenheitInput/bg").fills[0].color = parseHtmlColor("#FFFFFF")
  except ValueError:
    find("**/CelsiusInput/bg").fills[0].color = parseHtmlColor("#FFDAC5")
  fahrenheit = celsius * (9/5) + 32.0

onDisplay "FahrenheitInput/text":
  thisNode.characters = &"{fahrenheit:0.2f}"
onFocus "FahrenheitInput/text":
  textBox.endOfLine()
onEdit "FahrenheitInput/text":
  try:
    fahrenheit = parseFloat(thisNode.characters)
    find("**/FahrenheitInput/bg").fills[0].color = parseHtmlColor("#FFFFFF")
    find("**/CelsiusInput/bg").fills[0].color = parseHtmlColor("#FFFFFF")
  except ValueError:
    find("**/FahrenheitInput/bg").fills[0].color = parseHtmlColor("#FFDAC5")
  celsius = (fahrenheit - 32.0) * (5/9)

startFidget(
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
