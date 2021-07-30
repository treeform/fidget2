import fidgetapi

# Test function calling
callMeMaybe("+9 360872 1222")
echo(flightClubRule(2))
echo(inputCode(1, 2, 3, 4))
echo(testNumbers(
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
))

# Test ref objects
var fod = createFod()
echo("n.ref ", cast[uint64](fod))
fod.count = 123
echo("n.count ", fod.count)

# Test objects
giveVec(Vector2(x: 1, y: 2))
let v = takeVec()
echo(v.x, ", ", v.y)

# Test enums
echo(repeatEnum(asRight))

# Test callbacks
proc nimCb() {.cdecl.} =
  echo("in nimCb")
callMeBack(nimCb)

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
