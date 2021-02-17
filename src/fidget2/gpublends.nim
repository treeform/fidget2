import vmath

proc screenBlend(backdrop, source: float32): float32 {.inline.} =
  1 - (1 - backdrop) * (1 - source)

proc hardLight(backdrop, source: float32): float32 {.inline.} =
  if source <= 0.5:
    return backdrop * 2 * source
  else:
    return screenBlend(backdrop, 2 * source - 1)

proc softLight(backdrop, source: float32): float32 {.inline.} =
  ## Pegtop
  (1 - 2 * source) * backdrop * backdrop + 2 * source * backdrop

proc Lum(C: Vec4): float32 {.inline.} =
  0.3 * C.x + 0.59 * C.y + 0.11 * C.z

proc ClipColor(C: var Vec4) {.inline.} =
  let
    L = Lum(C)
    n = min(min(C.x, C.y), C.z)
    x = max(max(C.x, C.y), C.z)
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
  max(max(C.x, C.y), C.z) - min(min(C.x, C.y), C.z)

proc SetSat(C: Vec4, s: float32): Vec4 {.inline.} =
  let satC = Sat(C)
  if satC > 0:
    return (C - vec4(min(min(C.x, C.y), C.z))) * s / satC

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

proc alphaFix2(backdrop, source: Vec4): Vec4 =
  result.w = (source.w + backdrop.w * (1.0 - source.w))
  if result.w == 0:
    return

  let
    t01 = source.w
    t2 = (1 - source.w) * backdrop.w

  result.x = (t01) * source.x + t2 * backdrop.x
  result.y = (t01) * source.y + t2 * backdrop.y
  result.z = (t01) * source.z + t2 * backdrop.z

  result.x /= result.w
  result.y /= result.w
  result.z /= result.w

proc blendNormalFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  if source.w == 1.0:
    return source
  else:
    return alphaFix2(backdrop, source)

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

proc colorBurnBlend(backdrop, source: float32): float32 {.inline.} =
  if backdrop == 1:
    return 1.0
  elif source == 0:
    return 0.0
  else:
    return 1.0 - min(1, (1 - backdrop) / source)

proc blendColorBurnFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = colorBurnBlend(backdrop.x, source.x)
  result.y = colorBurnBlend(backdrop.y, source.y)
  result.z = colorBurnBlend(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendLightenFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = max(backdrop.x, source.x)
  result.y = max(backdrop.y, source.y)
  result.z = max(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendScreenFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = screenBlend(backdrop.x, source.x)
  result.y = screenBlend(backdrop.y, source.y)
  result.z = screenBlend(backdrop.z, source.z)
  result = alphaFix(backdrop, source, result)

proc blendLinearDodgeFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = backdrop.x + source.x
  result.y = backdrop.y + source.y
  result.z = backdrop.z + source.z
  result = alphaFix(backdrop, source, result)

proc colorDodgeBlend(backdrop, source: float32): float32 {.inline.} =
  if backdrop == 0:
    return 0.0
  elif source == 1:
    return 1.0
  else:
    return min(1, backdrop / (1 - source))

proc blendColorDodgeFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = colorDodgeBlend(backdrop.x, source.x)
  result.y = colorDodgeBlend(backdrop.y, source.y)
  result.z = colorDodgeBlend(backdrop.z, source.z)
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

proc exclusionBlend(backdrop, source: float32): float32 {.inline.} =
  backdrop + source - 2 * backdrop * source

proc blendExclusionFloats*(backdrop, source: Vec4): Vec4 {.inline.} =
  result.x = exclusionBlend(backdrop.x, source.x)
  result.y = exclusionBlend(backdrop.y, source.y)
  result.z = exclusionBlend(backdrop.z, source.z)
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
