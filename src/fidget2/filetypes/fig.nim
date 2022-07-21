import flatty/binny, chroma, zippy, flatty/hexprint, print, ../common, json,
    pixie, os, strutils

# https://github.com/evanw/kiwi/issues/17
# https://www.photopea.com/

type

  FigFile = ref object
    schema: seq[KiwiObject]
    changes: JsonNode
    thumbnail: Image
    blobs: seq[string]

  KiwiKind = enum
    KiwiEnum
    KiwiStructure
    KiwiMessage

  KiwiField = ref object
    name: string
    num: int
    isArray: bool
    tag: int

  KiwiObject = ref object
    kind: KiwiKind
    name: string
    fields: seq[KiwiField]

proc readPackedInt(data: string, i: var int): int =
  ## Reads packed integer up to 4 bytes
  ## [c ddddddd] [c ddddddd] [c ddddddd] [c ddddddd]
  var offset: int
  while i < data.len:
    # read 1 continuation bit and data 7 bits
    let value = data[i].ord
    inc i
    # add 7 data bits to result
    result = result or (value and 127) shl offset
    offset += 7
    # Are we over size?
    if offset >= 35:
      break
    # is there a continuation bit?
    if (value and 0b1000_0000) == 0:
      break

proc readZString(data: string, i: var int): string =
  ## Reads null terminated string.
  var j = i
  while data[j] != '\0':
    inc j
  var str = data[i ..< j]
  i += str.len
  inc i
  return str

proc readKiwiSchema(data: string): seq[KiwiObject] =
  ## Reads Kiwi Schema data structure
  var i = 0

  let version = readPackedInt(data, i)
  if version != 199:
    raise newException(FidgetError, "Unknown KiwiSchema version")

  while i < data.len:

    let
      kiwi = KiwiObject()
      name = readZString(data, i)
      tag = readPackedInt(data, i)
      num = readPackedInt(data, i)

    kiwi.name = name
    case tag:
    of 0: kiwi.kind = KiwiEnum
    of 1: kiwi.kind = KiwiStructure
    of 2: kiwi.kind = KiwiMessage
    else: raise newException(FidgetError, "Invalid Kiwi tag")

    for enumValues in 0 ..< num:
      var kiwiField = KiwiField()
      kiwiField.name = readZString(data, i)
      kiwiField.tag = readPackedInt(data, i)
      kiwiField.isArray = readPackedInt(data, i) == 1
      kiwiField.num = readPackedInt(data, i)
      kiwi.fields.add(kiwiField)

    result.add(kiwi)

proc getFieldByNum(obj: KiwiObject, num: int): KiwiField =
  ## Returns a field by number.
  for field in obj.fields:
    if field.num == num:
      return field

proc getObjByName(schema: seq[KiwiObject], name: string): KiwiObject =
  ## Returns object by name
  for idx, obj in schema:
    if obj.name == name:
      return obj

