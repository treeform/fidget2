import globs, httpclient, json, jsony, os, schema, strutils, sets

var
  figmaFile*: FigmaFile                ## Main figma file.
  globTree*: GlobTree[Node]            ## Glob tree for faster find access.

proc newFigmaClient(): HttpClient =
  result = newHttpClient()
  result.headers["User-Agent"] = "curl/7.58.0"
  result.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey").strip()

proc figmaFilePath(fileKey: string): string =
  "figma/" & fileKey & ".json"

proc lastModifiedFilePath(fileKey: string): string =
  "figma/" & fileKey & ".lastModified"

proc figmaImagePath*(imageRef: string): string =
  "figma/images/" & imageRef & ".png"

proc figmaFontPath*(fontPostScriptName: string): string =
  "figma/fonts/" & fontPostScriptName & ".ttf"

proc loadFigmaFile(fileKey: string): FigmaFile =
  let data = readFile(figmaFilePath(fileKey))
  parseFigmaFile(data)

proc downloadImage(imageRef, url: string) =
  if not fileExists(figmaImagePath(imageRef)):
    echo "Downloading ", url
    writeFile(figmaImagePath(imageRef), newHttpClient().getContent(url))

proc downloadImages(fileKey: string, figmaFile: FigmaFile) =
  if not dirExists("figma/images"):
    createDir("figma/images")

  # Walk the Figma file and find all the images used

  var imagesUsed: HashSet[string]

  proc walk(node: Node) =
    for fill in node.fills:
      if fill.imageRef.len > 0:
        imagesUsed.incl(fill.imageRef)
    for stroke in node.strokes:
      if stroke.imageRef.len > 0:
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
    data = newFigmaClient().getContent(url)
    json = parseJson(data)
  for imageRef in imagesUsed:
    let url = json["meta"]["images"][imageRef].getStr()
    downloadImage(imageRef, url)

proc downloadFont(fontPostScriptName, url: string) =
  if not fileExists(figmaFontPath(fontPostScriptName)):
    echo "Downloading ", url
    writeFile(
      figmaFontPath(fontPostScriptName),
      newHttpClient().getContent(url)
    )

proc downloadFonts(figmaFile: FigmaFile) =
  if not dirExists("figma/fonts"):
    createDir("figma/fonts")

  # Walk the Figma file and find all the fonts used

  var fontsUsed: HashSet[string]

  proc walk(node: Node) =
    if node.style != nil and node.style.fontPostScriptName.len > 0:
      fontsUsed.incl(node.style.fontPostScriptName)
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

  let
    csv = newHttpClient().getContent(
      "https://raw.githubusercontent.com/treeform/" &
      "freefrontfinder/master/fonts.csv"
    )
    lines = csv.split("\n")

  for fontPostScriptName in fontsUsed:
    let fontFilePath = figmaFontPath(fontPostScriptName)

    var found: bool
    for line in lines:
      var parts = line.split(",")
      if parts[0] == fontPostScriptName:
        found = true
        downloadFont(fontPostScriptName, parts[1])
        break

    if not found:
      echo "Missing font ", fontFilePath

proc downloadFigmaFile(fileKey: string) =
  ## Download and cache the Figma file for this file key.
  let
    figmaFilePath = figmaFilePath(fileKey)
    lastModifiedPath = lastModifiedFilePath(fileKey)

  var useCached: bool
  if fileExists(figmaFilePath) and fileExists(lastModifiedPath):
    # If we have a saved Figma file, is it up to date?
    var data: string
    try:
      let url = "https://api.figma.com/v1/files/" & fileKey & "?depth=1"
      data = newFigmaClient().getContent(url)
    except:
      echo "Failed to get live Figma file: " & getCurrentExceptionMsg()
      useCached = true

    if data.len > 0:
      try:
        let liveFile = parseFigmaFile(data)
        if liveFile.lastModified == readFile(lastModifiedPath):
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
  try:
    let
      url = "https://api.figma.com/v1/files/" & fileKey & "?geometry=paths"
      data = newFigmaClient().getContent(url)
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
  except:
    raise newException(
      FidgetError,
      "Error updating to latest Figma file: " & getCurrentExceptionMsg()
    )

proc rebuildGlobTree() =
  ## Nodes have changed rebuild the glob tree.
  globTree = GlobTree[Node]()
  proc walkNodes(path: string, node: Node) =
    globTree.add(path, node)
    for c in node.children:
      walkNodes(path & "/" & c.name, c)
  for c in figmaFile.document.children:
    # Skip pages
    for c2 in c.children:
      walkNodes(c2.name, c2)

proc use*(figmaUrl: string) =
  ## Use the figma url as a new figmaFile.
  ## Will download the full file if it needs to.
  if not dirExists("figma"):
    createDir("figma")
  let
    parts = figmaUrl.split("/")
    figmaFileKey =
      if parts.len == 1:
        parts[0]
      elif parts.len >= 5 and parts[4].len > 0:
        parts[4]
      else:
        raise newException(FidgetError, "Invalid Figma URL: '" & figmaUrl & "'")
  downloadFigmaFile(figmaFileKey)
  figmaFile = loadFigmaFile(figmaFileKey)
  rebuildGlobTree()
