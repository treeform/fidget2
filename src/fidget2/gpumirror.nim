import staticglfw, opengl, math, schema, gpurender, pixie, vmath, bumpy,
  loader, typography, typography/textboxes, tables, input, unicode, sequtils,
  strutils, strformat, sequtils, globs, algorithm, print, json, zpurender

export textboxes

type
  KeyState* = enum
    Empty
    Up
    Down
    Repeat
    Press # Used for text input

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

  Keyboard* = ref object
    state*: KeyState
    consumed*: bool ## Consumed - need to prevent default action.
    keyString*: string
    altKey*: bool
    ctrlKey*: bool
    shiftKey*: bool
    superKey*: bool
    #focusNode*: Node (use textBoxFocus)
    onFocusNode*: Node
    onUnfocusNode*: Node
    input*: string
    # textCursor*: int ## At which character in the input string are we
    # selectionCursor*: int ## To which character are we selecting to

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
    selector*: string
    run*: proc()

var
  windowTitle* = "Fidget"
  windowResizable*: bool
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
  windowSize*: Vec2    ## Screen coordinates
  windowFrame*: Vec2   ## Pixel coordinates
  dpi*: float32
  pixelRatio*: float32 ## Multiplier to convert from screen coords to pixels
  pixelScale*: float32 ## Pixel multiplier user wants on the UI

proc display()

proc clearInputs*() =

  mouse.wheelDelta = 0
  # Reset key and mouse press to default state
  for i in 0 ..< buttonPress.len:
    buttonPress[i] = false
    buttonRelease[i] = false

  if any(buttonDown, proc(b: bool): bool = b):
    keyboard.state = KeyState.Down
  else:
    keyboard.state = KeyState.Empty

  keyboard.onFocusNode = nil
  keyboard.onUnfocusNode = nil

proc click*(mouse: Mouse): bool =
  buttonPress[MOUSE_LEFT]

proc down*(mouse: Mouse): bool =
  buttonDown[MOUSE_LEFT]

proc showPopup*(name: string) =
  discard

