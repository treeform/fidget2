## Second way of perf

import tables, print, macros, std/monotimes, strutils, strformat

proc getTicks*(): int =
  ## Get accurate time.
  when defined(emscripten):
    0
  else:
    getMonoTime().ticks.int

var
  measureStart: int
  measureStack: seq[string]
  measures: CountTable[string]
  calls: CountTable[string]

proc measurePush*(what: string) =
  ## Used by {.measure.} pragma to push measure section.
  let now = getTicks()
  if measureStack.len > 0:
    let dt = now - measureStart
    let key = measureStack[^1]
    measures.inc(key, dt)
  measureStart = now
  measureStack.add(what)
  calls.inc(what)

proc measurePop*() =
  ## Used by {.measure.} pragma to pop measure section.
  let now = getTicks()
  let key = measureStack.pop()
  let dt = now - measureStart
  measures.inc(key, dt)
  measureStart = now

macro measure*(fn: untyped) =
  let procName = fn[0].repr
  fn[6].insert 0, quote do:
    measurePush(`procName`)
    defer:
      measurePop()
  return fn

proc dumpMeasures*(overTotalMs = 0.0) =
  measures.sort()
  var
    maxK = 0
    maxV = 0
    totalV = 0
  for k, v in measures:
    maxK = max(maxK, k.len)
    maxV = max(maxV, v)
    totalV += v

  if totalV.float32/1000000 > overTotalMs:
    let n = "name ".alignLeft(maxK, padding = '.')
    echo &"{n}.. self time    self %  # calls  relative amount"
    for k, v in measures:
      let
        n = k.alignLeft(maxK)
        bar = "#".repeat((v/maxV*40).int)
        numCalls = calls[k]
      echo &"{n} {v/1000000:>9.3f}ms{v/totalV*100:>9.3f}%{numCalls:>9} {bar}"

  calls.clear()
  measures.clear()

when isMainModule:
  import os

  proc run3() {.measure.} =
    sleep(10)

  proc run2() {.measure.} =
    sleep(10)

  proc run(a: int) {.measure.} =
    run3()
    for i in 0 ..< a:
      run2()
    return

  for i in 0 ..< 2:
    run(10)

  dumpMeasures()

  echo "done"
