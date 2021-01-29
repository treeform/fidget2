import globs, httpclient, json, jsony, os, schema, strformat, strutils, tables,
    print

var
  figmaFile*: FigmaFile                ## Main figma file.
  figmaFileKey*: string                ## Users figma key (keep private)
  globTree*: GlobTree[Node]            ## Glob tree for faster find access.
  imageRefToUrl: Table[string, string] ## Mapping of image IDs to URLs.

proc newFigmaClient(): HttpClient =
  result = newHttpClient()
  result.headers["User-Agent"] = "curl/7.58.0"
  result.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey").strip()

proc figmaFilePath(fileKey: string): string =
  "figma/" & fileKey & ".json"

proc lastModifiedFilePath(fileKey: string): string =
  "figma/" & fileKey & ".lastModified"

proc loadFigmaFile(fileKey: string): FigmaFile =
  let data = readFile(figmaFilePath(fileKey))
  parseFigmaFile(data)

proc downloadImageRef*(imageRef: string) =
  ## Make sure imageRef is downloaded.
  if not fileExists("figma/images/" & imageRef & ".png"):
    if imageRef in imageRefToUrl:
      if not dirExists("figma/images"):
        createDir("figma/images")
      let url = imageRefToUrl[imageRef]
      echo "Downloading ", url
      var client = newHttpClient()
      let data = client.getContent(url)
      writeFile("figma/images/" & imageRef & ".png", data)
    else:
      echo "Image not in imageRefToUrl: " & imageRef

proc getImageRefs*(fileKey: string) =
  ## Download all imageRefs.
  ## Note: Might download a bunch of useless junk.
  if not dirExists("figma/images"):
    createDir("figma/images")

  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "*/*"})
  client.headers["User-Agent"] = "curl/7.58.0"
  client.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey")

  let data = client.getContent(
    "https://api.figma.com/v1/files/" & fileKey & "/images")
  writeFile("figma/images/images.json", data)

  let json = parseJson(data)
  for imageRef, url in json["meta"]["images"].pairs:
    imageRefToUrl[imageRef] = url.getStr()

proc downloadFont*(fontPSName: string) =
  ## Try to download the font by name, or ask user to provide it.
  if fileExists("figma/fonts/" & fontPSName & ".ttf"):
    return

  if not dirExists("figma/fonts"):
    createDir("figma/fonts")

  if not fileExists("figma/fonts/fonts.csv"):
    var client = newHttpClient()
    let data = client.getContent(
      "https://raw.githubusercontent.com/treeform/" &
      "freefrontfinder/master/fonts.csv"
    )
    writeFile("figma/fonts/fonts.csv", data)

  for line in readFile("figma/fonts/fonts.csv").split("\n"):
    var line = line.split(",")
    if line[0] == fontPSName:
      let url = line[1]
      echo "Downloading ", url
      try:
        var client = newHttpClient()
        let data = client.getContent(url)
        writeFile("figma/fonts/" & fontPSName & ".ttf", data)
      except HttpRequestError:
        echo getCurrentExceptionMsg()
        echo &"Please download figma/fonts/{fontPSName}.ttf"
      return

  echo &"Please download figma/fonts/{fontPSName}.ttf"

proc downloadFigmaFile(fileKey: string) =
  ## Download and cache the Figma file for this file key.
  let
    figmaFilePath = figmaFilePath(fileKey)
    lastModifiedPath = lastModifiedFilePath(fileKey)

  if fileExists(figmaFilePath) and fileExists(lastModifiedPath):
    # If we have a saved Figma file, is it up to date?
    try:
      let
        url = "https://api.figma.com/v1/files/" & fileKey & "?depth=1"
        data = newFigmaClient().getContent(url)
        currentFile = data.fromJson(FigmaFile)
      if currentFile.lastModified == readFile(lastModifiedPath):
        echo "Using cached Figma file"
        return
    except:
      echo "Failed to validate cached Figma file, downloading latest"

  # Download and save the latest Figma file
  try:
    let
      url = "https://api.figma.com/v1/files/" & fileKey & "?geometry=paths"
      response = newFigmaClient().getContent(url)
      json = response.fromJson(JsonNode)
    writeFile(figmaFilePath, pretty(json))
    writeFile(lastModifiedPath, json["lastModified"].getStr())
    echo "Downloaded latest Figma file"
  except:
    raise newException(
      FidgetError,
      "Error downloading latest Figma file: " & getCurrentExceptionMsg()
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
  let figmaFileKey = figmaUrl.split("/")[4]
  downloadFigmaFile(figmaFileKey)
  getImageRefs(figmaFileKey)
  figmaFile = loadFigmaFile(figmaFileKey)
  rebuildGlobTree()
