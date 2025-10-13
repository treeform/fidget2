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
  windowTitle = "Writer",
  entryFrame = "/UI/TextFrame"
)
while isRunning():
  tickFidget()
closeFidget()
