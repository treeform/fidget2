require 'ffi'

class Vector2 < FFI::Struct
  layout \
    x: :float,
    y: :float
end

class Address < FFI::Struct
  layout \
    state: :int64,
    zip: :int64
end

class Contact < FFI::Struct
  layout \
    first_name: :int64,
    last_name: :int64,
    address: object
  state
  zip
.by_value
end

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

class Boz < FFI::Struct
  layout ref: :uint64

  def name
    return DLL.fidget_boz_get_name(self)
  end
  def name=(v)
    DLL.fidget_boz_set_name(self, v)
  end

  def fod
    return DLL.fidget_boz_get_fod(self)
  end
  def fod=(v)
    DLL.fidget_boz_set_fod(self, v)
  end
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

PaintKind = :uint64
PK_SOLID = 0
PK_IMAGE = 1
PK_IMAGE_TILED = 2
PK_GRADIENT_LINEAR = 3
PK_GRADIENT_RADIAL = 4
PK_GRADIENT_ANGULAR = 5

BlendMode = :uint64
BM_NORMAL = 0
BM_DARKEN = 1
BM_MULTIPLY = 2
BM_COLOR_BURN = 3
BM_LIGHTEN = 4
BM_SCREEN = 5
BM_COLOR_DODGE = 6
BM_OVERLAY = 7
BM_SOFT_LIGHT = 8
BM_HARD_LIGHT = 9
BM_DIFFERENCE = 10
BM_EXCLUSION = 11
BM_HUE = 12
BM_SATURATION = 13
BM_COLOR = 14
BM_LUMINOSITY = 15
BM_MASK = 16
BM_OVERWRITE = 17
BM_SUBTRACT_MASK = 18
BM_EXCLUDE_MASK = 19

class ColorRGBX < FFI::Struct
  layout \
    r: :uint8,
    g: :uint8,
    b: :uint8,
    a: :uint8
end

class ColorStop2 < FFI::Struct
  layout \
    color: object
  r
  g
  b
  a
.by_value,
    position: :float
end

class Paint2 < FFI::Struct
  layout \
    kind: enum
  pkSolid, pkImage, pkImageTiled, pkGradientLinear, pkGradientRadial,
  pkGradientAngular,
    blend_mode: enum
  bmNormal, bmDarken, bmMultiply, bmColorBurn, bmLighten, bmScreen,
  bmColorDodge, bmOverlay, bmSoftLight, bmHardLight, bmDifference, bmExclusion,
  bmHue, bmSaturation, bmColor, bmLuminosity, bmMask, bmOverwrite,
  bmSubtractMask, bmExcludeMask,
    gradient_stops: ColorStop2.by_value
end

class Typeface2 < FFI::Struct
  layout ref: :uint64

  def file_path
    return DLL.fidget_typeface2_get_file_path(self)
  end
  def file_path=(v)
    DLL.fidget_typeface2_set_file_path(self, v)
  end
end

class Font2 < FFI::Struct
  layout ref: :uint64

  def typeface
    return DLL.fidget_font2_get_typeface(self)
  end
  def typeface=(v)
    DLL.fidget_font2_set_typeface(self, v)
  end

  def size
    return DLL.fidget_font2_get_size(self)
  end
  def size=(v)
    DLL.fidget_font2_set_size(self, v)
  end

  def line_height
    return DLL.fidget_font2_get_line_height(self)
  end
  def line_height=(v)
    DLL.fidget_font2_set_line_height(self, v)
  end

  def paint
    return DLL.fidget_font2_get_paint(self)
  end
  def paint=(v)
    DLL.fidget_font2_set_paint(self, v)
  end

  def text_case
    return DLL.fidget_font2_get_text_case(self)
  end
  def text_case=(v)
    DLL.fidget_font2_set_text_case(self, v)
  end

  def underline
    return DLL.fidget_font2_get_underline(self)
  end
  def underline=(v)
    DLL.fidget_font2_set_underline(self, v)
  end

  def strikethrough
    return DLL.fidget_font2_get_strikethrough(self)
  end
  def strikethrough=(v)
    DLL.fidget_font2_set_strikethrough(self, v)
  end

  def no_kerning_adjustments
    return DLL.fidget_font2_get_no_kerning_adjustments(self)
  end
  def no_kerning_adjustments=(v)
    DLL.fidget_font2_set_no_kerning_adjustments(self, v)
  end
end


