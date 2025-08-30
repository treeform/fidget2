import fidget2, strformat, strutils

var
  celsius = 0.0
  fahrenheit = 32.0

find "/UI/TemperatureFrame":

  find "CelsiusInput/text":
    onDisplay:
      if not thisNode.focused:
        thisNode.text = &"{celsius:0.2f}"
    onFocus:
      echo "focus CelsiusInput"
    onEdit:
      echo "edit CelsiusInput ", thisNode.text
      try:
        celsius = parseFloat(thisNode.text)
        fahrenheit = celsius * (9/5) + 32.0
        #find("../bg").setVariant("State", "Default")
      except ValueError:
        discard
        find("../bg").setVariant("State", "Error")
    onUnfocus:
      echo "unfocus CelsiusInput"
      #find("../bg").setVariant("State", "Default")

  find "FahrenheitInput/text":
    onDisplay:
      if not thisNode.focused:
        thisNode.text = &"{fahrenheit:0.2f}"
    onFocus:
      echo "focus FahrenheitInput"
    onEdit:
      echo "edit FahrenheitInput ", thisNode.text
      try:
        fahrenheit = parseFloat(thisNode.text)
        celsius = (fahrenheit - 32.0) * (5/9)
        #find("../bg").setVariant("State", "Default")
      except ValueError:
        discard
        #find("../bg").setVariant("State", "Error")
    onUnfocus:
      echo "unfocus FahrenheitInput"
      #find("../bg").setVariant("State", "Default")

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Temperature",
  entryFrame = "/UI/TemperatureFrame",
  windowStyle = Decorated
)
