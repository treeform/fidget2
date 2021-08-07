when defined(windows):
  const LibFidget* = "fidget.dll"
elif defined(macosx):
  const LibFidget* = "libfidget.dylib"
else:
  const LibFidget* = "libfidget.so"

{.push dynlib: LibFidget, cdecl.}

proc inputCode*(a: int, b: int, c: int, d: int): bool {.importc: "fidget_input_code".}

proc testNumbers*(a: int8, b: uint8, c: int16, d: uint16, e: int32, f: uint32, g: int64, h: uint64, i: int, j: uint, k: float32, l: float64, m: float): bool {.importc: "fidget_test_numbers".}

proc callMeMaybe*(phone: cstring) {.importc: "fidget_call_me_maybe".}

proc flightClubRule*(n: int): cstring {.importc: "fidget_flight_club_rule".}

proc catStr*(a: cstring, b: cstring, c: cstring, d: cstring, e: cstring): cstring {.importc: "fidget_cat_str".}

type Vector2* = object
  x*: float32
  y*: float32

proc giveVec*(v: Vector2) {.importc: "fidget_give_vec".}

proc takeVec*(): Vector2 {.importc: "fidget_take_vec".}

type Address* = object
  state*: int
  zip*: int

type Contact* = object
  firstName*: int
  lastName*: int
  address*: Address

proc takeContact*(): Contact {.importc: "fidget_take_contact".}

type Fod* = object
  reference: uint64
proc `name`*(fod: Fod): cstring {.importc: "fidget_fod_get_name".}
proc `name=`*(fod: Fod, name: cstring) {.importc: "fidget_fod_set_name".}
proc `count`*(fod: Fod): int {.importc: "fidget_fod_get_count".}
proc `count=`*(fod: Fod, count: int) {.importc: "fidget_fod_set_count".}

proc takeFod*(): Fod {.importc: "fidget_take_fod".}

type Boz* = object
  reference: uint64
proc `name`*(boz: Boz): cstring {.importc: "fidget_boz_get_name".}
proc `name=`*(boz: Boz, name: cstring) {.importc: "fidget_boz_set_name".}
proc `fod`*(boz: Boz): Fod {.importc: "fidget_boz_get_fod".}
proc `fod=`*(boz: Boz, fod: Fod) {.importc: "fidget_boz_set_fod".}

proc takeBoz*(): Boz {.importc: "fidget_take_boz".}

type AlignSomething* = enum
  asDefault = 0
  asTop = 1
  asBottom = 2
  asRight = 3
  asLeft = 4

proc repeatEnum*(e: AlignSomething): AlignSomething {.importc: "fidget_repeat_enum".}

proc callMeBack*(cb: proc () {.cdecl.}) {.importc: "fidget_call_me_back".}

proc takeSeq*(): uint64 {.importc: "fidget_take_seq".}

proc giveSeq*(s: uint64) {.importc: "fidget_give_seq".}

proc giveSeqOfVector2*(s: Vector2) {.importc: "fidget_give_seq_of_vector2".}

proc takeSeqOfVector2*(): Vector2 {.importc: "fidget_take_seq_of_vector2".}

proc giveSeqOfBoz*(s: Boz) {.importc: "fidget_give_seq_of_boz".}

proc takeSeqOfBoz*(): Boz {.importc: "fidget_take_seq_of_boz".}

type TextCase* = enum
  tcNormal = 0
  tcUpper = 1
  tcLower = 2
  tcTitle = 3

type PaintKind* = enum
  pkSolid = 0
  pkImage = 1
  pkImageTiled = 2
  pkGradientLinear = 3
  pkGradientRadial = 4
  pkGradientAngular = 5

type BlendMode* = enum
  bmNormal = 0
  bmDarken = 1
  bmMultiply = 2
  bmColorBurn = 3
  bmLighten = 4
  bmScreen = 5
  bmColorDodge = 6
  bmOverlay = 7
  bmSoftLight = 8
  bmHardLight = 9
  bmDifference = 10
  bmExclusion = 11
  bmHue = 12
  bmSaturation = 13
  bmColor = 14
  bmLuminosity = 15
  bmMask = 16
  bmOverwrite = 17
  bmSubtractMask = 18
  bmExcludeMask = 19

type ColorRGBX* = object
  r*: uint8
  g*: uint8
  b*: uint8
  a*: uint8

type ColorStop2* = object
  color*: ColorRGBX
  position*: float32

type Paint2* = object
  kind*: enum
  pkSolid, pkImage, pkImageTiled, pkGradientLinear, pkGradientRadial,
  pkGradientAngular
  blendMode*: enum
  bmNormal, bmDarken, bmMultiply, bmColorBurn, bmLighten, bmScreen,
  bmColorDodge, bmOverlay, bmSoftLight, bmHardLight, bmDifference, bmExclusion,
  bmHue, bmSaturation, bmColor, bmLuminosity, bmMask, bmOverwrite,
  bmSubtractMask, bmExcludeMask
  gradientStops*: ColorStop2

type Typeface2* = object
  reference: uint64
proc `file_path`*(typeface2: Typeface2): cstring {.importc: "fidget_typeface2_get_file_path".}
proc `file_path=`*(typeface2: Typeface2, filePath: cstring) {.importc: "fidget_typeface2_set_file_path".}

type Font2* = object
  reference: uint64
proc `typeface`*(font2: Font2): Typeface2 {.importc: "fidget_font2_get_typeface".}
proc `typeface=`*(font2: Font2, typeface: Typeface2) {.importc: "fidget_font2_set_typeface".}
proc `size`*(font2: Font2): float32 {.importc: "fidget_font2_get_size".}
proc `size=`*(font2: Font2, size: float32) {.importc: "fidget_font2_set_size".}
proc `line_height`*(font2: Font2): float32 {.importc: "fidget_font2_get_line_height".}
proc `line_height=`*(font2: Font2, lineHeight: float32) {.importc: "fidget_font2_set_line_height".}
proc `paint`*(font2: Font2): Paint2 {.importc: "fidget_font2_get_paint".}
proc `paint=`*(font2: Font2, paint: Paint2) {.importc: "fidget_font2_set_paint".}
proc `text_case`*(font2: Font2): enum
  tcNormal, tcUpper, tcLower, tcTitle {.importc: "fidget_font2_get_text_case".}
proc `text_case=`*(font2: Font2, textCase: enum
  tcNormal, tcUpper, tcLower, tcTitle) {.importc: "fidget_font2_set_text_case".}
proc `underline`*(font2: Font2): bool {.importc: "fidget_font2_get_underline".}
proc `underline=`*(font2: Font2, underline: bool) {.importc: "fidget_font2_set_underline".}
proc `strikethrough`*(font2: Font2): bool {.importc: "fidget_font2_get_strikethrough".}
proc `strikethrough=`*(font2: Font2, strikethrough: bool) {.importc: "fidget_font2_set_strikethrough".}
proc `no_kerning_adjustments`*(font2: Font2): bool {.importc: "fidget_font2_get_no_kerning_adjustments".}
proc `no_kerning_adjustments=`*(font2: Font2, noKerningAdjustments: bool) {.importc: "fidget_font2_set_no_kerning_adjustments".}

proc readFont2*(font_path: cstring): Font2 {.importc: "fidget_read_font2".}


{.pop.}
