import bindey, print, fidget2, vmath
exports onClickGlobal

# exportObject(Vec2)
exports Node, [
  "name",
#  "position",
  "dirty",
  "characters",
]
proc findNode(glob: string): Node =
  if glob == ".":
    thisNode
  else:
    find(glob)
exports findNode

exports EventCbKind
exports addCb
exports startFidget

write("fidget")

include internalapi
