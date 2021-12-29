import fidget2/uni, unicode, sequtils

block:
  var s = "잠의 병사들이 작은 창과"
  var r = "잠의 병사들이 작은 창과".toRunes()

  s.u.delete(0)
  r.delete(0)

  doAssert s == $r

block:
  var s = "잠의 병"
  var r = "잠의 병".toRunes()

  s.u.delete(1)
  r.delete(1)

  doAssert s == $r

  doAssertRaises(RangeDefect):
    s.u.delete(3)

block:
  var s = "잠의 병"
  var r = "잠의 병".toRunes()

  s.u.delete(1 .. 2)
  r.delete(1 .. 2)

  doAssert s == $r

block:
  var s = "잠의 병"
  var r = "잠의 병".toRunes()

  s.u.delete(0 .. 3)
  r.delete(0 .. 3)

  doAssert s == $r

block:
  var
    s = "잠의 병사들이 작은 창과"
    r = "잠의 병사들이 작은 창과".toRunes()

  doAssert s.u[3 .. 5] == $r[3 .. 5]

  doAssertRaises(RangeDefect):
    discard s.u[10 .. 13]

block:
  let rune = "창".toRunes()[0]

  var s = "잠의병사"

  s.u.insert(rune, 0)

  doAssert s == "창잠의병사"

  s.u.insert(rune, 1)

  doAssert s == "창창잠의병사"

  doAssertRaises(RangeDefect):
    s.u.insert(rune, 7)

  s.u.insert(rune, 6)

  doAssert s == "창창잠의병사창"
