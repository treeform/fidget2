import bumpy, fidget2, print, fidget2/gpumirror, fidget2/globs, bumpy

proc startFidget*(
  figmaUrl: cstring,
  windowTitle: cstring,
  entryFrame: cstring,
  resizable: bool,
) {.stdcall,exportc,dynlib.} =

  print figmaUrl
  print windowTitle
  print entryFrame
  print resizable

  fidget2.startFidget(
    figmaUrl = $figmaUrl,
    windowTitle = $windowTitle,
    entryFrame = $entryFrame,
    resizable = resizable
  )

proc registerCallback*(
  callback: proc(a, b: cint) {.stdcall.},
  a: cint,
  b: cint,
) {.stdcall,exportc,dynlib.} =
  callback(a, b)

proc onClick*(
  glob: cstring,
  callback: proc() {.stdcall.},
) {.stdcall,exportc,dynlib.} =
  let glob = $glob

  addCb(
    eOnClick,
    100,
    glob,
    proc() =
      if mouse.click:
        print mouse.click
        print glob
        for node in globTree.findAll(glob):
          print node.name
          if node.rect.overlaps(mousePos):
            thisNode = node
            callback()
            thisNode = nil
  )

proc onDisplay*(
  glob: cstring,
  callback: proc() {.stdcall.},
) {.stdcall,exportc,dynlib.} =
  let glob = $glob

  addCb(
    eOnClick,
    100,
    glob,
    proc() =
      for node in globTree.findAll(glob):
        callback()
        # print node.name
        # print s
        # if s.len > 0:
        #   thisNode.characters = $s
  )

proc setCharacters*(
  glob: cstring,
  characters: cstring,
) {.stdcall,exportc,dynlib.} =
  let glob = $glob
  for node in globTree.findAll(glob):
    node.characters = $characters
    node.dirty = true
