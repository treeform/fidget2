from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

dll.fidget_call_me_maybe.argtypes = [c_char_p]
dll.fidget_call_me_maybe.restype = None
def call_me_maybe(phone):
  return dll.fidget_call_me_maybe(phone.encode('utf8'))

dll.fidget_flight_club_rule.argtypes = [c_int]
dll.fidget_flight_club_rule.restype = c_char_p
def flight_club_rule(n):
  return dll.fidget_flight_club_rule(n).decode('utf8')

dll.fidget_input_code.argtypes = [c_int, c_int, c_int, c_int]
dll.fidget_input_code.restype = c_bool
def input_code(a, b, c, d):
  return dll.fidget_input_code(a, b, c, d)

dll.fidget_node_get_name.argtypes = [c_int]
dll.fidget_node_get_name.restype = c_char_p
def node_get_name(nodeId):
  return dll.fidget_node_get_name(nodeId).decode('utf8')

dll.fidget_start_fidget.argtypes = [c_char_p, c_char_p, c_char_p, c_bool]
dll.fidget_start_fidget.restype = None
def start_fidget(figmaUrl, windowTitle, entryFrame, resizable):
  return dll.fidget_start_fidget(figmaUrl.encode('utf8'), windowTitle.encode('utf8'), entryFrame.encode('utf8'), resizable)

