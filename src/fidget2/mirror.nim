import algorithm, bumpy, globs, input, json, loader, math, opengl,
    pixie, schema, sequtils, staticglfw, strformat, tables,
    textboxes, unicode, vmath, times, common, algorithm,
    nodes

export textboxes, nodes

when defined(cpu):
  import cpurender

elif defined(gpu):
  import gpurender

elif defined(nanovg):
  import nanovgrender

elif defined(hyb):
  import context, hybridrender

else:
  # hybrid is default for now
  import context, hybridrender

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

  fullscreen* = false
  running*, focused*, minimized*: bool
  windowLogicalSize*: Vec2 ## Screen size in logical coordinates.
  windowSize*: Vec2        ## Screen coordinates
  windowFrame*: Vec2       ## Pixel coordinates
  dpi*: float32
  pixelRatio*: float32     ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32     ## Pixel multiplier user wants on the UI

  frameNum*: int

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
  echo "adding callback", kind, " ", glob
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
  globTree.find(glob)

iterator findAll*(glob: string): Node =
  ## Find all nodes matching glob pattern.
  var glob = glob
  if thisSelector.len > 0:
    glob = thisSelector & "/" & glob
  for node in globTree.findAll(glob):
    yield node

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
  keyboard.onFocusNode = textBoxFocus

  if keyboard.onUnfocusNode != nil:
    keyboard.onUnfocusNode.dirty = true
  keyboard.onFocusNode.dirty = true

  var font = newFont(typefaceCache[node.style.fontPostScriptName])
  font.size = node.style.fontSize
  font.lineHeight = node.style.lineHeightPx

  textBox = newTextBox(
    font,
    int node.pixelBox.w,
    int node.pixelBox.h,
    node.characters,
    HorizontalAlignment(node.style.textAlignHorizontal.int),
    VerticalAlignment(node.style.textAlignVertical.int),
    multiline = true, #TODO: node.multiline,
    worldWrap = true,
  )
  textBox.arrangement = arrangementCache[node.id]
  # TODO: add these:
  #textBox.editable = node.editableText
  #textBox.scrollable = true

proc textBoxMouseAction() =
  ## Performs mouse stuff on the text box.
  if textBoxFocus != nil:
    textBoxFocus.dirty = true
    textBox.mouseAction(
      textBoxFocus.mat.inverse() * mouse.pos,
      mouse.click,
      keyboard.shiftKey
    )

template onEdit*(body: untyped) =
  ## When text node is display or edited.
  addCb(
    eOnClick,
    100,
    thisSelector,
    proc() =
      if mouse.click:
        for node in globTree.findAll(thisSelector):
          if node.pixelBox.overlaps(mousePos):
            if textBoxFocus != node:
              setupTextBox(node)
            textBoxMouseAction()
      elif mouse.doubleClick:
        if textBox != nil:
          textBoxFocus.dirty = true
          textBox.selectWord(textBoxFocus.mat.inverse() * mouse.pos)
      elif mouse.tripleClick:
        if textBox != nil:
          textBoxFocus.dirty = true
          textBox.selectParagraph(textBoxFocus.mat.inverse() * mouse.pos)

  )
  addCb(
    eOnEdit,
    200,
    thisSelector,
    proc() =
      if textBoxFocus != nil and textBox != nil:
        for node in globTree.findAll(thisSelector):
          if textBoxFocus == node and textBox.hasChange:
            thisNode = node
            textBoxFocus.characters = $textBox.runes
            body
            thisNode = nil
            textBox.hasChange = false
  )

