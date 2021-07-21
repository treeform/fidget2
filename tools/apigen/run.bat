@REM nim c --app:lib --gc:arc fidget.nim
@REM python .\tools\apigen\use_fidget.py

rm use_fidget.exe
gcc -c -o use_fidget.o use_fidget.c
gcc -o use_fidget.exe -s use_fidget.o -L. -lfidget
use_fidget.exe
