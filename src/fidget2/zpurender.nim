import chroma, os, fidget2, pixie, strutils, strformat, times
import math, opengl, staticglfw, times, vmath, glsl, gpushader, print, math
import pixie

import gpurender

proc drawCompleteZPUFrame*(node: Node): pixie.Image =
  let
    width = node.absoluteBoundingBox.w.int
    height = node.absoluteBoundingBox.h.int

  dataBufferSeq.setLen(0)
  mat.identity()

  drawNode(node, 0)

  var image = newImage(width, height)
  dataBuffer.data = dataBufferSeq
  dataBuffer.data.add(0)

  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      var color: Vec4
      svgMain(vec4(x.float32, y.float32, 0, 1), color)
      image.setRgbaUnsafe(x, y, rgba(
        (color.x * 255).uint8,
        (color.y * 255).uint8,
        (color.z * 255).uint8,
        (color.w * 255).uint8
      ))

  return image