module DLL
  extend FFI::Library
  ffi_lib '/Users/me/p/fidget2/tools/apigen/libfidget.dylib'
  callback :fidget_cb, [], :void

  attach_function :fidget_input_code, [ :int64, :int64, :int64, :int64 ], :bool
  attach_function :fidget_test_numbers, [ :int8, :uint8, :int16, :uint16, :int32, :uint32, :int64, :uint64, :int64, :uint64, :float, :double, :double ], :bool
  attach_function :fidget_call_me_maybe, [ :string ], :void
  attach_function :fidget_flight_club_rule, [ :int64 ], :string
  attach_function :fidget_cat_str, [ :string, :string, :string, :string, :string ], :string
  attach_function :fidget_give_vec, [ Vector2.by_value ], :void
  attach_function :fidget_take_vec, [  ], Vector2.by_value
  attach_function :fidget_take_contact, [  ], Contact.by_value
  attach_function :fidget_fod_get_name, [Fod.by_value], :string
  attach_function :fidget_fod_set_name, [Fod.by_value, :string], :void
  attach_function :fidget_fod_get_count, [Fod.by_value], :int64
  attach_function :fidget_fod_set_count, [Fod.by_value, :int64], :void
  attach_function :fidget_take_fod, [  ], Fod.by_value
  attach_function :fidget_boz_get_name, [Boz.by_value], :string
  attach_function :fidget_boz_set_name, [Boz.by_value, :string], :void
  attach_function :fidget_boz_get_fod, [Boz.by_value], Fod.by_value
  attach_function :fidget_boz_set_fod, [Boz.by_value, Fod.by_value], :void
  attach_function :fidget_take_boz, [  ], Boz.by_value
  attach_function :fidget_repeat_enum, [ AlignSomething ], AlignSomething
  attach_function :fidget_call_me_back, [ :fidget_cb ], :void
  attach_function :fidget_take_seq, [  ], uint64.by_value
  attach_function :fidget_give_seq, [ uint64.by_value ], :void
  attach_function :fidget_give_seq_of_vector2, [ Vector2.by_value ], :void
  attach_function :fidget_take_seq_of_vector2, [  ], Vector2.by_value
  attach_function :fidget_give_seq_of_boz, [ Boz.by_value ], :void
  attach_function :fidget_take_seq_of_boz, [  ], Boz.by_value
  attach_function :fidget_typeface2_get_file_path, [Typeface2.by_value], :string
  attach_function :fidget_typeface2_set_file_path, [Typeface2.by_value, :string], :void
  attach_function :fidget_font2_get_typeface, [Font2.by_value], Typeface2.by_value
  attach_function :fidget_font2_set_typeface, [Font2.by_value, Typeface2.by_value], :void
  attach_function :fidget_font2_get_size, [Font2.by_value], :float
  attach_function :fidget_font2_set_size, [Font2.by_value, :float], :void
  attach_function :fidget_font2_get_line_height, [Font2.by_value], :float
  attach_function :fidget_font2_set_line_height, [Font2.by_value, :float], :void
  attach_function :fidget_font2_get_paint, [Font2.by_value], object
  kind
  blendMode
  gradientStops
.by_value
  attach_function :fidget_font2_set_paint, [Font2.by_value, object
  kind
  blendMode
  gradientStops
.by_value], :void
  attach_function :fidget_font2_get_text_case, [Font2.by_value], enum
  tcNormal, tcUpper, tcLower, tcTitle
  attach_function :fidget_font2_set_text_case, [Font2.by_value, enum
  tcNormal, tcUpper, tcLower, tcTitle], :void
  attach_function :fidget_font2_get_underline, [Font2.by_value], :bool
  attach_function :fidget_font2_set_underline, [Font2.by_value, :bool], :void
  attach_function :fidget_font2_get_strikethrough, [Font2.by_value], :bool
  attach_function :fidget_font2_set_strikethrough, [Font2.by_value, :bool], :void
  attach_function :fidget_font2_get_no_kerning_adjustments, [Font2.by_value], :bool
  attach_function :fidget_font2_set_no_kerning_adjustments, [Font2.by_value, :bool], :void
  attach_function :fidget_read_font2, [ :string ], Font2.by_value
end
def input_code(a, b, c, d)
  return DLL.fidget_input_code(a, b, c, d)
end

def test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)
  return DLL.fidget_test_numbers(a, b, c, d, e, f, g, h, i, j, k, l, m)
end

def call_me_maybe(phone)
  return DLL.fidget_call_me_maybe(phone)
end

def flight_club_rule(n)
  return DLL.fidget_flight_club_rule(n)
end

def cat_str(a, b, c, d, e)
  return DLL.fidget_cat_str(a, b, c, d, e)
end

def give_vec(v)
  return DLL.fidget_give_vec(v)
end

def take_vec()
  return DLL.fidget_take_vec()
end

def take_contact()
  return DLL.fidget_take_contact()
end

def take_fod()
  return DLL.fidget_take_fod()
end

def take_boz()
  return DLL.fidget_take_boz()
end

def repeat_enum(e)
  return DLL.fidget_repeat_enum(e)
end

def call_me_back(cb)
  return DLL.fidget_call_me_back(cb)
end

def take_seq()
  return DLL.fidget_take_seq()
end

def give_seq(s)
  return DLL.fidget_give_seq(s)
end

def give_seq_of_vector2(s)
  return DLL.fidget_give_seq_of_vector2(s)
end

def take_seq_of_vector2()
  return DLL.fidget_take_seq_of_vector2()
end

def give_seq_of_boz(s)
  return DLL.fidget_give_seq_of_boz(s)
end

def take_seq_of_boz()
  return DLL.fidget_take_seq_of_boz()
end

def read_font2(font_path)
  return DLL.fidget_read_font2(font_path)
end

