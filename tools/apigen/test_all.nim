import osproc


proc run(cmd: string): string =
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode == 1:
    quit(output, exitCode)
  return output

# Compile system lib:

echo run "nim c --app:lib --gc:arc testy.nim"

echo run "python test_testy.py"

echo "Succeeded"
