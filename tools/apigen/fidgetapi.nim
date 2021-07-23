proc fidget_call_me_maybe(phone: cstring) {.cdecl, exportc, dynlib.} =
  callMeMaybe(phone.`$`)

proc fidget_flight_club_rule(n: int): cstring {.cdecl, exportc, dynlib.} =
  flightClubRule(n).cstring

proc fidget_input_code(a: int, b: int, c: int, d: int): int {.cdecl, exportc, dynlib.} =
  inputCode(a, b, c, d).ord

proc fidget_test_numbers(a: int8, b: uint8, c: int16, d: uint16, e: int32, f: uint32, g: int64, h: uint64, i: int, j: uint, k: float32, l: float64, m: float): int {.cdecl, exportc, dynlib.} =
  testNumbers(a, b, c, d, e, f, g, h, i, j, k, l, m).ord

proc fidget_fod_get_name(fod: Fod): cstring {.cdecl, exportc, dynlib.} = 
  fod.name.cstring
proc fidget_fod_set_name(fod: Fod, name: cstring) {.cdecl, exportc, dynlib.} = 
  fod.name = name.`$`
proc fidget_fod_get_count(fod: Fod): int {.cdecl, exportc, dynlib.} = 
  fod.count
proc fidget_fod_set_count(fod: Fod, count: int) {.cdecl, exportc, dynlib.} = 
  fod.count = count


proc fidget_create_fod(): Fod {.cdecl, exportc, dynlib.} =
  createFod()

proc fidget_give_vec(v: Vector2) {.cdecl, exportc, dynlib.} =
  giveVec(v)

proc fidget_take_vec(): Vector2 {.cdecl, exportc, dynlib.} =
  takeVec()

proc fidget_repeat_enum(e: int): int {.cdecl, exportc, dynlib.} =
  repeatEnum(e.AlignSomething).ord

proc fidget_call_me_back(cb: proc () {.cdecl.}) {.cdecl, exportc, dynlib.} =
  callMeBack(cb)

proc fidget_on_click_global(a: proc () {.cdecl.}) {.cdecl, exportc, dynlib.} =
  onClickGlobal(a)

proc fidget_node_get_name(node: Node): cstring {.cdecl, exportc, dynlib.} = 
  node.name.cstring
proc fidget_node_set_name(node: Node, name: cstring) {.cdecl, exportc, dynlib.} = 
  node.name = name.`$`
proc fidget_node_get_characters(node: Node): cstring {.cdecl, exportc, dynlib.} = 
  node.characters.cstring
proc fidget_node_set_characters(node: Node, characters: cstring) {.cdecl, exportc, dynlib.} = 
  node.characters = characters.`$`
proc fidget_node_get_dirty(node: Node): bool {.cdecl, exportc, dynlib.} = 
  node.dirty
proc fidget_node_set_dirty(node: Node, dirty: bool) {.cdecl, exportc, dynlib.} = 
  node.dirty = dirty


proc fidget_find_node(glob: cstring): Node {.cdecl, exportc, dynlib.} =
  findNode(glob.`$`)

proc fidget_add_cb(kind: int, priority: int, glob: cstring, handler: proc () {.cdecl.}) {.cdecl, exportc, dynlib.} =
  addCb(kind.EventCbKind, priority, glob.`$`, handler)

proc fidget_start_fidget(figma_url: cstring, window_title: cstring, entry_frame: cstring, resizable: int) {.cdecl, exportc, dynlib.} =
  startFidget(figma_url.`$`, window_title.`$`, entry_frame.`$`, resizable.bool)

