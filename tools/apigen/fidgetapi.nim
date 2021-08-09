when defined(windows):
  const Libfidget* = "fidget.dll"
elif defined(macosx):
  const Libfidget* = "libfidget.dylib"
else:
  {.passL: "-Wl,-rpath='$ORIGIN'".}
  const Libfidget* = "libfidget.so"

{.push dynlib: Libfidget, cdecl.}

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
