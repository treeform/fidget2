import macros, strutils, ../common

var codec {.compiletime.}: string

proc typeH(nimType: NimNode): string =
  ## Converts nim type to c type.

  if nimType.kind == nnkBracketExpr:
    return nimType[1].getTypeInst().repr.split(":")[0]

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

proc exportProcH*(defSym: NimNode) =
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

proc exportRefObjectH*(def: NimNode) =
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
    if field.repr in bannedFields:
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

proc exportObjectH*(def: NimNode) =
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

proc exportEnumH*(def: NimNode) =
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

const header = """
#include <stdbool.h>

typedef void (*proc_cb)();

"""

proc writeH*(name: string) =
  writeFile(name & ".h", header & codec)
