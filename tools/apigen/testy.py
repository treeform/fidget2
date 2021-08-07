from ctypes import *
import os, sys

if sys.platform == "win32":
  dllPath = 'testy.dll'
elif sys.platform == "darwin":
  dllPath = os.getcwd() + '/libtesty.dylib'
else:
  dllPath = os.getcwd() + '/libtesty.so'
dll = cdll.LoadLibrary(dllPath)

c_proc_cb = CFUNCTYPE(None)

dll.fidget_input_code.argtypes = [c_longlong, c_longlong, c_longlong, c_longlong]
dll.fidget_input_code.restype = c_bool
def input_code(a, b, c, d):
  return dll.fidget_input_code(a, b, c, d)

dll.fidget_test_numbers.argtypes = [c_byte, c_ubyte, c_short, c_ushort, c_int, c_uint, c_longlong, c_ulonglong, c_longlong, c_ulonglong, c_float, c_double, c_double]
dll.fidget_test_numbers.restype = c_bool
def test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m):
  return dll.fidget_test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)

dll.fidget_call_me_maybe.argtypes = [c_char_p]
dll.fidget_call_me_maybe.restype = None
def call_me_maybe(phone):
  return dll.fidget_call_me_maybe(phone.encode('utf8'))

dll.fidget_flight_club_rule.argtypes = [c_longlong]
dll.fidget_flight_club_rule.restype = c_char_p
def flight_club_rule(n):
  return dll.fidget_flight_club_rule(n).decode('utf8')

dll.fidget_cat_str.argtypes = [c_char_p, c_char_p, c_char_p, c_char_p, c_char_p]
dll.fidget_cat_str.restype = c_char_p
def cat_str(a, b, c, d, e):
  return dll.fidget_cat_str(a.encode('utf8'), b.encode('utf8'), c.encode('utf8'), d.encode('utf8'), e.encode('utf8')).decode('utf8')

class Vector2(Structure):
    _fields_ = [
        ("x", c_float),
        ("y", c_float),
    ]
    def __eq__(self, obj):
        return self.x == obj.x and self.y == obj.y

dll.fidget_give_vec.argtypes = [Vector2]
dll.fidget_give_vec.restype = None
def give_vec(v):
  return dll.fidget_give_vec(v)

dll.fidget_take_vec.argtypes = []
dll.fidget_take_vec.restype = Vector2
def take_vec():
  return dll.fidget_take_vec()

class Address(Structure):
    _fields_ = [
        ("state", c_longlong),
        ("zip", c_longlong),
    ]
    def __eq__(self, obj):
        return self.state == obj.state and self.zip == obj.zip

class Contact(Structure):
    _fields_ = [
        ("first_name", c_longlong),
        ("last_name", c_longlong),
        ("address", Address),
    ]
    def __eq__(self, obj):
        return self.first_name == obj.first_name and self.last_name == obj.last_name and self.address == obj.address

dll.fidget_take_contact.argtypes = []
dll.fidget_take_contact.restype = Contact
def take_contact():
  return dll.fidget_take_contact()

class Fod(Structure):
    _fields_ = [("ref", c_longlong)]
    def __bool__(self): return self.ref != None
    @property
    def name(self):
        return dll.fidget_fod_get_name(self).decode('utf8')

    @name.setter
    def name(self, name):
        dll.fidget_fod_set_name(self, name.encode('utf8'))

    @property
    def count(self):
        return dll.fidget_fod_get_count(self)

    @count.setter
    def count(self, count):
        dll.fidget_fod_set_count(self, count)

dll.fidget_fod_get_name.argtypes = [Fod]
dll.fidget_fod_get_name.restype = c_char_p
dll.fidget_fod_set_name.argtypes = [Fod, c_char_p]
dll.fidget_fod_get_count.argtypes = [Fod]
dll.fidget_fod_get_count.restype = c_longlong
dll.fidget_fod_set_count.argtypes = [Fod, c_longlong]


dll.fidget_take_fod.argtypes = []
dll.fidget_take_fod.restype = Fod
def take_fod():
  return dll.fidget_take_fod()

