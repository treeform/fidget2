nim c --app:lib --gc:arc apigen.nim
@REM python .\tools\apigen\use_fidget.py

gcc -c -o use_fidget.o use_fidget.c
gcc -o use_fidget.exe -s use_fidget.o -L. -lfidget
use_fidget.exe
