import algorithm, bumpy, globs, input, json, loader, math, opengl,
    pixie, schema, sequtils, staticglfw, strformat, tables,
    textboxes, unicode, vmath, times, common, algorithm,
    nodes, perf, puppy, layout, os, print

export textboxes, nodes

when defined(cpu):
  import cpurender

elif defined(gpu):
  import gpurender

elif defined(nanovg):
  import nanovgrender

elif defined(hyb):
  import context, hybridrender, cpurender

else:
  # hybrid is default for now
  import context, hybridrender, cpurender

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
    pos*, delta*, prevPos*: Vec2
    pixelScale*: float32
    wheelDelta*: float32
    cursorStyle*: MouseCursorStyle ## Sets the mouse cursor icon
    prevCursorStyle*: MouseCursorStyle
    clickTimes*: array[3, float64]
    click*, doubleClick*, tripleClick*: bool

  Keyboard* = ref object
    state*: KeyState
    consumed*: bool ## Consumed - need to prevent default action.
    keyString*: string
    altKey*: bool
    ctrlKey*: bool
    shiftKey*: bool
    superKey*: bool
    onFocusNode*: Node
    onUnfocusNode*: Node
    input*: string

  EventCbKind* = enum
    eOnClick
    eOnAnyClick
    eOnFrame
    eOnEdit
    eOnDisplay
    eOnFocus
    eOnUnfocus

  EventCb* = ref object
    kind*: EventCbKind
    priority*: int
    glob*: string
    handler*: proc() {.cdecl.}

var
  windowTitle* = "Fidget"
  mousePos*: Vec2
  eventCbs: seq[EventCb]
  requestedFrame*: bool

  mouse* = Mouse()
  keyboard* = Keyboard()

  thisFrame*: Node
  thisNode*: Node
  thisCb*: EventCb
  thisSelector*: string
  selectorStack: seq[string]

proc display(withEvents=true)

proc clearInputs*() =
  ## Clear inputs that are only valid for 1 frame.

  mouse.wheelDelta = 0
  mouse.click = false
  mouse.doubleClick = false
  mouse.tripleClick = false

  # Reset key and mouse press to default state
  for i in 0 ..< buttonPress.len:
    buttonPress[i] = false
    buttonRelease[i] = false

  if any(buttonDown, proc(b: bool): bool = b):
    keyboard.state = ksDown
  else:
    keyboard.state = ksEmpty

  keyboard.onFocusNode = nil
  keyboard.onUnfocusNode = nil

proc down*(mouse: Mouse): bool =
  ## Is the ouse button pressed down?
  buttonDown[MOUSE_LEFT]

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

proc textBoxMouseAction() =
  ## Performs mouse stuff on the text box.
  if textBoxFocus != nil:

    ## Close IME if something was clicked.
    window.closeIme()

    textBoxFocus.dirty = true
    let mat = scale(vec2(1/pixelRatio, 1/pixelRatio)) *
      textBoxFocus.mat *
      translate(-textBoxFocus.scrollPos)
    textBoxFocus.mouseAction(
      mat.inverse() * mouse.pos,
      mouse.click,
      keyboard.shiftKey
    )

