from ctypes import *

fidget = cdll.LoadLibrary("libfidget.dll")

fidget.startFidget(
  "https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs".encode('utf8'),
  "Python Layouts".encode('utf8'),
  "Layout1".encode('utf8'),
  True
)
