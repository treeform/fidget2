proc fidget_input_code(a: int, b: int, c: int, d: int): int {.cdecl, exportc, dynlib.} =
  inputCode(a, b, c, d).ord

proc fidget_test_numbers(a: int8, b: uint8, c: int16, d: uint16, e: int32, f: uint32, g: int64, h: uint64, i: int, j: uint, k: float32, l: float64, m: float): int {.cdecl, exportc, dynlib.} =
  testNumbers(a, b, c, d, e, f, g, h, i, j, k, l, m).ord

proc fidget_call_me_maybe(phone: cstring) {.cdecl, exportc, dynlib.} =
  callMeMaybe(phone.`$`)

proc fidget_flight_club_rule(n: int): cstring {.cdecl, exportc, dynlib.} =
  flightClubRule(n).cstring

proc fidget_cat_str(a: cstring, b: cstring, c: cstring, d: cstring, e: cstring): cstring {.cdecl, exportc, dynlib.} =
  catStr(a.`$`, b.`$`, c.`$`, d.`$`, e.`$`).cstring

proc fidget_give_vec(v: Vector2) {.cdecl, exportc, dynlib.} =
  giveVec(v)

proc fidget_take_vec(): Vector2 {.cdecl, exportc, dynlib.} =
  takeVec()

proc fidget_take_contact(): Contact {.cdecl, exportc, dynlib.} =
  takeContact()

proc fidget_fod_get_name(fod: Fod): cstring {.cdecl, exportc, dynlib.} = 
  fod.name.cstring
proc fidget_fod_set_name(fod: Fod, name: cstring) {.cdecl, exportc, dynlib.} = 
  fod.name = name.`$`
proc fidget_fod_get_count(fod: Fod): int {.cdecl, exportc, dynlib.} = 
  fod.count
proc fidget_fod_set_count(fod: Fod, count: int) {.cdecl, exportc, dynlib.} = 
  fod.count = count


proc fidget_take_fod(): Fod {.cdecl, exportc, dynlib.} =
  takeFod()

proc fidget_boz_get_name(boz: Boz): cstring {.cdecl, exportc, dynlib.} = 
  boz.name.cstring
proc fidget_boz_set_name(boz: Boz, name: cstring) {.cdecl, exportc, dynlib.} = 
  boz.name = name.`$`
proc fidget_boz_get_fod(boz: Boz): Fod {.cdecl, exportc, dynlib.} = 
  boz.fod
proc fidget_boz_set_fod(boz: Boz, fod: Fod) {.cdecl, exportc, dynlib.} = 
  boz.fod = fod


proc fidget_take_boz(): Boz {.cdecl, exportc, dynlib.} =
  takeBoz()

proc fidget_repeat_enum(e: int): int {.cdecl, exportc, dynlib.} =
  repeatEnum(e.AlignSomething).ord

proc fidget_call_me_back(cb: proc () {.cdecl.}) {.cdecl, exportc, dynlib.} =
  callMeBack(cb)

proc fidget_seq_of_uint64_get(s: seq[uint64], i: int): uint64 {.cdecl, exportc, dynlib.} =
  s[i]
proc fidget_seq_of_uint64_set(s: var seq[uint64], i: int, v: uint64) {.cdecl, exportc, dynlib.} =
  s[i] = v

proc fidget_seq_of_uint64_len(s: var seq[uint64]): int {.cdecl, exportc, dynlib.} =
  s.len

proc fidget_take_seq(): seq[uint64] {.cdecl, exportc, dynlib.} =
  takeSeq()

proc fidget_give_seq(s: seq[uint64]) {.cdecl, exportc, dynlib.} =
  giveSeq(s)

proc fidget_seq_of_vector2_get(s: seq[Vector2], i: int): Vector2 {.cdecl, exportc, dynlib.} =
  s[i]
proc fidget_seq_of_vector2_set(s: var seq[Vector2], i: int, v: Vector2) {.cdecl, exportc, dynlib.} =
  s[i] = v

proc fidget_seq_of_vector2_len(s: var seq[Vector2]): int {.cdecl, exportc, dynlib.} =
  s.len

proc fidget_give_seq_of_vector2(s: seq[Vector2]) {.cdecl, exportc, dynlib.} =
  giveSeqOfVector2(s)

