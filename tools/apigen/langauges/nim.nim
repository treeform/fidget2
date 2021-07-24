import macros, strutils, ../common

var codenim {.compiletime.}: string

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
  if "object" in nimType.repr:
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

proc exportProcNim*(defSym: NimNode) =
  let
    def = defSym.getImpl()
    name = def[0].repr
    cName = "fidget_" & toSnakeCase(name)
    ret = def[3][0]
    params = def[3][1..^1]


  codenim.add "proc "
  codenim.add name
  codenim.add "*("
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
  codenim.add " {.importc: \""
  codenim.add cName
  codenim.add "\".}\n\n"

  # codenim.add "  "
  # codenim.add name
  # codenim.add "("
  # for param in params:
  #   for i in 0 .. param.len - 3:
  #     var paramType = param[^2]
  #     # TODO Handle default types
  #     # if paramType.kind == nnkEmpty:
  #     #   paramType = param[^1].getType()
  #     codenim.add toSnakeCase(param[i].repr)
  #     codenim.add converterToNim(paramType)
  #     codenim.add ", "
  # codenim.rm ", "
  # codenim.add ")"
  # codenim.add converterFromNim(ret)
  # codenim.add "\n\n"

proc exportRefObjectNim*(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  codenim.add "type "
  codenim.add objName
  codenim.add "* = object\n"
  codenim.add "  reference: uint64\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr notin allowedFields:
      continue

    let fieldType = field.getType()

    codenim.add "proc `"
    codenim.add toSnakeCase(field.repr)
    codenim.add "`*("
    codenim.add toVarCase(objName)
    codenim.add ": "
    codenim.add objName
    codenim.add "): "
    codenim.add typeNim(fieldType)
    codenim.add " {.importc: \""
    codenim.add "fidget_"
    codenim.add toSnakeCase(objName)
    codenim.add "_get_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "\".}"
    codenim.add "\n"

    codenim.add "proc `"
    codenim.add toSnakeCase(field.repr)
    codenim.add "=`*("
    codenim.add toVarCase(objName)
    codenim.add ": "
    codenim.add objName
    codenim.add ", "
    codenim.add toVarCase(field.repr)
    codenim.add ": "
    codenim.add typeNim(fieldType)
    codenim.add ") "
    codenim.add "{.importc: \""
    codenim.add "fidget_"
    codenim.add toSnakeCase(objName)
    codenim.add "_set_"
    codenim.add toSnakeCase(field.repr)
    codenim.add "\".}"
    codenim.add "\n"

  codenim.add "\n"

proc exportObjectNim*(def: NimNode) =
  let
    baseType = def.getType()[1].getType()
    objName = def.repr
  codenim.add "type "
  codenim.add objName
  codenim.add "* = object\n"
  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    codenim.add "  "
    codenim.add field.repr
    codenim.add "*: "
    codenim.add fieldType.repr
    codenim.add "\n"
  codenim.add "\n"

proc exportEnumNim*(def: NimNode) =
  let enumTy = def.getType()[1]
  var i = 0
  codenim.add "type "
  codenim.add def.repr
  codenim.add "* = enum"
  codenim.add "\n"
  for enums in enumTy[1 .. ^1]:
    codenim.add "  "
    codenim.add enums.repr
    codenim.add " = "
    codenim.add $i
    codenim.add "\n"
    inc i
  codenim.add "\n"

const header = """
when defined(windows):
  const LibFidget* = "fidget.dll"
elif defined(macosx):
  const LibFidget* = "libfidget.dylib"
else:
  const LibFidget* = "libfidget.so"

{.push dynlib: LibFidget, cdecl.}

"""

const footer = """

{.pop.}
"""

macro writeNim*() =
  writeFile("fidgetapi.nim", header & codenim & footer)
