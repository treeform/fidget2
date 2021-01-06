import vmath

proc screen(backdrop, source: float32): float32 {.inline.} =
  1 - (1 - backdrop) * (1 - source)

proc hardLight(backdrop, source: float32): float32 {.inline.} =
  if source <= 0.5:
    backdrop * 2 * source
  else:
    screen(backdrop, 2 * source - 1)

proc softLight(backdrop, source: float32): float32 {.inline.} =
  ## Pegtop
  (1 - 2 * source) * backdrop ^ 2 + 2 * source * backdrop

proc Lum(C: Vec4): float32 {.inline.} =
  0.3 * C.x + 0.59 * C.y + 0.11 * C.z

proc ClipColor(C: var Vec4) {.inline.} =
  let
    L = Lum(C)
    n = min([C.x, C.y, C.z])
    x = max([C.x, C.y, C.z])
  if n < 0:
      C = vec4(L) + (((C - vec4(L)) * L) / (L - n))
  if x > 1:
      C = vec4(L) + (((C - vec4(L)) * (1 - L)) / (x - L))

proc SetLum(C: Vec4, l: float32): Vec4 {.inline.} =
  let d = l - Lum(C)
  result.x = C.x + d
  result.y = C.y + d
  result.z = C.z + d
  ClipColor(result)

proc Sat(C: Vec4): float32 {.inline.} =
  max([C.x, C.y, C.z]) - min([C.x, C.y, C.z])

proc SetSat(C: Vec4, s: float32): Vec4 {.inline.} =
  let satC = Sat(C)
  if satC > 0:
    result = (C - vec4(min([C.x, C.y, C.z]))) * s / satC

proc alphaFix(backdrop, source, mixed: Vec4): Vec4 =
  result.w = (source.w + backdrop.w * (1.0 - source.w))
  if result.w == 0:
    return

  let
    t0 = source.w * (1 - backdrop.w)
    t1 = source.w * backdrop.w
    t2 = (1 - source.w) * backdrop.w

  result.x = t0 * source.x + t1 * mixed.x + t2 * backdrop.x
  result.y = t0 * source.y + t1 * mixed.y + t2 * backdrop.y
  result.z = t0 * source.z + t1 * mixed.z + t2 * backdrop.z

  result.x /= result.w
  result.y /= result.w
  result.z /= result.w

proc blendNormalFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = source
  result = alphaFix(backdrop, source, result)

proc blendDarkenFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = min(backdrop.x, source.x)
  result.y = min(backdrop.y, source.y)
  result.z = min(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendMultiplyFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = backdrop.x * source.x
  result.y = backdrop.y * source.y
  result.z = backdrop.z * source.z
  result = alphaFix(backdrop, source, result)

proc blendLinearBurnFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = backdrop.x + source.x - 1
  result.y = backdrop.y + source.y - 1
  result.z = backdrop.z + source.z - 1
  result = alphaFix(backdrop, source, result)

proc blendColorBurnFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  proc blend(backdrop, source: float32): float32 {.inline.} =
    if backdrop == 1:
      1.0
    elif source == 0:
      0.0
    else:
      1.0 - min(1, (1 - backdrop) / source)
  result.x = blend(backdrop.x, source.x)
  result.y = blend(backdrop.y, source.y)
  result.z = blend(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendLightenFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = max(backdrop.x, source.x)
  result.y = max(backdrop.y, source.y)
  result.z = max(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendScreenFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = screen(backdrop.x, source.x)
  result.y = screen(backdrop.y, source.y)
  result.z = screen(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendLinearDodgeFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = backdrop.x + source.x
  result.y = backdrop.y + source.y
  result.z = backdrop.z + source.z
  result = alphaFix(backdrop, source, result)

proc blendColorDodgeFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  proc blend(backdrop, source: float32): float32 {.inline.} =
    if backdrop == 0:
      0.0
    elif source == 1:
      1.0
    else:
      min(1, backdrop / (1 - source))
  result.x = blend(backdrop.x, source.x)
  result.y = blend(backdrop.y, source.y)
  result.z = blend(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendOverlayFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = hardLight(source.x, backdrop.x)
  result.y = hardLight(source.y, backdrop.y)
  result.z = hardLight(source.z, backdrop.z)
  result = alphaFix(backdrop, source, result)

proc blendHardLightFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = hardLight(backdrop.x, source.x)
  result.y = hardLight(backdrop.y, source.y)
  result.z = hardLight(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendSoftLightFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = softLight(backdrop.x, source.x)
  result.y = softLight(backdrop.y, source.y)
  result.z = softLight(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendDifferenceFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = abs(backdrop.x - source.x)
  result.y = abs(backdrop.y - source.y)
  result.z = abs(backdrop.z - source.z)
  result = alphaFix(backdrop, source, result)

proc blendExclusionFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  proc blend(backdrop, source: float32): float32 {.inline.} =
    backdrop + source - 2 * backdrop * source
  result.x = blend(backdrop.x, source.x)
  result.y = blend(backdrop.y, source.y)
  result.z = blend(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendColorFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = SetLum(source, Lum(backdrop))
  result = alphaFix(backdrop, source, result)

proc blendLuminosityFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = SetLum(backdrop, Lum(source))
  result = alphaFix(backdrop, source, result)

proc blendHueFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = SetLum(SetSat(source, Sat(backdrop)), Lum(backdrop))
  result = alphaFix(backdrop, source, result)

proc blendSaturationFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = SetLum(SetSat(backdrop, Sat(source)), Lum(backdrop))
  result = alphaFix(backdrop, source, result)

proc blendMaskFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = backdrop
  result.w = min(backdrop.w, source.w)

proc blendSubtractMaskFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = backdrop
  result.w = backdrop.w * (1 - source.w)

proc blendIntersectMaskFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = backdrop
  result.w = backdrop.w * source.w

proc blendExcludeMaskFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result = backdrop
  result.w = abs(backdrop.w - source.w)

proc blendOverwriteFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  source
