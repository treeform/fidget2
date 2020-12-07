import vmath



proc foo() =
  var c = 1.0

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =

  foo()

  if gl_FragCoord.x > 500.0:
    fragColor = vec4(1, 0, 0, 1)
  else:
    fragColor = vec4(1, 1, 1, 1)
