import chroma, os, fidget2, pixie, strutils, strformat, cligen, times, json

useNodeFile("figma/simple.fig.json")

# for frame in figmaFile.document.children[0].children:

let image = drawCompleteFrame(figmaFile.document.children[0])

#echo pretty %figmaFile

echo image

image.writeFile("tests/simple/simple.png")
