## Profile Tracing

import
  std/[macros, json, monotimes, strformat, strutils, tables, os],
  jsony

type
  Event = ref object
    ## Chrome Tracing Event.
    name: string
    ph: string      # Event type.
    ts: float       # Timestamp in microseconds.
    pid: int
    tid: int
    cat: string     # Optional, comma-separated
    args: JsonNode # Optional data
    dur: float      # Optional for "X" phase
    id: string      # Optional for linking
    tts: float      # Optional thread timestamp

  Trace = ref object
    ## This must be set to "ns" for Chrome tracing to show properly.
    displayTimeUnit: string = "ns"
    traceEvents: seq[Event]

var
  measureStart: int
  measureStack: seq[string]
  measures: CountTable[string]
  calls: CountTable[string]
  tracingEnabled: bool
  traceStartTick: int
  tracePid: int
  traceTid: int
  traceCategory: string
  traceData: Trace
  traceStartTicks: seq[int]

proc getTicks*(): int =
  ## Gets accurate time.
  when defined(emscripten):
    0
  else:
    getMonoTime().ticks.int

proc startTrace*(pid = 1, tid = 1, category = "measure") =
  ## Starts a chrome://tracing compatible capture and enables tracing.
  tracingEnabled = true
  traceStartTick = getTicks()
  tracePid = pid
  traceTid = tid
  traceCategory = category
  traceStartTicks.setLen(0)
  if traceData.isNil:
    traceData = Trace(traceEvents: @[])
  else:
    traceData.traceEvents.setLen(0)

  echo "Trace started"
  echo " trace events: ", traceData.traceEvents.len

proc endTrace*() =
  ## Ends tracing capture without writing to disk. Use dumpTrace to export.
  tracingEnabled = false

  echo "Trace ended"
  echo " trace events: ", traceData.traceEvents.len

proc setTraceEnabled*(on: bool) =
  ## Sets tracing enabled state without resetting buffers.
  tracingEnabled = on

proc measurePush*(what: string) =
  ## Used by {.measure.} pragma to push a measure section.
  if tracingEnabled:
    let now = getTicks()
    if measureStack.len > 0:
      let dt = now - measureStart
      let key = measureStack[^1]
      measures.inc(key, dt)
    measureStart = now
    measureStack.add(what)
    calls.inc(what)
    traceStartTicks.add(now)

proc measurePop*() =
  ## Used by {.measure.} pragma to pop a measure section.
  if tracingEnabled:
    let now = getTicks()
    let key = measureStack.pop()
    let dt = now - measureStart
    measures.inc(key, dt)
    measureStart = now
    if traceStartTicks.len > 0:
      let startTick = traceStartTicks.pop()
      if not traceData.isNil and tracingEnabled:
        let ev = Event(
          name: key,
          ph: "X",
          ts: (startTick - traceStartTick).float / 1000.0, # microseconds
          pid: tracePid,
          tid: traceTid,
          cat: traceCategory,
          args: newJNull(),
          dur: (now - startTick).float / 1000.0
        )
        traceData.traceEvents.add(ev)

macro measure*(fn: untyped) =
  ## Macro that adds performance measurement to a function.
  let procName = fn[0].repr
  fn[6].insert 0, quote do:
    measurePush(`procName`)
    defer:
      measurePop()
  return fn

proc dumpMeasures*(overTotalMs = 0.0, tracePath = "") =
  ## Dumps performance measurements if total time exceeds threshold.
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
  if tracePath.len > 0 and not traceData.isNil:
    let jsonText = toJson(traceData[])
    writeFile(tracePath, jsonText)
    echo "Trace written to ", tracePath

when isMainModule:

  proc run3() {.measure.} =
    sleep(10)

  proc run2() {.measure.} =
    sleep(10)

  proc run(a: int) {.measure.} =
    run3()
    for i in 0 ..< a:
      run2()
    return

  startTrace()
  for i in 0 ..< 2:
    run(10)

  endTrace()
  dumpMeasures(0.0, "tmp/trace.json")

  # Trace test: nested functions with high precision timings.
  # best tested with -d:release
  proc leaf() {.measure.} =
    discard

  proc inner() {.measure.} =
    for i in 0 ..< 12:
      leaf()

  proc outer() {.measure.} =
    for i in 0 ..< 8:
      inner()

  startTrace()
  outer()
  endTrace()
  dumpMeasures(0.0, "tmp/trace_nested.json")

  echo "done"
