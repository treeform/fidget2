import macros, strutils, tables

## Generates .h files for C based on nim exports

{.passL: "-o fidget.dll".} # {.passL: "-o fidget.dll -s -shared -Wl,--out-implib,libfidget.a".}

var codec {.compiletime.}: string
var codepy {.compiletime.}: string
var codenim {.compiletime.}: string

proc toSnakeCase(s: string): string =
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

proc toVarCase(s: string): string =
  result = s
  if s.len > 0:
    result[0] = s[0].toLowerAscii()

proc rm(s: var string, what: string) =
  if s.len >= what.len and s[^what.len..^1] == what:
    s.setLen(s.len - what.len)

proc typeH(nimType: string): string =
  case nimType:
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
  of "": "void"
  else: nimType

proc exportProcH(defSym: NimNode) =
  echo defSym.treeRepr
  let def = defSym.getImpl()
  assert def.kind == nnkProcDef

  codec.add typeH(def[3][0].repr)

  codec.add " "
  codec.add "fidget_"
  codec.add toSnakeCase(def[0].repr)

  codec.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codec.add typeH(param[^2].repr)
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

  echo baseType.treeRepr

  codec.add "\n"
  codec.add "typedef long long "
  codec.add objName
  codec.add ";\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    let objName = refType[1][1].repr.split(":")[0]

    echo field.treeRepr
    echo " ", field.getImpl().treeRepr
    echo " ", field.getType().treeRepr
    echo " ", field.getTypeInst().treeRepr
    echo " " , field.isExported

    # generate getter and setter:
    codec.add typeH(fieldType.repr)
    codec.add " fidget_get_"
    codec.add toSnakeCase(objName)
    codec.add "_"
    codec.add toSnakeCase(field.repr)
    codec.add "("
    codec.add objName
    codec.add " "
    codec.add toSnakeCase(objName)
    codec.add ");\n"

    codec.add "void"
    codec.add " fidget_set_"
    codec.add toSnakeCase(objName)
    codec.add "_"
    codec.add toSnakeCase(field.repr)
    codec.add "("
    codec.add objName
    codec.add " "
    codec.add toSnakeCase(objName)
    codec.add ", "
    codec.add typeH(fieldType.repr)
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
      continue
    let fieldType = field.getType()
    codec.add "  "
    codec.add typeH(fieldType.repr)
    codec.add " "
    codec.add toSnakeCase(field.repr)
    codec.add ";\n"
  codec.add "} "
  codec.add objName
  codec.add ";\n\n"

macro writeH() =
  let header = """
#include <stdbool.h>
"""
  writeFile("fidget.h", header & codec)

proc typePy(nimType: string): string =
  case nimType:
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
  of "": "None"
  else: nimType #"c_longlong"

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

  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codepy.add typePy(param[^2].repr)
      codepy.add ", "
  codepy.rm(", ")
  codepy.add "]"
  codepy.add "\n"

  codepy.add "dll."
  codepy.add cName
  codepy.add ".restype = "
  codepy.add typePy(def[3][0].repr)
  codepy.add "\n"

  codepy.add "def "
  codepy.add pyName
  codepy.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codepy.add param[i].repr
      codepy.add ", "
  codepy.rm(", ")
  codepy.add ")"
  codepy.add ":\n"
  codepy.add "  return "
  if ret.repr == "string":
    discard
  elif ret.repr == "int":
    discard
  # else:
  #   codepy.add ret.repr
  #   codepy.add("(")

  codepy.add "dll."
  codepy.add cName
  codepy.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      if param[^2].repr == "string":
        codepy.add param[i].repr
        codepy.add(".encode('utf8')")
      elif param[^2].repr == "int":
        codepy.add param[i].repr
      else:
        #codepy.add "here"
        # codepy.add "tmp = "
        codepy.add param[i].repr
        # codepy.add "()\n"
        # codepy.add param[i].repr

      codepy.add ", "
  codepy.rm(", ")
  codepy.add ")"
  if ret.repr == "string":
    codepy.add(".decode('utf8')")
  elif ret.repr == "int":
    discard
  # else:
  #   codepy.add(")")
  codepy.add "\n\n"

