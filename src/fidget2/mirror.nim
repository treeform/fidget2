import algorithm, bumpy, common, globs, json, loader, math, opengl,
    pixie, schema, sequtils, windy, strformat, tables,
    textboxes, unicode, vmath, times, internal, algorithm,
    nodes, perf, puppy, layout, os, print, strutils,  puppy/requestpools

export textboxes, nodes, common, windy

when defined(cpu):
  import cpurender
else:
  # Hybrid is default
  import boxy, hybridrender, cpurender

type
  Keyboard* = ref object
    onFocusNode*: Node
    onUnfocusNode*: Node

  EventCbKind* = enum
    OnClick
    OnClickOutside
    OnRightClick
    OnAnyClick
    OnFrame
    OnEdit
    OnDisplay
    OnFocus
    OnUnfocus
    OnShow
    OnHide
    OnMouseMove

  EventCb* = ref object
    kind*: EventCbKind
    priority*: int
    glob*: string
    handler*: proc(thisNode: Node)

var
  eventCbs: seq[EventCb]
  requestedFrame*: bool
  redisplay*: bool

  keyboard* = Keyboard()

  thisFrame*: Node
  thisCb*: EventCb
  thisSelector*: string
  selectorStack: seq[string]

  navigationHistory*: seq[Node]

  requestPool* = newRequestPool(10)

proc display(withEvents=true)

proc showPopup*(name: string) =
  ## Pop up a given node as a popup.
  ## TODO: implement.
  discard

proc addCb*(
  kind: EventCbKind,
  priority: int,
  glob: string,
  handler: proc(thisNode: Node),
) =
  ## Adds a generic call back.
  eventCbs.add EventCb(
    kind: kind,
    priority: priority,
    glob: glob,
    handler: handler
  )

proc find*(glob: string): Node =
  ## Find a node matching a glob pattern.
  var glob = glob
  if glob.len == 0:
    raise newException(FidgetError, &"Error glob can't be empty string \"\".")
  if thisSelector.len > 0:
    glob = thisSelector & "/" & glob
  result = figmaFile.document.find(glob)
  if result == nil:
    raise newException(FidgetError, &"find(\"{glob}\") not found.")


proc findAll*(glob: string): seq[Node] =
  ## Find all nodes matching glob pattern.
  var glob = glob
  if thisSelector.len > 0:
    glob = thisSelector & "/" & glob
  figmaFile.document.findAll(glob)

proc pushSelector(glob: string) =
  # Note: used to make less code in find template, do not inline.
  if thisSelector == "":
    if glob.len == 0 or glob[0] != '/':
      raise newException(FidgetError, "Root selectors must start with /")
    selectorStack.add(thisSelector)
    thisSelector = glob
  else:
    if glob.len > 0 and glob[0] == '/':
      raise newException(FidgetError, "Non-root selectors cannot start with /")
    selectorStack.add(thisSelector)
    if thisSelector[^1] != '/':
      thisSelector &= '/'
    thisSelector &= glob

proc popSelector() =
  # Note: used to make less code in find template, do not inline.
  thisSelector = selectorStack.pop()

template find*(glob: string, body: untyped) =
  ## Sets the root to the glob, everything inside will be relative to
  ## this glob pattern.
  pushSelector(glob)
  try:
    body
  finally:
    popSelector()

