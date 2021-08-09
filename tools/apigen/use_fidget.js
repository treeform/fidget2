fidget = require("./fidget")

// Test fidget
var count = 0
clickCb = fidget.cb(function() {
    count += 1
    console.log("count:", count)
})
fidget.addCb(fidget.E_ON_CLICK, 100, "/CounterFrame/Count1Up", clickCb)

displayCb = fidget.cb(function() {
    n = fidget.findNode("text")
    n.characters = count.toString()
    n.dirty = true
})
fidget.addCb(fidget.E_ON_DISPLAY, 100, "/CounterFrame/CounterDisplay", displayCb)

fidget.startFidget(
  "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  "JavaScript Counter",
  "CounterFrame",
  false
)
