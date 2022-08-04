import os, strutils

echo getAppFilename()

let
  magic = "[packed]"
  data = readFile(getAppFilename())
  dataStart = data.rfind(magic)

echo "from packed string: ", dataStart
if dataStart != -1:
  echo data[dataStart + magic.len .. ^1]
else:
  echo "packed not found"
