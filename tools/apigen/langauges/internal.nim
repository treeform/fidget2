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

proc exportProcInternal*(defSym: NimNode) =
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

proc exportRefObjectInternal*(def: NimNode) =
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

const header = """
"""

macro writeInternal*() =
  writeFile("internalapi.nim", header & codenim)