proc readKiwi(
  data: string,
  i: var int,
  schema: seq[KiwiObject],
  what: KiwiObject,
  depth: int
): JsonNode =
  ## Reads Kiwi data structure and returns it as JsonNode

  result = newJObject()

  let numFields = if what.kind == KiwiMessage: int.high else: what.fields.len
  var fieldCount = 1

  while fieldCount <= numFields:
    var fieldNum = fieldCount

    # Messages can have any number of fields in any order.
    if what.kind == KiwiMessage:
      fieldNum = readPackedInt(data, i)
      if fieldNum == 0:
          break

    let
      field = what.getFieldByNum(fieldNum)
      tag = field.tag
      arrayLen = if field.isArray: readPackedInt(data, i) else: 1
      outArray: JsonNode = newJArray() # of size arrayLen

    for q in 0 ..< arrayLen:
      var outObj: JsonNode

      if (tag and 1) == 1:
        if tag == 1: # boolean
          outObj = %(data[i].ord == 1)
          inc i
        elif tag == 3: # byte
          outObj = %data[i].ord
          inc i
        elif tag == 5: # signed int
          var value = readPackedInt(data, i)
          var p = if (value and 1) != 0:
              not (value shr 1)
            else:
              value shr 1
          outObj = %p
        elif tag == 7: # unsigned int
          outObj = %readPackedInt(data, i)
        elif tag == 9: # float32
          if data[i].ord == 0:
            outObj = %0
            inc i
          else:
            # very strange float32 format
            var buffer = "    "
            let value = data.readUint32(i)
            buffer.writeUint32(0, (value shl 23) or (value shr 9))
            outObj = %buffer.readFloat32(0)
            i += 4
        elif tag == 11: # string
          outObj = %readZString(data, i)
        else:
          raise newException(FidgetError, "Invalid Kiwi tag value")

      else:
        var z = schema[tag shr 1]

        if z.kind == KiwiEnum:
          var j = data[i].ord
          inc i
          if j > 127:
            raise newException(FidgetError, "Invalid Kiwi enum value")
          outObj = %(z.fields[j].name)

        else:
          outObj = readKiwi(data, i, schema, z, depth + 1)

      outArray.add(outObj)

    if field.isArray:
      result[field.name] = outArray
    else:
      result[field.name] = outArray[0]
    inc fieldCount

proc readVectorNetwork(blob: string): string =
  var
    i = 0
    G = 3

  var
    B = blob.readUint32(0).int
    z = blob.readUint32(4).int
    j = blob.readUint32(8).int
  i += 12

  print B, z, j

  var
    Z: seq[Vec2]
    V: seq[array[7, float32]]
    t: seq[seq[seq[int]]]
    oo = G + B * 3
    o = oo + z * 7

  print oo, o

  for q in 0 ..< B:
    var
      U = G + q * 3
      F = vec2(blob.readFloat32((U + 1)*4), blob.readFloat32((U + 2)*4))
    Z.add(F)

  print Z

  for q in 0 ..< z:
    var N = oo + q * 7
    V.add([
      blob.readInt32((N + 0)*4).float32,
      blob.readInt32((N + 1)*4).float32,
      blob.readFloat32((N + 2)*4),
      blob.readFloat32((N + 3)*4),
      blob.readInt32((N + 4)*4).float32,
      blob.readFloat32((N + 5)*4),
      blob.readFloat32((N + 6)*4)
    ])
  print V

  echo j
  for q in 0 ..< j:
    var m = blob.readInt32((o + 1)*4)
    o += 2
    for i in 0 ..< m:
      var v = blob.readInt32(o*4).int
      inc o
      for ac in 0 ..< v:
        t[q][i][ac] = blob.readInt32((o + ac)*4)
      o += v
  print t

  if o * 4 != blob.len:
    quit("not all of the blob was read")

  if j == 0:
    var dA = -1
    for q in 0 ..< z:
      if dA == -1:
        discard
      else:
        var gq = -1;
        for i in q ..< z:
          if V[i][4].int == dA:
            gq = i
        for i in q ..< z:
          if V[i][1].int == dA:
            gq = i

        if gq != -1:
          var eD = 0
          var g = V[gq]
          V[gq] = V[q]
          V[q] = g
          if g[1].int != dA:
            eD = g[1].int
            g[1] = g[4]
            g[4] = eD.float32
            eD = g[2].int
            g[2] = g[5]
            g[5] = eD.float32
            eD = g[3].int
            g[3] = g[6]
            g[6] = eD.float32

      dA = V[q][4].int

    t.add @[newSeq[int]()]

    for q in 0 ..< z:
      t[0][0].add(q)

  print t

  var e6: seq[string]
  for c7 in 0 ..< t.len:
    for ff in 0 ..< t[c7].len:
      var j5 = t[c7][ff]
      var gJ = 0;
      if j5.len > 1:
        var dV = V[j5[0]]
        var fZ = V[j5[1]]
        gJ = if dV[4] == fZ[1]:
            1
          else:
            0

      for q in 0 ..< j5.len:
        var bE = V[j5[q]]
        var cI = 1
        var gpz = 4
        if gJ == 0:
          cI = 4;
          gpz = 1

        var hN = Z[bE[cI].int]
        var bR = Z[bE[gpz].int]
        if q == 0:
          e6.add("M")
          e6.add($hN.x)
          e6.add($hN.y)

        e6.add("C")
        e6.add($(hN.x + bE[cI + 1]))
        e6.add($(hN.y + bE[cI + 2]))
        e6.add($(bR.x + bE[gpz + 1]))
        e6.add($(bR.y + bE[gpz + 2]))
        e6.add($bR.x)
        e6.add($bR.y)

  return e6.join(" ")

