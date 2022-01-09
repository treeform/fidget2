import common, sequtils, pixie, unicode, vmath, bumpy, internal, schema, strutils, nodes, u, windy

#[
It's hard to implement a text. A text box has many complex features one does not think about
because it is so natural. Here is a small list of the most important ones:

* Typing at location of cursor
* Cursor going left and right
* Backspace and delete
* Cursor going up and down must take into account font and line wrap
* Clicking should select a character edge. Closet edge wins.
* Click and drag should select text, selected text will be between text cursor and select cursor
* Any insert when typing or copy pasting and have selected text, it should get removed and then do normal action
* Copy text should set it to system clipboard
* Cut text should copy and remove selected text
* Paste text should paste at current text cursor, if there is selection it needs to be removed
* Clicking before text should select first character
* Clicking at the end of text should select last character
* Click at the end of the end of the line should select character before the new line
* Click at the end of the start of the line should select character first character and not the newline
* Double click should select current word and space (TODO: stops non world characters, TODO: and enter into word selection mode)
* Double click again should select current paragraph
* Double click again should select everything
* TODO: Selecting during world selection mode should select whole words.
* Text area needs to be able to have margins that can be clicked
* There should be a scroll bar and a scroll window
* Scroll window should stay with the text cursor
* Backspace and delete with selected text remove selected text and don't perform their normal action

TODO:
* affinity for left or right of the line.

]#

const
  LF = Rune(10)
  CR = Rune(13)

proc clamp(v, a, b: int): int =
  max(a, min(b, v))

proc getSelection*(arrangement: Arrangement, start, stop: int): seq[Rect] =
  ## Given a layout gives selection from start to stop in glyph positions.
  ## If start == stop returns [].
  if start == stop:
    return
  for i, selectRect in arrangement.selectionRects:
    if i >= start and i < stop:
      if result.len > 0:
        let onSameLine = result[^1].y == selectRect.y and
          result[^1].h == selectRect.h
        let notTooFar = selectRect.x - result[^1].x < result[^1].w * 2
        if onSameLine and notTooFar:
          result[^1].w = selectRect.x - result[^1].x + selectRect.w
          continue
      result.add selectRect

proc pickGlyphAt*(arrangement: Arrangement, pos: Vec2): int =
  ## Given X,Y coordinate, return the GlyphPosition picked.
  ## If direct click not happened finds closest to the right.
  var minG = -1
  var minDist = -1.0
  for i, selectRect in arrangement.selectionRects:
    if selectRect.y <= pos.y and pos.y < selectRect.y + selectRect.h:
      # on same line
      let dist = abs(pos.x - (selectRect.x))
      # closet character
      if minDist < 0 or dist < minDist:
        # min distance here
        minDist = dist
        minG = i
  return minG

proc multilineCheck(node: Node) =
  ## Makes sure there are not new lines in a single line text box.
  if not node.multiline:
    echo "fix non multiline"

proc layout*(node: Node): seq[Rect] =
  return node.arrangement.selectionRects

proc innerHeight*(node: Node): float32 =
  ## Rectangle where selection cursor should be drawn.
  let layout = node.layout()
  if layout.len > 0:
    let lastPos = layout[^1]
    return lastPos.y + lastPos.h
  else:
    return node.font.lineHeight

proc locationRect*(node: Node, loc: int): Rect =
  ## Rectangle where cursor should be drawn.
  let layout = node.layout()
  if layout.len > 0:
    if loc >= layout.len:
      let selectRect = layout[^1]
      # if last char is a new line go to next line.
      if node.characters.u[^1] == LF:
        result.x = 0
        result.y = selectRect.y + node.font.lineHeight
      else:
        result = selectRect
        result.x += selectRect.w
    else:
      let selectRect = layout[loc]
      result = selectRect
  result.w = node.font.cursorWidth
  result.h = max(node.font.size, node.font.lineHeight)

proc cursorRect*(node: Node): Rect =
  ## Rectangle where cursor should be drawn.
  node.locationRect(node.cursor + window.imeCursorIndex)

proc cursorPos*(node: Node): Vec2 =
  ## Position where cursor should be drawn.
  node.cursorRect.xy

