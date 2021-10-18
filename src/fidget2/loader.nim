import globs, json, jsony, os, schema, strutils, sets, tables, puppy,
    zippy/ziparchives
var
  archive: ZipArchive
  figmaFile*: FigmaFile                ## Main figma file.

proc readFigmaFile*(path: string): string =
  when defined(fidgetUseData):
    archive.contents[path].contents
  else:
    readFile(path)

proc figmaHeaders(): seq[Header] =
  result["X-FIGMA-TOKEN"] = readFigmaFile(getHomeDir() / ".figmakey").strip()

proc figmaFilePath(fileKey: string): string =
  "data/" & fileKey & ".json"

proc lastModifiedFilePath(fileKey: string): string =
  "data/" & fileKey & ".lastModified"

proc figmaImagePath*(imageRef: string): string =
  "data/images/" & imageRef & ".png"

proc figmaFontPath*(fontPostScriptName: string): string =
  "data/fonts/" & fontPostScriptName & ".ttf"

proc loadFigmaFile(fileKey: string): FigmaFile =
  let data = readFigmaFile(figmaFilePath(fileKey))
  parseFigmaFile(data)

proc downloadImage(imageRef, url: string) =
  if not fileExists(figmaImagePath(imageRef)):
    echo "Downloading ", url
    let data = fetch(url)
    if data == "":
      raise newException(FidgetError, "Downloading " & url & " failed")
    writeFile(figmaImagePath(imageRef), data)

proc downloadImages(fileKey: string, figmaFile: FigmaFile) =
  if not dirExists("data/images"):
    createDir("data/images")

  # Walk the Figma file and find all the images used

  var imagesUsed: HashSet[string]

  proc walk(node: Node) =
    for fill in node.fills:
      if fill.imageRef != "":
        imagesUsed.incl(fill.imageRef)
    for stroke in node.strokes:
      if stroke.imageRef != "":
        imagesUsed.incl(stroke.imageRef)
    for c in node.children:
      walk(c)

  walk(figmaFile.document)

  # Check if we need to download any images

  var needsDownload: bool
  for imageRef in imagesUsed:
    if not fileExists(figmaImagePath(imageRef)):
      needsDownload = true
      break

  if not needsDownload:
    return

  let
    url = "https://api.figma.com/v1/files/" & fileKey & "/images"
    data = fetch(url, headers = figmaHeaders())
  if data == "":
    raise newException(FidgetError, "Downloading Figma file image list failed")
  let json = parseJson(data)
  for imageRef in imagesUsed:
    let url = json["meta"]["images"][imageRef].getStr()
    downloadImage(imageRef, url)

proc downloadFont(fontPostScriptName: string) =
  if not fileExists(figmaFontPath(fontPostScriptName)):
    const baseUrl = "https://github.com/treeform/fidgetfonts/raw/main/fonts/"
    let url = baseUrl & fontPostScriptName & ".ttf"
    echo "Downloading ", url
    let data = fetch(url)
    if data == "":
      raise newException(FidgetError, "Downloading " & url & " failed")
    writeFile(figmaFontPath(fontPostScriptName), data)

proc downloadFonts(figmaFile: FigmaFile) =
  if not dirExists("data/fonts"):
    createDir("data/fonts")

  # Walk the Figma file and find all the fonts used

  var fontsUsed: HashSet[string]

  proc incl(style: TypeStyle) =
    if style.fontPostScriptName != "":
      fontsUsed.incl(style.fontPostScriptName)
    elif style.fontFamily != "":
      fontsUsed.incl(style.fontFamily & "-Regular")

  proc walk(node: Node) =
    if node.characterStyleOverrides.len == 0:
      if node.style != nil:
        incl(node.style)
    else:
      node.styleOverrideTable["0"] = node.style
      for i, styleKey in node.characterStyleOverrides:
        incl(node.styleOverrideTable[$styleKey])
    for c in node.children:
      walk(c)

  walk(figmaFile.document)

  # Check if we need to download any fonts

  var needsDownload: bool
  for fontPostScriptName in fontsUsed:
    if not fileExists(figmaFontPath(fontPostScriptName)):
      needsDownload = true
      break

  if not needsDownload:
    return

  # We need to download one or more fonts

  for fontPostScriptName in fontsUsed:
    downloadFont(fontPostScriptName)

proc downloadFigmaFile(fileKey: string) =
  ## Download and cache the Figma file for this file key.
  let
    figmaFilePath = figmaFilePath(fileKey)
    lastModifiedPath = lastModifiedFilePath(fileKey)

  var useCached: bool
  when defined(fidgetUseCached):
    useCached = true
  else:
    if fileExists(figmaFilePath) and fileExists(lastModifiedPath):
      # If we have a saved Figma file, is it up to date?
      let
        url = "https://api.figma.com/v1/files/" & fileKey & "?depth=1"
        data = fetch(url, headers = figmaHeaders())
      if data == "":
        echo "Failed to get live Figma file: " & getCurrentExceptionMsg()
        useCached = true

      if data != "":
        try:
          let liveFile = parseFigmaFile(data)
          if liveFile.lastModified == readFigmaFile(lastModifiedPath):
            useCached = true
          else:
            echo "Cached Figma file out of date, downloading latest"
        except:
          echo "Unexpected error while validating cached Figma file: " &
            getCurrentExceptionMsg()

  if useCached:
    echo "Using cached Figma file"
    return

  # Download and save the latest Figma file
  let
    url = "https://api.figma.com/v1/files/" & fileKey & "?geometry=paths"
    data = fetch(url, headers = figmaHeaders())
  if data != "":
    let
      liveFile = parseFigmaFile(data)
      json = data.fromJson(JsonNode)
    # Download images and fonts before writing the cached Figma file.
    # This way we either do or do not have a complete valid cache if we have a
    # lastModified file. This is important for falling back to cached data
    # in the event the API returns an error.
    downloadImages(fileKey, liveFile)
    downloadFonts(liveFile)
    writeFile(figmaFilePath, pretty(json))
    writeFile(lastModifiedPath, liveFile.lastModified)
    echo "Downloaded latest Figma file"
  else:
    raise newException(
      FidgetError,
      "Error downloading Figma file: " & getCurrentExceptionMsg()
    )

proc use*(figmaUrl: string) =
  ## Use the figma url as a new figmaFile.
  ## Will download the full file if it needs to.
  ## Or used it from the data.fz archive -d:fidgetUseData
  let
    parts = figmaUrl.split("/")
    figmaFileKey =
      if parts.len == 1:
        parts[0]
      elif parts.len >= 5 and parts[4].len > 0:
        parts[4]
      else:
        raise newException(FidgetError, "Invalid Figma URL: '" & figmaUrl & "'")

  when defined(fidgetUseData):
    echo "Reading archive"
    archive = ZipArchive()
    archive.open("data.fz")
    for k in archive.contents.keys:
      echo k
  else:
    if not dirExists("data"):
      createDir("data")
    downloadFigmaFile(figmaFileKey)
  figmaFile = loadFigmaFile(figmaFileKey)
