import vmath

proc foo(a: float, b: float): float =
  var c = 1.0 + a
  return 1.0

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =

  if gl_FragCoord.x > 500.0:
    fragColor = vec4(1, 0, 0, 1)
  else:
    fragColor = vec4(foo(1.0, 2.0), 1, 1, 1)
