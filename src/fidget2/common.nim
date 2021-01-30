import vmath, chroma, schema, staticglfw, typography, typography/textboxes,
    tables

## Common vars shared across renderers.
var
  # Window stuff.
  viewPortWidth*: int
  viewPortHeight*: int
  window*: Window
  offscreen* = false
  windowResizable*: bool
  vSync*: bool
  framePos*: Vec2

  # Text edit.
  textBox*: TextBox
  textBoxFocus*: Node
  typefaceCache*: Table[string, Typeface]
