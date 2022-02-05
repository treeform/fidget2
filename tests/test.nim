## Put your tests here.

import fidget2

doAssertRaises(FidgetError):
  find "":
    discard

doAssertRaises(FidgetError):
  find "/":
    find "/more":
      discard

find "/":
  discard

find "/":
  find "more":
    discard
