import chroma, fidget2, strformat, strutils

proc setVariant(node: Node, name, value: string) =
  if name == "State":
    if value == "Default":
      node.fills[0].color = parseHtmlColor("#FFFFFF")
    elif value == "Error":
      node.fills[0].color = parseHtmlColor("#FFDAC5")

var
  celsius = 0.0
  fahrenheit = 32.0

find "TemperatureFrame":

  find "CelsiusInput/text":
    onDisplay:
      thisNode.characters = &"{celsius:0.2f}"
    onFocus:
      echo "focus CelsiusInput"
    onEdit:
      echo "edit CelsiusInput"
      try:
        celsius = parseFloat(thisNode.characters)
        fahrenheit = celsius * (9/5) + 32.0
        find("../bg").setVariant("State", "Default")
      except ValueError:
        find("../bg").setVariant("State", "Error")
    onUnfocus:
      echo "unfocus CelsiusInput"
      find("../bg").setVariant("State", "Default")

  find "FahrenheitInput/text":
    onDisplay:
      thisNode.characters = &"{fahrenheit:0.2f}"
    onFocus:
      echo "focus FahrenheitInput"
    onEdit:
      echo "edit FahrenheitInput"
      try:
        fahrenheit = parseFloat(thisNode.characters)
        celsius = (fahrenheit - 32.0) * (5/9)
        find("../bg").setVariant("State", "Default")
      except ValueError:
        find("../bg").setVariant("State", "Error")
    onUnfocus:
      echo "unfocus FahrenheitInput"
      find("../bg").setVariant("State", "Default")

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Temperature",
  entryFrame = "TemperatureFrame",
  resizable = false
)
