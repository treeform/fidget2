from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

class Node:
    @property
    def name(self):
        self.id = 123
        return nodeGetName(self.id)

dll.callMeMaybe.argtypes = [c_char_p]
dll.callMeMaybe.restype = None
def callMeMaybe(phone):
  return dll.callMeMaybe(phone.encode('utf8'))

dll.flightClubRule.argtypes = [c_int]
dll.flightClubRule.restype = c_char_p
def flightClubRule(n):
  return dll.flightClubRule(n).decode('utf8')

dll.inputCode.argtypes = [c_int, c_int, c_int, c_int]
dll.inputCode.restype = c_bool
def inputCode(a, b, c, d):
  return dll.inputCode(a, b, c, d)

dll.nodeGetName.argtypes = [c_int]
dll.nodeGetName.restype = c_char_p
def nodeGetName(nodeId):
  return dll.nodeGetName(nodeId).decode('utf8')

