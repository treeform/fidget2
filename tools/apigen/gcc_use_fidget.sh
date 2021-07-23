rm use_fidget
gcc -c -o use_fidget.o use_fidget.c
gcc -o use_fidget -s use_fidget.o -L. -lfidget -Wl,-rpath='$ORIGIN'
./use_fidget
