import macros, strutils, ../common

var code0 {.compiletime.}: string
var code1 {.compiletime.}: string
var code2 {.compiletime.}: string

proc typeJs(nimType: NimNode): string =
  ## Converts nim type to python type.
  case nimType.repr:
  of "string": "'string'"
  of "bool": "'bool'"
  of "int8": "'int8'"
  of "int16": "'int16'"
  of "int32": "'int32'"
  of "int64": "'int64'"
  of "int": "'int64'"
  of "uint8": "'uint8'"
  of "uint16": "'uint16'"
  of "uint32": "'uint32'"
  of "uint64": "'uint64'"
  of "uint": "'uint64'"
  of "float32": "'float'"
  of "float64": "'double'"
  of "float": "'double'"
  of "proc () {.cdecl.}": "'pointer'"
  of "": "'void'"
  else: nimType.repr

proc exportProcJs*(defSym: NimNode) =
  let def = defSym.getImpl()
  assert def.kind == nnkProcDef
  let
    ret = def[3][0]
    params = def[3][1..^1]
    name = def[0].repr
    pyName = toSnakeCase(name)
    cName = "fidget_" & pyName

  code1.add "  '" & cName & "'"
  code1.add ": ["
  code1.add typeJs(ret)
  code1.add ", "
  code1.add "["
  for param in params:
    for i in 0 .. param.len - 3:
      code1.add typeJs(param[^2])
      code1.add ", "
  code1.rm(", ")
  code1.add "]],\n"

  code2.add "exports."
  code2.add name
  code2.add " = "
  code2.add "fidget."
  code2.add cName
  code2.add ";\n"

proc exportRefObjectJs*(def: NimNode) =
  let
    refType = def.getType()
    baseType = refType[1][1].getType()
    objName = refType[1][1].repr.split(":")[0]

  code0.add "var "
  code0.add objName
  code0.add " = Struct({'nimRef': 'pointer'});\n"

  code2.add "exports."
  code2.add objName
  code2.add " = "
  code2.add objName
  code2.add ";\n"

  for field in baseType[2]:
    if field.isExported == false:
      continue
    if field.repr notin allowedFields:
      continue
    let fieldType = field.getType()

    let
      name = field.repr
      getName = "fidget_" & toSnakeCase(objName) & "_get_" & toSnakeCase(name)
    code1.add "  '" & getName & "'"
    code1.add ": ["
    code1.add typeJs(fieldType)
    code1.add ", "
    code1.add "["
    code1.add objName
    code1.add "]],\n"

    let
      setName = "fidget_" & toSnakeCase(objName) & "_set_" & toSnakeCase(name)
    code1.add "  '" & setName & "'"
    code1.add ": ["
    code1.add "'void'"
    code1.add ", "
    code1.add "["
    code1.add objName
    code1.add ", "
    code1.add typeJs(fieldType)
    code1.add "]],\n"

    code2.add "Object.defineProperty("
    code2.add objName
    code2.add ".prototype"
    code2.add ", "
    code2.add "'" & name & "'"
    code2.add ", {\n"
    code2.add "  get: function() {return "
    code2.add "fidget."
    code2.add getName
    code2.add "(this)"
    code2.add "},\n"
    code2.add "  set: function(v) {"
    code2.add "fidget."
    code2.add setName
    code2.add "(this, v)"
    code2.add "}\n"
    code2.add "});\n"

proc exportObjectJs*(def: NimNode) =
  let
    baseType = def.getType()[1].getType()
    objName = def.repr

  code0.add "var "
  code0.add objName
  code0.add " = Struct({\n"
  for field in baseType[2]:
    if field.isExported == false:
      continue
    let fieldType = field.getType()
    code0.add "  "
    code0.add "'" & field.repr & "'"
    code0.add ": "
    code0.add typeJs(fieldType)
    code0.add ",\n"
  code0.rm ",\n"
  code0.add "});\n"

  code2.add "exports."
  code2.add objName
  code2.add " = "
  code2.add objName
  code2.add ";\n"

proc exportEnumJs*(def: NimNode) =
  let enumTy = def.getType()[1]
  var i = 0
  code0.add def.repr
  code0.add " = 'int64'"
  code0.add "\n"

  for enums in enumTy[1 .. ^1]:
    code0.add "exports."
    code0.add toCapCase(enums.repr)
    code0.add " = "
    code0.add $i
    code0.add "\n"
    inc i
  code0.add "\n"

const header = """
var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");

exports.cb = function(f){return ffi.Callback('void', [], f)};

"""
const loader = """

var dllPath = ""
if(process.platform == "win32") {
  dllPath = 'fidget.dll'
} else if (process.platform == "darwin") {
  dllPath = 'libfidget.dylib'
} else {
  dllPath = __dirname + '/libfidget.so'
}

var fidget = ffi.Library(dllPath, {
"""
const footer = """
});

"""

macro writeJs*() =
  writeFile("fidget.js", header & code0 & loader & code1 & footer & code2)
