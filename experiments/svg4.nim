import vmath

var c: float32

proc svgMain*(gl_FragCoord: Vec4, fragColor: var Vec4) =
  fragColor = vec4(c, 1, 1, 1)
