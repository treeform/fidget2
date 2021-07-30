from fidget import *

# Test function calling
call_me_maybe("+9 360872 1222")
print(flight_club_rule(2))
print(input_code(1, 2, 3, 4))
print(test_numbers(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
))

# Test ref objects
fod = create_fod()
print("n.ref", fod.ref)
fod.count = 123
print("n.count", fod.count)

# Test objects
print(give_vec(Vector2(x = 1, y = 2)))
v = take_vec()
print(v.x, v.y)

# Test enums
print(repeat_enum(AS_RIGHT))

# Test callbacks
@c_proc_cb
def python_cb():
    print("in python_cb")
call_me_back(python_cb)

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
