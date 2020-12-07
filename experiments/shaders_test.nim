import shadercompiler, vmath

block:
  echo "--------------------------------------------------"
  proc redFrag(fragColor: var Color) =
    # Output red shader.
    fragColor = color(1.0, 0.0, 0.0, 1.0)

  echo toShader(redFrag)
  var c: Color
  redFrag(c)
  echo c

block:
  echo "--------------------------------------------------"
  # in vec2 uv
  # in vec4 color
  # in vec3 normal
  # out vec4 fragColor
  # void main() {
  #   fragColor.rgb = color.rgb * dot(normal, normalize(vec3(1,1,1)))
  #   fragColor.a += 1.0
  #   fragColor.rgb += normal * 0.1
  # }
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
    # const black = vec3(0, 0, 0)
    fragColor.rgb = color.rgb * dot(normal, normalize(vec3(1.0, 1.0, 1.0)))
    fragColor.a = 1.0 #color(1.0, 0.0, 0.0, 1.0)

  echo toShader(basicFrag)

  var c: Color
  basicFrag(vec2(0, 0), color(1, 0, 0, 1), vec3(0, 1, 0), 1, c)
  echo c
