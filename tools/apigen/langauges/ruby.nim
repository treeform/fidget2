import macros, strutils, ../common

var coderb0 {.compiletime.}: string
var coderb1 {.compiletime.}: string
var coderb2 {.compiletime.}: string

proc typeRuby(nimType: NimNode): string =
  ## Converts nim type to python type.
  case nimType.repr:
  of "string": ":string"
  of "bool": ":bool"
  of "int8": ":int8"
  of "int16": ":int16"
  of "int32": ":int32"
  of "int64": ":int64"
  of "int": ":int64"
  of "uint8": ":uint8"
  of "uint16": ":uint16"
  of "uint32": ":uint32"
  of "uint64": ":uint64"
  of "uint": ":uint64"
  of "float32": ":float"
  of "float64": ":double"
  of "float": ":double"
  of "proc () {.cdecl.}": ":fidget_cb"
  of "": ":void"
  else:
    if nimType.kind == nnkBracketExpr:
      return nimType[1].getTypeInst().repr.split(":")[0] & ".by_value"
    elif "enum" in nimType.repr or
      (nimType.kind == nnkSym and "EnumTy" in nimType.getImpl().treeRepr):
        nimType.repr
    else:
      nimType.repr & ".by_value"

proc converterFromRuby(nimType: NimNode): string =
  if "string" == nimType.repr:
    return ".encode('utf8')"

proc converterToRuby(nimType: NimNode): string =
  if "string" == nimType.repr:
    return ".decode('utf8')"

proc exportProcRuby*(defSym: NimNode) =
  let def = defSym.getImpl()
  assert def.kind == nnkProcDef
  let
    ret = def[3][0]
    params = def[3][1..^1]
    name = def[0].repr
    rubyName = toSnakeCase(name)
    cName = "fidget_" & rubyName

  coderb1.add "  attach_function :"
  coderb1.add cName
  coderb1.add ", [ "
  for param in params:
    for i in 0 .. param.len - 3:
      coderb1.add typeRuby(param[^2])
      coderb1.add ", "
  coderb1.rm ", "
  coderb1.add " ], "
  coderb1.add typeRuby(ret)
  coderb1.add "\n"

  coderb2.add "def "
  coderb2.add rubyName
  coderb2.add "("
  for param in params:
    for i in 0 .. param.len - 3:
      coderb2.add toSnakeCase(param[i].repr)
      coderb2.add ", "
  coderb2.rm ", "
  coderb2.add ")\n"
  coderb2.add "  return "
  coderb2.add "DLL."
  coderb2.add cName
  coderb2.add "("
  for param in params:
    for i in 0 .. param.len - 3:
      coderb2.add toSnakeCase(param[i].repr)
      coderb2.add ", "
  coderb2.rm ", "
  coderb2.add ")\n"
  coderb2.add "end\n\n"

proc exportRefObjectRuby*(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  coderb0.add "class "
  coderb0.add objName
  coderb0.add " < FFI::Struct\n"
  coderb0.add "  layout ref: :uint64\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr in bannedFields:
      continue
    let
      fieldName = field.repr
      fieldRubyName = toSnakeCase(field.repr)
      fieldType = field.getType()

    coderb0.add "\n"
    coderb0.add "  def "
    coderb0.add fieldRubyName
    coderb0.add "\n"
    coderb0.add "    return DLL.fidget_"
    coderb0.add toSnakeCase(objName)
    coderb0.add "_get_"
    coderb0.add fieldRubyName
    coderb0.add "(self)"
    coderb0.add "\n"
    coderb0.add "  end\n"

    coderb1.add "  attach_function :fidget_"
    coderb1.add toSnakeCase(objName)
    coderb1.add "_get_"
    coderb1.add fieldRubyName
    coderb1.add ", ["
    coderb1.add objName
    coderb1.add ".by_value"
    coderb1.add "], "
    coderb1.add typeRuby(fieldType)
    coderb1.add "\n"

    coderb0.add "  def "
    coderb0.add fieldRubyName
    coderb0.add "=(v)\n"
    coderb0.add "    DLL.fidget_"
    coderb0.add toSnakeCase(objName)
    coderb0.add "_set_"
    coderb0.add fieldRubyName
    coderb0.add "(self, v)"
    coderb0.add "\n"
    coderb0.add "  end\n"

    coderb1.add "  attach_function :fidget_"
    coderb1.add toSnakeCase(objName)
    coderb1.add "_set_"
    coderb1.add fieldRubyName
    coderb1.add ", ["
    coderb1.add objName
    coderb1.add ".by_value"
    coderb1.add ", "
    coderb1.add typeRuby(fieldType)
    coderb1.add "], :void"
    coderb1.add "\n"

  coderb0.add "end\n\n"

proc exportObjectRuby*(def: NimNode) =
  let
    baseType = def.getType()[1].getType()
    objName = def.repr

  coderb0.add "class "
  coderb0.add objName
  coderb0.add " < FFI::Struct\n"
  coderb0.add "  layout \\\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    coderb0.add "    "
    coderb0.add toSnakeCase(field.repr)
    coderb0.add ": "
    coderb0.add typeRuby(fieldType)
    coderb0.add ",\n"
  coderb0.rm ",\n"
  coderb0.add "\n"

  coderb0.add "end\n\n"

proc exportEnumRuby*(def: NimNode) =
  let enumTy = def.getType()[1]
  var i = 0
  coderb0.add def.repr
  coderb0.add " = :uint64"
  coderb0.add "\n"
  for enums in enumTy[1 .. ^1]:
    coderb0.add toCapCase(enums.repr)
    coderb0.add " = "
    coderb0.add $i
    coderb0.add "\n"
    inc i
  coderb0.add "\n"

const header0 = """
require 'ffi'

"""

const header = """

module DLL
  extend FFI::Library
  ffi_lib '/Users/me/p/fidget2/tools/apigen/libfidget.dylib'
  callback :fidget_cb, [], :void

"""

const footer = """
end
"""

proc writeRuby*(name: string) =
  writeFile(name & ".rb", header0 & coderb0 & header & coderb1 & footer & coderb2)
