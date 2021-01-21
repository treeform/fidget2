from ctypes import *
fidget = cdll.LoadLibrary("libfidget.dll")

count = 0

@CFUNCTYPE(None)
def handler():
    global count
    count += 1
    print("count", count)
fidget.onClick("CounterFrame/Count1Up".encode('utf8'), handler)

@CFUNCTYPE(None, POINTER(c_char))
def handler2(what):
    fidget.setCharacters("CounterFrame/CounterDisplay/text".encode('utf8'), str(count).encode('utf8'))
fidget.onDisplay("CounterFrame/CounterDisplay/text".encode('utf8'), handler2)

fidget.startFidget(
  "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa".encode('utf8'),
  "Python Counter".encode('utf8'),
  "CounterFrame".encode('utf8'),
  False
)