class Boz(Structure):
    _fields_ = [("ref", c_longlong)]
    def __bool__(self): return self.ref != None
    @property
    def name(self):
        return dll.fidget_boz_get_name(self).decode('utf8')

    @name.setter
    def name(self, name):
        dll.fidget_boz_set_name(self, name.encode('utf8'))

    @property
    def fod(self):
        return dll.fidget_boz_get_fod(self)

    @fod.setter
    def fod(self, fod):
        dll.fidget_boz_set_fod(self, fod)

dll.fidget_boz_get_name.argtypes = [Boz]
dll.fidget_boz_get_name.restype = c_char_p
dll.fidget_boz_set_name.argtypes = [Boz, c_char_p]
dll.fidget_boz_get_fod.argtypes = [Boz]
dll.fidget_boz_get_fod.restype = Fod
dll.fidget_boz_set_fod.argtypes = [Boz, Fod]


dll.fidget_take_boz.argtypes = []
dll.fidget_take_boz.restype = Boz
def take_boz():
  return dll.fidget_take_boz()

AlignSomething = c_byte
AS_DEFAULT = 0
AS_TOP = 1
AS_BOTTOM = 2
AS_RIGHT = 3
AS_LEFT = 4

dll.fidget_repeat_enum.argtypes = [AlignSomething]
dll.fidget_repeat_enum.restype = AlignSomething
def repeat_enum(e):
  return dll.fidget_repeat_enum(e)

dll.fidget_call_me_back.argtypes = [c_proc_cb]
dll.fidget_call_me_back.restype = None
def call_me_back(cb):
  return dll.fidget_call_me_back(cb)

class SeqOfUint64(Structure):
    _fields_ = [
        ("cap", c_longlong),
        ("data", c_longlong)
    ]
    def __getitem__(self, index):
      return dll.fidget_seq_of_uint64_get(self, index)
    def __setitem__(self, index, value):
      return dll.fidget_seq_of_uint64_set(self, index, value)
    def __len__(self):
      return dll.fidget_seq_of_uint64_len(self)
dll.fidget_seq_of_uint64_get.argtypes = [SeqOfUint64, c_longlong]
dll.fidget_seq_of_uint64_get.restype = c_ulonglong
dll.fidget_seq_of_uint64_set.argtypes = [SeqOfUint64, c_longlong, c_ulonglong]
dll.fidget_seq_of_uint64_set.restype = None
dll.fidget_seq_of_uint64_len.argtypes = [SeqOfUint64]
dll.fidget_seq_of_uint64_len.restype = c_longlong

dll.fidget_take_seq.argtypes = []
dll.fidget_take_seq.restype = SeqOfUint64
def take_seq():
  return dll.fidget_take_seq()

dll.fidget_give_seq.argtypes = [SeqOfUint64]
dll.fidget_give_seq.restype = None
def give_seq(s):
  return dll.fidget_give_seq(s)

class SeqOfVector2(Structure):
    _fields_ = [
        ("cap", c_longlong),
        ("data", c_longlong)
    ]
    def __getitem__(self, index):
      return dll.fidget_seq_of_vector2_get(self, index)
    def __setitem__(self, index, value):
      return dll.fidget_seq_of_vector2_set(self, index, value)
    def __len__(self):
      return dll.fidget_seq_of_vector2_len(self)
dll.fidget_seq_of_vector2_get.argtypes = [SeqOfVector2, c_longlong]
dll.fidget_seq_of_vector2_get.restype = Vector2
dll.fidget_seq_of_vector2_set.argtypes = [SeqOfVector2, c_longlong, Vector2]
dll.fidget_seq_of_vector2_set.restype = None
dll.fidget_seq_of_vector2_len.argtypes = [SeqOfVector2]
dll.fidget_seq_of_vector2_len.restype = c_longlong

dll.fidget_give_seq_of_vector2.argtypes = [SeqOfVector2]
dll.fidget_give_seq_of_vector2.restype = None
def give_seq_of_vector2(s):
  return dll.fidget_give_seq_of_vector2(s)

dll.fidget_take_seq_of_vector2.argtypes = []
dll.fidget_take_seq_of_vector2.restype = SeqOfVector2
def take_seq_of_vector2():
  return dll.fidget_take_seq_of_vector2()

