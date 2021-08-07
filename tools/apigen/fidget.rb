require 'ffi'

class Fod < FFI::Struct
  layout ref: :uint64

  def name
    return DLL.fidget_fod_get_name(self)
  end
  def name=(v)
    DLL.fidget_fod_set_name(self, v)
  end

  def count
    return DLL.fidget_fod_get_count(self)
  end
  def count=(v)
    DLL.fidget_fod_set_count(self, v)
  end
end

class Vector2 < FFI::Struct
  layout \
    x: :float,
    y: :float
end

AlignSomething = :uint64
AS_DEFAULT = 0
AS_TOP = 1
AS_BOTTOM = 2
AS_RIGHT = 3
AS_LEFT = 4

TextCase = :uint64
TC_NORMAL = 0
TC_UPPER = 1
TC_LOWER = 2
TC_TITLE = 3

class Typeface2 < FFI::Struct
  layout ref: :uint64
end

class Font2 < FFI::Struct
  layout \
    typeface: Typeface2.by_value,
    size: :float,
    line_height: :float,
    text_case: enum
  tcNormal, tcUpper, tcLower, tcTitle,
    underline: :bool,
    strikethrough: :bool,
    no_kerning_adjustments: :bool
end

class Node < FFI::Struct
  layout ref: :uint64

  def name
    return DLL.fidget_node_get_name(self)
  end
  def name=(v)
    DLL.fidget_node_set_name(self, v)
  end

  def characters
    return DLL.fidget_node_get_characters(self)
  end
  def characters=(v)
    DLL.fidget_node_set_characters(self, v)
  end

  def dirty
    return DLL.fidget_node_get_dirty(self)
  end
  def dirty=(v)
    DLL.fidget_node_set_dirty(self, v)
  end
end

EventCbKind = :uint64
E_ON_CLICK = 0
E_ON_FRAME = 1
E_ON_EDIT = 2
E_ON_DISPLAY = 3
E_ON_FOCUS = 4
E_ON_UNFOCUS = 5


module DLL
  extend FFI::Library
  ffi_lib '/Users/me/p/fidget2/tools/apigen/libfidget.dylib'
  callback :fidget_cb, [], :void

  attach_function :fidget_call_me_maybe, [ :string ], :void
  attach_function :fidget_flight_club_rule, [ :int64 ], :string
  attach_function :fidget_input_code, [ :int64, :int64, :int64, :int64 ], :bool
  attach_function :fidget_test_numbers, [ :int8, :uint8, :int16, :uint16, :int32, :uint32, :int64, :uint64, :int64, :uint64, :float, :double, :double ], :bool
  attach_function :fidget_fod_get_name, [Fod.by_value], :string
  attach_function :fidget_fod_set_name, [Fod.by_value, :string], :void
  attach_function :fidget_fod_get_count, [Fod.by_value], :int64
  attach_function :fidget_fod_set_count, [Fod.by_value, :int64], :void
  attach_function :fidget_create_fod, [  ], Fod.by_value
  attach_function :fidget_give_vec, [ Vector2.by_value ], :void
  attach_function :fidget_take_vec, [  ], Vector2.by_value
  attach_function :fidget_repeat_enum, [ AlignSomething ], AlignSomething
  attach_function :fidget_call_me_back, [ :fidget_cb ], :void
  attach_function :fidget_take_seq, [ uint64.by_value ], :void
  attach_function :fidget_return_seq, [  ], uint64.by_value
  attach_function :fidget_read_font2, [ :string ], Font2.by_value
  attach_function :fidget_on_click_global, [ :fidget_cb ], :void
  attach_function :fidget_node_get_name, [Node.by_value], :string
  attach_function :fidget_node_set_name, [Node.by_value, :string], :void
  attach_function :fidget_node_get_characters, [Node.by_value], :string
  attach_function :fidget_node_set_characters, [Node.by_value, :string], :void
  attach_function :fidget_node_get_dirty, [Node.by_value], :bool
  attach_function :fidget_node_set_dirty, [Node.by_value, :bool], :void
  attach_function :fidget_find_node, [ :string ], Node.by_value
  attach_function :fidget_add_cb, [ EventCbKind, :int64, :string, :fidget_cb ], :void
  attach_function :fidget_start_fidget, [ :string, :string, :string, :bool ], :void
end
def call_me_maybe(phone)
  return DLL.fidget_call_me_maybe(phone)
end

def flight_club_rule(n)
  return DLL.fidget_flight_club_rule(n)
end

def input_code(a, b, c, d)
  return DLL.fidget_input_code(a, b, c, d)
end

def test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)
  return DLL.fidget_test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)
end

def create_fod()
  return DLL.fidget_create_fod()
end

def give_vec(v)
  return DLL.fidget_give_vec(v)
end

def take_vec()
  return DLL.fidget_take_vec()
end

def repeat_enum(e)
  return DLL.fidget_repeat_enum(e)
end

def call_me_back(cb)
  return DLL.fidget_call_me_back(cb)
end

def take_seq(s)
  return DLL.fidget_take_seq(s)
end

def return_seq()
  return DLL.fidget_return_seq()
end

def read_font2(font_path)
  return DLL.fidget_read_font2(font_path)
end

def on_click_global(a)
  return DLL.fidget_on_click_global(a)
end

def find_node(glob)
  return DLL.fidget_find_node(glob)
end

def add_cb(kind, priority, glob, handler)
  return DLL.fidget_add_cb(kind, priority, glob, handler)
end

def start_fidget(figma_url, window_title, entry_frame, resizable)
  return DLL.fidget_start_fidget(figma_url, window_title, entry_frame, resizable)
end

