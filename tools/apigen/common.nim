import strutils

const allowedFields* = @["name", "count", "characters", "dirty"]

proc toSnakeCase*(s: string): string =
  ## Converts NimTypes to nim_types.
  if s.len == 0:
    return
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[result.len-1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
      result.add c.toLowerAscii()
    else:
      prevCap = false
      result.add c

proc toCapCase*(s: string): string =
  ## Converts NimTypes to NIM_TYPES.
  if s.len == 0:
    return
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[result.len-1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
    else:
      prevCap = false
    result.add c.toUpperAscii()

proc toVarCase*(s: string): string =
  ## Lower the first char, NimType -> nimType.
  result = s
  if s.len > 0:
    result[0] = s[0].toLowerAscii()

proc rm*(s: var string, what: string) =
  ## Will remove the last thing from a string, usually used for ", "
  if s.len >= what.len and s[^what.len..^1] == what:
    s.setLen(s.len - what.len)
