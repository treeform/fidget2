import
  std/[strutils, unicode]

## Fancy .u UTF-8 API that mirrors strings.

when defined(amd64) and not defined(fidgetNoSimd):
  import nimsimd/sse2

type U = distinct ptr string

proc u*(s: var string): U {.inline.} =
  ## Creates a unicode view for the string.
  s.addr.U

proc str(u: U): var string {.inline.} =
  ## Gets the string from a unicode view.
  cast[ptr string](u)[]

proc add*(u: U, r: Rune) =
  ## Like .add but for unicode runes.
  u.str.add($r)

when defined(release):
  {.push checks: off.}

proc len*(u: U): int =
  ## Like .len but for unicode runes.
  let byteLen = u.str.len

  var i: int
  when defined(amd64) and not defined(fidgetNoSimd):
    for _ in 0 ..< byteLen div 16:
      let vec = mm_loadu_si128(u.str[i].addr)
      if mm_movemask_epi8(vec) == 0:
        # Fast path for ascii
        i += 16
        result += 16
      else:
        # There are some non-ascii runes present
        break

  while i < byteLen:
    if u.str[i].uint <= 127:
      inc i
    elif u.str[i].uint shr 5 == 0b110:
      i += 2
    elif u.str[i].uint shr 4 == 0b1110:
      i += 3
    elif u.str[i].uint shr 3 == 0b11110:
      i += 4
    else:
      inc i
    inc result

  # If the string is not valid utf-8, it is possible to return a len that is
  # longer than the string's byte length.

when defined(release):
  {.pop.}

proc `[]`*(u: U, i: int): Rune =
  ## Like `[i]` but for unicode runes.
  u.str.runeAtPos(i)

proc `[]`*(u: U, i: BackwardsIndex): Rune =
  ## Like `[^i]` but for unicode runes.
  u[u.len - i.int] # u.len is very expensive here, should instead work backwards

proc `[]`*(u: U, slice: HSlice[int, int]): string =
  ## Like `[i ..< j]` but for unicode runes.
  let
    aStart = u.str.runeOffset(slice.a)
    bStart = u.str.runeOffset(slice.b)
    bLen = u.str.runeLenAt(bStart)
  u.str[aStart ..< bStart + bLen]

proc insert*(u: U, r: Rune, i: int) =
  ## Like .insert but for unicode runes.
  let runeOffset =
    if i == u.len:
      u.str.len
    else:
      u.str.runeOffset(i)
  u.str.insert($r, runeOffset)

proc delete*(u: U, i: int) =
  ## Like .delete but for unicode runes.
  let
    runeOffset = u.str.runeOffset(i)
    runeLen = u.str.runeLenAt(runeOffset)
  u.str.delete(runeOffset ..< runeOffset + runeLen)

proc delete*(u: U, slice: HSlice[int, int]) =
  ## Like .delete but for unicode runes.
  let
    aStart = u.str.runeOffset(slice.a)
    bStart = u.str.runeOffset(slice.b)
    bLen = u.str.runeLenAt(bStart)
  u.str.delete(aStart ..< bStart + bLen)
