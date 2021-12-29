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


block:
  var s = "잠의 병"
  var r = "잠의 병".toRunes()

  s.u.delete(1 .. 2)
  r.delete(1 .. 2)

  echo s
  echo r

  doAssert s == $r

block:
  var
    s = "잠의 병사들이 작은 창과"
    r = "잠의 병사들이 작은 창과".toRunes()

  doAssert s.u[3 .. 5] == $r[3 .. 5]
