import
  std/[algorithm, os, json, strformat, strutils, tables, unicode, times],
  bumpy, pixie, vmath, windy,
  common, globs, internal, loader, nodes, inodes, measure, schema, textboxes

const
  ## After N pixels of mouse button down and dragging,
  ## having onDrag event handler,
  ## the node is considered to be dragged.
  DragThreshold = 5.0

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
    ## When user clicks on a node.
    OnClick
    ## When user clicks outside a node.
    OnClickOutside
    ## When user right-clicks on a node.
    OnRightClick
    ## When the mouse moves over a node.
    OnMouseMove
    ## When the node is loaded.
    ## Called only once per node.
    OnLoad
    ## Called once per frame.
    ## NOTE: Can caused performance issues if overused.
    OnFrame
    ## When a node is displayed.
    ## NOTE: Can caused performance issues if overused.
    OnDisplay
    ## When a text node is edited.
    ## Only text nodes with this event can be edited.
    OnEdit
    ## When a text node is focused.
    OnFocus
    ## When a text node is unfocused.
    OnUnfocus
    ## When a node is shown, `thisNode.visible` is true.
    OnShow
    ## When a node is hidden, `thisNode.visible` is false.
    OnHide
    ## When a button is pressed, includes mouse buttons and keyboard buttons.
    OnButtonPress
    ## When a button is released, includes mouse buttons and keyboard buttons.
    OnButtonRelease
    ## When the `thisNode.size` changes.
    OnResize
    ## When user starts dragging a node.
    ## Only nodes with this event can be dragged.
    ## `dragNode` is the node that is being dragged.
    OnDragStart
    ## When user is dragging a node.
    ## `dragNode` is the node that is being dragged.
    ## Similar to OnMouseMove, but only called on the node that is being dragged.
    OnDrag
    ## When user stops dragging a node called on the node that is being dragged.
    ## `dragNode` is the node that was stopped dragging.
    OnDragEnd
    ## When user drops a node, called on the node that is below the node that is being dragged.
    ## Only nodes with this event can be dropped to.
    ## `dropNode` is the node that was dropped.
    OnDrop

  EventCb* = ref object
    kind*: EventCbKind
    priority*: int
    glob*: string
    handler*: proc(thisNode: Node)

var
  eventCbs: seq[EventCb]
  editableSelectors: seq[string]
  requestedFrame*: bool
  redisplay*: bool

  keyboard* = Keyboard()

  thisFrame*: Node
  dragNode*: Node
  dragCandidate*: Node
  dragCandidatePos*: Vec2
  thisCb*: EventCb
  thisSelector*: string
  thisButton*: Button
  thisCursor*: Cursor
  hoverNodes*: seq[Node]

  selectorStack: seq[string]

  navigationHistory*: seq[Node]
  onResizeCache: Table[string, Vec2]

  traceActive: bool

proc display()

proc showPopup*(name: string) =
  ## Pops up a given node as a popup.
  ## TODO: implement.
  discard

proc addCb*(
  kind: EventCbKind,
  priority: int,
  glob: string,
  handler: proc(thisNode: Node),
) =
  ## Adds a generic callback.
  eventCbs.add EventCb(
    kind: kind,
    priority: priority,
    glob: glob,
    handler: handler
  )

proc find*(glob: string): Node =
  ## Finds a node matching a glob pattern.
  var glob = glob
  if glob.len == 0:
    raise newException(FidgetError, &"Error glob can't be empty string \"\".")
  if thisSelector.len > 0 and not glob.startsWith("/"):
    glob = thisSelector & "/" & glob
  result = figmaFile.document.find(glob)
  if result == nil:
    raise newException(FidgetError, &"find(\"{glob}\") not found.")

proc findAll*(glob: string): seq[Node] =
  ## Finds all nodes matching a glob pattern.
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

proc focused*(node: Node): bool =
  ## Checks if a node is focused.
  node.internal == textBoxFocus

