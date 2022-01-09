import windy

type
  FidgetError* = object of ValueError ## Raised if an operation fails.

var
  window*: Window
