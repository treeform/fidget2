import algorithm, bumpy, globs, input, json, loader, math, opengl,
    pixie, schema, sequtils, staticglfw, strformat, tables, typography,
    typography/textboxes, unicode, vmath, times, perf

proc drawHybridFrameToScreen*(thisFrame: Node) =
  glEnable(GL_BLEND)
  #glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glBlendFuncSeparate(
    GL_SRC_ALPHA,
    GL_ONE_MINUS_SRC_ALPHA,
    GL_ONE,
    GL_ONE_MINUS_SRC_ALPHA
  )

  glClearColor(0, 0, 0, 1)
  glClear(GL_COLOR_BUFFER_BIT)


  ctx.beginFrame(windowFrame)
  for x in 0 ..< 28:
    for y in 0 ..< 28:
      ctx.saveTransform()
      ctx.translate(vec2(x.float32*32, y.float32*32))
      ctx.drawImage("test.png", size = vec2(32, 32))
      ctx.restoreTransform()

  ctx.endFrame()
  perfMark "beginFrame/endFrame"
