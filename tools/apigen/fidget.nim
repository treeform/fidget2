import polyglot, common, print

# Test function calling
proc callMeMaybe(phone: string) =
  echo "from nim: ", phone
proc flightClubRule(n: int): string =
  return "Don't talk about flight club."
proc inputCode(a, b, c, d: int): bool =
  echo "got code: ", a, b, c, d
  return false
proc testNumbers(
  a: int8,
  b: uint8,
  c: int16,
  d: uint16,
  e: int32,
  f: uint32,
  g: int64,
  h: uint64,
  i: int,
  j: uint,
  k: float32,
  l: float64,
  m: float,
): bool =
  print a, b, c, d, e, f, g, h, i, j, k, l, m
exportProc(callMeMaybe)
exportProc(flightClubRule)
exportProc(inputCode)
exportProc(testNumbers)

# Test ref objects
type
  Fod = ref object
    id: int
    name*: string
    count*: int
exportRefObject(Fod)
proc createFod(): Fod =
  var fod = Fod()
  echo "new:", cast[int64](fod)
  return fod
exportProc(createFod)

# Test objects
type
  Vector2 = object
    x*, y*: float32
exportObject(Vector2)
proc giveVec(v: Vector2) =
  echo "given vec ", v
proc takeVec(): Vector2 =
  result = Vector2(x: 1.2, y: 3.4)
  echo "taken vec ", result
exportProc(giveVec)
exportProc(takeVec)

# Test enums
type
  AlignSomething = enum
    asDefault
    asTop
    asBottom
    asRight
    asLeft
var a: AlignSomething
exportEnum(AlignSomething)
proc repeatEnum(e: AlignSomething): AlignSomething =
  return e
exportProc(repeatEnum)

# Test callbacks
proc callMeBack(cb: proc() {.cdecl.}) =
  echo "calling cb"
  cb()
  echo "done with cb"
exportProc(callMeBack)


# Test seq
proc takeSeq(s: seq[uint64]) =
  echo s
proc returnSeq(): seq[uint64] =
  for i in 0 ..< 16:
    result.add i.uint64
exportSeq(seq[uint64])
exportProc(takeSeq)
exportProc(returnSeq)


import pixie/fontformats/opentype, pixie/fontformats/svgfont, pixie
# Test nested ref object
type
  Typeface2* = ref object
    opentype: OpenType
    svgFont: SvgFont
    filePath*: string

  Font2* = object
    typeface*: Typeface2
    size*: float32              ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.
    #paint*: Paint
    textCase*: TextCase
    underline*: bool            ## Apply an underline.
    strikethrough*: bool        ## Apply a strikethrough.
    noKerningAdjustments*: bool ## Optionally disable kerning pair adjustments
exportEnum(TextCase)
exportRefObject(Typeface2)
exportObject(Font2)
proc readFont2(fontPath: string): Font2 =
  var t = Typeface2()
  t.filePath = fontPath
  var f = Font2()
  echo "size of f:", sizeof(f)
  f.typeface = t
  f.size = 1
  f.lineHeight = 2
  f.noKerningAdjustments = true

  echo "underline:", offsetof(`f`, underline)
  echo "strikethrough:", offsetof(`f`, strikethrough)
  echo "noKerningAdjustments:", offsetof(`f`, noKerningAdjustments)

  return f
exportProc(readFont2)


#import pixie/fontformats/opentype, pixie/fontformats/svgfont
# Test nested ref object
# type
#   Typeface2 = ref object
#     opentype: OpenType
#     svgFont: SvgFont
#     filePath*: string
#   Font2* = object
#     typeface*: Typeface2
#     size*: float32
#     lineHeight*: float32

# exportRefObject(Typeface2)
# exportObject(Font2)
# proc readFont(): Font2 =
#   var t = Typeface2()
#   t.filePath = "foo/bar"
#   var f = Font2()
#   f.typeface = t
#   f.size = 1
#   f.lineHeight = 2
#   return f
# exportProc(readFont)


import fidget2, vmath
exportProc(onClickGlobal)

# exportObject(Vec2)
exportRefObject(Node)
proc findNode(glob: string): Node =
  if glob == ".":
    thisNode
  else:
    find(glob)
exportProc(findNode)

exportEnum(EventCbKind)

exportProc(addCb)
exportProc(startFidget)

writeAll()

include internalapi
