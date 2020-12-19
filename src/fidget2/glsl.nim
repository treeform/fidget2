## Shader macro, converts nim code into GLSL

import macros, strutils, vmath, tables, pixie, chroma

# For the ability to look at parent nodes.
var nodeStack {.compileTime.}: seq[NimNode]

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
  of "Uniform": "uniform"
  of "SamplerBuffer": "samplerBuffer"
  of "Sampler2d": "sampler2D"
  else: t

const glslGlobals = [
  "gl_Position", "gl_FragCoord",
]

const glslFunctions = [
  "rgb=", "rgb", "xyz", "xy", "xy=",
  "vec2", "vec3", "vec4", "mat3", "mat4", "color",
  "Vec2", "Vec3", "Vec4", "Mat3", "Mat4", "Color",
  "clamp", "min", "max", "dot", "sqrt", "mix", "length",
  "texelFetch", "texture",
  "normalize",
  "floor", "ceil",
  "[]", "[]="
]

const ignoreFunctions = [
  "echo", "print", "debugEcho"
]

proc procRename(t: string): string =
  ## Some GLSL proc names don't match nim names, rename here.
  case t
  of "color": "vec4"
  of "not": "!"
  of "and": "&&"
  of "or": "||"
  of "mod": "%"
  else: t

proc addIndent(res: var string, level: int) =
  for i in 0 ..< level:
    res.add "  "

proc toCodeStmts(n: NimNode, res: var string, level = 0)

proc toCode(n: NimNode, res: var string, level = 0) =
  ## Inner code block.

  nodeStack.add(n)

  case n.kind

  of nnkAsgn:
    res.addIndent level
    n[0].toCode(res)
    res.add " = "
    n[1].toCode(res)

  of nnkInfix:
    if n[0].repr in ["mod"] and n[1].getType().repr != "int":
      # In nim float mod and integer made are same thing.
      # In GLSL mod(float, float) is a function while % is for integers.
      res.add n[0].repr
      res.add "("
      n[1].toCode(res)
      res.add ", "
      n[2].toCode(res)
      res.add ")"
      return

    res.add "("
    n[1].toCode(res)
    res.add ") "
    n[0].toCode(res)
    res.add " ("
    n[2].toCode(res)
    res.add ")"
    if n[0].repr in ["+=", "-=", "*=", "/="]:
      res.add(";")

  of nnkHiddenDeref, nnkHiddenAddr:
    n[0].toCode(res)

  of nnkCall, nnkCommand:
    var procName = procRename(n[0].strVal)
    if procName in ignoreFunctions:
      return
    if procName in "[]=":
      n[1].toCode(res)
      for i in 2 ..< n.len - 1:
        res.add "["
        n[i].toCode(res)
        res.add "]"
      res.add " = "
      n[n.len - 1].toCode(res)
    elif procName in ["rgb=", "rgb", "xyz", "xy", "xy="]:
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
    res.add procRename(n.strVal)

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
    var i = 1
    while n.len > i:
      if n[i].kind == nnkElse:
        res.add " else {\n"
        n[i][0].toCodeStmts(res, level + 1)
        res.addIndent level
        res.add "}"
      elif n[i].kind == nnkElifBranch:
        res.add " else if ("
        n[i][0].toCode(res)
        res.add ") {\n"
        n[i][1].toCodeStmts(res, level + 1)
        res.addIndent level
        res.add "}"
      else:
        quit("Not supported if branch")
      inc i

  of nnkHiddenStdConv:
    let typeStr = typeRename(n.getType.repr)
    for j in 1 .. n.len-1:
      res.add typeStr
      res.add "("
      n[j].toCode(res)
      res.add ")"

  of nnkEmpty, nnkNilLit, nnkDiscardStmt, nnkPragma:
    # Skip all nil, empty and discard statements.
    discard

  of nnkIntLit .. nnkInt64Lit:
    var iv = $n.intVal
    res.add iv

  of nnkFloatLit .. nnkFloat64Lit:
    var fv = $n.floatVal
    res.add fv

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
      res.add typeRename(n[j].getTypeInst().strVal)
      res.add " "
      n[j].toCode(res)
      if n[j + 2].kind != nnkEmpty:
        res.add " = "
        n[j + 2].toCode(res)

  of nnkReturnStmt:
    res.addIndent level
    res.add "return "
    if n[0].kind != nnkEmpty:
      n[0][1].toCode(res)

  of nnkBreakStmt:
    res.addIndent level
    res.add "break"

  of nnkPrefix:
    res.add procRename(n[0].strVal) & " ("
    n[1].toCode(res)
    res.add ")"

  of nnkWhileStmt:
    res.addIndent level
    res.add "while("
    n[0].toCode(res)
    res.add ") {\n"
    n[1].toCode(res, level + 1)
    res.addIndent level
    res.add "}"

  of nnkForStmt:
    res.addIndent level
    res.add "for("
    res.add "int "
    res.add n[0].strVal
    res.add " = "
    n[1][1].toCode(res)
    res.add "; "
    res.add n[0].strVal
    if n[1][0].strVal == "..<":
      res.add " < "
    elif n[1][0].strVal == "..":
      res.add " <= "
    else:
      quit "For loop only supports integer .. or ..<."
    n[1][2].toCode(res)
    res.add "; "
    res.add n[0].strVal
    res.add "++"
    res.add ") {\n"
    n[2].toCode(res, level + 1)
    res.addIndent level
    res.add "}"

  of nnkConv:
    res.add typeRename(n[0].strVal)
    res.add "("
    n[1].toCode(res)
    res.add ")"

  of nnkProcDef:
    quit "Nested proc definitions are not allowed."

  # of nnkBracket:
  #   res.add "[?]"

  of nnkBracketExpr:
    n[0].toCode(res)
    res.add "["
    n[1].toCode(res)
    res.add "]"

  else:
    echo show(n)
    echo n.repr
    quit "^ can't compile"
    # res.add ($n.kind)
    # res.add "{{"
    # for j in 0 .. n.len-1:
    #   n[j].toCode(res)
    # res.add "}}"

  discard nodeStack.pop()

