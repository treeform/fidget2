import fidget2, strutils, chroma, strformat

var
  celsius = 0.0
  fahrenheit = 0.0

find "CelsiusInput":
  find "text":
    onDisplay: &"{celsius:0.2f}"
    onFocus:
      textBox.endOfLine()
    onEdit:
      try:
        celsius = parseFloat(thisNode.characters)
        thisNode.parent().variation("State", "Default")
        rootNode.find("FahrenheitInput").variation("State", "Default")
      except ValueError:
        thisNode.parent().variation("State", "Error")
      fahrenheit = celsius * (9/5) + 32.0

...

startFidget(
  figmaFile = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa"
  windowTitle = "Temperature",
  entryFrame = "Temperature",
  resizable = false
)
