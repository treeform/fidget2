from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

dll.fidget_test_numbers.argtypes = [c_byte, c_ubyte, c_short, c_ushort, c_int, c_uint, c_longlong, c_ulonglong, c_longlong, c_ulonglong, c_float, c_double, c_double]
dll.fidget_test_numbers.restype = c_bool
def test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m):
  return dll.fidget_test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)

class Node(Structure):
    _fields_ = [("ref", c_void_p)]

    @property
    def name(self):
        return dll.fidget_get_node_name(self)

    @name.setter
    def name(self, name):
        dll.fidget_set_node_name(self, name)

    @property
    def count(self):
        return dll.fidget_get_node_count(self)

    @count.setter
    def count(self, count):
        dll.fidget_set_node_count(self, count)

dll.fidget_get_node_name.argtypes = [Node]
dll.fidget_get_node_name.restype = c_char_p
dll.fidget_set_node_name.argtypes = [Node, c_char_p]
dll.fidget_get_node_count.argtypes = [Node]
dll.fidget_get_node_count.restype = c_longlong
dll.fidget_set_node_count.argtypes = [Node, c_longlong]


dll.fidget_create_node.argtypes = []
dll.fidget_create_node.restype = Node
def create_node():
  return dll.fidget_create_node()

class Vec2(Structure):
    _fields_ = [
        ("x", c_float),
        ("y", c_float),
    ]
dll.fidget_give_vec.argtypes = [Vec2]
dll.fidget_give_vec.restype = None
def give_vec(v):
  return dll.fidget_give_vec(v)

dll.fidget_take_vec.argtypes = []
dll.fidget_take_vec.restype = Vec2
def take_vec():
  return dll.fidget_take_vec()

