import strformat

let n = 4
for x in 0 ..< n:
  for y in 0 ..< n:
    echo &"crossCountMat[{x}, {y}] = crossCountMat[{x}, {y}] + pixelCross(a1 + vec2({x},{y})/5, b1 + vec2({x},{y})/5)"