proc addCb*(
  kind: EventCbKind,
  priority: int,
  selector: string,
  run: proc(),
) =
  ## Adds a generic call back.
  eventCbs.add EventCb(
    kind: kind,
    priority: priority,
    selector: selector,
    run: run
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
  pushSelector(glob)
  body
  popSelector()

template onFrame*(body: untyped) =
  ## Called once for each frame drawn.
  addCb(
    eOnFrame,
    0,
    "",
    proc() =
      body
  )

template onDisplay*(body: untyped) =
  ## When a node is displayed.
  addCb(
    eOnDisplay,
    1000,
    thisSelector,
    proc() =
      for node in globTree.findAll(thisSelector):
        thisNode = node
        body
        thisNode = nil
  )

template onClick*(body: untyped) =
  ## When node is clicked.
  addCb(
    eOnClick,
    100,
    thisSelector,
    proc() =
      if mouse.click:
        for node in globTree.findAll(thisSelector):
          if node.rect.overlap(mousePos):
            thisNode = node
            body
            thisNode = nil
  )

proc setupTextBox(node: Node) =
  ## Setup a the text box around this node.
  keyboard.onUnfocusNode = textBoxFocus
  textBoxFocus = node
  keyboard.onFocusNode = textBoxFocus

  var font = Font()
  font.typeface = typefaceCache[node.style.fontPostScriptName]
  font.size = node.style.fontSize
  font.lineHeight = node.style.lineHeightPx

  textBox = newTextBox(
    font,
    int node.pixelBox.w,
    int node.pixelBox.h,
    node.characters,
    node.style.textAlignHorizontal,
    node.style.textAlignVertical,
    false, #node.multiline,
    worldWrap = true,
  )
  #textBox.editable = node.editableText
  #textBox.scrollable = true
  echo "textBox created"

template onEdit*(body: untyped) =
  ## When text node is display or edited.
  addCb(
    eOnClick,
    100,
    thisSelector,
    proc() =
      if mouse.click:
        for node in globTree.findAll(thisSelector):
          if node.rect.overlap(mousePos):
            setupTextBox(node)
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

proc rect*(node: Node): Rect =
  ## Gets the nodes rectangle on screen.
  # TODO: this might be off with rotations, use better method.
  result.x = node.absoluteBoundingBox.x + framePos.x
  result.y = node.absoluteBoundingBox.y + framePos.y
  result.w = node.absoluteBoundingBox.w
  result.h = node.absoluteBoundingBox.h

proc updateWindowSize() =
  requestedFrame = true

  var cwidth, cheight: cint
  window.getWindowSize(addr cwidth, addr cheight)
  windowSize.x = float32(cwidth)
  windowSize.y = float32(cheight)

  window.getFramebufferSize(addr cwidth, addr cheight)
  windowFrame.x = float32(cwidth)
  windowFrame.y = float32(cheight)

  minimized = windowSize == vec2(0, 0)
  pixelRatio = if windowSize.x > 0: windowFrame.x / windowSize.x else: 0

  glViewport(0, 0, cwidth, cheight)

  let
    monitor = getPrimaryMonitor()
    mode = monitor.getVideoMode()
  monitor.getMonitorPhysicalSize(addr cwidth, addr cheight)
  dpi = mode.width.float32 / (cwidth.float32 / 25.4)

  windowLogicalSize = windowSize / pixelScale * pixelRatio

proc onResize(handle: staticglfw.Window, w, h: int32) {.cdecl.} =
  updateWindowSize()
  #updateLoop(poll = false)
  display()

proc onFocus(window: staticglfw.Window, state: cint) {.cdecl.} =
  focused = state == 1

proc onSetKey(
  window: staticglfw.Window, key, scancode, action, modifiers: cint
) {.cdecl.} =
  requestedFrame = true
  let setKey = action != RELEASE

  keyboard.altKey = setKey and ((modifiers and MOD_ALT) != 0)
  keyboard.ctrlKey = setKey and
    ((modifiers and MOD_CONTROL) != 0 or (modifiers and MOD_SUPER) != 0)
  keyboard.shiftKey = setKey and ((modifiers and MOD_SHIFT) != 0)

  # Do the text box commands.
  if textBox != nil and setKey:
    keyboard.state = KeyState.Press
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

proc onSetCharCallback(window: staticglfw.Window, character: cuint) {.cdecl.} =
  requestedFrame = true
  if textBox != nil:
    keyboard.state = KeyState.Press
    textBox.typeCharacter(Rune(character))
  else:
    keyboard.state = KeyState.Press
    keyboard.keyString = Rune(character).toUTF8()

proc onScroll(window: staticglfw.Window, xoffset, yoffset: float64) {.cdecl.} =
  requestedFrame = true
  if textBoxFocus != nil:
    textBox.scrollBy(-yoffset * 50)
  else:
    mouse.wheelDelta += yoffset

proc onMouseButton(
  window: staticglfw.Window, button, action, modifiers: cint
) {.cdecl.} =
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

proc onMouseMove(window: staticglfw.Window, x, y: cdouble) {.cdecl.} =
  requestedFrame = true

proc display() =
  ## Called every frame by main while loop.
  block:
    var x, y: float64
    window.getCursorPos(addr x, addr y)
    mousePos.x = x
    mousePos.y = y

    echo "hover index", getIndexAt(thisFrame, mousePos)

  if windowResizable:
    # Stretch the current frame to fit the window.
    thisFrame.box.wh = windowSize
  else:
    # Stretch the window to fit the current frame.
    if windowSize != thisFrame.box.wh:
      window.setWindowSize(thisFrame.box.w.cint, thisFrame.box.h.cint)

  for cb in eventCbs:
    thisCb = cb
    thisSelector = thisCb.selector
    thisCb.run()
  thisSelector = ""
  thisCb = nil

  clearInputs()

  drawGpuFrame(thisFrame)

  swapBuffers(window)

proc startFidget*(
  figmaUrl: string,
  windowTitle: string,
  entryFrame: string,
  resizable = true
) =
  ## Starts Fidget Main loop.

  use(figmaUrl)

  thisFrame = find(entryFrame)
  windowResizable = resizable

  if thisFrame == nil:
    raise newException(FidgetError, &"Frame \"{entryFrame}\" not found")

  createWindow(
    thisFrame,
    resizable = resizable
  )

  updateWindowSize()

  window.setWindowTitle(windowTitle)

  discard window.setFramebufferSizeCallback(onResize)
  discard window.setWindowFocusCallback(onFocus)
  discard window.setKeyCallback(onSetKey)
  discard window.setScrollCallback(onScroll)
  discard window.setMouseButtonCallback(onMouseButton)
  discard window.setCursorPosCallback(onMouseMove)
  discard window.setCharCallback(onSetCharCallback)

  # Sort callbacks
  eventCbs.sort(proc(a, b: EventCb): int = a.priority - b.priority)

  # Run while window is open.
  while windowShouldClose(window) == 0:
    pollEvents()
    display()

  # Destroy the window.
  window.destroyWindow()
  # Exit GLFW.
  terminate()
