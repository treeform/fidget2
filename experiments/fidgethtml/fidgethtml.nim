## Generates static HTML files from Figma API

import cligen, schema, loader, taggy, std/sets, std/os, vmath, chroma,
    std/strutils, pixie, std/algorithm, std/tables, std/unicode, webby, puppy,
    jsony, std/json

proc htmlFills(node: Node) =
  for fill in node.fills:
    if fill.visible:
      case fill.kind:
        of pkSolid:
          backgroundColor fill.color.toHtmlRgba()
        of pkImage:
          let imagePath = "images/" & fill.imageRef & ".png"
          backgroundImage "url(" & imagePath & ")"
          case fill.scaleMode
          of FillScaleMode:
            backgroundSize "cover"
            backgroundRepeat "no-repeat"
            backgroundPosition "center center"
          of FitScaleMode:
            backgroundSize "contain"
            backgroundRepeat "no-repeat"
            backgroundPosition "center center"
          of TileScaleMode:
            # CSS is scaling factor of the element
            # Figma is scaling factor of the image
            if fileExists(imagePath):
              let image = readImage(imagePath)
              let imageScaledWidth = image.width.float32 * fill.scalingFactor
              let scalingFactor = imageScaledWidth / node.size.x
              backgroundSize $(scalingFactor * 100) & "%"
            else:
              echo node.path, ": can't find image ", imagePath
          else:
            echo node.path, ": not implemented ", fill.scaleMode

        else:
          echo node.path, ": not implemented ", fill.kind

proc htmlBorders(node: Node) =
  var hasStrokes = false
  for stroke in node.strokes:
    if stroke.visible:
      hasStrokes = true
  if hasStrokes and node.strokeWeight > 0:
    borderWidth $node.strokeWeight & "px"
    borderStyle "solid"
    for stroke in node.strokes:
      if stroke.visible:
        case stroke.kind:
          of pkSolid:
            borderColor stroke.color.toHtmlRgba()
          else:
            echo node.path, ": not implemented border ", stroke.kind

proc htmlAutoLayout(node: Node) =

  # auto layout:
  case node.layoutMode:
    of NoneLayout:
      discard

    of HorizontalLayout, VerticalLayout:
      if not node.name.startsWith("size"):
        display "flex"
      if node.layoutMode == HorizontalLayout:
        flexDirection "row"
      else:
        flexDirection "column"

      paddingLeft node.paddingLeft
      paddingRight node.paddingRight
      paddingTop node.paddingTop
      paddingBottom node.paddingBottom
      gap $node.itemSpacing & "px"

      case node.counterAxisAlignItems:
        of MinAxisAlign:
          alignItems "flex-start"
        of CenterAxisAlign:
          alignItems "center"
        of MaxAxisAlign:
          alignItems "flex-end"
        else:
          echo node.path, ": not implemented ", node.counterAxisAlignItems

proc cssNodeStyle(style: TypeStyle) =
  fontFamily style.fontFamily
  if style.fontSize != 0:
    fontSize style.fontSize
  fontWeight style.fontWeight

  if style.lineHeightPx != 0:
    lineHeight style.lineHeightPx

  if style.textDecoration == Underline:
    textDecoration "underline"

  if style.fills.len > 0:
    color style.fills[0].color.toHtmlRgba()

  case style.textAlignHorizontal:
    of CenterAlign:
      textAlign "center"
    of LeftAlign:
      textAlign "left"
    of RightAlign:
      textAlign "right"

proc htmlNodeText(node: Node) =

  type
    TagSpan = object
      styleId: int
      text: string
    TagParagraph = object
      spans: seq[TagSpan]

  var
    currentStyle = 0
    currentText = ""
    currentParagraph: TagParagraph
    paragraphs: seq[TagParagraph]

  proc dumpAndSwitchStyles() =
    if currentText != "":
      currentParagraph.spans.add(TagSpan(
        styleId: currentStyle,
        text: currentText
      ))
      currentText = ""

  var i = 0
  for c in node.characters.runes():
    let thisStyle =
      if i < node.characterStyleOverrides.len:
        node.characterStyleOverrides[i]
      else:
        0
    if thisStyle != currentStyle:
      dumpAndSwitchStyles()
      currentStyle = thisStyle

    if c == Rune('\n'):
      dumpAndSwitchStyles()
      paragraphs.add(currentParagraph)
      currentParagraph = TagParagraph()
    else:
      currentText.add c

    inc i

  dumpAndSwitchStyles()
  if currentParagraph.spans.len > 0:
    paragraphs.add(currentParagraph)

  for lineNumber, paragraph in paragraphs:
    p:
      # compute paragraphSpacing
      var paragraphSpacing = node.style.paragraphSpacing
      for tagSpan in paragraph.spans:
        if tagSpan.styleId != 0:
          let typeStyle = node.styleOverrideTable[$tagSpan.styleId]
          paragraphSpacing = max(
            paragraphSpacing,
            typeStyle.paragraphSpacing
          )

      style:
        minHeight "1em"
        marginBottom paragraphSpacing
        if node.lineTypes[lineNumber] == UnorderedLineType:
          display "list-item"
          marginLeft "1em"

      for tagSpan in paragraph.spans:
        if tagSpan.styleId == 0:
          say tagSpan.text
        else:
          let typeStyle = node.styleOverrideTable[$tagSpan.styleId]
          if typeStyle.hyperlink != nil:
            a:
              style:
                cssNodeStyle(typeStyle)
              href typeStyle.hyperlink.url
              say tagSpan.text
          else:
            span:
              style:
                cssNodeStyle(typeStyle)
              say tagSpan.text

