install JS:

```
npm install ffi-napi ref-struct-napi
```


Compile fidget.dll libfidget.dylib

```
nim c --app:lib --gc:arc fidget.nim
```

```
python .use_fidget.py
```

```
node use_fidget.js
```

```
gcc_use_fidget.bat
```
