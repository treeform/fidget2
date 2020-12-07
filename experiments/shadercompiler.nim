## Shader macro, converts nim code into GLSL

import chroma, macros, strutils, vmath, print, tables

proc show(n: NimNode): string =
  result.add $n.kind
  case n.kind
  of nnkStrLit..nnkTripleStrLit, nnkCommentStmt, nnkSym, nnkIdent:
    result.add "\""
    result.add n.strVal
    result.add "\""
  else:
    discard
  result.add "("
  for i, c in n:
    if i > 0: result.add ","
    result.add $i
    result.add ":"
    result.add show(c)
  result.add ")"

type
  uniform*[T] = T

proc typeRename(t: string): string =
  ## Some GLSL type names don't match nim names, rename here.
  case t
  of "Mat4": "mat4"
  of "Mat3": "mat3"
  of "Color": "vec4"
  of "Vec4": "vec4"
  of "Vec3": "vec3"
  of "Vec2": "vec2"
  of "float32": "float"
  of "float64": "float"
  else: t

proc procRename(t: string): string =
  ## Some GLSL proc names don't match nim names, rename here.
  case t
  of "color": "vec4"
  else: t

proc addIndent(res: var string, level: int) =
  for i in 0 ..< level:
    res.add "  "

proc toCodeStmts(n: NimNode, res: var string, level = 0)

proc toCode(n: NimNode, res: var string, level = 0) =
  ## Inner code block.
  if n.kind == nnkEmpty:
    return
  case n.kind
  of nnkAsgn:
    res.addIndent level
    n[0].toCode(res)
    res.add " = "
    n[1].toCode(res)
  of nnkInfix:
    n[1].toCode(res)
    res.add " "
    n[0].toCode(res)
    res.add " "
    n[2].toCode(res)
  of nnkHiddenDeref, nnkHiddenAddr:
    n[0].toCode(res)
  of nnkCall:
    var procName = procRename(n[0].strVal)
    if procName in ["rgb=", "rgb", "xyz", "xy", "xy="]:
      if n[1].kind == nnkSym:
        n[1].toCode(res)
      else:
        res.add "("
        n[1].toCode(res)
        res.add ")"
      res.add "."
      res.add procName.replace("=", " = ")
      if n.len == 3:
        n[2].toCode(res)
    else:
      res.add procName
      res.add "("
      for j in 1 ..< n.len:
        if j != 1: res.add ", "
        n[j].toCode(res)
      res.add ")"
  of nnkDotExpr:
    n[0].toCode(res)
    res.add "."
    n[1].toCode(res)
  of nnkIdent, nnkSym:
    res.add n.strVal
  of nnkStmtListExpr:
    for j in 0 ..< n.len:
      n[j].toCode(res, level)
  of nnkStmtList:
    for j in 0 ..< n.len:
      if n[j].kind in [nnkCall]:
        res.addIndent level
      n[j].toCode(res, level)
      if n[j].kind notin [nnkLetSection, nnkVarSection]:
        res.add ";\n"
  of nnkIfStmt:
    res.addIndent level
    res.add "if ("
    n[0][0].toCode(res)
    res.add ") {\n"
    n[0][1].toCodeStmts(res, level + 1)
    res.addIndent level
    res.add "}"
    if n.len > 1:
      # TODO else if?
      if n[1].kind == nnkElse:
        res.add " else {\n"
        n[1][0].toCodeStmts(res, level + 1)
        res.addIndent level
        res.add "}"
  of nnkHiddenStdConv:
    for j in 0 .. n.len-1:
      n[j].toCode(res)
  of nnkEmpty, nnkNilLit:
    discard # same as nil node in this representation
  of nnkCharLit .. nnkInt64Lit:
    res.add $n.intVal
  of nnkFloatLit .. nnkFloat64Lit:
    res.add $n.floatVal
  of nnkStrLit .. nnkTripleStrLit, nnkCommentStmt:
    res.add $n.strVal.newLit.repr
  of nnkNone:
    assert false
  of nnkVarSection, nnkLetSection:
    for j in 0 ..< n.len:
      res.addIndent level
      n[j].toCode(res, level)
      res.add ";\n"
  of nnkIdentDefs:
    for j in countup(0, n.len - 1, 3):
      res.add typeRename(n[j + 2].getTypeInst().strVal)
      res.add " "
      n[j].toCode(res)
      res.add " = "
      n[j + 2].toCode(res)

  of nnkReturnStmt:
    res.addIndent level
    res.add "return "
    n[0][1].toCode(res)

  # of nnkProcDef:
  #   var procCode = ""
  #   toCodeTopLevel(n, procCode)
  #   echo "->>>", procStr

  else:
    res.add ($n.kind)
    res.add "{{"
    for j in 0 .. n.len-1:
      n[j].toCode(res)
    res.add "}}"

proc toCodeStmts(n: NimNode, res: var string, level = 0) =
  if n.kind != nnkStmtList:
    res.addIndent level
    n.toCode(res, level)
    res.add ";\n"
  else:
    n.toCode(res, level)