proc shouldLinkTo(node: Node): string =
    if node.transitionNodeID != "":
      let transitionNode = figmaFile.findById(node.transitionNodeID)
      if transitionNode.name.endsWith("html") or
        transitionNode.name.startsWith("http"):
          return transitionNode.name

proc isIcon(node: Node): bool =
  if node.kind == InstanceNode:
    let component = figmaFile.findById(node.componentId)
    if component != nil and component.exportSettings.len > 0:
        return true

proc htmlNode(node: Node) =

  var tagName = "div"

  if node.shouldLinkTo != "":
    tagName = "a"

  tag node.name.replace(" ", "-"), tagName:
    style:

      if node.name.startsWith("size"):

        if node.layoutMode == NoneLayout:
          height node.size.y.int

      else:

        if node.parent.layoutMode != NoneLayout:
          if node.layoutPositioning == LayoutPositioningAbsolute:
            position "absolute"
            left node.position.x.int
            top node.position.y.int
          else:
            position "relative"

          case node.layoutAlign:
            of InheritLayout:
              width node.size.x.int
              height node.size.y.int
            of StretchLayout:
              if node.parent.layoutMode == HorizontalLayout:
                if node.layoutMode == NoneLayout:
                  width node.size.x.int
                height "100%"
              elif node.parent.layoutMode == VerticalLayout:
                width "100%"
                if node.layoutMode == NoneLayout and
                  not (node.kind == TextNode and node.style.textAutoResize in {HeightTextResize, WidthAndHeightTextResize}):
                  height node.size.y.int
              # else:
              #   width node.size.x.int
              #   height node.size.y.int

          if node.parent.itemReverseZIndex:
            zIndex node.parent.children.len - node.parent.children.find(node)

        else:
          position "absolute"

          var
            translatePx: Vec2
            translatePr: Vec2

          template genConstraints(vertical, y, top, bottom, height) =
            case node.constraints.vertical:
              of MinConstraint:
                top node.position.y.int
                height node.size.y.int
              of MaxConstraint:
                bottom (node.parent.size.y - node.position.y - node.size.y).int
                height node.size.y.int
              of StretchConstraint:
                top node.position.y.int
                bottom (node.parent.size.y - node.position.y - node.size.y).int
              of CenterConstraint:
                top "50%"
                translatePx.y = node.position.y - node.parent.size.y / 2
                height node.size.y.int
              of ScaleConstraint:
                top $((node.position.y + node.size.y / 2) / node.parent.size.y * 100) & "%"
                translatePr.y = -50
                height $(node.size.y / node.parent.size.y * 100) & "%"

          genConstraints(vertical, y, top, bottom, height)
          genConstraints(horizontal, x, left, right, width)

          if translatePx != vec2(0, 0):
            transform "translate(" & $translatePx.x & "px ," & $translatePx.y & "px)"
          if translatePr != vec2(0, 0):
            transform "translate(" & $translatePr.x & "% ," & $translatePr.y & "%)"

      node.htmlAutoLayout()

      if not node.visible:
        display "none"
      if node.opacity != 1.0:
        opacity $node.opacity

      if node.cornerRadius != 0:
        borderRadius node.cornerRadius
      if node.rectangleCornerRadii[0] != 0 or
        node.rectangleCornerRadii[1] != 0 or
        node.rectangleCornerRadii[2] != 0 or
        node.rectangleCornerRadii[3] != 0:
        borderRadius $node.rectangleCornerRadii[0] & "px " &
          $node.rectangleCornerRadii[1] & "px " &
          $node.rectangleCornerRadii[2] & "px " &
          $node.rectangleCornerRadii[3]

      # fills
      if node.kind == InstanceNode:
        let component = figmaFile.findById(node.componentId)
        if component != nil and component.exportSettings.len > 0:
          echo "", node.path
          let masterComponent = figmaFile.findById(node.componentId)
          let imagePath = masterComponent.name & ".png"
          backgroundImage "url(images/" & imagePath & ")"
        else:
          echo node.path, ": can't find component ", node.componentId

      if node.exportSettings.len > 0:
        let imagePath = "img" / node.name.replace(" ", "-").replace("/", "--") & ".png"
        backgroundImage "url(" & imagePath & ")"

        if not dirExists(rootPath / "img"):
          createDir(rootPath / "img")

        if not fileExists(rootPath / imagePath):
          let urlPath = "https://api.figma.com/v1/images/" & figmaFileKey
          var url = parseUrl(urlPath)
          url.query["ids"] = node.id
          url.query["format"] = "png"
          url.query["scale"] = "1"
          let response = newRequest($url, headers = figmaHeaders()).fetch()
          if response.code != 200:
            echo "failed!"
            echo response.body
          else:
            let imageData = fromJson(response.body)
            for k, v in imageData["images"]:
              if v.getStr() != "":
                let imageResponse = newRequest(v.getStr()).fetch()
                writeFile(rootPath / imagePath, imageResponse.body)

      else:

        if node.kind == TextNode:
          cssNodeStyle(node.style)

          if node.fills.len > 0:
            color node.fills[0].color.toHtmlRgba()

        else:
          htmlFills(node)
          htmlBorders(node)

      # shadows
      var boxShadows: string

      for effect in node.effects:
        case effect.kind:
          of DropShadow:
            #box-shadow: 3px 3px red, -1em 0 0.4em olive;#
            boxShadows.add(
              $effect.offset.x & "px " &
              $effect.offset.y & "px " &
              $effect.radius & "px " &
              $effect.spread & "px " &
              effect.color.toHtmlRgba() &
              ","
            )
          else:
            echo node.path, ": not implemented ", effect.kind

      if boxShadows != "":
        boxShadows.removeSuffix(",")
        boxShadow boxShadows

    if node.kind == TextNode:
      htmlNodeText(node)

    if node.shouldLinkTo != "":
      href node.shouldLinkTo()

    if node.isIcon():
      discard
    elif node.exportSettings.len > 0:
      # node is an image
      discard
    else:
      for c in node.children:
        htmlNode(c)

