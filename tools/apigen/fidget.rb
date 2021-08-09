require 'ffi'

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
  dll_path = ""
  if RUBY_PLATFORM == "x64-mingw32"
    dll_path = Dir.getwd + "/fidget.dll"
  elsif RUBY_PLATFORM == "arm64-darwin20"
    dll_path = Dir.getwd + "/libfidget.dylib"
  else
    dll_path = Dir.getwd + "/libfidget.so"
  end
  ffi_lib dll_path
  callback :fidget_cb, [], :void

  attach_function :fidget_on_click_global, [:fidget_cb], :void
  attach_function :fidget_node_get_name, [Node.by_value], :string
  attach_function :fidget_node_set_name, [Node.by_value, :string], :void
  attach_function :fidget_node_get_characters, [Node.by_value], :string
  attach_function :fidget_node_set_characters, [Node.by_value, :string], :void
  attach_function :fidget_node_get_dirty, [Node.by_value], :bool
  attach_function :fidget_node_set_dirty, [Node.by_value, :bool], :void
  attach_function :fidget_find_node, [:string], Node.by_value
  attach_function :fidget_add_cb, [EventCbKind, :int64, :string, :fidget_cb], :void
  attach_function :fidget_start_fidget, [:string, :string, :string, :bool], :void
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

