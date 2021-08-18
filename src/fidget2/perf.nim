## Second way of perf

import tables, print, macros, std/monotimes, strutils

proc getTicks*(): int =
  ## Get accurate time.
  getMonoTime().ticks.int

var
  measureStart: int
  measureStack: seq[string]
  measures: CountTable[string]

proc measurePush*(what: string) =
  ## Used by {.measure.} pragma to push measure section.
  let now = getTicks()
  if measureStack.len > 0:
    let dt = now - measureStart
    let key = measureStack[^1]
    #echo " ".repeat(measureStack.len), "+ ", dt.float / 1000000.0, " to ", key
    measures.inc(key, dt)
  #echo " ".repeat(measureStack.len), "{ ", what
  measureStart = now
  measureStack.add(what)

proc measurePop*() =
  ## Used by {.measure.} pragma to pop measure section.
  let now = getTicks()
  let key = measureStack.pop()
  let dt = now - measureStart
  #echo " ".repeat(measureStack.len + 1), "+ ", dt.float / 1000000.0, " to ", key
  #echo " ".repeat(measureStack.len), "} ", key
  measures.inc(key, dt)
  measureStart = now

macro measure*(fn: untyped) =
  let procName = fn[0].repr
  fn[6].insert 0, quote do:
    measurePush(`procName`)
    defer:
      measurePop()
  return fn

proc dumpMeasures*() =
  ## Dumps the {.measure.} timings.
  echo "Performance:"
  var s: seq[(string, float)]
  measures.sort()
  for k, v in measures:
    s.add((k, v.float / 1000000.0))
  printBarChart(s)
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