proc exportRefObjectPy(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  codepy.add "class "
  codepy.add objName
  codepy.add "(Structure):\n"
  # codepy.add "    def __init__(self, id):\n"
  # codepy.add "      self.id = id\n"
  codepy.add "    _fields_ = [(\"ref\", c_void_p)]\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()

    codepy.add "\n"
    codepy.add "    @property\n"
    codepy.add "    def "
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self):\n"

    codepy.add "        return dll.fidget_get_"
    codepy.add toSnakeCase(objName)
    codepy.add "_"
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self)\n"

    codepy.add "\n"
    codepy.add "    @"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".setter\n"
    codepy.add "    def "
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self, "
    codepy.add toSnakeCase(field.repr)
    codepy.add "):\n"
    codepy.add "        dll.fidget_set_"
    codepy.add toSnakeCase(objName)
    codepy.add "_"
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self, "
    codepy.add toSnakeCase(field.repr)
    codepy.add ")\n"

  codepy.add "\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()

    codepy.add "dll.fidget_get_"
    codepy.add toSnakeCase(objName)
    codepy.add "_"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".argtypes = ["
    codepy.add objName
    codepy.add "]"
    codepy.add "\n"

    codepy.add "dll.fidget_get_"
    codepy.add toSnakeCase(objName)
    codepy.add "_"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".restype = "
    codepy.add typePy(fieldType.repr)
    codepy.add "\n"

    codepy.add "dll.fidget_set_"
    codepy.add toSnakeCase(objName)
    codepy.add "_"
    codepy.add toSnakeCase(field.repr)
    codepy.add ".argtypes = ["
    codepy.add objName
    codepy.add ", "
    codepy.add typePy(fieldType.repr)
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
  #  ("x", c_int),
  # ("y", c_int)


  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    codepy.add "        (\""
    codepy.add toSnakeCase(field.repr)
    codepy.add "\", "
    codepy.add  typePy(fieldType.repr)
    codepy.add "),\n"
  codepy.add "    ]\n"


macro writePy() =
  let header = """
from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

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
      if param[^2].repr == "string":
        codenim.add "cstring"
      else:
        codenim.add param[^2].repr
      codenim.add ", "
  codenim.rm ", "
  codenim.add ")"
  if ret.kind != nnkEmpty:
    codenim.add ": "
    if ret.repr == "string":
      codenim.add "cstring"
    else:
      codenim.add ret.repr
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
      if paramType.repr == "string":
        codenim.add "$"
      codenim.add toSnakeCase(param[i].repr)
      codenim.add ", "
  codenim.rm ", "
  codenim.add ")"
  if ret.repr == "string":
    codenim.add ".cstring"
  #if ret.repr notin nimBasicTypes:
  #  codenim.add ".toInt()"
  codenim.add "\n\n"

proc exportRefObjectNim(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    let fieldTypeName =
      if "enum" in fieldType.repr or "object" in fieldType.repr:
        "int"
      elif fieldType.repr == "string":
        "cstring"
      else:
        fieldType.repr

    codenim.add "proc fidget_get_"
    codenim.add toSnakeCase(objName)
    codenim.add "_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "("
    codenim.add toSnakeCase(objName)
    codenim.add ": "
    codenim.add objName
    codenim.add "): "
    codenim.add fieldTypeName
    codenim.add " {.cdecl, exportc, dynlib.} = \n"
    codenim.add "  echo \"get:\", cast[uint64](node)\n"
    codenim.add "  "
    codenim.add toSnakeCase(objName)
    codenim.add "."
    codenim.add field.repr
    codenim.add "\n"

    codenim.add "proc fidget_set_"
    codenim.add toSnakeCase(objName)
    codenim.add "_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "("
    codenim.add toSnakeCase(objName)
    codenim.add ": "
    codenim.add objName
    codenim.add ", "
    codenim.add field.repr
    codenim.add ": "
    codenim.add fieldTypeName
    codenim.add ")"
    codenim.add " {.cdecl, exportc, dynlib.} = \n"
    codenim.add "  echo \"set:\", cast[uint64](node)\n"
    codenim.add "  "
    codenim.add toSnakeCase(objName)
    codenim.add "."
    codenim.add field.repr
    codenim.add " = "
    codenim.add field.repr
    codenim.add "\n"

    # codenim.add "proc fidget_get_"
    # codenim.add toSnakeCase(objName)
    # codenim.add "_"
    # codenim.add toSnakeCase(field.repr)
    # codenim.add "("
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id: "
    # codenim.add "int"
    # codenim.add "): "
    # codenim.add fieldTypeName
    # codenim.add " {.cdecl, exportc, dynlib.} = "
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id.to"
    # codenim.add objName
    # codenim.add "()."
    # codenim.add field.repr
    # codenim.add "\n"

    # codenim.add "proc fidget_set_"
    # codenim.add toSnakeCase(objName)
    # codenim.add "_"
    # codenim.add toSnakeCase(field.repr)
    # codenim.add "("
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id: "
    # codenim.add "int"
    # codenim.add ", "
    # codenim.add field.repr
    # codenim.add ": "
    # codenim.add fieldTypeName
    # codenim.add ")"
    # codenim.add " {.cdecl, exportc, dynlib.} = \n"
    # codenim.add "  echo \"got:\", node_id\n"
    # codenim.add "  "
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id.to"
    # codenim.add objName
    # codenim.add "()."
    # codenim.add field.repr
    # codenim.add " = "
    # codenim.add field.repr
    # codenim.add "\n"

    # codenim.add "proc fidget_get_"
    # codenim.add toSnakeCase(objName)
    # codenim.add "_"
    # codenim.add toSnakeCase(field.repr)
    # codenim.add "("
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id: int): "
    # codenim.add fieldTypeName
    # codenim.add " {.cdecl, exportc, dynlib.} = "
    # codenim.add toVarCase(objName)
    # codenim.add "s["
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id]."
    # codenim.add field.repr
    # codenim.add "\n"

    # codenim.add "proc fidget_set_"
    # codenim.add toSnakeCase(objName)
    # codenim.add "_"
    # codenim.add toSnakeCase(field.repr)
    # codenim.add "("
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id: int, "
    # codenim.add field.repr
    # codenim.add ": "
    # codenim.add fieldTypeName
    # codenim.add ")"
    # codenim.add " {.cdecl, exportc, dynlib.} = "
    # codenim.add toVarCase(objName)
    # codenim.add "s["
    # codenim.add toSnakeCase(objName)
    # codenim.add "_id]."
    # codenim.add field.repr
    # codenim.add " = "
    # codenim.add field.repr
    # codenim.add "\n"


  codenim.add "\n"
  codenim.add "\n"

macro writeNim() =
  let header = """
