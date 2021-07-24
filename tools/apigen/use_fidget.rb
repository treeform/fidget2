require_relative 'fidget'

# Test function calling
call_me_maybe("+9 360872 1222")
puts flight_club_rule(2)
puts input_code(1, 2, 3, 4)
puts test_numbers(
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
)

# Test ref objects
fod = create_fod()
puts "n.ref: " + fod[:ref].to_s
fod.count = 123
puts "n.count: " + fod.count.to_s

# Test enums
puts repeat_enum(AS_RIGHT)

# Test objects
a = Vector2.new()
a[:x] = 1.0
a[:y] = 2.0
give_vec(a)
v = take_vec()
puts v[:x].to_s + " " + v[:y].to_s

# Test callbacks
ruby_cb = FFI::Function.new(:void, []) do
  puts("in ruby_cb")
end
call_me_back(ruby_cb)

# Test callbacks
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
