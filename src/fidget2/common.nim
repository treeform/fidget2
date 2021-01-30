import vmath, chroma, schema, staticglfw, typography, typography/textboxes,
    tables, print

export print

## Common vars shared across renderers.
var
  # Window stuff.
  viewportSize*: Vec2
  window*: Window
  offscreen* = false
  windowResizable*: bool
  vSync*: bool
  framePos*: Vec2

  # Text edit.
  textBox*: TextBox
  textBoxFocus*: Node
  typefaceCache*: Table[string, Typeface]
