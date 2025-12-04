import
  std/[os],
  zippy,
  common, schema

# Loader is responsible for loading the Figma file.
# It also downloads images and fonts and manages the cache.

var figmaFile*: FigmaFile             ## Main Figma file.

proc figmaFilePath(fileKey: string): string =
  ## Gets the Figma file path.
  dataDir / "fidget" / fileKey & ".json.z"

proc loadFigmaFile(fileKey: string): FigmaFile =
  ## Loads the Figma file.
  let data = uncompress(readFile(figmaFilePath(fileKey)))
  parseFigmaFile(data)

proc lastModifiedFilePath(fileKey: string): string =
  ## Gets the last-modified file path.
  dataDir / "fidget" / fileKey & ".lastModified"

proc figmaImagePath*(imageRef: string): string =
  ## Gets the Figma image path.
  dataDir / "fidget" / "images" / imageRef & ".png"

proc figmaFontPath*(fontPostScriptName: string): string =
  ## Gets the Figma font path.
  dataDir / "fidget" / "fonts" / fontPostScriptName & ".ttf"

proc userFontPath*(fontPostScriptName: string): string =
  ## Gets the user font path.
  dataDir / "fonts" / fontPostScriptName & ".ttf"

when defined(figmaLive):

  import
    std/[json, strutils, sets, tables],
    jsony,
    puppy

  proc figmaHeaders(): HttpHeaders =
    ## Gets the Figma headers.
    result["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmatoken").strip()

  proc downloadImage(imageRef, url: string) =
    ## Downloads an image.
    let imagePath = figmaImagePath(imageRef)
    if not fileExists(imagePath):
      echo "Downloading '", url, "'"
      let
        request = newRequest(url)
        response = fetch(request)
      if response.code != 200:
        raise newException(FidgetError, "Downloading '" & url & "' failed")
      writeFile(imagePath, response.body)

  proc downloadImages(fileKey: string, figmaFile: FigmaFile) =
    ## Downloads all the images used in the Figma file.
    if not dirExists(dataDir / "fidget" / "images"):
      createDir(dataDir / "fidget" / "images")

    # Walk the Figma file and find all the images used
    var imagesUsed: HashSet[string]
    proc walk(node: INode) =
      for fill in node.fills:
        if fill.imageRef != "":
          imagesUsed.incl(fill.imageRef)
      for stroke in node.strokes:
        if stroke.imageRef != "":
          imagesUsed.incl(stroke.imageRef)
      for c in node.children:
        walk(c)
    walk(figmaFile.document)

    # Walk images dir and remove any unused images.
    for kind, path in walkDir(dataDir / "fidget" / "images", relative = true):
      case kind:
      of pcFile:
        let (_, imageRef, _) = splitFile(path)
        if imageRef notin imagesUsed:
          removeFile(figmaImagePath(imageRef))
      of pcDir:
        removeDir(dataDir / "fidget" / "images" / path)
      of pcLinkToFile, pcLinkToDir:
        removeFile(dataDir / "fidget" / "images" / path)

    # Check if we need to download any images.
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
    ## Downloads a font.
    let fontPath = figmaFontPath(fontPostScriptName).replace(" ", "")
    let fontUserPath = userFontPath(fontPostScriptName)
    if not fileExists(fontPath) and not fileExists(fontUserPath):
      const baseUrl = "https://github.com/treeform/fidgetfonts/raw/main/fonts/"
      let url = baseUrl & fontPostScriptName & ".ttf"
      echo "Font not found: '", fontPath, "'"
      echo "Downloading '", url, "'"
      let
        request = newRequest(url)
        response = fetch(request)
      if response.code != 200:
        raise newException(FidgetError, "Downloading '" & url & "' failed")
      writeFile(fontPath, response.body)

  proc downloadFonts(figmaFile: FigmaFile) =
    ## Downloads all the fonts used in the Figma file.
    if not dirExists(dataDir / "fidget" / "fonts"):
      createDir(dataDir / "fidget" / "fonts")

    # Walk the Figma file and find all the fonts used.

    var fontsUsed: HashSet[string]

    # TODO Make fallback font download better:
    fontsUsed.incl("NotoSansJP-Regular")
    # fontsUsed.incl("NotoSansCH-Regular")
    # fontsUsed.incl("NotoSansKR-Regular")

    proc incl(style: TypeStyle) =
      if style.fontPostScriptName != "":
        fontsUsed.incl(style.fontPostScriptName)
      elif style.fontFamily != "":
        fontsUsed.incl(style.fontFamily & "-Regular")

    proc walk(node: INode) =
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

    # Walk font dir and remove any unused fonts.

    for kind, path in walkDir(dataDir / "fidget" / "fonts", relative = true):
      case kind:
      of pcFile:
        let (_, name, _) = splitFile(path)
        if name notin fontsUsed:
          removeFile(figmaFontPath(name))
      of pcDir:
        removeDir(dataDir / "fidget" / "fonts" / path)
      of pcLinkToFile, pcLinkToDir:
        removeFile(dataDir / "fidget" / "fonts" / path)

    # Check if we need to download any fonts.

    var needsDownload: bool
    for fontPostScriptName in fontsUsed:
      if not fileExists(figmaFontPath(fontPostScriptName)):
        needsDownload = true
        break

    if not needsDownload:
      return

    # We need to download one or more fonts.

    for fontPostScriptName in fontsUsed:
      downloadFont(fontPostScriptName)

  proc downloadFigmaFile(fileKey: string) =
    ## Downloads and caches the Figma file for this file key.
    if not dirExists(dataDir / "fidget"):
      createDir(dataDir / "fidget")

    let
      figmaFilePath = figmaFilePath(fileKey)
      lastModifiedFilePath = lastModifiedFilePath(fileKey)

    # Walk data/fidget dir and remove any unexpected entries.

    for kind, path in walkDir(dataDir / "fidget", relative = true):
      case kind:
      of pcFile:
        let (_, name, _) = splitFile(path)
        if name != fileKey:
          removeFile(dataDir / "fidget" / path)
      of pcDir:
        if path notin ["images", "fonts"]:
          removeDir(dataDir / "fidget" / path)
      of pcLinkToFile, pcLinkToDir:
        removeFile(dataDir / "fidget" / path)

    var useCached: bool
    if fileExists(figmaFilePath) and fileExists(lastModifiedFilePath):
      # If we have a saved Figma file, is it up to date?
      let
        url = "https://api.figma.com/v1/files/" & fileKey & "?depth=1"
        request = newRequest(url, headers = figmaHeaders())
        response = fetch(request)
      if response.code == 200:
        let liveFile = parseFigmaFile(response.body)
        if liveFile.lastModified == readFile(lastModifiedFilePath):
          useCached = true
        else:
          echo "Cached Figma file out of date, downloading latest."

    if useCached:
      echo "Using cached Figma file."
      return

    let
      url = "https://api.figma.com/v1/files/" & fileKey & "?geometry=paths"
      request = newRequest(url, headers = figmaHeaders())
      response = fetch(request)

    if response.code != 200:
      for (key, value) in response.headers:
        if key.toLowerAscii().startsWith("x-figma"):
          echo key, ": ", value
      raise newException(
        FidgetError,
        "Error downloading Figma file, status code: " & $response.code & "\n" &
        response.body
      )

    let
      liveFile = parseFigmaFile(response.body)
      json = response.body.fromJson(JsonNode)
    # Download images and fonts before writing the cached Figma file.
    # This way we either do or do not have a complete valid cache if we have a
    # version file. This is important for falling back to cached data
    # in the event the API returns an error.
    downloadImages(fileKey, liveFile)
    downloadFonts(liveFile)
    writeFile(figmaFilePath, compress($json))
    writeFile(lastModifiedFilePath, liveFile.lastModified)
    echo "Downloaded latest Figma file."

  proc loadFigmaUrl*(figmaUrl: string): FigmaFile =
    ## Use the Figma URL as a new figmaFile.
    ## Will download the full file if it needs to.
    var figmaFileKey: string

    let parsed = parseUrl(figmaUrl)
    if parsed.paths.len >= 2:
      figmaFileKey = parsed.paths[1]
    else:
      raise newException(FidgetError, "Invalid Figma URL: " & figmaUrl)

    downloadFigmaFile(figmaFileKey)
    return loadFigmaFile(figmaFileKey)

else:

  import webby

  proc loadFigmaUrl*(figmaUrl: string): FigmaFile =
    ## Use the Figma URL as a new figmaFile.
    ## Will download the full file if it needs to.
    var figmaFileKey: string

    let parsed = parseUrl(figmaUrl)
    if parsed.paths.len >= 2:
      figmaFileKey = parsed.paths[1]
    else:
      raise newException(FidgetError, "Invalid Figma URL: " & figmaUrl)

    return loadFigmaFile(figmaFileKey)
