import fidget2


var loaded: bool

find "/UI/MainScreen":
  onDisplay:
    if loaded == false:
      loaded = true
    #var writerBox = find("/UI/MainScreen/Writer/PlaceHolderText")
    #writerBox.editable = true

  find "Writer/PlaceHolderText":
    onEdit:
      echo "editing"

startFidget(
  figmaUrl = "https://www.figma.com/file/PRNHOO9xeHYkq5LskwDn33",
  windowTitle = "Pushbullet",
  entryFrame = "/UI/MainScreen",
  resizable = true
)