template onUnfocus*(body: untyped) =
  ## When a text node is displayed and will continue to update.
  addCb(
    eOnUnFOcus,
    500,
    thisSelector,
    proc() =
      if keyboard.onUnfocusNode != nil:
        for node in globTree.findAll(thisSelector):
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
    proc() =
      if keyboard.onFocusNode != nil:
        for node in globTree.findAll(thisSelector):
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
  if textBox != nil and setKey:
    textBoxFocus.dirty = true
    keyboard.state = ksPress
    let
      ctrl = keyboard.ctrlKey
      shift = keyboard.shiftKey
    case cast[Button](key):
      of ARROW_LEFT:
        if ctrl:
          textBox.leftWord(shift)
        else:
          textBox.left(shift)
      of ARROW_RIGHT:
        if ctrl:
          textBox.rightWord(shift)
        else:
          textBox.right(shift)
      of ARROW_UP:
        textBox.up(shift)
      of ARROW_DOWN:
        textBox.down(shift)
      of Button.HOME:
        textBox.startOfLine(shift)
      of Button.END:
        textBox.endOfLine(shift)
      of Button.PAGE_UP:
        textBox.pageUp(shift)
      of Button.PAGE_DOWN:
        textBox.pageDown(shift)
      of ENTER:
        #TODO: keyboard.multiline:
        textBox.typeCharacter(Rune(10))
      of BACKSPACE:
        textBox.backspace(shift)
      of DELETE:
        textBox.delete(shift)
      of LETTER_C: # copy
        if ctrl:
          window.setClipboardString(textBox.copy())
      of LETTER_V: # paste
        if ctrl:
          textBox.paste($window.getClipboardString())
      of LETTER_X: # cut
        if ctrl:
          window.setClipboardString(textBox.cut())
      of LETTER_A: # select all
        if ctrl:
          textBox.selectAll()
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

var onClickGlobalCb: proc() {.cdecl.}
proc onClickGlobal*(a: proc() {.cdecl.}) =
  echo "setting onClickGlobal"
  onClickGlobalCb = a

proc onSetCharCallback(window: staticglfw.Window, character: cuint) {.cdecl.} =
  ## User typed a character, needed for unicode entry.
  requestedFrame = true
  if textBox != nil:
    keyboard.state = ksPress
    textBox.typeCharacter(Rune(character))
  else:
    keyboard.state = ksPress
    keyboard.keyString = Rune(character).toUTF8()

proc onScroll(window: staticglfw.Window, xoffset, yoffset: float64) {.cdecl.} =
  ## Scroll wheel glfw callback.
  requestedFrame = true
  if textBoxFocus != nil:
    textBox.scrollBy(-yoffset * 50)
  else:
    mouse.wheelDelta += yoffset

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
        for node in globTree.findAll(cb.glob):
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
  mouse.pos.x = x
  mouse.pos.y = y

  if buttonDown[MOUSE_LEFT]:
    textBoxMouseAction()

proc display(withEvents = true) =
  ## Called every frame by main while loop.

  block:
    var x, y: float64
    window.getCursorPos(addr x, addr y)
    mousePos.x = x
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

  if windowResizable:
    # Stretch the current frame to fit the window.
    if windowSize != thisFrame.size:
      thisFrame.markTreeDirty()
      thisFrame.size = windowSize
  else:
    # Stretch the window to fit the current frame.
    if windowSize != thisFrame.size:
      window.setWindowSize(thisFrame.size.x.cint, thisFrame.size.y.cint)

  if withEvents:
    for cb in eventCbs:
      thisCb = cb
      thisSelector = thisCb.glob

      case cb.kind:
      of eOnClick:

        if mouse.click:
          for node in globTree.findAll(thisSelector):
            if node.pixelBox.overlaps(mousePos):
              thisNode = node
              thisCb.handler()
              thisNode = nil

      of eOnDisplay:

        for node in globTree.findAll(thisSelector):
          thisNode = node
          thisCb.handler()
          thisNode = nil

      of eOnFrame:
        thisCb.handler()

      else:
        echo "not covered: ": cb.kind

    thisSelector = ""
    thisCb = nil

    if buttonPress[F4]:
      echo "writing atlas"
      ctx.writeAtlas("atlas.png")

    clearInputs()

  thisFrame.checkDirty()

  drawToScreen(thisFrame)

  when not defined(cpu):
    if vSync:
      window.swapBuffers()
    else:
      glFlush()

  inc frameNum

proc startFidget*(
  figmaUrl: string,
  windowTitle: string,
  entryFrame: string,
  resizable: bool
) =
  ## Starts Fidget Main loop.

  use(figmaUrl)

  thisFrame = find(entryFrame)
  windowResizable = resizable

  viewportSize = thisFrame.size

  if thisFrame == nil:
    raise newException(FidgetError, &"Frame \"{entryFrame}\" not found")

  setupWindow(
    thisFrame,
    resizable = resizable
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

  # Run while window is open.
  while windowShouldClose(window) == 0 and running:
    pollEvents()
    display()

  # Destroy the window.
  window.destroyWindow()
  # Exit GLFW.
  terminate()
