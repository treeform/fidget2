#version 300 es
precision mediump float;

in vec4 gl_FragCoord;
out vec4 fragColor;

uniform samplerBuffer dataBuffer;

void main() {
  float first = texelFetch(dataBuffer, 0);
  if (gl_FragCoord.x > first) {
    fragColor = vec4(0.0, 1.0, 1.0, 1.0);
  } else {
    fragColor = vec4(1.0, 1.0, 1.0, 1.0);
  }
}