proc toCodeStmts(n: NimNode, res: var string, level = 0) =
  if n.kind != nnkStmtList:
    res.addIndent level
    n.toCode(res, level)
    res.add ";\n"
  else:
    n.toCode(res, level)

proc toCodeTopLevel(topLevelNode: NimNode, res: var string, level = 0) =
  ## Top level block such as in and out params.
  ## Generates the main function (which is not like all the other functions)
  assert topLevelNode.kind == nnkProcDef
  for n in topLevelNode:
    case n.kind
    of nnkEmpty:
      discard
    of nnkSym:
      discard
    of nnkFormalParams:
      ## Main function parameters are different in they they go in as globals.
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
      res.add "}\n"

proc procDef(topLevelNode: NimNode): string =
  ## Process whole function (that is not the main function).

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
      # Reading parameter list `(x, y, z: float)`
      if n[0].kind != nnkEmpty:
        returnType = typeRename(n[0].strVal)
      for paramDef in n[1 .. ^1]:
        # The paramDef is like `x, y, z: float`.
        if paramDef.kind != nnkEmpty:
          for param in paramDef[0 ..< ^2]:
            # Process each `x`, `y`, `z` in a loop.
            paramsStr.add "  "
            let paramName = param.repr()
            let paramType = param.getTypeInst()
            if paramType.kind == nnkVarTy:
              # Process `x: var float`
              if paramType[0].strVal == "int":
                paramsStr.add "flat "
              paramsStr.add "inout "
              paramsStr.add typeRename(paramType[0].strVal)
            elif paramType.kind == nnkBracketExpr:
              # Process varying[uniform].
              # TODO test?
              paramsStr.add paramType[0].strVal
              paramsStr.add " "
              paramsStr.add typeRename(paramType[1].strVal)
            else:
              # Just a simple `x: float` case.
              if paramType.strVal == "int":
                paramsStr.add "flat "
              paramsStr.add typeRename(paramType.strVal)
            paramsStr.add " "
            paramsStr.add paramName
            paramsStr.add ",\n"
    else:
      result.add "\n"
      if paramsStr.len > 0:
        paramsStr = paramsStr[0 .. ^3] & "\n"
      result.add returnType & " " & procName & "(\n" & paramsStr & ") {\n"
      n.toCodeStmts(result, 1)
      result.add "}"

proc gatherFunction(
  topLevelNode: NimNode,
  functions: var Table[string, string],
  globals: var Table[string, string]
) =

  ## Looks for functions this function calls and brings them up
  for n in topLevelNode:
    if n.kind == nnkSym:
      # Looking for globals.
      let name = n.strVal
      if name notin glslGlobals and name notin glslFunctions and name notin globals:
        if n.owner().symKind == nskModule:
          let impl = n.getImpl()
          if impl.kind notin {nnkIteratorDef, nnkProcDef} and
              impl.kind != nnkNilLit:
            var defStr = ""
            let typeInst = n.getTypeInst
            if typeInst.kind == nnkBracketExpr:
              # might be a uniform
              if typeInst[0].repr == "Uniform":
                defStr.add typeRename(typeInst[0].repr)
                defStr.add " "
                defStr.add typeRename(typeInst[1].repr)
              else:
                quit("Invalid x[y].")
            else:
              defStr.add typeRename(typeInst.repr)
            defStr.add " " & name
            if impl[2].kind != nnkEmpty:
              defStr.add " = " & repr(impl[2])
            defStr.add ";"
            globals[name] = defStr


    if n.kind == nnkCall:
      # Looking for functions.
      let procName = n[0].strVal()
      if procName in ignoreFunctions:
        continue
      if procName notin glslFunctions and procName notin functions:
        ## If its not a builtin proc, we need to bring definition.
        let impl = n[0].getImpl()
        gatherFunction(impl, functions, globals)
        functions[procName] = procDef(impl)

    gatherFunction(n, functions, globals)

