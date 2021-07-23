import macros, strutils, ../common

var codepy {.compiletime.}: string

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

proc exportProcPy*(defSym: NimNode) =
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

proc exportRefObjectPy*(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  codepy.add "class "
  codepy.add objName
  codepy.add "(Structure):\n"
  codepy.add "    _fields_ = [(\"ref\", c_void_p)]\n"
  codepy.add "    def __bool__(self): return self.ref != None"

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

proc exportObjectPy*(def: NimNode) =
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

proc exportEnumPy*(def: NimNode) =
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

const header = """
from ctypes import *
import os, sys

if sys.platform == "win32":
  dllPath = 'fidget.dll'
elif sys.platform == "darwin":
  dllPath = 'libfidget.dylib'
else:
  dllPath = os.getcwd() + '/libfidget.so'
dll = cdll.LoadLibrary(dllPath)

c_proc_cb = CFUNCTYPE(None)

"""

macro writePy*() =
  writeFile("fidget.py", header & codepy)
