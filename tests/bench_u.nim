import benchy, random, fidget2/u, unicode

randomize()

block:
  var longAscii: string
  for i in 0 ..< 1_000_000:
    longAscii.add(rand(0 .. 127).char)

  timeIt "ascii rune len":
    discard longAscii.runeLen

  timeIt "ascii u len":
    discard longAscii.u.len

  timeIt "ascii to runes":
    discard longAscii.toRunes()

block:
  const mostlyAscii = "that is neat añyóng 작은 wow 창과 cool มฑ げゴ ok".toRunes()

  var longMostlyAsciiUtf8: string
  for i in 0 ..< 1_000_000:
    longMostlyAsciiUtf8.add(mostlyAscii[rand(mostlyAscii.high)])

  timeIt "mostly-ascii utf8 rune len":
    discard longMostlyAsciiUtf8.runeLen

  timeIt "mostly-ascii utf8 u len":
    discard longMostlyAsciiUtf8.u.len

  timeIt "mostly-ascii utf8 to runes":
    discard longMostlyAsciiUtf8.toRunes()

block:
  const minimallyAscii = "añyóng 잠의병사들이작은창과 ฑมณโฑ イー曖ざげゴ".toRunes()

  var longMinimallyAsciiUtf8: string
  for i in 0 ..< 1_000_000:
    longMinimallyAsciiUtf8.add(minimallyAscii[rand(minimallyAscii.high)])

  timeIt "minimally-ascii utf8 rune len":
    discard longMinimallyAsciiUtf8.runeLen

  timeIt "minimally-ascii utf8 u len":
    discard longMinimallyAsciiUtf8.u.len

  timeIt "minimally-ascii utf8 to runes":
    discard longMinimallyAsciiUtf8.toRunes()