class SeqOfBoz(Structure):
    _fields_ = [
        ("cap", c_longlong),
        ("data", c_longlong)
    ]
    def __getitem__(self, index):
      return dll.fidget_seq_of_boz_get(self, index)
    def __setitem__(self, index, value):
      return dll.fidget_seq_of_boz_set(self, index, value)
    def __len__(self):
      return dll.fidget_seq_of_boz_len(self)
dll.fidget_seq_of_boz_get.argtypes = [SeqOfBoz, c_longlong]
dll.fidget_seq_of_boz_get.restype = Boz
dll.fidget_seq_of_boz_set.argtypes = [SeqOfBoz, c_longlong, Boz]
dll.fidget_seq_of_boz_set.restype = None
dll.fidget_seq_of_boz_len.argtypes = [SeqOfBoz]
dll.fidget_seq_of_boz_len.restype = c_longlong

dll.fidget_give_seq_of_boz.argtypes = [SeqOfBoz]
dll.fidget_give_seq_of_boz.restype = None
def give_seq_of_boz(s):
  return dll.fidget_give_seq_of_boz(s)

dll.fidget_take_seq_of_boz.argtypes = []
dll.fidget_take_seq_of_boz.restype = SeqOfBoz
def take_seq_of_boz():
  return dll.fidget_take_seq_of_boz()

TextCase = c_byte
TC_NORMAL = 0
TC_UPPER = 1
TC_LOWER = 2
TC_TITLE = 3

PaintKind = c_byte
PK_SOLID = 0
PK_IMAGE = 1
PK_IMAGE_TILED = 2
PK_GRADIENT_LINEAR = 3
PK_GRADIENT_RADIAL = 4
PK_GRADIENT_ANGULAR = 5

BlendMode = c_byte
BM_NORMAL = 0
BM_DARKEN = 1
BM_MULTIPLY = 2
BM_COLOR_BURN = 3
BM_LIGHTEN = 4
BM_SCREEN = 5
BM_COLOR_DODGE = 6
BM_OVERLAY = 7
BM_SOFT_LIGHT = 8
BM_HARD_LIGHT = 9
BM_DIFFERENCE = 10
BM_EXCLUSION = 11
BM_HUE = 12
BM_SATURATION = 13
BM_COLOR = 14
BM_LUMINOSITY = 15
BM_MASK = 16
BM_OVERWRITE = 17
BM_SUBTRACT_MASK = 18
BM_EXCLUDE_MASK = 19

class ColorRGBX(Structure):
    _fields_ = [
        ("r", c_ubyte),
        ("g", c_ubyte),
        ("b", c_ubyte),
        ("a", c_ubyte),
    ]
    def __eq__(self, obj):
        return self.r == obj.r and self.g == obj.g and self.b == obj.b and self.a == obj.a

class ColorStop2(Structure):
    _fields_ = [
        ("color", ColorRGBX),
        ("position", c_float),
    ]
    def __eq__(self, obj):
        return self.color == obj.color and self.position == obj.position

class SeqOfColorStop2(Structure):
    _fields_ = [
        ("cap", c_longlong),
        ("data", c_longlong)
    ]
    def __getitem__(self, index):
      return dll.fidget_seq_of_color_stop2_get(self, index)
    def __setitem__(self, index, value):
      return dll.fidget_seq_of_color_stop2_set(self, index, value)
    def __len__(self):
      return dll.fidget_seq_of_color_stop2_len(self)
dll.fidget_seq_of_color_stop2_get.argtypes = [SeqOfColorStop2, c_longlong]
dll.fidget_seq_of_color_stop2_get.restype = ColorStop2
dll.fidget_seq_of_color_stop2_set.argtypes = [SeqOfColorStop2, c_longlong, ColorStop2]
dll.fidget_seq_of_color_stop2_set.restype = None
dll.fidget_seq_of_color_stop2_len.argtypes = [SeqOfColorStop2]
dll.fidget_seq_of_color_stop2_len.restype = c_longlong

class Paint2(Structure):
    _fields_ = [
        ("kind", PaintKind),
        ("blend_mode", BlendMode),
        ("gradient_stops", SeqOfColorStop2),
    ]
    def __eq__(self, obj):
        return self.kind == obj.kind and self.blend_mode == obj.blend_mode and self.gradient_stops == obj.gradient_stops

