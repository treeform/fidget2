import math, std/monotimes, strformat, strutils, times, print

when defined(nimTypeNames):
  import tables

type
  PerfEntry* = object
    tag: string
    ticks: int64

var
  perfEnabled* = true
  perfPixels*: int
  defaultBuffer*: seq[PerfEntry]

proc getTicks*(): int64 =
  ## Get accurate time.
  getMonoTime().ticks

template perfMark*(
  tagName: string,
  buffer: var seq[PerfEntry] = defaultBuffer
) =
  ## Set a per mark here.
  if perfEnabled:
    buffer.add(PerfEntry(tag: tagName, ticks: getTicks()))

proc `$`*(buffer: seq[PerfEntry]): string =
  ## Turns perf entries into a string.
  if len(buffer) == 0:
    return

  var
    lines: seq[string]
    indent = ""
    prevTicks = buffer[0].ticks

  for i, entry in buffer:
    # Convert from nanoseconds to floating point ms seconds
    let delta = float64(entry.ticks - prevTicks) / 1000000.0
    prevTicks = entry.ticks
    lines.add(&"{delta:>03.6f}ms {indent} {entry.tag}")

  let total = float64(buffer[^1].ticks - buffer[0].ticks) / 1000000.0
  lines.add(&"{total:>03.6f}ms total")
  lines.add(&"{total/perfPixels.float64:>03.12f}ms per pixel ({perfPixels})")

  result = lines.join("\n")

proc perfDump*(buffer: seq[PerfEntry] = defaultBuffer) =
  ## Display the perf buffer.
  if perfEnabled:
    echo $defaultBuffer
    defaultBuffer.setLen(0)

var lastPerfDump = getTicks()
proc perfDumpEverySecond*() =
  ## Dump perf every second.
  if perfEnabled:
    perfDump()
    perfEnabled = false

  if getTicks() > lastPerfDump + 1000000000:
    lastPerfDump = getTicks()
    perfEnabled = true
