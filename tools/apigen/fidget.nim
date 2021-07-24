import macros, strutils, common, print, langauges/internal,
  langauges/c, langauges/python, langauges/nim, langauges/javascript

## Generates .h and py files for nim exports

macro exportProc(def: typed) =
  exportProcH(def)
  exportProcPy(def)
  exportProcJs(def)
  exportProcNim(def)
  exportProcInternal(def)

macro exportRefObject(def: typed) =
  exportRefObjectH(def)
  exportRefObjectPy(def)
  exportRefObjectJs(def)
  exportRefObjectNim(def)
  exportRefObjectInternal(def)

macro exportObject(def: typed) =
  exportObjectH(def)
  exportObjectPy(def)
  exportObjectJs(def)
  exportObjectNim(def)

macro exportEnum(def: typed) =
  exportEnumH(def)
  exportEnumPy(def)
  exportEnumJs(def)
  exportEnumNim(def)

# Test function calling
proc callMeMaybe(phone: string) =
  echo "from nim: ", phone
proc flightClubRule(n: int): string =
  return "Don't talk about flight club."
proc inputCode(a, b, c, d: int): bool =
  echo "got code: ", a, b, c, d
  return false
proc testNumbers(
  a: int8,
  b: uint8,
  c: int16,
  d: uint16,
  e: int32,
  f: uint32,
  g: int64,
  h: uint64,
  i: int,
  j: uint,
  k: float32,
  l: float64,
  m: float,
): bool =
  print a, b, c, d, e, f, g, h, i, j, k, l, m
exportProc(callMeMaybe)
exportProc(flightClubRule)
exportProc(inputCode)
exportProc(testNumbers)

# Test ref objects
type
  Fod = ref object
    id: int
    name*: string
    count*: int
exportRefObject(Fod)
proc createFod(): Fod =
  var fod = Fod()
  echo "new:", cast[int64](fod)
  return fod
exportProc(createFod)

# Test objects
type
  Vector2 = object
    x*, y*: float32
exportObject(Vector2)
proc giveVec(v: Vector2) =
  echo "given vec ", v
proc takeVec(): Vector2 =
  result = Vector2(x: 1.2, y: 3.4)
  echo "taken vec ", result
exportProc(giveVec)
exportProc(takeVec)

# Test enums
type
  AlignSomething = enum
    asDefault
    asTop
    asBottom
    asRight
    asLeft
exportEnum(AlignSomething)
proc repeatEnum(e: AlignSomething): AlignSomething =
  return e
exportProc(repeatEnum)

# Test callbacks
proc callMeBack(cb: proc() {.cdecl.}) =
  echo "calling cb"
  cb()
  echo "done with cb"
exportProc(callMeBack)

import fidget2, vmath
exportProc(onClickGlobal)

# exportObject(Vec2)
exportRefObject(Node)
proc findNode(glob: string): Node =
  if glob == ".":
    thisNode
  else:
    find(glob)
exportProc(findNode)

exportEnum(EventCbKind)

exportProc(addCb)
exportProc(startFidget)

writeH()
writePy()
writeJs()
writeNim()
writeInternal()
include internalapi
