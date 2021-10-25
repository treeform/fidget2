import fidget2


var loaded: bool

find "/UI/TextFrame":
  onDisplay:
    if loaded == false:
      loaded = true

  find "Writer/Text":
    onEdit:
      discard
      #echo "editing"
    # onFocus:
    #   echo "focus node"
    # onUnfocus:
    #   echo "unfocus node"

startFidget(
  figmaUrl = "https://www.figma.com/file/PRNHOO9xeHYkq5LskwDn33",
  windowTitle = "Writer",
  entryFrame = "/UI/TextFrame",
  resizable = true
)