template onFrame*(body: untyped) =
  ## Called once for each frame drawn.
  addCb(
    OnFrame,
    0,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onDisplay*(body: untyped) =
  ## When a node is displayed.
  addCb(
    OnDisplay,
    1000,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onShow*(body: untyped) =
  ## When a node is displayed.
  addCb(
    OnShow,
    1000,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onHide*(body: untyped) =
  ## When a node is displayed.
  addCb(
    OnHide,
    1000,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onClick*(body: untyped) =
  ## When node is clicked.
  addCb(
    OnClick,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onRightClick*(body: untyped) =
  ## When node is clicked.
  addCb(
    OnRightClick,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onClickOutside*(body: untyped) =
  ## When node is clicked.
  addCb(
    OnClickOutside,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onMouseMove*(body: untyped) =
  ## When node is clicked.
  addCb(
    OnMouseMove,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

proc setupTextBox(node: Node) =
  ## Setup a the text box around this node.
  keyboard.onUnfocusNode = textBoxFocus
  textBoxFocus = node
  node.dirty = true
  keyboard.onFocusNode = textBoxFocus

  if keyboard.onUnfocusNode != nil:
    keyboard.onUnfocusNode.dirty = true
  keyboard.onFocusNode.dirty = true

  # TODO: handle these properties better
  node.multiline = true
  node.wordWrap = false
  node.scrollable = true
  node.editable = true

proc relativeMousePos*(window: Window, node: Node): Vec2 =
  let
    mat = scale(vec2(1, 1) / window.contentScale) *
      node.mat * translate(-node.scrollPos)
  return mat.inverse() * window.mousePos.vec2

proc textBoxKeyboardAction(button: Button) =
  requestedFrame = true

  # Do the text box commands.
  if textBoxFocus != nil:
    let
      ctrl = window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]
      super = window.buttonDown[KeyLeftSuper] or window.buttonDown[KeyRightSuper]
      shift = window.buttonDown[KeyLeftShift] or window.buttonDown[KeyRightShift]
    if window.imeCompositionString == "":
      case button:
        of KeyLeft:
          if ctrl:
            textBoxFocus.leftWord(shift)
          else:
            textBoxFocus.left(shift)
        of KeyRight:
          if ctrl:
            textBoxFocus.rightWord(shift)
          else:
            textBoxFocus.right(shift)
        of KeyUp:
          textBoxFocus.up(shift)
        of KeyDown:
          textBoxFocus.down(shift)
        of KeyHome:
          textBoxFocus.startOfLine(shift)
        of KeyEnd:
          textBoxFocus.endOfLine(shift)
        of KeyPageUp:
          textBoxFocus.pageUp(shift)
        of KeyPageDown:
          textBoxFocus.pageDown(shift)
        of KeyEnter:
          #TODO: keyboard.multiline:
          textBoxFocus.typeCharacter(Rune(10))
        of KeyBackspace:
          textBoxFocus.backspace(shift)
        of KeyDelete:
          textBoxFocus.delete(shift)
        of KeyZ:
          if (ctrl or super) and shift:
            textBoxFocus.redo()
          elif ctrl or super:
            textBoxFocus.undo()
        of KeyC: # copy
          if ctrl or super:
            setClipboardString(textBoxFocus.copyText())
        of KeyV: # paste
          if ctrl or super:
            let s = getClipboardString()
            echo s
            textBoxFocus.pasteText(s)
        of KeyX: # cut
          if ctrl or super:
            setClipboardString(textBoxFocus.cutText())
        of KeyA: # select all
          if ctrl or super:
            textBoxFocus.selectAll()
        of MouseLeft:
          echo "Click"
          textBoxFocus.mouseAction(
            window.relativeMousePos(textBoxFocus),
            true,
            shift
          )
        of DoubleClick:
          echo "DoubleClick"
          textBoxFocus.selectWord(window.relativeMousePos(textBoxFocus))
        of TripleClick:
          echo "TripleClick"
          textBoxFocus.selectParagraph(window.relativeMousePos(textBoxFocus))
        of QuadrupleClick:
          echo "QuadrupleClick"
          textBoxFocus.selectAll()
        else:
          discard

    textBoxFocus.makeTextDirty()

proc onRune(rune: Rune) =
  ## User typed a character, needed for unicode entry.
  if textBoxFocus != nil:
    echo "type:", rune
    textBoxFocus.typeCharacter(rune)
    requestedFrame = true

proc onScroll() =
  ## Handle scroll wheel.
  requestedFrame = true
  if textBoxFocus != nil:
    textBoxFocus.scrollBy(-window.scrollDelta.y * 50)

  let underMouseNodes = underMouse(thisFrame, window.mousePos.vec2)

  for node in underMouseNodes:
    if node.overflowDirection == VerticalScrolling:
      # TODO make it scroll both x and y.
      node.scrollPos.y -= window.scrollDelta.y * 50

      node.dirty = true

      let bounds = node.computeScrollBounds()
      if node.scrollPos.y > bounds.h:
        node.scrollPos.y = bounds.h
        continue
      if node.scrollPos.y < 0:
        node.scrollPos.y = 0
        continue

      break

proc simulateClick*(glob: string) =
  ## Simulates a mouse click on a node. Used mainly for writing tests.
  for cb in eventCbs:
    if cb.kind == OnClick:
      thisCb = cb
      thisSelector = thisCb.glob
      if cb.glob == glob:
        for node in findAll(cb.glob):
          cb.handler(node)

template onEdit*(body: untyped) =
  ## When text node is display or edited.
  addCb(
    OnDisplay,
    100,
    thisSelector,
    proc(thisNode: Node) =
      if window.buttonPressed[MouseLeft]:
        if thisNode.parent.overlaps(window.mousePos.vec2):
          if textBoxFocus != thisNode:
            setupTextBox(thisNode)
            textBoxFocus.mouseAction(
              window.relativeMousePos(textBoxFocus),
              true,
              false
            )
        else:
          if textBoxFocus == thisNode:
            keyboard.onUnfocusNode = textBoxFocus
            textBoxFocus.dirty = true
            textBoxFocus = nil
  )
  block:
    let fn = proc(thisNode {.inject.}: Node) =
      body
    addCb(
      OnEdit,
      200,
      thisSelector,
      proc(thisNode: Node) =
        if textBoxFocus != nil:
          for node in figmaFile.document.findAll(thisSelector):
            if textBoxFocus == node and textBoxFocus.dirty:
              fn(node)
    )

template onUnfocus*(body: untyped) =
  ## When a text node is displayed and will continue to update.
  block:
    let fn = proc(thisNode {.inject.}: Node) =
      body
    addCb(
      OnUnFocus,
      500,
      thisSelector,
      proc(thisNode: Node) =
        if keyboard.onUnfocusNode != nil:
          for node in figmaFile.document.findAll(thisSelector):
            if keyboard.onUnfocusNode == node:
              fn(node)
    )

template onFocus*(body: untyped) =
  ## When a text node is displayed and will continue to update.
  block:
    let fn = proc(thisNode {.inject.}: Node) =
      body
    addCb(
      OnFocus,
      600,
      thisSelector,
      proc(thisNode: Node)  =
        if keyboard.onFocusNode != nil:
          for node in figmaFile.document.findAll(thisSelector):
            if keyboard.onFocusNode == node:
              fn(node)
    )

proc updateWindowSize() =
  ## Handle window resize.
  requestedFrame = true
  thisFrame.dirty = true

proc onResize() =
  ## Handle window resize.
  updateWindowSize()
  display(withEvents = false)

proc takeScreenShot*(): Image =
  ## Takes a screenshot of the current screen. Used mainly for writing tests.
  readGpuPixelsFromScreen()

proc clearAllEventHandlers*() =
  ## Clears all handlers.  Used mainly for writing tests.
  eventCbs.setLen(0)

proc resizeWindow*(x, y: int) =
  window.size = ivec2(x.cint, y.cint)

proc onMouseMove() =
  ## Mouse move
  requestedFrame = true
  if textBoxFocus != nil:
    if window.buttonDown[MouseLeft]:
      textBoxFocus.mouseAction(
        window.relativeMousePos(textBoxFocus),
        false,
        false
      )

proc swapBuffers() {.measure.} =
  window.swapBuffers()

proc processEvents() {.measure.} =

  # Get the node list under the mouse.
  let underMouseNodes = underMouse(thisFrame, window.mousePos.vec2)

  # if window.buttonPressed[MouseLeft]:
  #   echo "---"
  #   for n in underMouseNodes:
  #     echo n.name
  #   echo "---"

  if window.buttonDown[MouseLeft]:
    window.closeIme()

  if requestPool.requestsCompleted():
    redisplay = true

  if window.buttonDown.len > 0 or window.scrollDelta.length != 0:
    redisplay = true

  # Do hovering logic.
  var hovering = false
  if hoverNode != nil:
    for n in underMouseNodes:
      if n == hoverNode:
        hovering = true
        break

  if not hovering:
    if hoverNode != nil:
      hoverNode.setVariant("State", "Default")
      hoverNode = nil

  for n in underMouseNodes:
    if n.isInstance:
      var stateDown = false
      if window.buttonDown[MouseLeft]:
        # Is an instance has potential to Down.
        if n.hasVariant("State", "Down"):
            stateDown = true
            hoverNode = n
            n.setVariant("State", "Down")

      # Is an instance has potential to hover.
      if not stateDown and n.hasVariant("State", "Hover"):
          hoverNode = n
          n.setVariant("State", "Hover")

  for cb in eventCbs:
    thisCb = cb

    case cb.kind:

    of OnShow:

      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame):
          if node.shown == false:
            node.shown = true
            thisCb.handler(node)

    of OnClick:

      if window.buttonPressed[MouseLeft]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and node in underMouseNodes:
            thisCb.handler(node)

    of OnRightClick:

      if window.buttonPressed[MouseRight]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and node in underMouseNodes:
            thisCb.handler(node)

    of OnClickOutside:

      if window.buttonPressed[MouseLeft]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and
            node notin underMouseNodes and
            node.visible:
              thisCb.handler(node)

    of OnDisplay:

      if redisplay:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame):
            thisCb.handler(node)

    of OnHide:

      for node in findAll(thisCb.glob):
        if not node.inTree(thisFrame):
          if node.shown == true:
            node.shown = false
            thisCb.handler(node)

    of OnMouseMove:

      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame) and node in underMouseNodes:
          thisCb.handler(node)

    of OnFrame:
      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame):
          thisCb.handler(node)

    of OnEdit:
      thisCb.handler(nil)

    of OnFocus:
      thisCb.handler(nil)

    of OnUnfocus:
      thisCb.handler(nil)

    else:
      echo "not covered: ": cb.kind

  if textBoxFocus != nil:
    let cursor = textBoxFocus.cursorRect()
    var imePos = textBoxFocus.mat * (cursor.xy + vec2(0, cursor.h) - textBoxFocus.scrollPos)
    imePos = imePos / window.contentScale()
    when compiles(window.imePos):
      window.imePos = imePos.ivec2

  thisSelector = ""
  thisCb = nil
  redisplay = false

  if window.buttonPressed[KeyF4]:
    echo "writing atlas"
    bxy.readAtlas().writeFile("atlas.png")

  if window.buttonPressed[KeyF5]:
    echo "reloading from web"
    use(currentFigmaUrl)
    thisFrame = find(entryFramePath)

proc `imageUrl=`*(paint: schema.Paint, url: string) =
  # TODO: Make loading images async.
  when not defined(emscripten):
    if url notin imageCache:
      let fileKey = "cache/" & url.replace("/", "_").replace(":", "_").replace(".", "_").replace("?", "_")
      var imageData = ""
      if existsFile(fileKey):
        imageData = readFile(fileKey)
      else:
        imageData = fetch(url)
        echo "write file", url
        writeFile(fileKey, imageData)

      let image = decodeImage(imageData)
      imageCache[url] = image
    paint.imageRef = url

proc `image=`*(paint: schema.Paint, image: Image) =
  imageCache[paint.imageRef] = image
  bxy.addImage(paint.imageRef, image)

proc navigateTo*(fullPath: string, smart = false) =
  ## Navigates to a new frame a new frame.
  ## Smart will try to preserve all nodes with the same name.
  navigationHistory.add(thisFrame)
  thisFrame = find(fullPath)
  if thisFrame == nil:
    raise newException(FidgetError, &"Frame '{fullPath}' not found")
  thisFrame.markTreeDirty()

proc navigateBack*() =
  ## Navigates back the navigation history.
  if navigationHistory.len == 0:
    return
  thisFrame = navigationHistory.pop()
  thisFrame.markTreeDirty()

proc display(withEvents = true) {.measure.} =
  ## Called every frame by main while loop.

  if withEvents:
    processEvents()

  keyboard.onFocusNode = nil
  keyboard.onUnfocusNode = nil

  window.runeInputEnabled = textBoxFocus != nil

  # thisFrame.dirty = true
  thisFrame.checkDirty()
  if true or thisFrame.dirty:
    drawToScreen(thisFrame)

    swapBuffers()
  else:
    # skip frame
    sleep(7)

proc mainLoop() {.cdecl.} =
  pollEvents()
  display()

  if window.buttonToggle[KeyF8]:
    dumpMeasures()

  if window.buttonToggle[KeyF9]:
    dumpMeasures(16)

proc startFidget*(
  figmaUrl: string,
  windowTitle: string,
  entryFrame: string,
  windowStyle = DecoratedResizable
) =
  ## Starts Fidget Main loop.
  currentFigmaUrl = figmaUrl
  use(currentFigmaUrl)

  entryFramePath = entryFrame
  thisFrame = find(entryFramePath)
  if thisFrame == nil:
    quit(entryFrame & ", not found in " & currentFigmaUrl & ".")

  if thisFrame == nil:
    raise newException(FidgetError, &"Frame \"{entryFrame}\" not found")

  hybridrender.setupWindow(
    thisFrame,
    thisFrame.size.ivec2,
    style = windowStyle
  )

  updateWindowSize()

  window.title = windowTitle

  window.onResize = onResize
  window.onScroll = onScroll
  window.onButtonPress = proc(button: Button) =
    textBoxKeyboardAction(button)
  window.onMouseMove = onMouseMove
  window.onRune = onRune

  window.onImeChange = proc() =
    if textBoxFocus != nil:
      textBoxFocus.dirty = true
      textBoxFocus.makeTextDirty()

  window.onCloseRequest = proc() =
    internal.running = false

  # Sort fidget user callbacks.
  eventCbs.sort(proc(a, b: EventCb): int = a.priority - b.priority)

  internal.running = true

  redisplay = true

  when defined(emscripten):
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    emscripten_set_main_loop(mainLoop, 0, true);
  else:
    # When running native code we can block in an infinite loop.
    while internal.running:
      mainLoop()

    # Destroy the window.
    window.close()
