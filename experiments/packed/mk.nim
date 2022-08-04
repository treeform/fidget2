
let
  exe = readFile("packed.exe")
  data = readFile("packed.txt")

  newExe = exe & "[packed]" & data


writeFile("packed.data.exe", newExe)
