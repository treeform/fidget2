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
