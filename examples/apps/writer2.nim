import fidget2

find "/UI/TextFrame":
  find "Writer/Text":
    onEdit:
      echo "editing"
    onFocus:
      echo "focus node"
    onUnfocus:
      echo "unfocus node"

startFidget(
  figmaUrl = "https://www.figma.com/file/kJcxgRM2ZRjDovcjdkDHQH/Flowpad",
  windowTitle = "Flowpad",
  entryFrame = "/UI/TextFrame",
  resizable = true
)
