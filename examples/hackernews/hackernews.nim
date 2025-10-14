import fidget2

startFidget(
  figmaUrl = "https://www.figma.com/file/Sybmdu0vDxeQa5vAk63rLG",
  windowTitle = "Hacker News",
  entryFrame = "/Main/MainScreen"
)
while isRunning():
  tickFidget()
closeFidget()
