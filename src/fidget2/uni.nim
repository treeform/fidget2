import unicode, strutils

# fancy .u unicode API that mirrors strings

type U = distinct ptr string

proc u*(s: var string): U =
  s.addr.U

proc str(u: U): var string =
  cast[ptr string](u)[]

proc add*(u: U, r: Rune) =
  ## Like .add but for unicode runes.
  u.str.add($r)

proc len*(u: U): int =
  ## Like .len but for unicode runes.
  u.str.runeLen()

proc `[]`*(u: U, i: int): Rune =
  ## Like [i] but for unicode runes.
  u.str.runeAtPos(i)

proc `[]`*(u: U, i: BackwardsIndex): Rune =
  ## Like [^i] but for unicode runes.
  u[u.len - i.int]

proc `[]`*(u: U, slice: HSlice[int, int]): string =
  ## Like [i ..< j] but for unicode runes.
  let
    aStart = u.str.runeOffset(slice.a)
    bStart = u.str.runeOffset(slice.b)
    bLen = u.str.runeLenAt(bStart)
  u.str[aStart ..< bStart + bLen]

proc runeOffsetSafe(s: var string, i: int): int =
  result = s.runeOffset(i)
  if result == -1 and i == s.runeLen:
    result = s.len

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
    loc = u.str.runeOffsetSafe(i)
    size = u.str.runeLenAt(loc)
  u.str.delete(loc ..< loc + size)

proc delete*(u: U, slice: HSlice[int, int]) =
  ## Like .delete but for unicode runes.
  let
    aLoc = u.str.runeOffsetSafe(slice.a)
    bLoc = u.str.runeOffsetSafe(slice.b)
    bSize = u.str.runeLenAt(bLoc)
  u.str.delete(aLoc ..< bLoc + bSize)