proc scanForHtml(node: Node) =
  if node.name.endsWith(".html") and not node.name.startsWith("http"):
    echo "doing page: ", node.name

    let html = render:
      html:
        head:
          title:
            say node.name
          link:
            rel "stylesheet"
            href "style.css"

          # add media queries CSS
          var sizes: seq[(int, Node)]
          for c in node.children:
            if c.name.startsWith("size"):
              sizes.add((parseInt(c.name[4..^1]), c))
          sizes.sort(proc(a, b: (int, Node)): int = cmp(a[0], b[0]))

          if sizes.len > 0:
            meta:
              name "viewport"
              attrContent "width=device-width, initial-scale=1"
            styleSheet:
              for i, (s, node) in sizes:
                sayCss ".size" & $s & " {display: none;}\n"
                let w =
                  if node.layoutMode == NoneLayout:
                    "block"
                  else:
                    "flex"
                if i < sizes.len - 1:
                  let b = sizes[i + 1][0] - 1
                  sayCss "@media only screen and (max-width: " & $b & "px) and (min-width: " & $s & "px) { .size" & $s & " {display: " & w & ";}}\n"
                else:
                  sayCss "@media only screen and (min-width: " & $s & "px) { .size" & $s & " {display: " & w & ";}}\n"

        body:
          style:
            htmlFills(node)
            htmlAutoLayout(node)

          for c in node.children:
            htmlNode(c)

    let htmlPath = rootPath / node.name
    writeFile(htmlPath, html)

  for page in node.children:
    scanForHtml(page)

proc cssNode(node: Node) =

  css "." & node.name.replace(" ", "-"):
    for c in node.children:
      cssNode(c)

proc cssDocument(document: Node) =
  for page in document.children:
    for node in page.children:
      cssNode(node)

proc generate(fileUrl: string) =
  echo "Generating HTML"
  use(fileUrl)

  let
    cssPath = rootPath / "style.css"

  scanForHtml(figmaFile.document)

  let css = render:
    styleSheet:
      css "*":
        boxSizing "border-box"
        margin 0
        padding 0
        textDecoration "inherit"

      css "a":
        textDecoration "none"

      css "a:hover":
        textDecoration "underline"


      # add fonts to CSS
      var usedFonts: HashSet[string]
      proc walkFonts(node: Node) =
        if node.kind == TextNode:
          if node.style.fontPostScriptName notin usedFonts:
            usedFonts.incl(node.style.fontPostScriptName)
            css "@font-face":
              fontFamily node.style.fontFamily
              cssProp "src", "url(fonts/" & node.style.fontPostScriptName & ".ttf)"
              fontWeight node.style.fontWeight
        for c in node.children:
          walkFonts(c)
      walkFonts(figmaFile.document)

      #cssDocument(figmaFile.document)

  writeFile(cssPath, css[22 .. ^9])

  #discard execShellCmd("tidy --tidy-mark no -q -i -m " & quoteShell(htmlPath))

proc load(fileUrl: string) =
  ## Some API call
  echo "Fetching JSON schema, images and fonts"
  use(fileUrl)

proc run(fileUrl: string) =
  load(fileUrl)
  generate(fileUrl)

when isMainModule:

  dispatchMulti(
    # [load],
    # [generate],
    [run]
  )
