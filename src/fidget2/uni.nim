import unicode, strutils

# fancy .u unicode API that mirrors strings

type U = distinct ptr string

proc u*(s: var string): U =
  s.addr.U

proc str(uu: U): var string =
  cast[ptr string](uu)[]

proc add*(s: U, r: Rune) =
  ## Like .add but for unicode runes.
  s.str.add($r)

proc runeOffsetSafe(s: var string, i: int): int =
  result = s.runeOffset(i)
  if result == -1 and i == s.runeLen:
    result = s.len

proc insert*(s: U, r: Rune, i: int) =
  ## Like .insert but for unicode runes.
  s.str.insert($r, s.str.runeOffsetSafe(i))

proc delete*(s: U, i: int) =
  ## Like .delete but for unicode runes.
  let
    loc = s.str.runeOffsetSafe(i)
    size = s.str.runeLenAt(loc)
  s.str.delete(loc ..< loc + size)

proc delete*(s: U, slice: HSlice[int, int]) =
  ## Like .delete but for unicode runes.
  let
    aLoc = s.str.runeOffsetSafe(slice.a)
    bLoc = s.str.runeOffsetSafe(slice.b)
    bSize = s.str.runeLenAt(bLoc)
  s.str.delete(aLoc ..< bLoc + bSize)

proc len*(s: U): int =
  ## Like .len but for unicode runes.
  s.str.runeLen()

proc `[]`*(s: U, i: int): Rune =
  ## Like [i] but for unicode runes.
  s.str.runeAtPos(i)

proc `[]`*(s: U, i: BackwardsIndex): Rune =
  ## Like [^i] but for unicode runes.
  s[s.len - i.int]

proc `[]`*(s: U, slice: HSlice[int, int]): string =
  ## Like [^i] but for unicode runes.
  let
    aLoc = s.str.runeOffsetSafe(slice.a)
    bLoc = s.str.runeOffsetSafe(slice.b + 1)
  s.str[aLoc ..< bLoc]