template onEdit*(body: untyped) =
  ## When text node is display or edited.
  addCb(
    eOnDisplay,
    100,
    thisSelector,
    proc() {.cdecl.} =
      if mouse.click:
        if thisNode.parent.overlaps(mousePos):
          if textBoxFocus != thisNode:
            setupTextBox(thisNode)
          textBoxMouseAction()
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

  var cwidth, cheight: cint
  window.getWindowSize(addr cwidth, addr cheight)
  windowSize.x = float32(cwidth)
  windowSize.y = float32(cheight)

  window.getFramebufferSize(addr cwidth, addr cheight)
  windowFrame.x = float32(cwidth)
  windowFrame.y = float32(cheight)

  viewportSize = windowFrame

  thisFrame.dirty = true

  minimized = windowSize == vec2(0, 0)
  pixelRatio = if windowSize.x > 0: windowFrame.x / windowSize.x else: 0

  let
    monitor = getPrimaryMonitor()
    mode = monitor.getVideoMode()
  monitor.getMonitorPhysicalSize(addr cwidth, addr cheight)
  dpi = mode.width.float32 / (cwidth.float32 / 25.4)

  windowLogicalSize = windowSize / pixelScale * pixelRatio

proc onResize(handle: staticglfw.Window, w, h: int32) {.cdecl.} =
  ## Handle window resize glfw callback.
  updateWindowSize()
  display(withEvents = false)

proc onFocus(window: staticglfw.Window, state: cint) {.cdecl.} =
  ## Handle window focus glfw callback.
  focused = state == 1

proc onSetKey(
  window: staticglfw.Window, key, scancode, action, modifiers: cint
) {.cdecl.} =
  ## Handle keyboard button glfw callback.
  requestedFrame = true
  let setKey = action != RELEASE

  keyboard.altKey = setKey and ((modifiers and MOD_ALT) != 0)
  keyboard.ctrlKey = setKey and
    ((modifiers and MOD_CONTROL) != 0 or (modifiers and MOD_SUPER) != 0)
  keyboard.shiftKey = setKey and ((modifiers and MOD_SHIFT) != 0)

  # Do the text box commands.
  if textBoxFocus != nil and setKey:
    textBoxFocus.dirty = true
    keyboard.state = ksPress
    let
      ctrl = keyboard.ctrlKey
      shift = keyboard.shiftKey
    if textImeEditString == "":
      case cast[Button](key):
        of ARROW_LEFT:
          if ctrl:
            textBoxFocus.leftWord(shift)
          else:
            textBoxFocus.left(shift)
        of ARROW_RIGHT:
          if ctrl:
            textBoxFocus.rightWord(shift)
          else:
            textBoxFocus.right(shift)
        of ARROW_UP:
          textBoxFocus.up(shift)
        of ARROW_DOWN:
          textBoxFocus.down(shift)
        of Button.HOME:
          textBoxFocus.startOfLine(shift)
        of Button.END:
          textBoxFocus.endOfLine(shift)
        of Button.PAGE_UP:
          textBoxFocus.pageUp(shift)
        of Button.PAGE_DOWN:
          textBoxFocus.pageDown(shift)
        of ENTER:
          #TODO: keyboard.multiline:
          textBoxFocus.typeCharacter(Rune(10))
        of BACKSPACE:
          textBoxFocus.backspace(shift)
        of DELETE:
          textBoxFocus.delete(shift)
        of LETTER_C: # copy
          if ctrl:
            window.setClipboardString(textBoxFocus.copyText())
        of LETTER_V: # paste
          if ctrl:
            textBoxFocus.pasteText($window.getClipboardString())
        of LETTER_X: # cut
          if ctrl:
            window.setClipboardString(textBoxFocus.cutText())
        of LETTER_A: # select all
          if ctrl:
            textBoxFocus.selectAll()
        else:
          discard

  # Now do the buttons.
  if key < buttonDown.len and key >= 0:
    if buttonDown[key] == false and setKey:
      buttonToggle[key] = not buttonToggle[key]
      buttonPress[key] = true
    if buttonDown[key] == true and setKey == false:
      buttonRelease[key] = true
    buttonDown[key] = setKey

proc onSetCharCallback(window: staticglfw.Window, character: cuint) {.cdecl.} =
  ## User typed a character, needed for unicode entry.
  requestedFrame = true
  if textBoxFocus != nil:
    keyboard.state = ksPress
    textBoxFocus.typeCharacter(Rune(character))
  else:
    keyboard.state = ksPress
    keyboard.keyString = Rune(character).toUTF8()

proc onScroll(window: staticglfw.Window, xoffset, yoffset: float64) {.cdecl.} =
  ## Scroll wheel glfw callback.
  requestedFrame = true
  if textBoxFocus != nil:
    textBoxFocus.scrollBy(-yoffset * 50)
  else:
    mouse.wheelDelta += yoffset

  let underMouseNodes = underMouse(thisFrame, mousePos)

  for node in underMouseNodes:
    if node.overflowDirection == odVerticalScrolling:
      # TODO make it scroll both x and y.
      echo "non text scroll limit"
      node.scrollPos.y -= yoffset * 50

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

proc onMouseButton(
  window: staticglfw.Window, button, action, modifiers: cint
) {.cdecl.} =
  ## Mouse button glfw callback.
  requestedFrame = true
  let
    setKey = action != 0
    button = button + 1 # Fidget mouse buttons are +1 from staticglfw
  if button < buttonDown.len:
    if buttonDown[button] == false and setKey == true:
      buttonPress[button] = true
    buttonDown[button] = setKey
  if buttonDown[button] == false and setKey == false:
    buttonRelease[button] = true

  # TODO: Figure out double and triple clicks.
  # if setKey:
  #   for i in 0 ..< 2:
  #     mouse.clickTimes[i] = mouse.clickTimes[i + 1]
  #   mouse.clickTimes[2] = epochTime()
  # let doubleClickTime = mouse.clickTimes[2] - mouse.clickTimes[1]
  # let tripleClickTime = mouse.clickTimes[1] - mouse.clickTimes[0]
  # if doubleClickTime < 0.500 and tripleClickTime < 0.500:
  #   if setKey:
  #     mouse.click = false
  #     mouse.doubleClick = false
  #     mouse.tripleClick = true
  # elif doubleClickTime < 0.500:
  #   if setKey:
  #     mouse.click = false
  #     mouse.doubleClick = true
  #     mouse.tripleClick = false
  # else:
  #   if setKey:
  #     # regular click
  #     mouse.click = true
  #     mouse.doubleClick = true
  #     mouse.tripleClick = false
  #   else:
  #     textBoxMouseAction()

  if setKey:
    mouse.click = true
  else:
    textBoxMouseAction()

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

proc takeScreenShot*(): Image =
  ## Takes a screenshot of the current screen. Used mainly for writing tests.
  readGpuPixelsFromScreen()

proc clearAllEventHandlers*() =
  ## Clears all handlers.  Used mainly for writing tests.
  eventCbs.setLen(0)

proc resizeWindow*(x, y: int) =
  window.setWindowSize(x.cint, y.cint)

proc onMouseMove(window: staticglfw.Window, x, y: cdouble) {.cdecl.} =
  ## Mouse moved glfw callback.
  requestedFrame = true

  mouse.prevPos = mouse.pos
  mouse.pos = vec2(x, y)
  mouse.delta = mouse.pos - mouse.prevPos

  if buttonDown[MOUSE_LEFT]:
    textBoxMouseAction()

proc swapBuffers() {.measure.} =
  when not defined(cpu):
    if vSync:
      window.swapBuffers()
    else:
      glFlush()

proc processEvents() {.measure.} =

  var x, y: float64
  window.getCursorPos(addr x, addr y)
  mousePos.x = x
  if rtl:
    mousePos.x = thisFrame.size.x - mousePos.x
  mousePos.y = y

  # Get the node list under the mouse.
  let underMouseNodes = underMouse(thisFrame, mousePos)

  if buttonPress[MOUSE_LEFT]:
    echo "---"
    for n in underMouseNodes:
      echo n.name

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
        # Is an instance has potential to hover.
        if n.hasVariant("State", "Hover") and
          n.getVariant("State") == "Default":
            hoverNode = n
            n.setVariant("State", "Hover")

  for cb in eventCbs:
    thisCb = cb
    thisSelector = thisCb.glob

    case cb.kind:
    of eOnClick:

      if mouse.click:
        for node in findAll(thisSelector):
          if node.overlaps(mousePos):
            thisNode = node
            thisCb.handler()
            thisNode = nil

    of eOnDisplay:

      for node in findAll(thisSelector):
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
    window.setImePos(imePos.x.cint, imePos.y.cint)

  thisSelector = ""
  thisCb = nil

  if buttonPress[F4]:
    echo "writing atlas"
    ctx.writeAtlas("atlas.png")

  if buttonPress[F5]:
    echo "reloading from web"
    use(currentFigmaUrl)
    thisFrame = find(entryFramePath)

  clearInputs()

proc `imageUrl=`*(paint: schema.Paint, url: string) =
  # TODO: Make loading images async.
  when not defined(emscripten):
    if url notin imageCache:
      let
        imageData = fetch(url)
        avatarImage = decodeImage(imageData)
      imageCache[url] = avatarImage
    paint.imageRef = url

proc display(withEvents = true) {.measure.} =
  ## Called every frame by main while loop.

  if withEvents:
    processEvents()

  var
    imeEditLocation: cint
    iemEditString = newString(256)
  window.getIme(imeEditLocation.addr, iemEditString.cstring)
  for i, c in iemEditString:
    if c == '\0':
      iemEditString.setLen(i)
      break
  if textImeEditString != iemEditString or textImeEditLocation != imeEditLocation:
    echo "ime: ", imeEditLocation, ":'", iemEditString, "'"
    textImeEditLocation = imeEditLocation
    textImeEditString = iemEditString
    textBoxFocus.dirty = true

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
  if buttonToggle[F8]:
    dumpMeasures()

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

  window.setWindowTitle(windowTitle)

  # Setup glfw callbacks.
  discard window.setFramebufferSizeCallback(onResize)
  discard window.setWindowFocusCallback(onFocus)
  discard window.setKeyCallback(onSetKey)
  discard window.setScrollCallback(onScroll)
  discard window.setMouseButtonCallback(onMouseButton)
  discard window.setCursorPosCallback(onMouseMove)
  discard window.setCharCallback(onSetCharCallback)

  # Sort fidget user callbacks.
  eventCbs.sort(proc(a, b: EventCb): int = a.priority - b.priority)

  running = true

  when defined(emscripten):
    # Emscripten can't block so it will call this callback instead.
    proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
    emscripten_set_main_loop(mainLoop, 0, true);
  else:
    # When running native code we can block in an infinite loop.
    while windowShouldClose(window) == 0 and running:
      mainLoop()

    # Destroy the window.
    window.destroyWindow()
    # Exit GLFW.
    terminate()