macro toShader*(s: typed, version = "410", precision = "highp float"): string =
  ## Converts proc to a glsl string.
  var code: string

  # Add GLS header stuff.
  code.add "#version " & version.strVal & "\n"
  code.add "precision " & precision.strVal & ";\n"
  code.add "// from " & s.strVal & "\n\n"

  var n = getImpl(s)

  # Gather all globals and functions, and globals and functions they use.
  var functions: Table[string, string]
  var globals: Table[string, string]
  gatherFunction(n, functions, globals)

  # Put globals first.
  for k, v in globals:
    code.add(v)
    code.add "\n"

  # Put functions definition (just name and types part).
  for k, v in functions:
    code.add v.split("{")[0]
    code.add ";\n"

  # Put functions (with bodies) next.
  for k, v in functions:
    code.add v
    code.add "\n"

  # Put the main function last.
  toCodeTopLevel(n, code)

  result = newLit(code)

## GLSL helper functions

type
  Uniform*[T] = T
  SamplerBuffer* = object
    data*: seq[float32]

  Sampler2d* = object
    image*: Image

  Color* = object
    r*: float32
    g*: float32
    b*: float32
    a*: float32

proc color*(r, g, b: float32, a: float32 = 1.0): Color {.inline.} =
  Color(r: r, g: g, b: b, a: a)

proc rgb*(c: Color): Vec3 =
  vec3(c.r, c.g, c.b)

proc `rgb=`*(c: var Color, v: Vec3) =
  c.r = v.x
  c.g = v.y
  c.b = v.z

proc vec4*(v: Vec3, w: float32): Vec4 =
  vec4(v.x, v.y, v.z, w)

proc vec4*(c: chroma.ColorRGBA): Vec4 =
  vec4(
    c.r.float32/255,
    c.g.float32/255,
    c.b.float32/255,
    c.a.float32/255
  )

# proc xyz*(v: Vec4): Vec3 =
#   vec3(v.x, v.y, v.z)

proc mix*(a, b: Vec2, v: float32): Vec2 =
  lerp(a, b, v)

proc mix*(a, b: Vec3, v: float32): Vec3 =
  lerp(a, b, v)

proc mix*(a, b: Vec4, v: float32): Vec4 =
  result.x = lerp(a.x, b.x, v)
  result.y = lerp(a.y, b.y, v)
  result.z = lerp(a.z, b.z, v)
  result.w = lerp(a.w, b.w, v)

proc `mod`*(a, b: Vec2): Vec2 =
  result.x = a.x mod b.x
  result.y = a.y mod b.y

proc `mod`*(a, b: Vec3): Vec3 =
  result.x = a.x mod b.x
  result.y = a.y mod b.y
  result.z = a.y mod b.z

proc `mod`*(a, b: Vec4): Vec4 =
  result.x = a.x mod b.x
  result.y = a.y mod b.y
  result.z = a.y mod b.z
  result.w = a.w mod b.w

proc `*`*(m: Mat4, v: Vec4): Vec4 =
  vec4(m * v.xyz, 1.0)

proc `xy=`*(a: var Vec4, b: Vec2) =
  a.x = b.x
  a.y = b.y

proc `xy`*(a: Vec4): Vec2 =
  vec2(a.x, a.y)

proc texelFetch*(buffer: Uniform[SamplerBuffer], index: int): float32 =
  buffer.data[index]

proc texture*(buffer: Uniform[Sampler2D], pos: Vec2): Vec4 =
  buffer.image.getRgbaSmooth(
    ((pos.x mod 1.0) * buffer.image.width.float32),
    ((pos.y mod 1.0) * buffer.image.height.float32)
  ).vec4

# proc setf*(mat: var Mat3, i, j: int, v: float32) =
#   mat[i, j] = v
#   mat[i][j] = v

# proc r*(v: Vec4|Vec3|Vec2): float = v.x
# proc g*(v: Vec4|Vec3|Vec2): float = v.y
# proc b*(v: Vec4|Vec3): float = v.z
# proc a*(v: Vec4): float = v.w

# proc `r=`*(v: var (Vec4|Vec3|Vec2), f: float32) = v.x = f
# proc `g=`*(v: var (Vec4|Vec3|Vec2), f: float32) = v.y = f
# proc `b=`*(v: var (Vec4|Vec3), f: float32) = v.z = f
# proc `a=`*(v: var Vec4, f: float32) = v.w = f

# proc r*(v: Vec4): float = v.x
# proc g*(v: Vec4): float = v.y
# proc b*(v: Vec4): float = v.z
# proc a*(v: Vec4): float = v.w

# proc `r=`*(v: var Vec4, f: float32) = v.x = f
# proc `g=`*(v: var Vec4, f: float32) = v.y = f
# proc `b=`*(v: var Vec4, f: float32) = v.z = f
# proc `a=`*(v: var Vec4, f: float32) = v.w = f

# proc rgb*(c: Vec4): Vec3 =
#   vec3(c.r, c.g, c.b)

# proc `rgb=`*(c: var Vec4, v: Vec3) =
#   c.r = v.x
#   c.g = v.y
#   c.b = v.z
