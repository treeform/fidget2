require_relative 'fidget'

# Test fidget
count = 0
click_cb = FFI::Function.new(:void, []) do
  count += 1
  puts("count:" + count.to_s)
end
add_cb(E_ON_CLICK, 100, "/CounterFrame/Count1Up", click_cb)

count = 0
display_cb = FFI::Function.new(:void, []) do
  n = find_node("text")
  n.characters = count.to_s
  n.dirty = true
end
add_cb(E_ON_DISPLAY, 100, "/CounterFrame/CounterDisplay", display_cb)

start_fidget(
  "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  "Ruby Counter",
  "CounterFrame",
  false
)
