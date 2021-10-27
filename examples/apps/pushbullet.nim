import fidget2

var loaded: bool
find "/UI/MainScreen":
  onDisplay:
    if loaded == false:
      loaded = true

  find "Writer/Text":
    onEdit:
      discard
      #echo "editing"
    onFocus:
      echo "focus node"
    onUnfocus:
      echo "unfocus node"

find "/UI/Settings":
  find "Settings/*/Toggle":
    onClick:
      proc flipValue(value: string): string =
        if value == "Off":
          "On"
        else:
          "Off"
      let value = thisNode.getVariant("Value").flipValue()
      echo thisNode.parent.name, " = ", value
      thisNode.setVariant("Value", value)

startFidget(
  figmaUrl = "https://www.figma.com/file/PRNHOO9xeHYkq5LskwDn33",
  windowTitle = "Pushbullet",
  entryFrame = "/UI/Settings",
  resizable = true
)