proc selectorRect*(node: Node): Rect =
  ## Rectangle where selection cursor should be drawn.
  node.locationRect(node.selector)

proc selectorPos*(node: Node): Vec2 =
  ## Position where selection cursor should be drawn.
  node.cursorRect.xy

proc selectionRegions*(node: Node): seq[Rect] =
  ## Selection regions to draw selection of text.
  let sel = node.selection
  node.arrangement.getSelection(sel.a, sel.b)

proc undoSave(node: Node) =
  ## Save current state of undo.
  node.undoStack.add((node.characters, node.cursor))
  node.redoStack.setLen(0)

proc undo*(node: Node) =
  ## Go back in history.
  if node.undoStack.len > 0:
    node.redoStack.add((node.characters, node.cursor))
    (node.characters, node.cursor) = node.undoStack.pop()
    node.selector = node.cursor

proc redo*(node: Node) =
  ## Go forward in history.
  if node.redoStack.len > 0:
    node.undoStack.add((node.characters, node.cursor))
    (node.characters, node.cursor) = node.redoStack.pop()
    node.selector = node.cursor

proc runesChanged(node: Node) =
  node.makeTextDirty()

proc removedSelection*(node: Node): bool =
  ## Removes selected runes if they are selected.
  ## Returns true if anything was removed.
  let sel = node.selection
  if sel.a != sel.b:
    node.characters.u.delete(sel.a ..< sel.b)
    node.runesChanged()
    node.cursor = sel.a
    node.selector = node.cursor
    node.makeTextDirty()
    return true
  return false

proc removeSelection(node: Node) =
  ## Removes selected runes if they are selected.
  discard node.removedSelection()

proc scrollToCursor*(node: Node) =
  ## Adjust scroll to make sure cursor is in the window.
  if node.scrollable:
    let
      r = node.cursorRect()
    # is pos.y inside the window?
    if r.y < node.scrollPos.y:
      node.scrollPos.y = r.y
      node.makeTextDirty()
    if r.y + r.h > node.scrollPos.y + node.size.y:
      node.scrollPos.y = r.y + r.h - node.size.y
      node.makeTextDirty()
    # is pos.x inside the window?
    if r.x < node.scrollPos.x:
      node.scrollPos.x = r.x
      node.makeTextDirty()
    if r.x + r.w > node.scrollPos.x + node.size.x:
      node.scrollPos.x = r.x + r.w - node.size.x
      node.makeTextDirty()

proc typeCharacter*(node: Node, rune: Rune) =
  ## Add a character to the text box.
  if not node.editable:
    return
  node.removeSelection()
  # don't add new lines in a single line box.
  if not node.multiline and rune == Rune(10):
    return
  node.undoSave()
  if node.cursor == node.characters.u.len:
    node.characters.u.add(rune)
  else:
    node.characters.u.insert(rune, node.cursor)
  node.runesChanged()
  inc node.cursor
  node.selector = node.cursor
  node.scrollToCursor()
  node.makeTextDirty()

proc typeCharacter*(node: Node, letter: char) =
  ## Add a character to the text box.
  node.typeCharacter(Rune(letter))

proc typeCharacters*(node: Node, s: string) =
  ## Add a character to the text box.
  if not node.editable:
    return
  node.removeSelection()
  for rune in runes(s):
    if rune == CR:
      continue
    node.characters.u.insert(rune, node.cursor)
    inc node.cursor
  node.selector = node.cursor
  node.runesChanged()
  node.scrollToCursor()
  node.makeTextDirty()

proc copyText*(node: Node): string =
  ## Returns the text that was copied.
  let sel = node.selection
  if sel.a != sel.b:
    return $node.characters.u[sel.a ..< sel.b]

proc pasteText*(node: Node, s: string) =
  ## Pastes a string.
  if not node.editable:
    return
  node.typeCharacters(s)
  node.savedX = node.cursorPos.x

proc cutText*(node: Node): string =
  ## Returns the text that was cut.
  result = node.copyText()
  if not node.editable or result == "":
    return
  node.removeSelection()
  node.savedX = node.cursorPos.x

proc setCursor*(node: Node, loc: int) =
  node.cursor = clamp(loc, 0, node.characters.u.len + 1)
  node.selector = node.cursor

