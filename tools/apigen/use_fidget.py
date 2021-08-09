from fidget import *

# Test fidget
count = 0
@c_proc_cb
def click_cb():
    global count
    count += 1
    print("count:", count)
add_cb(E_ON_CLICK, 100, "/CounterFrame/Count1Up", click_cb)

@c_proc_cb
def display_cb():
    n = find_node("text")
    if n:
        n.characters = str(count)
        n.dirty = True
add_cb(E_ON_DISPLAY, 100, "/CounterFrame/CounterDisplay", display_cb)

start_fidget(
  "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  "Python Counter",
  "CounterFrame",
  False
)
