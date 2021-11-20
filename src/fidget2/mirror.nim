import algorithm, bitty, bumpy, globs, json, loader, math, opengl,
    pixie, schema, sequtils, windy, strformat, tables,
    textboxes, unicode, vmath, times, common, algorithm,
    nodes, perf, puppy, layout, os, print, strutils

export textboxes, nodes, common, windy

when defined(cpu):
  import cpurender
else:
  # Hybrid is default
  import boxy, hybridrender, cpurender

type
  KeyState* = enum
    ksEmpty  ## Nothing.
    ksUp     ## Key was help this frame..
    ksDown   ## Key was just held down this frame.
    ksRepeat ## Os wants the key to repeat (while typing and holding).
    ksPress  ## The key is held down right now.

  MouseCursorStyle* = enum
    Default
    Pointer
    Grab
    NSResize

  Mouse* = ref object
    cursorStyle*: MouseCursorStyle ## Sets the mouse cursor icon
    prevCursorStyle*: MouseCursorStyle

  Keyboard* = ref object
    onFocusNode*: Node
    onUnfocusNode*: Node

  EventCbKind* = enum
    eOnClick
    eOnAnyClick
    eOnFrame
    eOnEdit
    eOnDisplay
    eOnFocus
    eOnUnfocus
    eOnShow
    eOnHide

  EventCb* = ref object
    kind*: EventCbKind
    priority*: int
    glob*: string
    handler*: proc() {.cdecl.}

var
  windowTitle* = "Fidget"
  eventCbs: seq[EventCb]
  requestedFrame*: bool

  mouse* = Mouse()
  keyboard* = Keyboard()

  thisFrame*: Node
  thisNode*: Node
  thisCb*: EventCb
  thisSelector*: string
  selectorStack: seq[string]

  navigationHistory*: seq[Node]

proc display(withEvents=true)

# proc clearInputs*() =
#   ## Clear inputs that are only valid for 1 frame.

#   mouse.wheelDelta = 0
#   mouse.delta = vec2(0, 0)
#   window.buttonPressed[MouseLeft] = false
#   mouse.doubleClick = false
#   mouse.tripleClick = false

#   buttonPressed.clear()
#   buttonRelease.clear()

#   if buttonDown.count > 0:
#     keyboard.state = ksDown
#   else:
#     keyboard.state = ksEmpty

#   keyboard.onFocusNode = nil
#   keyboard.onUnfocusNode = nil

proc down*(mouse: Mouse): bool =
  ## Is the ouse button pressed down?
  window.buttonDown[MouseLeft]

proc showPopup*(name: string) =
  ## Pop up a given node as a popup.
  ## TODO: implement.
  discard

