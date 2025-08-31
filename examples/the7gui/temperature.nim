import
  std/[strformat, strutils],
  chroma, fidget2

var
  celsius = 0.0
  fahrenheit = 32.0

proc setVariant(node: Node, name, value: string) =
  if name == "State":
    if value == "Default":
      node.fills[0].color = parseHtmlColor("#FFFFFF")
      node.dirty = true
    elif value == "Error":
      node.fills[0].color = parseHtmlColor("#FFDAC5")
      node.dirty = true

find "/UI/TemperatureFrame":

  find "CelsiusInput/text":
    onDisplay:
      if not thisNode.focused:
        thisNode.text = &"{celsius:0.2f}"
    onEdit:
      thisNode.multiline = false
      try:
        celsius = parseFloat(thisNode.text)
        fahrenheit = celsius * (9/5) + 32.0
        find("../bg").setVariant("State", "Default")
      except ValueError:
        find("../bg").setVariant("State", "Error")
    onUnfocus:
      find("../bg").setVariant("State", "Default")

  find "FahrenheitInput/text":
    onDisplay:
      if not thisNode.focused:
        thisNode.text = &"{fahrenheit:0.2f}"
    onEdit:
      thisNode.multiline = false
      try:
        fahrenheit = parseFloat(thisNode.text)
        celsius = (fahrenheit - 32.0) * (5/9)
        find("../bg").setVariant("State", "Default")
      except ValueError:
        find("../bg").setVariant("State", "Error")
    onUnfocus:
      find("../bg").setVariant("State", "Default")

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Temperature",
  entryFrame = "/UI/TemperatureFrame",
  windowStyle = Decorated
)
