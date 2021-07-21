from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

c_proc_cb = CFUNCTYPE(None)

dll.fidget_call_me_maybe.argtypes = [c_char_p]
dll.fidget_call_me_maybe.restype = None
def call_me_maybe(phone):
  return dll.fidget_call_me_maybe(phone.encode('utf8'))

dll.fidget_flight_club_rule.argtypes = [c_longlong]
dll.fidget_flight_club_rule.restype = c_char_p
def flight_club_rule(n):
  return dll.fidget_flight_club_rule(n).decode('utf8')

dll.fidget_input_code.argtypes = [c_longlong, c_longlong, c_longlong, c_longlong]
dll.fidget_input_code.restype = c_bool
def input_code(a, b, c, d):
  return dll.fidget_input_code(a, b, c, d)

dll.fidget_test_numbers.argtypes = [c_byte, c_ubyte, c_short, c_ushort, c_int, c_uint, c_longlong, c_ulonglong, c_longlong, c_ulonglong, c_float, c_double, c_double]
dll.fidget_test_numbers.restype = c_bool
def test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m):
  return dll.fidget_test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)

class Fod(Structure):
    _fields_ = [("ref", c_void_p)]

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


dll.fidget_create_fod.argtypes = []
dll.fidget_create_fod.restype = Fod
def create_fod():
  return dll.fidget_create_fod()

class Vector2(Structure):
    _fields_ = [
        ("x", c_float),
        ("y", c_float),
    ]
dll.fidget_give_vec.argtypes = [Vector2]
dll.fidget_give_vec.restype = None
def give_vec(v):
  return dll.fidget_give_vec(v)

dll.fidget_take_vec.argtypes = []
dll.fidget_take_vec.restype = Vector2
def take_vec():
  return dll.fidget_take_vec()

AlignSomething = c_longlong
asDefault = 0
asTop = 1
asBottom = 2
asRight = 3
asLeft = 4

dll.fidget_repeat_enum.argtypes = [AlignSomething]
dll.fidget_repeat_enum.restype = AlignSomething
def repeat_enum(e):
  return dll.fidget_repeat_enum(e)

dll.fidget_call_me_back.argtypes = [c_proc_cb]
dll.fidget_call_me_back.restype = None
def call_me_back(cb):
  return dll.fidget_call_me_back(cb)

dll.fidget_on_click_global.argtypes = [c_proc_cb]
dll.fidget_on_click_global.restype = None
def on_click_global(a):
  return dll.fidget_on_click_global(a)

class Node(Structure):
    _fields_ = [("ref", c_void_p)]

    @property
    def name(self):
        return dll.fidget_node_get_name(self).decode('utf8')

    @name.setter
    def name(self, name):
        dll.fidget_node_set_name(self, name.encode('utf8'))

    @property
    def characters(self):
        return dll.fidget_node_get_characters(self).decode('utf8')

    @characters.setter
    def characters(self, characters):
        dll.fidget_node_set_characters(self, characters.encode('utf8'))

    @property
    def dirty(self):
        return dll.fidget_node_get_dirty(self)

    @dirty.setter
    def dirty(self, dirty):
        dll.fidget_node_set_dirty(self, dirty)

dll.fidget_node_get_name.argtypes = [Node]
dll.fidget_node_get_name.restype = c_char_p
dll.fidget_node_set_name.argtypes = [Node, c_char_p]
dll.fidget_node_get_characters.argtypes = [Node]
dll.fidget_node_get_characters.restype = c_char_p
dll.fidget_node_set_characters.argtypes = [Node, c_char_p]
dll.fidget_node_get_dirty.argtypes = [Node]
dll.fidget_node_get_dirty.restype = c_bool
dll.fidget_node_set_dirty.argtypes = [Node, c_bool]


dll.fidget_find_node.argtypes = [c_char_p]
dll.fidget_find_node.restype = Node
def find_node(glob):
  return dll.fidget_find_node(glob.encode('utf8'))

dll.fidget_start_fidget.argtypes = [c_char_p, c_char_p, c_char_p, c_bool]
dll.fidget_start_fidget.restype = None
def start_fidget(figma_url, window_title, entry_frame, resizable):
  return dll.fidget_start_fidget(figma_url.encode('utf8'), window_title.encode('utf8'), entry_frame.encode('utf8'), resizable)

