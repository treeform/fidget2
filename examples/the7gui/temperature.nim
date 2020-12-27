import fidget2, strutils, chroma, strformat

proc `fillColor=`(node: Node, colorHtml: string) =
  node.fills[0].color = parseHtmlColor(colorHtml)

use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

var
  celsius = 0.0
  fahrenheit = 32.0

onDisplay "CelsiusInput/text":
  thisNode.characters = &"{celsius:0.2f}"
onEdit "CelsiusInput/text":
  try:
    celsius = parseFloat(thisNode.characters)
    find("**/CelsiusInput/bg").fillColor = "#FFFFFF"
    find("**/FahrenheitInput/bg").fillColor = "#FFFFFF"
  except ValueError:
    find("**/CelsiusInput/bg").fillColor = "#FFDAC5"
  fahrenheit = celsius * (9/5) + 32.0

onDisplay "FahrenheitInput/text":
  thisNode.characters = &"{fahrenheit:0.2f}"
onEdit "FahrenheitInput/text":
  try:
    fahrenheit = parseFloat(thisNode.characters)
    find("**/FahrenheitInput/bg").fillColor = "#FFFFFF"
    find("**/CelsiusInput/bg").fillColor = "#FFFFFF"
  except ValueError:
    find("**/FahrenheitInput/bg").fillColor = "#FFDAC5"
  celsius = (fahrenheit - 32.0) * (5/9)

startFidget(
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
