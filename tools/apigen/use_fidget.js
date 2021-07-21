fidget = require("./fidget")

// Test function calling
fidget.callMeMaybe("+9 360872 1222")
console.log(fidget.flightClubRule(2))
console.log(fidget.inputCode(1, 2, 3, 4))
console.log(fidget.testNumbers(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
))

// Test ref objects
fod = fidget.createFod()
console.log("n.ref", fod.nimRef)
fod.count = 123
console.log("n.count", fod.count)

// Test objects
console.log(fidget.giveVec(fidget.Vector2(x = 1, y = 2)))
v = fidget.takeVec()
console.log(v.x, v.y)

// Test enums
console.log(fidget.repeatEnum(fidget.AS_RIGHT))

// Test callbacks

jsCb = fidget.cb(function() {
    console.log("in jsCb")
})
fidget.callMeBack(jsCb)

// # Test fidget
var count = 0
clickCb = fidget.cb(function() {
    count += 1
    console.log("in click_cb", count)
    n = fidget.findNode("CounterFrame/CounterDisplay/text")
    n.characters = count.toString()
    n.dirty = true
})
fidget.onClickGlobal(clickCb)

fidget.startFidget(
  "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  "JavaScript Counter",
  "CounterFrame",
  false
)
