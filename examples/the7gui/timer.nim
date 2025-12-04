import
  std/[strformat, times],
  chroma, chrono, fidget2, vmath

var
  startTime: float64 = epochTime()
  stoppedTime: float64 = epochTime()
  running = false
  duration: float64 = 30

proc currentTime(): float64 =
  if running:
    result = epochTime() - startTime
    if result > duration:
      running = false
      stoppedTime = startTime + duration
      result = duration
  else:
    result = stoppedTime - startTime

find "/UI/TimerFrame":
  find "TimeGroup/ProgressBar/progress":
    onDisplay:
      thisNode.size = vec2(currentTime() / duration * 272, thisNode.size.y)
      thisNode.dirty = true

  find "Label/text":
    onDisplay:
      let s = currentTime()
      thisNode.text = &"{s:0.2f}s"
      thisNode.dirty = true

  find "Button":
    onClick:
      if not running:
        startTime = epochTime()
        running = true
        find("text").text = "stop"
        find("text").dirty = true
      else:
        stoppedTime = epochTime()
        running = false
        find("text").text = "start"
        find("text").dirty = true

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Timer",
  entryFrame = "/UI/TimerFrame",
  windowStyle = Decorated
)
while isRunning():
  tickFidget()
closeFidget()