proc backspace*(node: Node, shift = false) =
  ## Backspace command.
  if node.editable:
    if node.removedSelection(): return
    if node.cursor > 0:
      node.characters.u.delete(node.cursor - 1)
      node.runesChanged()
      dec node.cursor
      node.selector = node.cursor
      node.makeTextDirty()
  node.scrollToCursor()

proc delete*(node: Node, shift = false) =
  ## Delete command.
  if node.editable:
    if node.removedSelection(): return
    if node.cursor < node.characters.u.len:
      node.characters.u.delete(node.cursor)
      node.runesChanged()
      node.makeTextDirty()
  node.scrollToCursor()

proc backspaceWord*(node: Node, shift = false) =
  ## Backspace word command. (Usually ctr + backspace).
  if node.editable:
    if node.removedSelection(): return
    if node.cursor > 0:
      while node.cursor > 0 and
        not node.characters.u[node.cursor - 1].isWhiteSpace():
        node.characters.u.delete(node.cursor - 1)
        dec node.cursor
      node.runesChanged()
      node.selector = node.cursor
      node.makeTextDirty()
  node.scrollToCursor()

proc deleteWord*(node: Node, shift = false) =
  ## Delete word command. (Usually ctr + delete).
  if node.editable:
    if node.removedSelection(): return
    if node.cursor < node.characters.u.len:
      while node.cursor < node.characters.u.len and
        not node.characters.u[node.cursor].isWhiteSpace():
        node.characters.u.delete(node.cursor)
      node.runesChanged()
      node.makeTextDirty()
  node.scrollToCursor()

proc left*(node: Node, shift = false) =
  ## Move cursor left.
  if node.cursor > 0:
    dec node.cursor
    if not shift:
      node.selector = node.cursor
    node.savedX = node.cursorPos.x
  node.scrollToCursor()

proc right*(node: Node, shift = false) =
  ## Move cursor right.
  if node.cursor < node.characters.u.len:
    inc node.cursor
    if not shift:
      node.selector = node.cursor
    node.savedX = node.cursorPos.x
  node.scrollToCursor()

proc down*(node: Node, shift = false) =
  ## Move cursor down.
  let layout = node.layout()
  if layout.len > 0:
    let index = node.arrangement.pickGlyphAt(
      vec2(node.savedX, node.cursorPos.y + node.font.lineHeight * 1.5))
    if index != -1:
      node.cursor = index
      if not shift:
        node.selector = node.cursor
    elif node.cursorPos.y == layout[^1].y:
      # Are we on the last line? Then jump to start location last.
      node.cursor = node.characters.u.len
      if not shift:
        node.selector = node.cursor
  node.scrollToCursor()

proc up*(node: Node, shift = false) =
  ## Move cursor up.
  let layout = node.layout()
  if layout.len > 0:
    let index = node.arrangement.pickGlyphAt(
      vec2(node.savedX, node.cursorPos.y - node.font.lineHeight * 0.5))
    if index != -1:
      node.cursor = index
      if not shift:
        node.selector = node.cursor
    elif node.cursorPos.y == layout[0].y:
      # Are we on the first line? Then jump to start location 0.
      node.cursor = 0
      if not shift:
        node.selector = node.cursor
  node.scrollToCursor()

proc leftWord*(node: Node, shift = false) =
  ## Move cursor left by a word (Usually ctr + left).
  if node.cursor > 0:
    dec node.cursor
  while node.cursor > 0 and
    not node.characters.u[node.cursor - 1].isWhiteSpace():
    dec node.cursor
  if not shift:
    node.selector = node.cursor
  node.savedX = node.cursorPos.x
  node.scrollToCursor()

proc rightWord*(node: Node, shift = false) =
  ## Move cursor right by a word (Usually ctr + right).
  if node.cursor < node.characters.u.len:
    inc node.cursor
  while node.cursor < node.characters.u.len and
    not node.characters.u[node.cursor].isWhiteSpace():
    inc node.cursor
  if not shift:
    node.selector = node.cursor
  node.savedX = node.cursorPos.x
  node.scrollToCursor()

