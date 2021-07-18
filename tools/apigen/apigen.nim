import macros

## Generates .h files for C based on nim exports

var codec {.compiletime.}: string
var codepy {.compiletime.}: string

proc rm(s: var string, number = 1) =
  if s.len >= number:
    s.setLen(s.len - number)

proc nimToCTypeRename(nimType: string): string =
  case nimType:
  of "cstring": "char*"
  of "": "void"
  else: nimType

macro exporth(def: typed) =
  echo def.treeRepr
  assert def.kind == nnkProcDef

  codec.add nimToCTypeRename(def[3][0].repr)

  codec.add " "
  codec.add def[0].repr

  codec.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codec.add nimToCTypeRename(param[^2].repr)
      codec.add " "
      codec.add param[i].repr
      codec.add ", "
  codec.rm(2)
  codec.add ")"
  codec.add ";\n"
  return def

macro writeH() =
  let header = """

"""
  writeFile("fidget.h", header & codec)


proc nimToCTypesRename(nimType: string): string =
  case nimType:
  of "cstring": "c_char_p"
  of "": "None"
  else: "c_" & nimType

macro exportpy(def: typed) =
  echo def.treeRepr
  assert def.kind == nnkProcDef

  codepy.add "dll."
  codepy.add def[0].repr
  codepy.add ".argtypes = ["
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codepy.add nimToCTypesRename(param[^2].repr)
      codepy.add ", "
  codepy.rm(2)
  codepy.add "]"
  codepy.add "\n"

  codepy.add "dll."
  codepy.add def[0].repr
  codepy.add ".restype = "
  codepy.add nimToCTypesRename(def[3][0].repr)
  codepy.add "\n"

  codepy.add "def "
  codepy.add def[0].repr
  codepy.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codepy.add param[i].repr
      codepy.add ", "
  codepy.rm(2)
  codepy.add ")"
  codepy.add ":\n"
  codepy.add "  return dll."
  codepy.add def[0].repr
  codepy.add "("
  for param in def[3][1..^1]:
    for i in 0 .. param.len - 3:
      codepy.add param[i].repr
      if param[^2].repr == "cstring":
        codepy.add(".encode('utf8')")
      codepy.add ", "
  codepy.rm(2)
  codepy.add ")"
  if def[3][0].repr == "cstring":
    codepy.add(".decode('utf8')")
  codepy.add "\n\n"
  return def

macro writePy() =
  let header = """
from ctypes import *
dll = cdll.LoadLibrary("fidget.dll")

class Node:
    @property
    def name(self):
        self.id = 123
        return nodeGetName(self.id)

"""
  writeFile("fidget.py", header & codepy)

proc callMeMaybe(phone: string) =
  echo "from nim: ", phone

proc callMeMaybe(phone: cstring) {.cdecl, exportc, dynlib, exporth, exportpy.} =
  echo "calling wrapper"
  callMeMaybe($phone)

proc flightClubRule(n: int): cstring {.cdecl, exportc, dynlib, exporth, exportpy.} =
  return "Don't talk about flight club."

proc inputCode(a, b, c, d: int): bool {.cdecl, exportc, dynlib, exporth, exportpy.} =
  return false

proc nodeGetName(nodeId: int): cstring {.cdecl, exportc, dynlib, exporth, exportpy.} =
  return "nodeName"

writeH()
writePy()