proc toCodeTopLevel(topLevelNode: NimNode, res: var string, level = 0) =
  ## Top level block such as in and out params.
  assert topLevelNode.kind == nnkProcDef
  for n in topLevelNode:
    case n.kind
    of nnkEmpty:
      discard
    of nnkSym:
      res.add "// name: "
      res.add $n
      res.add "\n\n"
    of nnkFormalParams:
      for param in n:
        if param.kind != nnkEmpty:
          if param[1].kind == nnkVarTy:
            if param[1][0].strVal == "int":
              res.add "flat "
            res.add "out "
            res.add typeRename(param[1][0].strVal)
          else:
            if param[1].kind == nnkBracketExpr:
              res.add param[1][0].strVal
              res.add " "
              res.add typeRename(param[1][1].strVal)
            else:
              if param[1].strVal == "int":
                res.add "flat "
              res.add "in "
              res.add typeRename(param[1].strVal)
          res.add " "
          res.add param[0].strVal
          res.add ";\n"
    else:
      res.add "\n"
      res.add "void main() {\n"
      n.toCodeStmts(res, level+1)
      res.add "}"


proc procDef(topLevelNode: NimNode): string =

  echo show(topLevelNode)

  var procName = ""
  var paramsStr = ""
  var returnType = "void"

  assert topLevelNode.kind == nnkProcDef
  for n in topLevelNode:
    case n.kind
    of nnkEmpty:
      discard
    of nnkSym:
      procName = $n
    of nnkFormalParams:
      if n[0].kind != nnkEmpty:
        returnType = typeRename(n[0].strVal)
      for param in n[1 .. ^1]:
        if param.kind != nnkEmpty:
          paramsStr.add "  "
          if param[1].kind == nnkVarTy:
            if param[1][0].strVal == "int":
              paramsStr.add "flat "
            paramsStr.add "out "
            paramsStr.add typeRename(param[1][0].strVal)
          else:
            if param[1].kind == nnkBracketExpr:
              paramsStr.add param[1][0].strVal
              paramsStr.add " "
              paramsStr.add typeRename(param[1][1].strVal)
            else:
              if param[1].strVal == "int":
                paramsStr.add "flat "
              paramsStr.add typeRename(param[1].strVal)
          paramsStr.add " "
          paramsStr.add param[0].strVal
          paramsStr.add ",\n"
    else:
      result.add "\n"
      if paramsStr.len > 0:
        paramsStr = paramsStr[0 .. ^3] & "\n"
      result.add returnType & " " & procName & "(\n" & paramsStr & ") {\n"
      n.toCodeStmts(result, 1)
      result.add "}"



proc gatherFunction(
  topLevelNode: NimNode, functions: var Table[string, string]) =
  ## Looks for functions this function calls and brings them up
  let glslProcs = @[
    "rgb=", "rgb", "xyz", "xy", "xy=", "vec4",
    "Vec2", "Vec3", "Vec4",
    "gl_Position", "gl_FragCoord",
  ]
  for n in topLevelNode:
    if n.kind == nnkSym:
      # Looking for globals.
      let name = n.strVal
      if name notin glslProcs:
        echo show(n)
        echo declaredInScope(n)
    if n.kind == nnkCall:
      # Looking for functions.
      let procName = n[0].strVal()
      if procName notin glslProcs and procName notin functions:
        ## not a build int proc, we need to bring definition
        echo show(n)
        echo "-->", procName
        functions[procName] = procDef(n[0].getImpl())
    gatherFunction(n, functions)

macro toShader*(s: typed, version = "410", precision = "mediump float"): string =
  ## Converts proc to a glsl string.
  var code: string
  code.add "#version " & version.strVal & "\n"
  code.add "precision " & precision.strVal & ";\n\n"

  var n = getImpl(s)

  var functions: Table[string, string]
  gatherFunction(n, functions)

  for k, v in functions:
    code.add(v)
    code.add "\n"

  toCodeTopLevel(n, code)
  result = newLit(code)

type
  Color* = object
    ## Main color type, float32 points
    r*: float32 ## red (0-1)
    g*: float32 ## green (0-1)
    b*: float32 ## blue (0-1)
    a*: float32 ## alpha (0-1, 0 is fully transparent)

proc color*(r, g, b: float32, a: float32 = 1.0): Color {.inline.} =
  ## Creates from floats like:
  ## * color(1,0,0) -> red
  ## * color(0,1,0) -> green
  ## * color(0,0,1) -> blue
  ## * color(0,0,0,1) -> opaque  black
  ## * color(0,0,0,0) -> transparent black
  Color(r: r, g: g, b: b, a: a)

proc rgb*(c: Color): Vec3 =
  vec3(c.r, c.g, c.b)

proc `rgb=`*(c: var Color, v: Vec3) =
  c.r = v.x
  c.g = v.y
  c.b = v.z

proc vec4*(v: Vec3, w: float32): Vec4 =
  vec4(v.x, v.y, v.z, w)

# proc xyz*(v: Vec4): Vec3 =
#   vec3(v.x, v.y, v.z)

proc mix*(a, b: Vec3, v: float32): Vec3 =
  lerp(a, b, v)

proc `*`*(m: Mat4, v: Vec4): Vec4 =
  vec4(m * v.xyz, 1.0)

proc `xy=`*(a: var Vec4, b: Vec2) =
  a.x = b.x
  a.y = b.y
