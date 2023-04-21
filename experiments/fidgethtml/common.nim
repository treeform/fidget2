
type
  FidgetError* = object of ValueError ## Raised if an operation fails.

var
  clearFrame*: bool = true
