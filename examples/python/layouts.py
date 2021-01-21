from ctypes import *

fidget = cdll.LoadLibrary("libfidget.dll")

print(fidget)

@CFUNCTYPE(None, c_int, c_int)
def callback(a, b):
    print("foo has finished its job (%d, %d)" % (a, b))
fidget.registerCallback(callback, 1, 2)

# fidget.startFidget(
#   "https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs".encode('utf8'),
#   "Layouts".encode('utf8'),
#   "Layout1".encode('utf8'),
#   True
# )
