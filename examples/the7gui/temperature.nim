import
  std/[strformat, strutils],
  fidget2

var
  celsius = 0.0
  fahrenheit = 32.0

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
        thisNode.parent.setVariant("State", "Default")
      except ValueError:
        thisNode.parent.setVariant("State", "Error")
    onUnfocus:
      thisNode.parent.setVariant("State", "Default")

  find "FahrenheitInput/text":
    onDisplay:
      if not thisNode.focused:
        thisNode.text = &"{fahrenheit:0.2f}"
    onEdit:
      thisNode.multiline = false
      try:
        fahrenheit = parseFloat(thisNode.text)
        celsius = (fahrenheit - 32.0) * (5/9)
        thisNode.parent.setVariant("State", "Default")
      except ValueError:
        thisNode.parent.setVariant("State", "Error")
    onUnfocus:
      thisNode.parent.setVariant("State", "Default")

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Temperature",
  entryFrame = "/UI/TemperatureFrame",
  windowStyle = Decorated
)
