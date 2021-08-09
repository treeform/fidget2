from ctypes import *
import os, sys

if sys.platform == "win32":
  dllPath = 'fidget.dll'
elif sys.platform == "darwin":
  dllPath = os.getcwd() + '/libfidget.dylib'
else:
  dllPath = os.getcwd() + '/libfidget.so'
dll = cdll.LoadLibrary(dllPath)

c_proc_cb = CFUNCTYPE(None)

dll.fidget_on_click_global.argtypes = [c_proc_cb]
dll.fidget_on_click_global.restype = None
def on_click_global(a):
  return dll.fidget_on_click_global(a)

class Node(Structure):
    _fields_ = [("ref", c_longlong)]
    def __bool__(self): return self.ref != None
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

EventCbKind = c_byte
E_ON_CLICK = 0
E_ON_FRAME = 1
E_ON_EDIT = 2
E_ON_DISPLAY = 3
E_ON_FOCUS = 4
E_ON_UNFOCUS = 5

dll.fidget_add_cb.argtypes = [EventCbKind, c_longlong, c_char_p, c_proc_cb]
dll.fidget_add_cb.restype = None
def add_cb(kind, priority, glob, handler):
  return dll.fidget_add_cb(kind, priority, glob.encode('utf8'), handler)

dll.fidget_start_fidget.argtypes = [c_char_p, c_char_p, c_char_p, c_bool]
dll.fidget_start_fidget.restype = None
def start_fidget(figma_url, window_title, entry_frame, resizable):
  return dll.fidget_start_fidget(figma_url.encode('utf8'), window_title.encode('utf8'), entry_frame.encode('utf8'), resizable)

