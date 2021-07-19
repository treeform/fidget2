yproc fidget_call_me_maybe(phone: cstring) {.cdecl, exportc, dynlib.} =
  callMeMaybe($phone)

proc fidget_flight_club_rule(n: int): cstring {.cdecl, exportc, dynlib.} =
  flightClubRule(n).cstring

proc fidget_input_code(a: int, b: int, c: int, d: int): bool {.cdecl, exportc, dynlib.} =
  inputCode(a, b, c, d)

proc fidget_node_get_name(node_id: int): cstring {.cdecl, exportc, dynlib.} =
  nodeGetName(node_id).cstring

proc fidget_start_fidget(figma_url: cstring, window_title: cstring, entry_frame: cstring, resizable: bool) {.cdecl, exportc, dynlib.} =
  startFidget($figma_url, $window_title, $entry_frame, resizable)
