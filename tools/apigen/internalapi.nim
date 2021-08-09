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

