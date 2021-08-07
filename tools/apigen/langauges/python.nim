import macros, strutils, ../common, strformat

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
  else:
    if nimType.kind == nnkVarTy:
      typePy(nimType[0])
    elif nimType.kind == nnkObjectTy:
      nimType.getTypeInst().repr
    elif nimType.kind == nnkBracketExpr:
      if nimType[0].repr == "seq":
        "SeqOf" & nimType[1].repr.capitalizeAscii()
      else:
        nimType[1].getTypeInst().repr.split(":")[0]
    elif nimType.kind == nnkEnumTy:
      nimType.getTypeInst().repr
    else:
      nimType.repr

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
  codepy.add "    _fields_ = [(\"ref\", c_longlong)]\n"
  codepy.add "    def __bool__(self): return self.ref != None"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr in bannedFields:
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
    if field.repr in bannedFields:
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
    codepy.add typePy(fieldType)
    codepy.add "),\n"
  codepy.add "    ]\n"

  codepy.add "    def __eq__(self, obj):\n"
  codepy.add "        return "
  for field in baseType[2]:
    codepy.add "self."
    codepy.add toSnakeCase(field.repr)
    codepy.add " == obj."
    codepy.add toSnakeCase(field.repr)
    codepy.add " and "
  codepy.rm " and "
  codepy.add "\n"
  codepy.add "\n"

proc exportSeqPy*(def: NimNode) =
  echo ":::", def.treeRepr
  let
    refType = def[1]
    objPyType = typePy(refType)
    objName = refType.repr
    seqName = "SeqOf" & objName.capitalizeAscii()
    cName = toSnakeCase(seqName)

  codepy.add "class "
  codepy.add seqName
  codepy.add "(Structure):\n"
  codepy.add "    _fields_ = [\n"
  codepy.add "        (\"cap\", c_longlong),\n"
  codepy.add "        (\"data\", c_longlong)\n"
  codepy.add "    ]\n"

  codepy.add "    def __getitem__(self, index):\n"
  codepy.add "      return dll.fidget_"
  codepy.add cName
  codepy.add "_get(self, index)\n"
  codepy.add "    def __setitem__(self, index, value):\n"
  codepy.add "      return dll.fidget_"
  codepy.add cName
  codepy.add "_set(self, index, value)\n"
  codepy.add "    def __len__(self):\n"
  codepy.add "      return dll.fidget_"
  codepy.add cName
  codepy.add "_len(self)\n"

  codepy.add "dll.fidget_"
  codepy.add cName
  codepy.add "_get.argtypes = ["
  codepy.add seqName
  codepy.add ", c_longlong]\n"
  codepy.add "dll.fidget_"
  codepy.add cName
  codepy.add "_get.restype = "
  codepy.add objPyType
  codepy.add "\n"

  codepy.add "dll.fidget_"
  codepy.add cName
  codepy.add "_set.argtypes = ["
  codepy.add seqName
  codepy.add ", c_longlong, "
  codepy.add objPyType
  codepy.add "]\n"
  codepy.add "dll.fidget_"
  codepy.add cName
  codepy.add "_set.restype = None\n"

  codepy.add "dll.fidget_"
  codepy.add cName
  codepy.add "_len.argtypes = ["
  codepy.add seqName
  codepy.add "]\n"
  codepy.add "dll.fidget_"
  codepy.add cName
  codepy.add "_len.restype = c_longlong\n"

  codepy.add "\n"

proc exportEnumPy*(def: NimNode) =
  let enumTy = def.getType()[1]
  var i = 0
  var pyType = case getSize(enumTy):
    of 1: "c_byte"
    of 2: "c_short"
    of 4: "c_int"
    of 8: "c_longlong"
    else: quit("enum size not supported")
  codepy.add def.repr
  codepy.add " = "
  codepy.add pyType
  codepy.add "\n"
  for enums in enumTy[1 .. ^1]:
    codepy.add toCapCase(enums.repr)
    codepy.add " = "
    codepy.add $i
    codepy.add "\n"
    inc i
  codepy.add "\n"


proc writePy*(name: string) =
  var header = fmt"""
from ctypes import *
import os, sys

if sys.platform == "win32":
  dllPath = '{name}.dll'
elif sys.platform == "darwin":
  dllPath = os.getcwd() + '/lib{name}.dylib'
else:
  dllPath = os.getcwd() + '/lib{name}.so'
dll = cdll.LoadLibrary(dllPath)

c_proc_cb = CFUNCTYPE(None)

"""

  writeFile(name & ".py", header & codepy)
