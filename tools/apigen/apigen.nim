import macros, strutils, strformat

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

proc rm(s: var string, what: string) =
  if s.len >= what.len and s[^what.len..^1] == what:
    s.setLen(s.len - what.len)

proc nimToCTypeRename(nimType: string): string =
  case nimType:
  of "cstring": "char*"
  of "string": "char*"
  of "": "void"
  else: nimType

proc exportProcH(defSym: NimNode) =
  let def = defSym.getImpl()
  assert def.kind == nnkProcDef

  codec.add nimToCTypeRename(def[3][0].repr)

  codec.add " "
  codec.add "fidget_"
  codec.add toSnakeCase(def[0].repr)

  codec.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codec.add nimToCTypeRename(param[^2].repr)
      codec.add " "
      codec.add toSnakeCase(param[i].repr)
      codec.add ", "
  codec.rm(", ")
  codec.add ")"
  codec.add ";\n"

macro exportTypeH(def: typed) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()

  for field in baseType[2]:
    echo field.treeRepr
    let fieldType = field.getType()
    let objName = refType[1][1].repr.split(":")[0]
    echo field.getType().treeRepr

    # generate getter and setter:
    codec.add nimToCTypeRename(fieldType.repr)
    codec.add " get_"
    codec.add toSnakeCase(field.repr)
    codec.add "(int "
    codec.add toSnakeCase(objName)
    codec.add "_id);\n"

    codec.add "void"
    codec.add " set_"
    codec.add toSnakeCase(field.repr)
    codec.add "(int "
    codec.add toSnakeCase(objName)
    codec.add "_id, "
    codec.add nimToCTypeRename(fieldType.repr)
    codec.add " "
    codec.add toSnakeCase(field.repr)
    codec.add ");\n"

macro writeH() =
  let header = """
#include <stdbool.h>
"""
  writeFile("fidget.h", header & codec)

proc nimToCTypesRename(nimType: string): string =
  case nimType:
  of "string": "c_char_p"
  of "": "None"
  else: "c_" & nimType

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
      codepy.add nimToCTypesRename(param[^2].repr)
      codepy.add ", "
  codepy.rm(", ")
  codepy.add "]"
  codepy.add "\n"

  codepy.add "dll."
  codepy.add cName
  codepy.add ".restype = "
  codepy.add nimToCTypesRename(def[3][0].repr)
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
  codepy.add "  return dll."
  codepy.add cName
  codepy.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codepy.add param[i].repr
      if param[^2].repr == "string":
        codepy.add(".encode('utf8')")
      codepy.add ", "
  codepy.rm(", ")
  codepy.add ")"
  if ret.repr == "string":
    codepy.add(".decode('utf8')")
  codepy.add "\n\n"

macro exportTypePy(def: typed) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  codepy.add "class "
  codepy.add objName
  codepy.add ":\n"

  for field in baseType[2]:
    echo field.treeRepr
    let fieldType = field.getType()

    echo field.getType().treeRepr

    codepy.add "\n"
    codepy.add "    @property\n"
    codepy.add "    def "
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self):\n"
    codepy.add "        return dll.fidget_get_"
    codepy.add toSnakeCase(objName)
    codepy.add "_"
    codepy.add toSnakeCase(field.repr)
    codepy.add "(self.id)\n"

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
    codepy.add "(self.id, "
    codepy.add toSnakeCase(field.repr)
    codepy.add ")\n"

  codepy.add "\n"
  codepy.add "\n"

macro writePy() =
  let header = """
from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

"""
  writeFile("fidget.py", header & codepy)

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
  codenim.add "\n\n"


macro exportTypeNim(def: typed) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  for field in baseType[2]:
    echo field.treeRepr
    let fieldType = field.getType()

    echo field.getType().treeRepr

    let fieldTypeName =
      if "enum" in fieldType.repr or "object" in fieldType.repr:
        "int"
      else:
        fieldType.repr

    codenim.add "proc fidget_get_"
    codenim.add toSnakeCase(objName)
    codenim.add "_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "(id: int): "
    codenim.add fieldTypeName
    codenim.add " {.exportc.} = "
    codenim.add "nodes[id]."
    codenim.add field.repr
    codenim.add "\n"

    codenim.add "proc fidget_set_"
    codenim.add toSnakeCase(objName)
    codenim.add "_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "(id: int, "
    codenim.add field.repr
    codenim.add ": "
    codenim.add fieldTypeName
    codenim.add ")"
    codenim.add " {.exportc.} = "
    codenim.add "nodes[id]."
    codenim.add field.repr
    codenim.add " = "
    codenim.add field.repr
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

proc callMeMaybe(phone: string) =
  echo "from nim: ", phone

proc flightClubRule(n: int): string =
  return "Don't talk about flight club."

proc inputCode(a, b, c, d: int): bool =
  return false

proc nodeGetName(nodeId: int): string =
  return "nodeName"


exportProc(callMeMaybe)
exportProc(flightClubRule)
exportProc(inputCode)
exportProc(nodeGetName)

import fidget2

exportProc(startFidget)

# proc startFidget() {.cdecl, exportc, dynlib, exporth, exportpy.} =
#   fidget2.startFidget(
#     figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
#     windowTitle = "Fidget",     # The title of the window.
#     entryFrame = "WelcomeFrame", # Frame to use as the entry from.
#     resizable = false,           # We want the window to resize to frame size.
#   )

# import tables

# type
#   Node = ref object
#     id: int
#     name: string
#     count: int

# var nodes: Table[int, Node]

# exportType(Node)

#exportTypeH(SomeObject)
# exportTypePy(SomeObject)

# import fidget2/schema

# exportTypePy(Node)
# exportTypeNim(Node)

writeH()
writePy()
writeNim()

include fidgetapi
