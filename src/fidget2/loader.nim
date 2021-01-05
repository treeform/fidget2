import schema, httpclient, json, tables, os, strutils, strformat, globs

var
  figmaFile*: FigmaFile                 ## Main figma file.
  figmaFileKey*: string                 ## Users figma key (keep private)
  globTree*: GlobTree[Node]             ## Glob tree for faster find access.
  imageRefToUrl: Table[string, string]  ## Mapping of image IDs to URLs.

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

proc figmaClient(): HttpClient =
  ## Helper method to get a figma API client.
  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "*/*"})
  client.headers["User-Agent"] = "curl/7.58.0"
  client.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey").strip()
  return client

proc download(figmaFileKey: string) =
  ## Download a figma file based on the file key.
  let jsonPath = &"figma/{figmaFileKey}.json"
  let modifiedPath = &"figma/{figmaFileKey}.lastModified"
  if fileExists(modifiedPath):
    ## Check if we really need to download the whole thing.
    let
      data1 = figmaClient().getContent(
        "https://api.figma.com/v1/files/" & figmaFileKey & "?depth=1")
      figmaModified = parseJson(data1)["lastModified"].getStr()
      haveModified = readFile(modifiedPath)
    if figmaModified == haveModified:
      echo "Using cached"
      return
  let data = figmaClient().getContent(
    "https://api.figma.com/v1/files/" & figmaFileKey & "?geometry=paths")
  let json = parseJson(data)
  writeFile(modifiedPath, json["lastModified"].getStr())
  writeFile(jsonPath, pretty(json))

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
  download(figmaFileKey)
  getImageRefs(figmaFileKey)
  var data = readFile(&"figma/{figmaFileKey}.json")
  figmaFile = parseFigmaFile(data)
  rebuildGlobTree()