proc fidget_take_seq_of_vector2(): seq[Vector2] {.cdecl, exportc, dynlib.} =
  takeSeqOfVector2()

proc fidget_seq_of_boz_get(s: seq[Boz], i: int): Boz {.cdecl, exportc, dynlib.} =
  s[i]
proc fidget_seq_of_boz_set(s: var seq[Boz], i: int, v: Boz) {.cdecl, exportc, dynlib.} =
  s[i] = v

proc fidget_seq_of_boz_len(s: var seq[Boz]): int {.cdecl, exportc, dynlib.} =
  s.len

proc fidget_give_seq_of_boz(s: seq[Boz]) {.cdecl, exportc, dynlib.} =
  giveSeqOfBoz(s)

proc fidget_take_seq_of_boz(): seq[Boz] {.cdecl, exportc, dynlib.} =
  takeSeqOfBoz()

proc fidget_seq_of_color_stop2_get(s: seq[ColorStop2], i: int): ColorStop2 {.cdecl, exportc, dynlib.} =
  s[i]
proc fidget_seq_of_color_stop2_set(s: var seq[ColorStop2], i: int, v: ColorStop2) {.cdecl, exportc, dynlib.} =
  s[i] = v

proc fidget_seq_of_color_stop2_len(s: var seq[ColorStop2]): int {.cdecl, exportc, dynlib.} =
  s.len

proc fidget_typeface2_get_file_path(typeface2: Typeface2): cstring {.cdecl, exportc, dynlib.} = 
  typeface2.filePath.cstring
proc fidget_typeface2_set_file_path(typeface2: Typeface2, filePath: cstring) {.cdecl, exportc, dynlib.} = 
  typeface2.filePath = filePath.`$`


proc fidget_font2_get_typeface(font2: Font2): Typeface2 {.cdecl, exportc, dynlib.} = 
  font2.typeface
proc fidget_font2_set_typeface(font2: Font2, typeface: Typeface2) {.cdecl, exportc, dynlib.} = 
  font2.typeface = typeface
proc fidget_font2_get_size(font2: Font2): float32 {.cdecl, exportc, dynlib.} = 
  font2.size
proc fidget_font2_set_size(font2: Font2, size: float32) {.cdecl, exportc, dynlib.} = 
  font2.size = size
proc fidget_font2_get_line_height(font2: Font2): float32 {.cdecl, exportc, dynlib.} = 
  font2.lineHeight
proc fidget_font2_set_line_height(font2: Font2, lineHeight: float32) {.cdecl, exportc, dynlib.} = 
  font2.lineHeight = lineHeight
proc fidget_font2_get_paint(font2: Font2): Paint2 {.cdecl, exportc, dynlib.} = 
  font2.paint
proc fidget_font2_set_paint(font2: Font2, paint: Paint2) {.cdecl, exportc, dynlib.} = 
  font2.paint = paint
proc fidget_font2_get_text_case(font2: Font2): int {.cdecl, exportc, dynlib.} = 
  font2.textCase.ord
proc fidget_font2_set_text_case(font2: Font2, textCase: int) {.cdecl, exportc, dynlib.} = 
  font2.textCase = textCase.TextCase
proc fidget_font2_get_underline(font2: Font2): bool {.cdecl, exportc, dynlib.} = 
  font2.underline
proc fidget_font2_set_underline(font2: Font2, underline: bool) {.cdecl, exportc, dynlib.} = 
  font2.underline = underline
proc fidget_font2_get_strikethrough(font2: Font2): bool {.cdecl, exportc, dynlib.} = 
  font2.strikethrough
proc fidget_font2_set_strikethrough(font2: Font2, strikethrough: bool) {.cdecl, exportc, dynlib.} = 
  font2.strikethrough = strikethrough
proc fidget_font2_get_no_kerning_adjustments(font2: Font2): bool {.cdecl, exportc, dynlib.} = 
  font2.noKerningAdjustments
proc fidget_font2_set_no_kerning_adjustments(font2: Font2, noKerningAdjustments: bool) {.cdecl, exportc, dynlib.} = 
  font2.noKerningAdjustments = noKerningAdjustments


proc fidget_read_font2(font_path: cstring): Font2 {.cdecl, exportc, dynlib.} =
  readFont2(font_path.`$`)

