import macros, strutils, print

## Generates .h and py files for nim exports

const allowedFields = @["name", "count", "characters", "dirty"]

{.passL: "-o fidget.dll".} # {.passL: "-o fidget.dll -s -shared -Wl,--out-implib,libfidget.a".}

var codec {.compiletime.}: string
var codepy {.compiletime.}: string
var codenim {.compiletime.}: string

proc toSnakeCase(s: string): string =
  ## Converts NimTypes to nim_types.
  if s.len == 0:
    return
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[result.len-1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
      result.add c.toLowerAscii()
    else:
      prevCap = false
      result.add c

proc toCapCase(s: string): string =
  ## Converts NimTypes to NIM_TYPES.
  if s.len == 0:
    return
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[result.len-1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
    else:
      prevCap = false
    result.add c.toUpperAscii()

proc toVarCase(s: string): string =
  ## Lower the first char, NimType -> nimType.
  result = s
  if s.len > 0:
    result[0] = s[0].toLowerAscii()

proc rm(s: var string, what: string) =
  ## Will remove the last thing from a string, usually used for ", "
  if s.len >= what.len and s[^what.len..^1] == what:
    s.setLen(s.len - what.len)

proc typeH(nimType: NimNode): string =
  ## Converts nim type to c type.
  case nimType.repr:
  of "string": "char*"
  of "bool": "bool"
  of "int8": "char"
  of "int16": "short"
  of "int32": "int"
  of "int64": "long long"
  of "int": "long long"
  of "uint8": "unsigned char"
  of "uint16": "unsigned short"
  of "uint32": "unsigned int"
  of "uint64": "unsigned long long"
  of "uint": "unsigned long long"
  of "float32": "float"
  of "float64": "double"
  of "float": "double"
  of "proc () {.cdecl.}": "proc_cb"
  of "": "void"
  else: nimType.repr

proc exportProcH(defSym: NimNode) =
  let def = defSym.getImpl()
  assert def.kind == nnkProcDef
  codec.add typeH(def[3][0])
  codec.add " fidget_"
  codec.add  toSnakeCase(def[0].repr)
  codec.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codec.add typeH(param[^2])
      codec.add " "
      codec.add toSnakeCase(param[i].repr)
      codec.add ", "
  codec.rm(", ")
  codec.add ")"
  codec.add ";\n"

proc exportRefObjectH(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  codec.add "\n"
  codec.add "typedef long long "
  codec.add objName
  codec.add ";\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr notin allowedFields:
      continue
    let fieldType = field.getType()

    # generate getter and setter:
    codec.add typeH(fieldType)
    codec.add " fidget_"
    codec.add toSnakeCase(objName)
    codec.add "_get_"
    codec.add toSnakeCase(field.repr)
    codec.add "("
    codec.add objName
    codec.add " "
    codec.add toSnakeCase(objName)
    codec.add ");\n"

    codec.add "void"
    codec.add " fidget_"
    codec.add toSnakeCase(objName)
    codec.add "_set_"
    codec.add toSnakeCase(field.repr)
    codec.add "("
    codec.add objName
    codec.add " "
    codec.add toSnakeCase(objName)
    codec.add ", "
    codec.add typeH(fieldType)
    codec.add " "
    codec.add toSnakeCase(field.repr)
    codec.add ");\n"
  codec.add "\n"

proc exportObjectH(def: NimNode) =
  let
    baseType = def.getType()[1].getType()
    objName = def.repr
  codec.add "\n"
  codec.add "typedef struct "
  codec.add objName
  codec.add " {\n"
  for field in baseType[2]:
    if field.isExported == false:
      # TODO: Probably can't do this as layout will not match.
      quit()
    let fieldType = field.getType()
    codec.add "  "
    codec.add typeH(fieldType)
    codec.add " "
    codec.add toSnakeCase(field.repr)
    codec.add ";\n"
  codec.add "} "
  codec.add objName
  codec.add ";\n\n"

proc exportEnumH(def: NimNode) =
  let enumTy = def.getType()[1]
  var i = 0
  codec.add "\n"
  codec.add "typedef long long "
  codec.add def.repr
  codec.add ";\n"
  for enums in enumTy[1 .. ^1]:
    codec.add "#define "
    codec.add toCapCase(enums.repr)
    codec.add " "
    codec.add $i
    codec.add "\n"
    inc i

macro writeH() =
  let header = """
#include <stdbool.h>

typedef void (*proc_cb)();

"""
  writeFile("fidget.h", header & codec)

proc typePy(nimType: NimNode): string =
  ## Converts nim type to python type.
  case nimType.repr:
  of "string": "c_char_p"
  of "bool": "c_bool"
  of "int8": "c_byte"
  of "int16": "c_short"
  of "int32": "c_int"
  of "int64": "c_longlong"
  of "int": "c_longlong"
  of "uint8": "c_ubyte"
  of "uint16": "c_ushort"
  of "uint32": "c_uint"
  of "uint64": "c_ulonglong"
  of "uint": "c_ulonglong"
  of "float32": "c_float"
  of "float64": "c_double"
  of "float": "c_double"
  of "proc () {.cdecl.}": "c_proc_cb"
  of "": "None"
  else: nimType.repr

proc converterFromPy(nimType: NimNode): string =
  if "string" == nimType.repr:
    return ".encode('utf8')"

proc converterToPy(nimType: NimNode): string =
  if "string" == nimType.repr:
    return ".decode('utf8')"

proc exportProcPy(defSym: NimNode) =
  let def = defSym.getImpl()
  assert def.kind == nnkProcDef
  let
    ret = def[3][0]
    params = def[3][1..^1]
    name = def[0].repr
    pyName = toSnakeCase(name)
    cName = "fidget_" & pyName

  codepy.add "dll."
  codepy.add cName
  codepy.add ".argtypes = ["
  for param in params:
    for i in 0 .. param.len - 3:
      codepy.add typePy(param[^2])
      codepy.add ", "
  codepy.rm(", ")
  codepy.add "]"
  codepy.add "\n"

  codepy.add "dll."
  codepy.add cName
  codepy.add ".restype = "
  codepy.add typePy(ret)
  codepy.add "\n"

  codepy.add "def "
  codepy.add pyName
  codepy.add "("
  for param in params:
    for i in 0 .. param.len - 3:
      codepy.add toSnakeCase(param[i].repr)
      codepy.add ", "
  codepy.rm(", ")
  codepy.add ")"
  codepy.add ":\n"

  codepy.add "  return "
  codepy.add "dll."
  codepy.add cName
  codepy.add "("
  for param in params:
    for i in 0 .. param.len - 3:
      codepy.add toSnakeCase(param[i].repr)
      codepy.add converterFromPy(param[^2])
      codepy.add ", "
  codepy.rm(", ")
  codepy.add ")"
  codepy.add converterToPy(ret)
  codepy.add "\n\n"

proc exportRefObjectPy(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  codepy.add "class "
  codepy.add objName
  codepy.add "(Structure):\n"
  codepy.add "    _fields_ = [(\"ref\", c_void_p)]\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr notin allowedFields:
      continue
    let fieldType = field.getType()

    codepy.add "\n"
    codepy.add "    @property\n"
    codepy.add "    def "
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self):\n"

    codepy.add "        return dll.fidget_"
    codepy.add toSnakeCase(objName)
    codepy.add "_get_"
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self)"
    codepy.add converterToPy(fieldType)
    codepy.add "\n"

    codepy.add "\n"
    codepy.add "    @"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".setter\n"
    codepy.add "    def "
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self, "
    codepy.add toSnakeCase(field.repr)
    codepy.add "):\n"
    codepy.add "        dll.fidget_"
    codepy.add toSnakeCase(objName)
    codepy.add "_set_"
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self, "
    codepy.add toSnakeCase(field.repr)
    codepy.add converterFromPy(fieldType)
    codepy.add ")\n"

  codepy.add "\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr notin allowedFields:
      continue
    let fieldType = field.getType()

    codepy.add "dll.fidget_"
    codepy.add toSnakeCase(objName)
    codepy.add "_get_"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".argtypes = ["
    codepy.add objName
    codepy.add "]"
    codepy.add "\n"

    codepy.add "dll.fidget_"
    codepy.add toSnakeCase(objName)
    codepy.add "_get_"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".restype = "
    codepy.add typePy(fieldType)
    codepy.add "\n"

    codepy.add "dll.fidget_"
    codepy.add toSnakeCase(objName)
    codepy.add "_set_"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".argtypes = ["
    codepy.add objName
    codepy.add ", "
    codepy.add typePy(fieldType)
    codepy.add "]"
    codepy.add "\n"

  codepy.add "\n"
  codepy.add "\n"

proc exportObjectPy(def: NimNode) =
  let
    baseType = def.getType()[1].getType()
    objName = def.repr
  codepy.add "class "
  codepy.add objName
  codepy.add "(Structure):\n"
  codepy.add "    _fields_ = [\n"
  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    codepy.add "        (\""
    codepy.add toSnakeCase(field.repr)
    codepy.add "\", "
    codepy.add  typePy(fieldType)
    codepy.add "),\n"
  codepy.add "    ]\n"

proc exportEnumPy(def: NimNode) =
  let enumTy = def.getType()[1]
  var i = 0
  codepy.add def.repr
  codepy.add " = c_longlong"
  codepy.add "\n"
  for enums in enumTy[1 .. ^1]:
    codepy.add toCapCase(enums.repr)
    codepy.add " = "
    codepy.add $i
    codepy.add "\n"
    inc i
  codepy.add "\n"

macro writePy() =
  let header = """
from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

c_proc_cb = CFUNCTYPE(None)

"""
  writeFile("fidget.py", header & codepy)

const nimBasicTypes = [
  "bool",
  "int8",
  "uint8",
  "int16",
  "uint16",
  "int32",
  "uint32",
  "int64",
  "uint64",
  "int",
  "uint",
  "float32",
  "float64",
  "float",
  "Vec2"
]

proc typeNim(nimType: NimNode): string =
  # echo nimType.repr
  # echo nimType.getImpl().treeRepr
  if "enum" in nimType.repr or
    (nimType.kind == nnkSym and "EnumTy" in nimType.getImpl().treeRepr):
    return "int"
  elif "object" in nimType.repr:
    return nimType.getTypeInst().repr
  elif nimType.repr == "string":
    return "cstring"
  elif nimType.repr == "GVec2":
    return "Vec2"
  else:
    nimType.repr

proc converterFromNim(nimType: NimNode): string =
  if "enum" in nimType.repr or
    (nimType.kind == nnkSym and "EnumTy" in nimType.getImpl().treeRepr):
    return ".ord"
  elif "string" == nimType.repr:
    return ".cstring"

proc converterToNim(nimType: NimNode): string =
  if "enum" in nimType.repr or (
    nimType.kind == nnkSym and "EnumTy" in nimType.getImpl().treeRepr):
    return "." & nimType.getTypeInst().repr
  elif "string" == nimType.repr:
    return ".`$`"

proc exportProcNim(defSym: NimNode) =
  let
    def = defSym.getImpl()
    name = def[0].repr
    ret = def[3][0]
    params = def[3][1..^1]

  codenim.add "proc "
  codenim.add "fidget_"
  codenim.add toSnakeCase(name)
  codenim.add "("
  for param in params:
    for i in 0 .. param.len - 3:
      codenim.add toSnakeCase(param[i].repr)
      codenim.add ": "
      codenim.add typeNim(param[^2])
      codenim.add ", "
  codenim.rm ", "
  codenim.add ")"
  if ret.kind != nnkEmpty:
    codenim.add ": "
    codenim.add typeNim(ret)
  codenim.add " {.cdecl, exportc, dynlib.} =\n"

  codenim.add "  "
  codenim.add name
  codenim.add "("
  for param in params:
    for i in 0 .. param.len - 3:
      var paramType = param[^2]
      # TODO Handle default types
      # if paramType.kind == nnkEmpty:
      #   paramType = param[^1].getType()
      codenim.add toSnakeCase(param[i].repr)
      codenim.add converterToNim(paramType)
      codenim.add ", "
  codenim.rm ", "
  codenim.add ")"
  codenim.add converterFromNim(ret)
  codenim.add "\n\n"

proc exportRefObjectNim(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr notin allowedFields:
      continue

    let fieldType = field.getType()

    codenim.add "proc fidget_"
    codenim.add toSnakeCase(objName)
    codenim.add "_get_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "("
    codenim.add toSnakeCase(objName)
    codenim.add ": "
    codenim.add objName
    codenim.add "): "
    codenim.add typeNim(fieldType)
    codenim.add " {.cdecl, exportc, dynlib.} = \n"
    codenim.add "  "
    codenim.add toSnakeCase(objName)
    codenim.add "."
    codenim.add field.repr
    codenim.add converterFromNim(fieldType)
    codenim.add "\n"

    codenim.add "proc fidget_"
    codenim.add toSnakeCase(objName)
    codenim.add "_set_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "("
    codenim.add toSnakeCase(objName)
    codenim.add ": "
    codenim.add objName
    codenim.add ", "
    codenim.add field.repr
    codenim.add ": "
    codenim.add typeNim(fieldType)
    codenim.add ")"
    codenim.add " {.cdecl, exportc, dynlib.} = \n"
    codenim.add "  "
    codenim.add toSnakeCase(objName)
    codenim.add "."
    codenim.add field.repr
    codenim.add " = "
    codenim.add field.repr
    codenim.add converterToNim(fieldType)
    codenim.add "\n"
  codenim.add "\n"
  codenim.add "\n"

macro writeNim() =
  let header = """
"""
  writeFile("fidgetapi.nim", header & codenim)

macro exportProc(def: typed) =
  exportProcH(def)
  exportProcPy(def)
  exportProcNim(def)

macro exportRefObject(def: typed) =
  exportRefObjectH(def)
  exportRefObjectPy(def)
  exportRefObjectNim(def)

macro exportObject(def: typed) =
  exportObjectH(def)
  exportObjectPy(def)
  #exportObjectNim(def)

macro exportEnum(def: typed) =
  exportEnumH(def)
  exportEnumPy(def)

# Test function calling
proc callMeMaybe(phone: string) =
  echo "from nim: ", phone
proc flightClubRule(n: int): string =
  return "Don't talk about flight club."
proc inputCode(a, b, c, d: int): bool =
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
# proc setCharacters(glob, characters: string) =
#   var node = find(glob)
#   node.characters = characters
#   node.dirty = true
# exportProc(setCharacters)
exportProc(onClickGlobal)

# exportObject(Vec2)
exportRefObject(Node)
proc findNode(glob: string): Node =
  find(glob)
exportProc(findNode)
exportProc(startFidget)

writeH()
writePy()
writeNim()
include fidgetapi