class Typeface2(Structure):
    _fields_ = [("ref", c_longlong)]
    def __bool__(self): return self.ref != None
    @property
    def file_path(self):
        return dll.fidget_typeface2_get_file_path(self).decode('utf8')

    @file_path.setter
    def file_path(self, file_path):
        dll.fidget_typeface2_set_file_path(self, file_path.encode('utf8'))

dll.fidget_typeface2_get_file_path.argtypes = [Typeface2]
dll.fidget_typeface2_get_file_path.restype = c_char_p
dll.fidget_typeface2_set_file_path.argtypes = [Typeface2, c_char_p]


class Font2(Structure):
    _fields_ = [("ref", c_longlong)]
    def __bool__(self): return self.ref != None
    @property
    def typeface(self):
        return dll.fidget_font2_get_typeface(self)

    @typeface.setter
    def typeface(self, typeface):
        dll.fidget_font2_set_typeface(self, typeface)

    @property
    def size(self):
        return dll.fidget_font2_get_size(self)

    @size.setter
    def size(self, size):
        dll.fidget_font2_set_size(self, size)

    @property
    def line_height(self):
        return dll.fidget_font2_get_line_height(self)

    @line_height.setter
    def line_height(self, line_height):
        dll.fidget_font2_set_line_height(self, line_height)

    @property
    def paint(self):
        return dll.fidget_font2_get_paint(self)

    @paint.setter
    def paint(self, paint):
        dll.fidget_font2_set_paint(self, paint)

    @property
    def text_case(self):
        return dll.fidget_font2_get_text_case(self)

    @text_case.setter
    def text_case(self, text_case):
        dll.fidget_font2_set_text_case(self, text_case)

    @property
    def underline(self):
        return dll.fidget_font2_get_underline(self)

    @underline.setter
    def underline(self, underline):
        dll.fidget_font2_set_underline(self, underline)

    @property
    def strikethrough(self):
        return dll.fidget_font2_get_strikethrough(self)

    @strikethrough.setter
    def strikethrough(self, strikethrough):
        dll.fidget_font2_set_strikethrough(self, strikethrough)

    @property
    def no_kerning_adjustments(self):
        return dll.fidget_font2_get_no_kerning_adjustments(self)

    @no_kerning_adjustments.setter
    def no_kerning_adjustments(self, no_kerning_adjustments):
        dll.fidget_font2_set_no_kerning_adjustments(self, no_kerning_adjustments)

dll.fidget_font2_get_typeface.argtypes = [Font2]
dll.fidget_font2_get_typeface.restype = Typeface2
dll.fidget_font2_set_typeface.argtypes = [Font2, Typeface2]
dll.fidget_font2_get_size.argtypes = [Font2]
dll.fidget_font2_get_size.restype = c_float
dll.fidget_font2_set_size.argtypes = [Font2, c_float]
dll.fidget_font2_get_line_height.argtypes = [Font2]
dll.fidget_font2_get_line_height.restype = c_float
dll.fidget_font2_set_line_height.argtypes = [Font2, c_float]
dll.fidget_font2_get_paint.argtypes = [Font2]
dll.fidget_font2_get_paint.restype = Paint2
dll.fidget_font2_set_paint.argtypes = [Font2, Paint2]
dll.fidget_font2_get_text_case.argtypes = [Font2]
dll.fidget_font2_get_text_case.restype = TextCase
dll.fidget_font2_set_text_case.argtypes = [Font2, TextCase]
dll.fidget_font2_get_underline.argtypes = [Font2]
dll.fidget_font2_get_underline.restype = c_bool
dll.fidget_font2_set_underline.argtypes = [Font2, c_bool]
dll.fidget_font2_get_strikethrough.argtypes = [Font2]
dll.fidget_font2_get_strikethrough.restype = c_bool
dll.fidget_font2_set_strikethrough.argtypes = [Font2, c_bool]
dll.fidget_font2_get_no_kerning_adjustments.argtypes = [Font2]
dll.fidget_font2_get_no_kerning_adjustments.restype = c_bool
dll.fidget_font2_set_no_kerning_adjustments.argtypes = [Font2, c_bool]


dll.fidget_read_font2.argtypes = [c_char_p]
dll.fidget_read_font2.restype = Font2
def read_font2(font_path):
  return dll.fidget_read_font2(font_path.encode('utf8'))