"""
  writeFile("fidgetapi.nim", header & codenim)

macro exportRefObject(def: typed) =
  exportRefObjectH(def)
  exportRefObjectPy(def)
  exportRefObjectNim(def)

macro exportObject(def: typed) =
  exportObjectH(def)
  exportObjectPy(def)
  #exportObjectNim(def)

macro exportProc(def: typed) =
  exportProcH(def)
  exportProcPy(def)
  exportProcNim(def)

proc callMeMaybe(phone: string) =
  echo "from nim: ", phone

proc flightClubRule(n: int): string =
  return "Don't talk about flight club."

proc inputCode(a, b, c, d: int): bool =
  return false

proc nodeGetName(nodeId: int): string =
  return "nodeName"

import print
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


# exportProc(callMeMaybe)
# exportProc(flightClubRule)
# exportProc(inputCode)
# exportProc(nodeGetName)
exportProc(testNumbers)

# import fidget2
# exportProc(startFidget)

# proc startFidget() {.cdecl, exportc, dynlib, exporth, exportpy.} =
#   fidget2.startFidget(
#     figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
#     windowTitle = "Fidget",     # The title of the window.
#     entryFrame = "WelcomeFrame", # Frame to use as the entry from.
#     resizable = false,           # We want the window to resize to frame size.
#   )

# import tables



type
  Node = ref object
    id: int
    name*: string
    count*: int
exportRefObject(Node)

# var
#   nodesGenCount = 1
#   nodes: Table[int, Node]
# proc toInt(n: Node): int =
#   n.id
# proc toNode(i: int): Node =
#   nodes[i]
# nodes[0] = Node()

proc createNode(): Node =
  var node = Node()
  echo "new:", cast[int64](node)
  return node
exportProc(createNode)

type
  Vec2 = object
    x*, y*: float32
exportObject(Vec2)
proc giveVec(v: Vec2) =
  echo "given vec ", v

proc takeVec(): Vec2 =
  echo "taken vec ", Vec2(x: 1.2, y: 3.4)

exportProc(giveVec)
exportProc(takeVec)

writeH()
writePy()
writeNim()

converter cstringToString(s: cstring): string = $s

include fidgetapi