proc startOfLine*(node: Node, shift = false) =
  ## Move cursor left by a word.
  while node.cursor > 0 and
    node.characters.u[node.cursor - 1] != Rune(10):
    dec node.cursor
  if not shift:
    node.selector = node.cursor
  node.savedX = node.cursorPos.x
  node.scrollToCursor()

proc endOfLine*(node: Node, shift = false) =
  ## Move cursor right by a word.
  while node.cursor < node.characters.u.len and
    node.characters.u[node.cursor] != Rune(10):
    inc node.cursor
  if not shift:
    node.selector = node.cursor
  node.savedX = node.cursorPos.x
  node.scrollToCursor()

proc pageUp*(node: Node, shift = false) =
  ## Move cursor up by half a text box height.
  let layout = node.layout()
  if layout.len == 0:
    return
  let
    pos = vec2(node.savedX, node.cursorPos.y - float(node.size.y) * 0.5)
    index = node.arrangement.pickGlyphAt(pos)
  if index != -1:
    node.cursor = index
    if not shift:
      node.selector = node.cursor
  elif pos.y <= layout[0].y:
    # Above the first line? Then jump to start location 0.
    node.cursor = 0
    if not shift:
      node.selector = node.cursor
  node.scrollToCursor()

proc pageDown*(node: Node, shift = false) =
  ## Move cursor down up by half a text box height.
  let layout = node.layout()
  if layout.len == 0:
    return
  let
    pos = vec2(node.savedX, node.cursorPos.y + float(node.size.y) * 0.5)
    index = node.arrangement.pickGlyphAt(pos)
  if index != -1:
    node.cursor = index
    node.scrollToCursor()
    if not shift:
      node.selector = node.cursor
  elif pos.y > layout[^1].y:
    # Bellow the last line? Then jump to start location last.
    node.cursor = node.characters.u.len
    node.scrollToCursor()
    if not shift:
      node.selector = node.cursor

proc mouseAction*(
  node: Node,
  mousePos: Vec2,
  click = true,
  shift = false
) =
  ## Click on this with a mouse.
  # Pick where to place the cursor.
  let index = node.arrangement.pickGlyphAt(mousePos)
  if index != -1:
    node.cursor = index
    node.savedX = mousePos.x
    if node.characters.u[index] != LF:
      # Select to the right or left of the character based on what is closer.
      let selectRect = node.arrangement.selectionRects[index]
      let pickOffset = mousePos - selectRect.xy
      if pickOffset.x > selectRect.w / 2 and
          node.cursor == node.characters.u.len - 1:
        inc node.cursor
  else:
    # If above the text select first character.
    if mousePos.y < 0:
      node.cursor = 0
    # If below text select last character + 1.
    if mousePos.y > node.innerHeight:
      node.cursor = node.characters.u.len
  node.savedX = mousePos.x
  if not shift and click:
    node.selector = node.cursor

  node.scrollToCursor()
  node.makeTextDirty()

proc selectWord*(node: Node, mousePos: Vec2, extraSpace = false) =
  ## Select word under the cursor (double click).
  node.mouseAction(mousePos, click = true)
  while node.cursor > 0 and
    not node.characters.u[node.cursor - 1].isWhiteSpace():
    dec node.cursor
  while node.selector < node.characters.u.len and
    not node.characters.u[node.selector].isWhiteSpace():
    inc node.selector
  if extraSpace:
    # Select extra space to the right if its there.
    if node.selector < node.characters.u.len and
      node.characters.u[node.selector] == Rune(32):
      inc node.selector
  node.makeTextDirty()
  node.dirty = true

proc selectParagraph*(node: Node, mousePos: Vec2) =
  ## Select paragraph under the cursor (triple click).
  node.mouseAction(mousePos, click = true)
  while node.cursor > 0 and
    node.characters.u[node.cursor - 1] != Rune(10):
    dec node.cursor
  while node.selector < node.characters.u.len and
    node.characters.u[node.selector] != Rune(10):
    inc node.selector

proc selectAll*(node: Node) =
  ## Select all text (quad click or ctrl-a).
  node.cursor = 0
  node.selector = node.characters.u.len

proc scrollBy*(node: Node, amount: float) =
  ## Scroll text box with a scroll wheel.
  node.scrollPos.y += amount
  node.makeTextDirty()
