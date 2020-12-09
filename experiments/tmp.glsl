#version 300 es
precision mediump float;

uniform samplerBuffer dataBuffer;
// name: svgMain

in vec4 gl_FragCoord;
out vec4 fragColor;

void main() {
  float first = texelFetch(dataBuffer, 0);
  if ((first) < (gl_FragCoord.x)) {
        fragColor = vec4(0.0, 1.0, 1.0, 1.0);
  } else {
        fragColor = vec4(1.0, 1.0, 1.0, 1.0);
  };
}