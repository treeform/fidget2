import std/[os, strformat, strutils, osproc, terminal]
import cligen

const params = "-d:release " # -d:figmaLive

const examples = [
  "examples/the7gui/temperature.nim",
  "examples/the7gui/counter.nim",
  "examples/the7gui/booking.nim",
  "examples/the7gui/cells.nim",
  "examples/the7gui/circles.nim",
  "examples/the7gui/crud.nim",
  # "examples/the7gui/timer.nim",
  "examples/calculator/calculator.nim",
  "examples/panels/panels.nim",
  "examples/writer/writer.nim",
  "examples/colorpicker/colorpicker.nim", # just UI no functionality
  "examples/dragon/dragon.nim",
  "examples/gradaui/gradaui.nim",
  "examples/hackernews/hackernews.nim",
  "examples/inspector/inspector.nim",
  "examples/layouts/layouts.nim",
  "examples/nimforum/nimforum.nim",
  "examples/scifi/scifi.nim",
  "examples/uberlight/uberlight.nim",
  # "examples/purecode/purecode.nim", needs inode fixing
  # "examples/bubbleats/bubbleats.nim", # needs fixing
]

proc cmd(command: string) =
  # Run command and exit if it fails
  echo "> ", command
  let exitCode = execCmd(command)
  if exitCode != 0:
    quit &"FAILED: {command} (exit code {exitCode})"

let mainDir = getCurrentDir()

for name in examples:
  # Handle running from repo root or package root
  var dir = name.splitFile().dir
  var file = name.splitFile().name

  echo "cd ", dir
  setCurrentDir(dir)
  cmd(&"nim r {params} {file}")
  setCurrentDir(mainDir)
