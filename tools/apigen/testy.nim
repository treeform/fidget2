import polyglot, print

# Test function calling
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
  return true

exportProc(inputCode)
exportProc(testNumbers)

# Test function calling with strings
proc callMeMaybe(phone: string) =
  echo "from nim: ", phone
proc flightClubRule(n: int): string =
  return "Don't talk about flight club."
proc catStr(a, b, c, d, e: string): string =
  return a & b & c & d & e
exportProc(callMeMaybe)
exportProc(flightClubRule)
exportProc(catStr)

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

# Test nested objects
type
  Address = object
    state*: int
    zip*: int
  Contact = object
    firstName*: int
    lastName*: int
    address*: Address
exportObject(Address)
exportObject(Contact)
proc takeContact(): Contact =
  Contact(
    firstName: 123,
    lastName: 678,
    address: Address(
      state: 1,
      zip: 2
    )
  )
exportProc(takeContact)

# Test ref objects
type
  Fod = ref object
    id: int
    name*: string
    count*: int
exportRefObject(Fod)
proc takeFod(): Fod =
  var fod = Fod(
    id: -1,
    name: "just fod",
    count: 12
  )
  return fod
exportProc(takeFod)

# Test nested ref objects
type
  Boz = ref object
    name*: string
    fod*: Fod
exportRefObject(Boz)
proc takeBoz(): Boz =
  Boz(
    name: "the one",
    fod: Fod(
      id: 888,
      name: "other fod",
      count: 99
    )
  )
exportProc(takeBoz)

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
proc giveSeq(s: seq[uint64]) =
  echo s
proc takeSeq(): seq[uint64] =
  for i in 0 ..< 16:
    result.add i.uint64
exportSeq(seq[uint64])
exportProc(takeSeq)
exportProc(giveSeq)

# Test seq of obj
proc giveSeqOfVector2(s: seq[Vector2]) =
  echo s
proc takeSeqOfVector2(): seq[Vector2] =
  result = newSeqOfCap[Vector2](77)
  for i in 0 ..< 11:
    result.add Vector2(x: i.float32, y: i.float32 * 2)
exportSeq(seq[Vector2])
exportProc(giveSeqOfVector2)
exportProc(takeSeqOfVector2)

# Test seq of nested ref obj
proc giveSeqOfBoz(s: seq[Boz]) =
  print s
proc takeSeqOfBoz(): seq[Boz] =
  result = newSeqOfCap[Boz](77)
  for i in 0 ..< 11:
    result.add Boz(
      name: "#" & $i,
      fod: Fod(
        id: i,
        name: "fod" & $i,
        count: 99
      )
    )
exportSeq(seq[Boz])
exportProc(giveSeqOfBoz)
exportProc(takeSeqOfBoz)

import pixie/fontformats/opentype, pixie/fontformats/svgfont, pixie
# Test nested ref object
type

  ColorStop2* = object
    ## Color stop on a gradient curve.
    color*: ColorRGBX  ## Color of the stop
    position*: float32 ## Gradient Stop position 0..1.

  Paint2 = object
    kind*: PaintKind
    blendMode*: BlendMode
    gradientStops*: seq[ColorStop2]

  Typeface2* = ref object
    opentype: OpenType
    svgFont: SvgFont
    filePath*: string

  Font2* = ref object
    typeface*: Typeface2
    size*: float32              ## Font size in pixels.
    lineHeight*: float32 ## The line height in pixels or AutoLineHeight for the font's default line height.
    paint*: Paint2
    textCase*: TextCase
    underline*: bool            ## Apply an underline.
    strikethrough*: bool        ## Apply a strikethrough.
    noKerningAdjustments*: bool ## Optionally disable kerning pair adjustments

exportEnum(TextCase)
exportEnum(PaintKind)
exportEnum(BlendMode)
exportObject(ColorRGBX)
exportObject(ColorStop2)
exportSeq(seq[ColorStop2])
exportObject(Paint2)
exportRefObject(Typeface2)
exportRefObject(Font2)

var globalF: Font2
var globalT: Typeface2
proc readFont2(fontPath: string): Font2 =

  var f = Font2()
  echo "sizeof(f):", sizeof(f)
  echo "alignof(f):", alignof(f)

  echo "offsetOf(f, typeface):", offsetOf(f, typeface)
  echo "offsetOf(f, size):", offsetOf(f, size)
  echo "offsetOf(f, lineHeight):", offsetOf(f, lineHeight)
  echo "offsetOf(f, paint):", offsetOf(f, paint)
  echo "offsetOf(f, textCase):", offsetOf(f, textCase)
  echo "offsetof(f, underline):", offsetof(f, underline)
  echo "offsetof(f, strikethrough):", offsetof(f, strikethrough)
  echo "offsetof(f, noKerningAdjustments):", offsetof(f, noKerningAdjustments)

  var t = Typeface2()
  t.filePath = fontPath

  f.typeface = t

  f.size = 1
  f.lineHeight = 2
  f.paint = Paint2(
    kind: pkSolid,
    blendMode: bmColorBurn
  )
  f.paint.gradientStops.add(ColorStop2(
    color: rgbx(0, 0, 0, 100),
    position: 10
  ))
  f.textCase = tcUpper
  f.noKerningAdjustments = true

  # globalT = t
  # globalF = f

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


writeAll(testy)

include testyinternalapi