template onLoad*(body: untyped) =
  ## Called when the node is loaded.
  addCb(
    OnLoad,
    0,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

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
  ## When a node is shown.
  addCb(
    OnShow,
    1000,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onHide*(body: untyped) =
  ## When a node is hidden.
  addCb(
    OnHide,
    1000,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onClick*(body: untyped) =
  ## When a node is clicked.
  addCb(
    OnClick,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onRightClick*(body: untyped) =
  ## When a node is right-clicked.
  addCb(
    OnRightClick,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onClickOutside*(body: untyped) =
  ## When clicked outside a node.
  addCb(
    OnClickOutside,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onMouseMove*(body: untyped) =
  ## When the mouse moves over a node.
  addCb(
    OnMouseMove,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onButtonPress*(body: untyped) =
  ## When a key is pressed.
  addCb(
    OnButtonPress,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onButtonRelease*(body: untyped) =
  ## When a key is pressed.
  addCb(
    OnButtonRelease,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onResize*(body: untyped) =
  ## When the window is resized.
  addCb(
    OnResize,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

proc setupTextBox(node: Node) =
  ## Sets up this node as a text box.
  keyboard.onUnfocusNode = textBoxFocus.Node()
  textBoxFocus = node.internal
  node.dirty = true
  keyboard.onFocusNode = textBoxFocus.Node()

  if keyboard.onUnfocusNode != nil:
    keyboard.onUnfocusNode.dirty = true
  keyboard.onFocusNode.dirty = true

  # TODO: handle these properties better
  node.wordWrap = false
  node.scrollable = true
  node.editable = true

proc relativeMousePos*(window: Window, node: INode): Vec2 =
  ## Gets the mouse position relative to a node.
  let
    mat = scale(vec2(1, 1) / window.contentScale) *
      node.mat * translate(-node.scrollPos)
  return mat.inverse() * window.mousePos.vec2

proc relativeMousePos*(window: Window, node: Node): Vec2 =
  ## Gets the mouse position relative to a node.
  relativeMousePos(window, node.internal)

proc textBoxKeyboardAction(button: Button) =
  ## Handles keyboard actions for text boxes.
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
          if not textBoxFocus.singleline:
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
            textBoxFocus.pasteText(s)
        of KeyX: # cut
          if ctrl or super:
            setClipboardString(textBoxFocus.cutText())
        of KeyA: # select all
          if ctrl or super:
            textBoxFocus.selectAll()
        of MouseLeft:
          textBoxFocus.mouseAction(
            window.relativeMousePos(textBoxFocus),
            true,
            shift
          )
        of DoubleClick:
          textBoxFocus.selectWord(window.relativeMousePos(textBoxFocus))
        of TripleClick:
          textBoxFocus.selectParagraph(window.relativeMousePos(textBoxFocus))
        of QuadrupleClick:
          textBoxFocus.selectAll()
        else:
          discard

    let oldSingleline = textBoxFocus.singleline
    textBoxFocus.makeTextDirty()

    for cb in eventCbs:
      if cb.kind == OnEdit and cb.glob == textBoxFocus.path:
        thisSelector = textBoxFocus.path
        cb.handler(textBoxFocus.Node())

    # If singleline changed during onEdit, refresh the arrangement
    if textBoxFocus.singleline != oldSingleline:
      textBoxFocus.makeTextDirty()

proc onRune(rune: Rune) =
  ## The user typed a character, needed for unicode entry.
  if textBoxFocus != nil:
    let oldSingleline = textBoxFocus.singleline
    textBoxFocus.typeCharacter(rune)
    requestedFrame = true

    for cb in eventCbs:
      if cb.kind == OnEdit and cb.glob == textBoxFocus.path:
        thisSelector = textBoxFocus.path
        cb.handler(textBoxFocus.Node())

    # If singleline changed during onEdit, refresh the arrangement
    if textBoxFocus.singleline != oldSingleline:
      textBoxFocus.makeTextDirty()

proc onScroll() =
  ## Handles the scroll wheel.
  requestedFrame = true
  if textBoxFocus != nil:
    textBoxFocus.scrollBy(-window.scrollDelta.y * 50)

  let hoverNodes = underMouse(
    thisFrame.internal,
    window.mousePos.vec2 / window.contentScale
  )

  for node in hoverNodes:
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

template onEdit*(body: untyped) =
  ## When a text node is edited.
  editableSelectors.add(thisSelector)
  addCb(
    OnEdit,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onUnfocus*(body: untyped) =
  ## When a text node loses focus.
  addCb(
    OnUnFocus,
    500,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onFocus*(body: untyped) =
  ## When a text node gets focused.
  addCb(
    OnFocus,
    600,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onDragStart*(body: untyped) =
  ## When a node is dragged.
  addCb(
    OnDragStart,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onDrag*(body: untyped) =
  ## When a node is dragged.
  addCb(
    OnDrag,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onDragEnd*(body: untyped) =
  ## When a node is dragged.
  addCb(
    OnDragEnd,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

template onDrop*(body: untyped) =
  ## When a node is dropped.
  addCb(
    OnDrop,
    100,
    thisSelector,
    proc(thisNode {.inject.}: Node) =
      body
  )

proc simulateClick*(glob: string) =
  ## Simulates a mouse click on a node.
  ## Used mainly for writing tests.
  for cb in eventCbs:
    if cb.kind == OnClick:
      thisCb = cb
      thisSelector = thisCb.glob
      if cb.glob == glob:
        for node in findAll(cb.glob):
          cb.handler(node)

proc updateWindowSize() =
  ## Handles window resize.
  requestedFrame = true
  thisFrame.dirty = true

proc onResize() =
  ## Handles window resize.
  updateWindowSize()
  display()

proc takeScreenShot*(): Image =
  ## Takes a screenshot of the current screen.
  ## Used mainly for writing tests.
  readGpuPixelsFromScreen()

proc clearAllEventHandlers*() =
  ## Clears all handlers.
  ## Used mainly for writing tests.
  eventCbs.setLen(0)

proc resizeWindow*(x, y: int) =
  ## Resizes the window to the specified dimensions.
  window.size = ivec2(x.cint, y.cint)

proc onMouseMove() =
  ## Handles mouse movement.
  requestedFrame = true
  if textBoxFocus != nil:
    if window.buttonDown[MouseLeft]:
      textBoxFocus.mouseAction(
        window.relativeMousePos(textBoxFocus.Node()),
        false,
        false
      )

proc swapBuffers() {.measure.} =
  ## Swaps the display buffers.
  window.swapBuffers()

proc underMouse(node: Node, mousePos: Vec2): seq[Node] =
  ## Gets the nodes under the mouse.
  cast[seq[Node]](underMouse(node.internal, mousePos))

proc processEvents() =
  ## Processes window and input events.

  thisCursor = Cursor(kind: ArrowCursor)

  # Get the node list under the mouse.
  hoverNodes = underMouse(
    thisFrame,
    window.mousePos.vec2 / window.contentScale
  )

  # echo "hoverNodes: "
  # for n in hoverNodes:
  #   echo n.path
  # echo "--------------------------------"

  if window.buttonDown[MouseLeft]:
    window.closeIme()

  if window.buttonDown.len > 0 or window.scrollDelta.length != 0:
    redisplay = true

  # Do hovering logic.
  var hovering = false
  if hoverNode != nil:
    for n in hoverNodes:
      if n.internal == hoverNode:
        hovering = true
        break

  if not hovering and hoverNode != nil:
    if hoverNode.hasVariant("State", "Default"):
      hoverNode.setVariant("State", "Default")
    hoverNode = nil

  for n in hoverNodes:
    if n.isInstance:
      var stateDown = false
      if window.buttonDown[MouseLeft]:
        # Is an instance has potential to Down.
        if n.hasVariant("State", "Down"):
          stateDown = true
          hoverNode = n.internal
          n.setVariant("State", "Down")

      # Is an instance has potential to hover.
      if not stateDown and n.hasVariant("State", "Hover"):
        hoverNode = n.internal
        n.setVariant("State", "Hover")

  for cb in eventCbs:
    thisCb = cb

    case cb.kind:
    of OnLoad:
      # Handled in during startFidget phase.
      discard

    of OnShow:
      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame):
          if node.internal.shown == false:
            node.internal.shown = true
            thisSelector = thisCb.glob
            thisCb.handler(node)

    of OnClick:
      if window.buttonPressed[MouseLeft]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and node in hoverNodes:
            thisCb.handler(node)

    of OnRightClick:
      if window.buttonPressed[MouseRight]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and node in hoverNodes:
            thisCb.handler(node)

    of OnClickOutside:
      if window.buttonPressed[MouseLeft]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and
            node notin hoverNodes and
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
          if node.internal.shown == true:
            node.internal.shown = false
            thisCb.handler(node)

    of OnMouseMove:
      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame) and node in hoverNodes:
          thisCb.handler(node)

    of OnFrame:
      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame):
          thisCb.handler(node)

    of OnEdit, OnFocus, OnUnfocus:
      # Handled in text box keyboard action.
      discard

    of OnButtonPress, OnButtonRelease:
      # Handled in the onButtonPress and onButtonRelease callbacks.
      discard

    of OnResize:
      for node in findAll(thisCb.glob):
        if node.inTree(thisFrame):
          if node.path notin onResizeCache or
            onResizeCache[node.path] != node.size.vec2:
              onResizeCache[node.path] = node.size.vec2
              thisCb.handler(node)

    of OnDragStart:
      if dragNode == nil and window.buttonDown[MouseLeft]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame):
            # Second: If mouse moved enough, we set the drag node and call the handler.
            if dragCandidate != nil and dragCandidate == node:
              let dragDistance = window.mousePos.vec2 - dragCandidatePos
              if dragDistance.length > DragThreshold:
                dragNode = dragCandidate
                thisCb.handler(dragNode)
                dragCandidate = Node(nil)
            # First: we get a candidate drag node, but it's not the drag node yet.
            if window.buttonPressed[MouseLeft] and node in hoverNodes:
              dragCandidate = node
              dragCandidatePos = window.mousePos.vec2
      if dragCandidate != nil and not window.buttonDown[MouseLeft]:
        dragCandidate = Node(nil)

    of OnDrag:
      if dragNode != nil:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and node == dragNode:
            thisCb.handler(node)

    of OnDragEnd:
      if dragNode != nil and window.buttonReleased[MouseLeft]:
        for node in findAll(thisCb.glob):
          if node.inTree(thisFrame) and node == dragNode:
            thisCb.handler(node)
            dragNode = Node(nil)

    of OnDrop:
      # TODO: implement.
      discard

  # Check if clicks on editable nodes.
  if window.buttonPressed[MouseLeft]:
    for selector in editableSelectors:
      for node in findAll(selector):
        if node.inTree(thisFrame) and node in hoverNodes:

          if textBoxFocus != nil:
            # Call onUnfocus on any old text box.
            for cb in eventCbs:
              if cb.kind == OnUnfocus and cb.glob == textBoxFocus.path:
                thisSelector = textBoxFocus.path
                cb.handler(textBoxFocus.Node())

          setupTextBox(node)
          textBoxFocus.mouseAction(
            window.relativeMousePos(textBoxFocus),
            true,
            false
          )

          # Call onFocus on the new text box.
          for cb in eventCbs:
            if cb.kind == OnFocus and cb.glob == textBoxFocus.path:
              thisSelector = node.path
              cb.handler(textBoxFocus.Node())

  if textBoxFocus != nil:
    let cursor = textBoxFocus.cursorRect()
    var imePos = textBoxFocus.mat * (cursor.xy + vec2(0, cursor.h) - textBoxFocus.scrollPos)
    imePos = imePos / window.contentScale()
    when compiles(window.imePos):
      window.imePos = imePos.ivec2

  thisSelector = ""
  thisCb = nil
  redisplay = false

  if window.buttonPressed[KeyF2]:
    echo "Current node tree: "
    echo thisFrame.dumpTree()

  when not defined(emscripten):
    if window.buttonPressed[KeyF3]:
      if traceActive == false:
        traceActive = true
        startTrace()
      else:
        traceActive = false
        endTrace()
        dumpMeasures(0, "tmp/trace.json")

    if window.buttonPressed[KeyF4]:
        echo "Writing 'atlas.png'"
        bxy.readAtlas().writeFile("atlas.png")

    if window.buttonPressed[KeyF5]:
      echo "Reloading from web '", currentFigmaUrl, "'"
      figmaFile = loadFigmaUrl(currentFigmaUrl)
      thisFrame = find(entryFramePath)

  if thisCursor.kind != window.cursor.kind:
    # Only set the cursor if it has changed.
    window.cursor = thisCursor

proc `imageUrl=`*(paint: schema.Paint, url: string) =
  when not defined(emscripten) and not defined(nimdoc):
    if url notin fetchResponses:
      # Request the image.
      fetchRequests[url] = startHttpRequest(url)
      fetchRequests[url].onResponse = proc(response: HttpResponse) =
        fetchResponses[url] = response
        paint.imageRef = url
        imageCache[url] = decodeImage(fetchResponses[url].body)
        # Find all nodes that use this image and mark them dirty.
        proc visit(node: Node) =
          for child in node.children:
            visit(child)
          if node.fills.len > 0 and node.fills[0].imageRef == url:
            node.dirty = true
        visit(thisFrame)
        thisFrame.markTreeDirty()
        echo "Image fetched: ", url
      fetchRequests[url].onError = proc(error: string) =
        echo "Error fetching image: ", error
    elif url in fetchResponses:
      # Have the response.
      paint.imageRef = url
    else:
      # Wait for the response.
      discard

proc `image=`*(paint: schema.Paint, image: Image) =
  imageCache[paint.imageRef] = image
  bxy.addImage(paint.imageRef, image)

proc navigateTo*(fullPath: string, smart = false) =
  ## Navigates to a new frame.
  ## Smart will try to preserve all nodes with the same name.
  navigationHistory.add(thisFrame)
  thisFrame = find(fullPath)
  if thisFrame == nil:
    raise newException(FidgetError, &"Frame '{fullPath}' not found")
  thisFrame.markTreeDirty()

proc navigateBack*() =
  ## Navigates back through the navigation history.
  if navigationHistory.len == 0:
    return
  thisFrame = navigationHistory.pop()
  thisFrame.markTreeDirty()

proc absolutePosition*(node: Node): Vec2 =
  ## Gets the absolute position of the node.
  ## TODO: Take transform and rotation into account.
  if node.parent == nil or thisFrame == node:
    return vec2(0, 0)
  return node.parent.absolutePosition + node.position

proc display() {.measure.} =
  ## Called every frame by the main while loop.
  if window.minimized:
    return

  # Update cursor blink timing.
  if textBoxFocus != nil:
    let currentTime = epochTime()
    if cursorBlinkTime + cursorBlinkDuration < currentTime:
      cursorBlinkTime = currentTime
      # Toggle cursor visible state.
      cursorVisible = not cursorVisible
      # Mark text box dirty if cursor is visible.
      textBoxFocus.makeTextDirty()

  keyboard.onFocusNode = Node(nil)
  keyboard.onUnfocusNode = Node(nil)

  window.runeInputEnabled = textBoxFocus != nil

  # thisFrame.dirty = true
  thisFrame.internal.checkDirty()
  if true or thisFrame.dirty:
    drawToScreen(thisFrame.internal)
    swapBuffers()
  else:
    when defined(emscripten):
      # Emscripten needs to return as soon as possible.
      discard
    else:
      # Native needs to sleep to avoid 100% CPU usage.
      sleep(7)

proc tickFidget*() =
  ## Processes events and displays the frame.
  processEvents()
  display()
  pollEvents()

proc setupWindowAndEvents*(
  windowTitle: string,
  windowStyle = DecoratedResizable
) =
  ## Sets up the window and events.
  hybridrender.setupWindow(
    thisFrame.size.ivec2,
    style = windowStyle
  )

  updateWindowSize()

  window.title = windowTitle

  window.onResize = onResize
  window.onScroll = onScroll
  window.onButtonPress = proc(button: Button) =
    # Do text box keyboard action.
    textBoxKeyboardAction(button)
    # Do button press callbacks.
    for cb in eventCbs:
      if cb.kind == OnButtonPress:
        for node in findAll(cb.glob):
          if node.inTree(thisFrame):
            thisButton = button
            thisSelector = cb.glob
            thisCb = cb
            thisCb.handler(node)

  window.onButtonRelease = proc(button: Button) =
    for cb in eventCbs:
      if cb.kind == OnButtonRelease:
        for node in findAll(cb.glob):
          if node.inTree(thisFrame):
            thisButton = button
            thisSelector = cb.glob
            thisCb = cb
            thisCb.handler(node)

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

  # All all onLoad callbacks.
  for cb in eventCbs:
    if cb.kind == OnLoad:
      thisSelector = cb.glob
      cb.handler(find(cb.glob))

proc startFidget*(
  figmaFile: FigmaFile,
  windowTitle: string,
  entryFrame: string,
  windowStyle = DecoratedResizable,
  dataDir = "data"
) =
  ## Starts fidget with a manually created FigmaFile instead of loading from URL.
  ## This allows you to create UIs purely in code without needing Figma files.

  # Set up the global figmaFile
  loader.figmaFile = figmaFile
  echo "Figma data dir: ", dataDir
  common.dataDir = dataDir

  # Set up entry frame
  entryFramePath = entryFrame
  thisFrame = find(entryFramePath)
  if thisFrame == nil:
    raise newException(FidgetError, &"Frame \"{entryFrame}\" not found")

  setupWindowAndEvents(
    windowTitle = windowTitle,
    windowStyle = windowStyle
  )

proc startFidget*(
  figmaUrl: string,
  windowTitle: string,
  entryFrame: string,
  windowStyle = DecoratedResizable,
  dataDir = "data"
) =
  ## Starts fidget with a figma URL.
  common.dataDir = dataDir
  let figmaFile = loadFigmaUrl(figmaUrl)
  startFidget(
    figmaFile = figmaFile,
    windowTitle = windowTitle,
    entryFrame = entryFrame,
    windowStyle = windowStyle,
    dataDir = dataDir
  )

proc isRunning*(): bool =
  ## Checks if fidget is running.
  internal.running

proc closeFidget*() =
  ## Closes the fidget window.
  window.close()
