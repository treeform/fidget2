when defined(windows):
  const LibFidget* = "fidget.dll"
elif defined(macosx):
  const LibFidget* = "libfidget.dylib"
else:
  const LibFidget* = "libfidget.so"

{.push dynlib: LibFidget, cdecl.}

proc callMeMaybe*(phone: cstring) {.importc: "fidget_call_me_maybe".}

proc flightClubRule*(n: int): cstring {.importc: "fidget_flight_club_rule".}

proc inputCode*(a: int, b: int, c: int, d: int): bool {.importc: "fidget_input_code".}

proc testNumbers*(a: int8, b: uint8, c: int16, d: uint16, e: int32, f: uint32, g: int64, h: uint64, i: int, j: uint, k: float32, l: float64, m: float): bool {.importc: "fidget_test_numbers".}

type Fod* = object
  reference: uint64
proc `name`*(fod: Fod): cstring {.importc: "fidget_fod_get_name".}
proc `name=`*(fod: Fod, name: cstring) {.importc: "fidget_fod_set_name".}
proc `count`*(fod: Fod): int {.importc: "fidget_fod_get_count".}
proc `count=`*(fod: Fod, count: int) {.importc: "fidget_fod_set_count".}

proc createFod*(): Fod {.importc: "fidget_create_fod".}

type Vector2* = object
  x*: float32
  y*: float32

proc giveVec*(v: Vector2) {.importc: "fidget_give_vec".}

proc takeVec*(): Vector2 {.importc: "fidget_take_vec".}

type AlignSomething* = enum
  asDefault = 0
  asTop = 1
  asBottom = 2
  asRight = 3
  asLeft = 4

proc repeatEnum*(e: AlignSomething): AlignSomething {.importc: "fidget_repeat_enum".}

proc callMeBack*(cb: proc () {.cdecl.}) {.importc: "fidget_call_me_back".}

proc takeSeq*(s: uint64) {.importc: "fidget_take_seq".}

proc returnSeq*(): uint64 {.importc: "fidget_return_seq".}

type TextCase* = enum
  tcNormal = 0
  tcUpper = 1
  tcLower = 2
  tcTitle = 3

type Typeface2* = object
  reference: uint64

type Font2* = object
  typeface*: Typeface2
  size*: float32
  lineHeight*: float32
  textCase*: enum
  tcNormal, tcUpper, tcLower, tcTitle
  underline*: bool
  strikethrough*: bool
  noKerningAdjustments*: bool

proc readFont2*(font_path: cstring): Font2 {.importc: "fidget_read_font2".}

proc onClickGlobal*(a: proc () {.cdecl.}) {.importc: "fidget_on_click_global".}

type Node* = object
  reference: uint64
proc `name`*(node: Node): cstring {.importc: "fidget_node_get_name".}
proc `name=`*(node: Node, name: cstring) {.importc: "fidget_node_set_name".}
proc `characters`*(node: Node): cstring {.importc: "fidget_node_get_characters".}
proc `characters=`*(node: Node, characters: cstring) {.importc: "fidget_node_set_characters".}
proc `dirty`*(node: Node): bool {.importc: "fidget_node_get_dirty".}
proc `dirty=`*(node: Node, dirty: bool) {.importc: "fidget_node_set_dirty".}

proc findNode*(glob: cstring): Node {.importc: "fidget_find_node".}

type EventCbKind* = enum
  eOnClick = 0
  eOnFrame = 1
  eOnEdit = 2
  eOnDisplay = 3
  eOnFocus = 4
  eOnUnfocus = 5

proc addCb*(kind: EventCbKind, priority: int, glob: cstring, handler: proc () {.cdecl.}) {.importc: "fidget_add_cb".}

proc startFidget*(figma_url: cstring, window_title: cstring, entry_frame: cstring, resizable: bool) {.importc: "fidget_start_fidget".}


{.pop.}
