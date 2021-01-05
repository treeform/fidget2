import fidget2/glsl, strutils, vmath

var buffer = ""
proc echo(msg: varargs[string, `$`]) =
  var msg = msg.join("")
  buffer.add(msg)
  buffer.add("\n")

block:
  echo "--------------------------------------------------"
  proc redFrag(fragColor: var Color) =
    fragColor = color(1.0, 0.0, 0.0, 1.0)
  echo toShader(redFrag)
  var c: Color
  redFrag(c)
  echo c

block:
  echo "--------------------------------------------------"

  proc basicFrag(
    uv: Vec2,
    color: Color,
    normal: Vec3,
    texelOffset: int,
    fragColor: var Color
  ) =
    let
      a = vec3(0.5, 0.5, 0.5)
      b = vec3(0.5, 0.5, 0.5)
    var
      c = vec3(1, 1, 1)
      d = vec3(1, 0, 1)
      e = vec3(1, 0, 0)
    fragColor.rgb = color.rgb * dot(normal, normalize(vec3(1.0, 1.0, 1.0)))
    fragColor.a = 1.0

  echo toShader(basicFrag)

  var c: Color
  basicFrag(vec2(0, 0), color(1, 0, 0, 1), vec3(0, 1, 0), 1, c)
  echo c

block:
  echo "--------------------------------------------------"

  proc floatTest() =
    var f: float32 = 1

  echo toShader(floatTest)

block:
  echo "--------------------------------------------------"

  var dataBuffer: Uniform[SamplerBuffer]

  proc samplerBufferTest(fragColor: var Color) =
    if texelFetch(dataBuffer, 0).x == 0:
      fragColor = color(1, 0, 0, 1)
    else:
      fragColor = color(0, 0, 0, 1)

  echo toShader(samplerBufferTest)

  dataBuffer.data = @[0.float32]
  var c: Color
  samplerBufferTest(c)
  echo c

  dataBuffer.data = @[1.float32]
  samplerBufferTest(c)
  echo c

writeFile("tests/test_glsl.txt", buffer)

if buffer != readFile("tests/test_glsl.master.txt"):
  quit("Outputs did not match!")
