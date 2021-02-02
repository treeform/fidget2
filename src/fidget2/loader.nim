import globs, httpclient, json, jsony, os, schema, strformat, strutils, tables

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

proc loadFigmaFile(fileKey: string): FigmaFile =
  let data = readFile(figmaFilePath(fileKey))
  parseFigmaFile(data)

proc downloadImage(imageRef, url: string) =
  if not fileExists(figmaImagePath(imageRef)):
    if not dirExists("figma/images"):
      createDir("figma/images")
    echo "Downloading ", url
    writeFile(figmaImagePath(imageRef), newHttpClient().getContent(url))

proc downloadImages(fileKey: string) =
  let
    url = "https://api.figma.com/v1/files/" & fileKey & "/images"
    data = newFigmaClient().getContent(url)
    json = parseJson(data)
  for imageRef, url in json["meta"]["images"].pairs:
    downloadImage(imageRef, url.getStr())

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
      response = newFigmaClient().getContent(url)
      json = response.fromJson(JsonNode)
    # Download images before writing the cached Figma file. This way we
    # either do or do not have a complete valid cache if we have a
    # lastModified file. This is important for falling back to cached data
    # in the event the API returns an error.
    downloadImages(fileKey)
    writeFile(figmaFilePath, pretty(json))
    writeFile(lastModifiedPath, json["lastModified"].getStr())
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
  let figmaFileKey = figmaUrl.split("/")[4]
  downloadFigmaFile(figmaFileKey)
  figmaFile = loadFigmaFile(figmaFileKey)
  rebuildGlobTree()
