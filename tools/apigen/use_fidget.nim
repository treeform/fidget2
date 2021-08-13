import fidgetapi

# Test fidget
var count = 0
proc clickCb() {.cdecl.} =
  count += 1
  echo("count: ", count)
addCb(eOnClick, 100, "/CounterFrame/Count1Up", clickCb)

proc display_cb() {.cdecl.} =
  var n = find_node("text")
  n.characters = $count
  n.dirty = true
addCb(eOnDisplay, 100, "/CounterFrame/CounterDisplay", display_cb)

startFidget(
  "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  "Nim Counter",
  "CounterFrame",
  false
)
