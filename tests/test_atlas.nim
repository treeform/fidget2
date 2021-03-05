import chroma, fidget2/atlas, pixie

var mainAtlas = newCpuAtlas(1024, 1)

for i in 1 .. 136:
  var image = newImage(i, i)
  image.fill(rgba(255, 0, 0, 255))
  mainAtlas.put($i, image)

mainAtlas.image.writeFile("tests/test_atlas.png")
