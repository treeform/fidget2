proc fidget_test_numbers(a: int8, b: uint8, c: int16, d: uint16, e: int32, f: uint32, g: int64, h: uint64, i: int, j: uint, k: float32, l: float64, m: float): bool {.cdecl, exportc, dynlib.} =
  testNumbers(a, b, c, d, e, f, g, h, i, j, k, l, m)

proc fidget_get_node_name(node: Node): cstring {.cdecl, exportc, dynlib.} = 
  echo "get:", cast[uint64](node)
  node.name
proc fidget_set_node_name(node: Node, name: cstring) {.cdecl, exportc, dynlib.} = 
  echo "set:", cast[uint64](node)
  node.name = name
proc fidget_get_node_count(node: Node): int {.cdecl, exportc, dynlib.} = 
  echo "get:", cast[uint64](node)
  node.count
proc fidget_set_node_count(node: Node, count: int) {.cdecl, exportc, dynlib.} = 
  echo "set:", cast[uint64](node)
  node.count = count


proc fidget_create_node(): Node {.cdecl, exportc, dynlib.} =
  createNode()

proc fidget_give_vec(v: Vec2) {.cdecl, exportc, dynlib.} =
  giveVec(v)

proc fidget_take_vec(): Vec2 {.cdecl, exportc, dynlib.} =
  takeVec()