proc addCb*(
  kind: EventCbKind,
  priority: int,
  glob: string,
  handler: proc() {.cdecl.},
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
  if thisSelector.len > 0:
    glob = thisSelector & "/" & glob
  figmaFile.document.find(glob)

proc findAll*(glob: string): seq[Node] =
  ## Find all nodes matching glob pattern.
  var glob = glob
  if thisSelector.len > 0:
    glob = thisSelector & "/" & glob
  figmaFile.document.findAll(glob)

proc pushSelector(glob: string) =
  # Note: used to make less code in find template, do not inline.
  selectorStack.add(thisSelector)
  if thisSelector.len > 0:
    thisSelector = thisSelector & "/" & glob
  else:
    thisSelector = glob

proc popSelector() =
  # Note: used to make less code in find template, do not inline.
  thisSelector = selectorStack.pop()

template find*(glob: string, body: untyped) =
  ## Sets the root to the glob, everything inside will be relative to
  ## this glob pattern.
  pushSelector(glob)
  body
  popSelector()

template onFrame*(body: untyped) =
  ## Called once for each frame drawn.
  addCb(
    eOnFrame,
    0,
    "",
    proc() {.cdecl.} =
      body
  )

template onDisplay*(body: untyped) =
  ## When a node is displayed.
  addCb(
    eOnDisplay,
    1000,
    thisSelector,
    proc() {.cdecl.} = body
  )

template onShow*(body: untyped) =
  ## When a node is displayed.
  addCb(
    eOnShow,
    1000,
    thisSelector,
    proc() {.cdecl.} = body
  )

template onHide*(body: untyped) =
  ## When a node is displayed.
  addCb(
    eOnHide,
    1000,
    thisSelector,
    proc() {.cdecl.} = body
  )

template onClick*(body: untyped) =
  ## When node is clicked.
  addCb(
    eOnClick,
    100,
    thisSelector,
    proc() {.cdecl.} = body
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
    mat = scale(vec2(1, 1) / pixelRatio) *
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
    if textImeEditString == "":
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
          if ctrl and shift:
            textBoxFocus.redo()
          elif ctrl:
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
  ## Scroll wheel glfw callback.
  requestedFrame = true
  if textBoxFocus != nil:
    textBoxFocus.scrollBy(-window.scrollDelta.y * 50)

  let underMouseNodes = underMouse(thisFrame, window.mousePos.vec2)

  for node in underMouseNodes:
    if node.overflowDirection == odVerticalScrolling:
      # TODO make it scroll both x and y.
      node.scrollPos.y -= window.scrollDelta.y * 50

      #if node.collapse:
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
    if cb.kind == eOnClick:
      thisCb = cb
      thisSelector = thisCb.glob
      if cb.glob == glob:
        for node in findAll(cb.glob):
          thisNode = node
          cb.handler()
          thisNode = nil

template onEdit*(body: untyped) =
  ## When text node is display or edited.
  addCb(
    eOnDisplay,
    100,
    thisSelector,
    proc() {.cdecl.} =
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
  addCb(
    eOnEdit,
    200,
    thisSelector,
    proc() {.cdecl.} =
      if textBoxFocus != nil:
        for node in figmaFile.document.findAll(thisSelector):
          if textBoxFocus == node and textBoxFocus.dirty:
            thisNode = node
            #textBoxFocus.characters = $textBoxFocus.arrangement.runes
            body
            thisNode = nil
  )

template onUnfocus*(body: untyped) =
  ## When a text node is displayed and will continue to update.
  addCb(
    eOnUnFocus,
    500,
    thisSelector,
    proc() {.cdecl.} =
      if keyboard.onUnfocusNode != nil:
        for node in figmaFile.document.findAll(thisSelector):
          if keyboard.onUnfocusNode == node:
            thisNode = node
            body
            thisNode = nil
  )

template onFocus*(body: untyped) =
  ## When a text node is displayed and will continue to update.
  addCb(
    eOnFocus,
    600,
    thisSelector,
    proc() {.cdecl.} =
      if keyboard.onFocusNode != nil:
        for node in figmaFile.document.findAll(thisSelector):
          if keyboard.onFocusNode == node:
            thisNode = node
            body
            thisNode = nil
  )

proc updateWindowSize() =
  ## Handle window resize.
  requestedFrame = true
  thisFrame.dirty = true
  # windowSize = window.size.vec2  # decoratedSize ?
  windowFrame = window.size.vec2
  viewportSize = windowFrame
  pixelRatio = window.contentScale()

proc onResize() =
  ## Handle window resize glfw callback.
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
  when not defined(cpu):
    if vSync:
      window.swapBuffers()
    else:
      glFlush()

proc processEvents() {.measure.} =

  # Get the node list under the mouse.
  let underMouseNodes = underMouse(thisFrame, window.mousePos.vec2)

  # if window.buttonPressed[MouseLeft]:
  #   echo "---"
  #   for n in underMouseNodes:
  #     echo n.name

  if window.buttonDown[MouseLeft]:
    window.closeIme()

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
    thisSelector = thisCb.glob

    case cb.kind:
    of eOnClick:

      if window.buttonPressed[MouseLeft]:
        for node in findAll(thisSelector):
          if node.inTree(thisFrame) and node.overlaps(window.mousePos.vec2):
            thisNode = node
            thisCb.handler()
            thisNode = nil

    of eOnDisplay:

      for node in findAll(thisSelector):
        if node.inTree(thisFrame):
          thisNode = node
          thisCb.handler()
          thisNode = nil

    of eOnShow:

      for node in findAll(thisSelector):
        if node.inTree(thisFrame):
          if node.shown == false:
            node.shown = true
            thisNode = node
            thisCb.handler()
            thisNode = nil

    of eOnHide:

      for node in findAll(thisSelector):
        if not node.inTree(thisFrame):
          if node.shown == true:
            node.shown = false
            thisNode = node
            thisCb.handler()
            thisNode = nil

    of eOnFrame:
      thisCb.handler()

    of eOnEdit:
      thisCb.handler()

    of eOnFocus:
      thisCb.handler()

    of eOnUnfocus:
      thisCb.handler()

    else:
      echo "not covered: ": cb.kind

  if textBoxFocus != nil:
    let cursor = textBoxFocus.cursorRect()
    var imePos = textBoxFocus.mat * (cursor.xy + vec2(0, cursor.h) - textBoxFocus.scrollPos)
    imePos = imePos / pixelRatio
    window.imePos = imePos.ivec2

  thisSelector = ""
  thisCb = nil

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
      #echo fileKey
      var imageData = ""
      if existsFile(fileKey):
        #echo "read file"
        imageData = readFile(fileKey)
      else:
        imageData = fetch(url)
        echo "write file", url
        writeFile(fileKey, imageData)

      let image = decodeImage(imageData)
      imageCache[url] = image
    paint.imageRef = url

proc navigateTo*(fullPath: string, smart = false) =
  ## Navigates to a new frame a new frame.
  ## Smart will try to preserve all nodes with the same name.
  navigationHistory.add(thisFrame)
  thisFrame = find(fullPath)
  if thisFrame == nil:
    raise newException(FidgetError, &"Frame '{fullPath}' not found")
  #bxy.clearAtlas()
  thisFrame.markTreeDirty()

proc navigateBack*() =
  ## Navigates back the navigation history.
  if navigationHistory.len == 0:
    raise newException(FidgetError, &"The navigation history is empty!")
  thisFrame = navigationHistory.pop()
  #bxy.clearAtlas()
  thisFrame.markTreeDirty()

proc display(withEvents = true) {.measure.} =
  ## Called every frame by main while loop.

  if withEvents:
    processEvents()

  keyboard.onFocusNode = nil
  keyboard.onUnfocusNode = nil

  window.runeInputEnabled = textBoxFocus != nil

  thisFrame.dirty = true
  thisFrame.checkDirty()
  if thisFrame.dirty:
    drawToScreen(thisFrame)
    swapBuffers()
  else:
    # skip frame
    sleep(7)

  inc frameNum

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
  resizable: bool,
  decorated = true,
) =
  ## Starts Fidget Main loop.
  currentFigmaUrl = figmaUrl
  use(currentFigmaUrl)

  entryFramePath = entryFrame
  thisFrame = find(entryFramePath)
  if thisFrame == nil:
    quit(entryFrame & ", not found in " & currentFigmaUrl & ".")
  windowResizable = resizable

  viewportSize = thisFrame.size

  if thisFrame == nil:
    raise newException(FidgetError, &"Frame \"{entryFrame}\" not found")

  setupWindow(
    thisFrame,
    resizable = resizable,
    decorated = decorated
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
    var
      imeEditLocation = window.imeCursorIndex
      iemEditString = window.imeCompositionString

    for i, c in iemEditString:
      if c == '\0':
        iemEditString.setLen(i)
        break
    if textImeEditString != iemEditString or textImeEditLocation != imeEditLocation:
      echo "ime: ", imeEditLocation, ":'", iemEditString, "'"
      textImeEditLocation = imeEditLocation
      textImeEditString = iemEditString
      if textBoxFocus != nil:
        textBoxFocus.dirty = true
        textBoxFocus.makeTextDirty()

  window.onCloseRequest = proc() =
    common.running = false

  # Sort fidget user callbacks.
  eventCbs.sort(proc(a, b: EventCb): int = a.priority - b.priority)

  common.running = true

  when defined(emscripten):
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    emscripten_set_main_loop(mainLoop, 0, true);
  else:
    # When running native code we can block in an infinite loop.
    while common.running:
      mainLoop()

    # Destroy the window.
    window.close()
