from testy import *

print("Test function calling")
assert input_code(1, 2, 3, 4) == False
assert test_numbers(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
) == True

print("Test function calling with strings")
call_me_maybe("+9 360872 1222")
assert flight_club_rule(2) == "Don't talk about flight club."
assert cat_str("hi ", "how ", "are ", "you ", "doing?") == "hi how are you doing?"

print("Test objects")
give_vec(Vector2(x = 1, y = 2))
v = take_vec()
assert v.x == 1.2000000476837158
assert v.y == 3.4000000953674316

print("Test nested objects")
c = take_contact()
assert c.first_name == 123
assert c.last_name == 678
assert c.address.state == 1
assert c.address.zip == 2

print("Test ref objects")
fod = take_fod()
assert fod.name == "just fod"
assert fod.count == 12
fod.count = 123
assert fod.count == 123

print("Test nested ref objects")
boz = take_boz()
assert boz.name == "the one"
assert boz.fod.count == 99
boz.fod.count = 123
assert boz.fod.name == "other fod"
assert boz.fod.count == 123

print("Test enums")
assert repeat_enum(AS_RIGHT) == AS_RIGHT

print("Test callbacks")
was_called = False
@c_proc_cb
def python_cb():
    global was_called
    was_called = True
    print("in python_cb")
call_me_back(python_cb)
assert was_called == True

print("Test seq")
s = take_seq()
give_seq(s)
assert s[3] == 3
assert s[9] == 9
assert len(s) == 16
s[3] = 33
assert s[3] == 33
give_seq(s)

print("Test seq of obj")
s = take_seq_of_vector2()
give_seq_of_vector2(s)
print(s[3].x, s[3].y)
assert s[3] == Vector2(x = 3, y = 6)
assert s[9] == Vector2(x = 9, y = 18)
print(len(s))
assert len(s) == 11
s[3] = Vector2(x = 33, y = 33)
assert s[3] == Vector2(x = 33, y = 33)
give_seq_of_vector2(s)

print("Test seq of nested ref obj")
s = take_seq_of_boz()
assert s[8].fod.name == "fod8"
give_seq_of_boz(s)

f = read_font2("font/path.ttf")
print(sizeof(f))

#print("f.typeface.file_path", f.typeface.file_path)
print("f.size", f.size)
print("f.line_height", f.line_height)
print("f.paint.kind", f.paint.kind)
print("f.paint.blend_mode", f.paint.blend_mode)
print("len(f.paint.gradient_stops)", len(f.paint.gradient_stops))
print("f.paint.gradient_stops[0].position", f.paint.gradient_stops[0].position)
print("f.text_case", f.text_case)
print("f.underline", f.underline)
print("f.strikethrough", f.strikethrough)
print("f.no_kerning_adjustments", f.no_kerning_adjustments)

#assert f.typeface.file_path == "font/path.ttf"
assert f.size == 1.0
assert f.line_height == 2.0
assert f.paint.kind == PK_SOLID
assert f.paint.blend_mode == BM_COLOR_BURN
assert len(f.paint.gradient_stops) == 1
assert f.paint.gradient_stops[0].position == 10
assert f.text_case == TC_UPPER
assert f.underline == False
assert f.strikethrough == False
assert f.no_kerning_adjustments == True

print("DONE")