proc printKiwiSchema(schema: seq[KiwiObject]) =
  # Prints kiwi schema looking up all of the types.
  for obj in schema:
    echo obj.name, " ", obj.kind
    for field in obj.fields:
      if obj.kind == KiwiEnum:
        echo "    ", field.num, " ", field.name
      else:
        let tag = field.tag
        var tagName =
          if (tag and 1) == 1:
            if tag == 1: "bool"
            elif tag == 3: "byte"
            elif tag == 5: "int32"
            elif tag == 7: "uint32"
            elif tag == 9: "float32"
            elif tag == 11: "cstring"
            else: "?" & $tag
          else:
            schema[tag shr 1].name
        if field.isArray:
          tagName.add "[]"
        echo "    ", field.num, " ", field.name, " ", tagName

proc readFig(filePath: string): FigFile =
  result = FigFile()

  var
    data = readFile(filePath)
    i = 0

  doAssert data.readStr(i, 8) == "fig-kiwi"
  i += 8

  let version = data.readUInt32(i)
  i += 4
  doAssert version == 15

  var chunks: seq[string]

  while i < data.len:
    let size = data.readUInt32(i).int
    i += 4

    let chunk = data[i ..< i + size]
    i += size

    if chunk.readUint8(0) == 137 and chunk.readUint8(1) == 80:
      # uncompressed
      chunks.add(chunk)
    else:
      # compressed
      let chunk2 = uncompress(chunk, dfDeflate)
      chunks.add(chunk2)

  # 1st chunk is kiwi schema
  result.schema = readKiwiSchema(chunks[0])

  # 2nd chunk is the cumulative set of changes
  block:
    var i = 0
    result.changes = readKiwi(
      chunks[1],
      i,
      result.schema,
      result.schema.getObjByName("Message"),
      0
    )

    let blobs = result.changes["blobs"]
    result.changes.delete("blobs")

    for blob in blobs:
      var data = ""
      for value in blob["bytes"]:
        data.add value.getInt().char
      result.blobs.add(data)

  # 3rd chunk is thumbnail
  result.thumbnail = decodeImage(chunks[2])

proc writeDir(fig: FigFile, dir: string) =
  if not dirExists(dir):
    createDir(dir)
  if not dirExists(dir / "blobs"):
    createDir(dir / "blobs")
  writeFile(dir / "schema.json", pretty(%fig.schema))
  writeFile(dir / "changes.json", pretty(%fig.changes))
  fig.thumbnail.writeFile(dir / "thumbnail.png")
  for i, blob in fig.blobs:
    try:
      discard decodeImageDimensions(blob)
      writeFile(dir / "blobs/blob" & $i & ".png", blob)
    except PixieError:
      writeFile(dir / "blobs/blob" & $i & ".blob", blob)

block:
  let fig = readFig("tests/fileformats/triangle.fig")
  fig.writeDir("tmp/fileformats/triangle")
  echo readVectorNetwork(fig.blobs[1])

# block:
#   let fig = readFig("tests/fileformats/simple.fig")
#   fig.writeDir("tmp/fileformats/simple")

# block:
#   let fig = readFig("tests/fileformats/more.fig")
#   fig.writeDir("tmp/fileformats/more")

# block:
#   let fig = readFig("tests/fileformats/Fidget Test Masters.fig")
#   fig.writeDir("tmp/fileformats/Fidget Test Masters")
