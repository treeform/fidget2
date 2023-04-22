## Generates static HTML files from Figma API

import cligen, schema, loader, std/sets, std/os, vmath, chroma,
    std/strutils, pixie, std/algorithm, std/tables, std/unicode, webby, puppy,
    jsony, std/json

type
  StringMap* = seq[(string, string)]

func `[]`*(query: StringMap, key: string): string =
  ## Get a key out of attributes or "".
  for (k, v) in query:
    if k == key:
      return v

func `[]=`*(query: var StringMap, key, value: string) =
  ## Sets an attribute.
  for pair in query.mitems:
    if pair[0] == key:
      pair[1] = value
      return
  query.add((key, value))

func contains*(query: var StringMap, key: string): bool =
  ## Returns of attribute exists.
  for pair in query.mitems:
    if pair[0] == key:
      return true

type
  Element = ref object
    content*: string
    tagName*: string
    attributes*: StringMap
    children*: seq[Element]
    style*: StringMap

  Selector = ref object
    cssName*: string
    style*: StringMap

const
  SelfClosingTags = [
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr"
  ]

proc prettyPrint*(e: Element, indent = 0): string =
  if e.tagName == "":
    for i in 0 ..< indent:
      result.add "  "
    result.add e.content
    result.add '\n'
  else:
    for i in 0 ..< indent:
      result.add "  "
    result.add '<'
    result.add e.tagName

    var style = ""
    for (k, v) in e.style:
      style.add k
      style.add ": "
      style.add v
      style.add "; "
    if style != "":
      style.removeSuffix("; ")
      e.attributes["style"] = style

    for (k, v) in e.attributes:
      result.add " "
      result.add k
      result.add "=\""
      result.add v
      result.add "\""

    result.add '>'
    result.add '\n'

    if e.tagName notin SelfClosingTags:
      for c in e.children:
        result.add prettyPrint(c, indent + 1)

      for i in 0 ..< indent:
        result.add "  "
      result.add "</"
      result.add e.tagName
      result.add '>'
      result.add '\n'

proc prettyPrint(s: Selector): string =
  result.add s.cssName & " {\n"
  for (k, v) in s.style:
    result.add "  " & k & ": " & v & ";\n"
  result.add "}\n"

proc prettyPrint(css: seq[Selector]): string =
  for s in css:
    result.add prettyPrint(s)
    result.add "\n"

proc px(num: float32): string =
  ## Format 123.00 -> 123px nicely
  if num == 0: return "0"
  result = $num
  result.removeSuffix(".0")
  result.add("px")

proc pr(num: float32): string =
  ## Format 123.00 -> 123% nicely
  if num == 0: return "0"
  result = $num
  result.removeSuffix(".0")
  result.add("%")

proc htmlNaming(e: Element, node: Node) =
  if node.kind == TextNode and " " in node.name:
    # If the node is a text node and name contains spaces
    # it probably contains a copy of the content string so
    # just name it "text"
    e.attributes["class"] = "text"
  elif node.name.startsWith("#") or
    node.name.startsWith(".") or
    node.name.startsWith("<"):
    # appears to be css selectors ... expand them!
    var classes: seq[string]
    for s in node.name.replace(" ", "-").toLowerAscii().split("."):
      if s == "":
        continue
      elif s.startsWith("#"):
        # its an id
        e.attributes["id"] = s[1 .. ^1]
      elif s.startsWith("<"):
        # its an tag
        e.tagName = s[1 .. ^1].replace(">", "")
      else:
        classes.add(s)
    if classes.len > 0:
      echo classes
      e.attributes["class"] = classes.join(" ")
  else:
    e.attributes["class"] = node.name.replace(" ", "-").toLowerAscii()

proc htmlFills(e: Element, node: Node) =
  ## Do background fills
  for fill in node.fills:
    if fill.visible:
      case fill.kind:
        of pkSolid:
          e.style["background-color"] = fill.color.toHtmlRgba()
        of pkImage:
          let imagePath = "images/" & fill.imageRef & ".png"
          e.style["background-image"] = "url(" & imagePath & ")"
          case fill.scaleMode
          of FillScaleMode:
            e.style["background-size"] = "cover"
            e.style["background-repeat"] = "no-repeat"
            e.style["background-position"] = "center center"
          of FitScaleMode:
            e.style["background-size"] = "contain"
            e.style["background-repeat"] = "no-repeat"
            e.style["background-position"] = "center center"
          of TileScaleMode:
            # CSS is scaling factor of the element
            # Figma is scaling factor of the image
            if fileExists(imagePath):
              let image = readImage(imagePath)
              let imageScaledWidth = image.width.float32 * fill.scalingFactor
              let scalingFactor = imageScaledWidth / node.size.x
              e.style["background-size"] = (scalingFactor * 100).pr
            else:
              echo node.path, ": can't find image ", imagePath
          else:
            echo node.path, ": not implemented ", fill.scaleMode
        else:
          echo node.path, ": not implemented ", fill.kind

proc htmlBorders(e: Element, node: Node) =
  ## Borders and Strokes and corner radius.

  if node.cornerRadius != 0:
    e.style["border-radius"] = node.cornerRadius.px

  if node.rectangleCornerRadii[0] != 0 or
    node.rectangleCornerRadii[1] != 0 or
    node.rectangleCornerRadii[2] != 0 or
    node.rectangleCornerRadii[3] != 0:
    e.style["border-radius"] = $node.rectangleCornerRadii[0].px & " " &
      $node.rectangleCornerRadii[1].px & " " &
      $node.rectangleCornerRadii[2].px & " " &
      $node.rectangleCornerRadii[3].px

  # Only add border if there are strokes
  var hasStrokes = false
  for stroke in node.strokes:
    if stroke.visible:
      hasStrokes = true

  if hasStrokes and node.strokeWeight > 0:
    e.style["border-width"] = node.strokeWeight.px
    e.style["border-style"] = "solid"
    for stroke in node.strokes:
      if stroke.visible:
        case stroke.kind:
          of pkSolid:
            e.style["border-color"] = stroke.color.toHtmlRgba()
          else:
            echo node.path, ": not implemented border ", stroke.kind

proc htmlAutoLayout(e: Element, node: Node) =
  # Auto Layout

  case node.layoutMode:
    of NoneLayout:
      discard

    of HorizontalLayout, VerticalLayout:
      if not node.name.startsWith("size"):
        e.style["display"] = "flex"
      if node.layoutMode == HorizontalLayout:
        e.style["flex-direction"] = "row"
      else:
        e.style["flex-direction"] = "column"

      e.style["padding-left"] = node.paddingLeft.px
      e.style["padding-right"] = node.paddingRight.px
      e.style["padding-top"] = node.paddingTop.px
      e.style["padding-bottom"] = node.paddingBottom.px
      e.style["gap"] = node.itemSpacing.px

      case node.counterAxisAlignItems:
        of MinAxisAlign:
          e.style["align-items"] = "flex-start"
        of CenterAxisAlign:
          e.style["align-items"] = "center"
        of MaxAxisAlign:
          e.style["align-items"] = "flex-end"
        else:
          echo node.path, ": not implemented ", node.counterAxisAlignItems

proc htmlLayout(e: Element, node: Node) =
  # Constraint Layout, Child Auto Layout and Parent Auto Layout

  if node.name.startsWith("size"):
    # Responsive layout based on media queries
    # NOT PART OF FIGMA
    if node.layoutMode == NoneLayout:
      e.style["height"] = node.size.y.px

  elif node.parent.layoutMode != NoneLayout:
    # Parent Auto Layout

    if node.layoutPositioning == LayoutPositioningAbsolute:
      e.style["position"] = "absolute"
      e.style["left"] = node.position.x.px
      e.style["top"] = node.position.y.px
    else:
      e.style["position"] = "relative"

    case node.layoutAlign:
      of InheritLayout:
        e.style["width"] = node.size.x.px
        e.style["height"] = node.size.y.px
      of StretchLayout:
        if node.parent.layoutMode == HorizontalLayout:
          if node.layoutMode == NoneLayout:
            e.style["width"] = node.size.x.px
          e.style["height"] = "100%"
        elif node.parent.layoutMode == VerticalLayout:
          e.style["width"] = "100%"
          if node.layoutMode == NoneLayout and
            not (node.kind == TextNode and node.style.textAutoResize in {HeightTextResize, WidthAndHeightTextResize}):
            e.style["height"] = node.size.y.px
        else:
          echo "auto layout missmatch?"
          e.style["width"] = node.size.x.px
          e.style["height"] = node.size.y.px

    if node.parent.itemReverseZIndex:
      e.style["z-index"] = $(node.parent.children.len - node.parent.children.find(node))

  else:
    # Constraints based layout
    e.style["position"] = "absolute"
    var
      translatePx: Vec2
      translatePr: Vec2

    case node.constraints.vertical:
      of MinConstraint:
        e.style["top"] = node.position.y.px
        e.style["height"] = node.size.y.px
      of MaxConstraint:
        e.style["bottom"] = (node.parent.size.y - node.position.y - node.size.y).px
        e.style["height"] = node.size.y.px
      of StretchConstraint:
        e.style["top"] = node.position.y.px
        e.style["bottom"] = (node.parent.size.y - node.position.y - node.size.y).px
      of CenterConstraint:
        e.style["top"] = "50%"
        translatePx.y = node.position.y - node.parent.size.y / 2
        e.style["height"] = node.size.y.px
      of ScaleConstraint:
        e.style["top"] = ((node.position.y + node.size.y / 2) / node.parent.size.y * 100).pr
        translatePr.y = -50
        e.style["height"] = (node.size.y / node.parent.size.y * 100).pr

    case node.constraints.horizontal:
      of MinConstraint:
        e.style["left"] = node.position.x.px
        e.style["width"] = node.size.x.px
      of MaxConstraint:
        e.style["right"] = (node.parent.size.x - node.position.x - node.size.x).px
        e.style["width"] = node.size.x.px
      of StretchConstraint:
        e.style["left"] = node.position.x.px
        e.style["right"] = (node.parent.size.x - node.position.x - node.size.x).px
      of CenterConstraint:
        e.style["left"] = "50%"
        translatePx.x = node.position.x - node.parent.size.x / 2
        e.style["width"] = node.size.x.px
      of ScaleConstraint:
        e.style["left"] = ((node.position.x + node.size.x / 2) / node.parent.size.x * 100).pr
        translatePr.x = -50
        e.style["width"] = (node.size.x / node.parent.size.x * 100).pr

    if translatePx != vec2(0, 0):
      e.style["transform"] = "translate(" & translatePx.x.px & " ," & translatePx.y.px & ")"
    if translatePr != vec2(0, 0):
      e.style["transform"] = "translate(" & translatePr.x.pr & " ," & translatePr.y.pr & ")"

  e.htmlAutoLayout(node)

proc htmlTypeStyle(e: Element, style: TypeStyle) =
  ## Apply the TypeStyle node to the element.

  e.style["font-family"] = style.fontFamily
  if style.fontSize != 0:
    e.style["font-size"] = style.fontSize.px
  e.style["font-weight"] = $style.fontWeight

  if style.lineHeightPx != 0:
    e.style["line-height"] = style.lineHeightPx.px

  if style.textDecoration == Underline:
    e.style["text-decoration"] = "underline"

  if style.fills.len > 0:
    e.style["color"] = style.fills[0].color.toHtmlRgba()

  case style.textAlignHorizontal:
    of CenterAlign:
      e.style["text-align"] = "center"
    of LeftAlign:
      e.style["text-align"] = "left"
    of RightAlign:
      e.style["text-align"] = "right"

proc htmlRichText(e: Element, node: Node) =

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
    let p = Element(tagName: "p")
    # compute paragraphSpacing
    var paragraphSpacing = node.style.paragraphSpacing
    for tagSpan in paragraph.spans:
      if tagSpan.styleId != 0:
        let typeStyle = node.styleOverrideTable[$tagSpan.styleId]
        paragraphSpacing = max(
          paragraphSpacing,
          typeStyle.paragraphSpacing
        )

    p.style["min-height"] = "1em"
    p.style["margin-bottom"] = paragraphSpacing.px
    if node.lineTypes[lineNumber] == UnorderedLineType:
      p.style["display"] = "list-item"
      p.style["margin-left"] = "1em"

    for tagSpan in paragraph.spans:
      if tagSpan.styleId == 0:
        let textNode = Element(tagName: "")
        textNode.content = tagSpan.text
        p.children.add(textNode)
      else:
        let typeStyle = node.styleOverrideTable[$tagSpan.styleId]
        if typeStyle.hyperlink != nil:
          let a = Element(tagName: "a")
          a.htmlTypeStyle(typeStyle)
          a.attributes["href"] = typeStyle.hyperlink.url
          let textNode = Element(tagName: "")
          textNode.content = tagSpan.text
          a.children.add(textNode)
          p.children.add(a)
        else:
          let span = Element(tagName: "span")
          span.htmlTypeStyle(typeStyle)
          let textNode = Element(tagName: "")
          textNode.content = tagSpan.text
          span.children.add(textNode)
          p.children.add(span)

    e.children.add(p)

proc htmlTextNode(e: Element, node: Node) =
  ## Process TextNode
  e.htmlTypeStyle(node.style)
  if node.fills.len > 0:
    # TODO: Its odd that both node fills and style fills can effect text
    e.style["color"] = node.fills[0].color.toHtmlRgba()
  #TODO: effects
  #TODO: strokes
  e.htmlRichText(node)

proc isIcon(node: Node): bool =
  ## Does this node qualifies to be an icon?
  ## Icons are components that point to exported master component.
  if node.kind == InstanceNode:
    let component = figmaFile.findById(node.componentId)
    if component != nil and component.exportSettings.len > 0:
        return true

proc htmlIcon(e: Element, node: Node) =
  ## Process this node as an Icon.
  let component = figmaFile.findById(node.componentId)
  if component == nil:
    echo node.path, ": can't find component ", node.componentId
  else:
    if component.exportSettings.len > 0:
      let masterComponent = figmaFile.findById(node.componentId)
      let imagePath = masterComponent.name & ".png"
      e.style["background-image"] = "url(images/" & imagePath & ")"

proc isImage(node: Node): bool =
  ## Does this node qualifies to be an image?
  ## Images are exported nodes
  ## TODO: Nodes too complex to be rendered in HTML.
  node.exportSettings.len > 0

proc htmlImage(e: Element, node: Node) =
  ## This node is exported so we should treat it as an frozen flat image

  let imagePath = "img" / node.name.replace(" ", "-").replace("/", "--") & ".png"
  e.style["background-image"] = "url(" & imagePath & ")"

  if not dirExists(rootPath / "img"):
    createDir(rootPath / "img")

  if not fileExists(rootPath / imagePath):
    # Ask figma to render it for us:
    # TODO: This is really slow and needs caching.
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

proc htmlShadows(e: Element, node: Node) =
  ## Shadows
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
    e.style["box-shadow"] = boxShadows

proc htmlVisibility(e: Element, node: Node) =
  ## Sets visible and opacity
  if not node.visible:
    e.style["display"] = "none"
  if node.opacity != 1.0:
    e.style["opacity"] = $node.opacity

proc shouldLinkTo(node: Node): string =
  ## Where should this node link to?
  if node.transitionNodeID != "":
    let transitionNode = figmaFile.findById(node.transitionNodeID)
    if transitionNode.name.endsWith("html") or
      transitionNode.name.startsWith("http"):
        return transitionNode.name

proc isLink(node: Node): bool =
  ## Is this node a link?
  node.shouldLinkTo != ""

proc htmlLinking(e: Element, node: Node) =
  ## Process this node as a link.
  ## Will change tag type to "a"
  e.tagName = "a"
  e.attributes["href"] = node.shouldLinkTo()

proc htmlNode(node: Node): Element =

  let e = Element(tagName: "div")

  e.htmlNaming(node)
  e.htmlLayout(node)
  e.htmlVisibility(node)

  if node.isLink():
    e.htmlLinking(node)

  if node.isIcon():
    e.htmlIcon(node)
  elif node.isImage():
    e.htmlImage(node)
  elif node.kind == TextNode:
    e.htmlTextNode(node)
  else:
    e.htmlFills(node)
    e.htmlBorders(node)
    e.htmlShadows(node)
    # TODO: other effects

    for c in node.children:
      e.children.add(htmlNode(c))

  return e

proc scanForHtml(node: Node) =
  if node.name.endsWith(".html") and not node.name.startsWith("http"):
    echo "doing page: ", node.name

    let html = Element(tagName: "html")
    let head = Element(tagName: "head")
    html.children.add(head)
    let title = Element(tagName: "title")
    title.children.add(Element(content: node.name))
    head.children.add(title)
    let link = Element(tagName: "link")
    link.attributes["rel"] = "stylesheet"
    link.attributes["href"] = "style.css"
    head.children.add(link)

    # Look for media queries CSS
    var sizes: seq[(int, Node)]
    for c in node.children:
      if c.name.startsWith("size"):
        sizes.add((parseInt(c.name[4..^1]), c))
    sizes.sort(proc(a, b: (int, Node)): int = cmp(a[0], b[0]))

    if sizes.len > 0:
      # Add media queries
      let meta = Element(tagName: "meta")
      meta.attributes["name"] = "viewport"
      meta.attributes["content"] = "width=device-width, initial-scale=1"
      head.children.add(meta)

      let style = Element(tagName: "style")
      let css = Element(tagName: "")
      for i, (s, node) in sizes:
        css.content.add ".size" & $s & " {display: none;}\n"
        let w =
          if node.layoutMode == NoneLayout:
            "block"
          else:
            "flex"
        if i < sizes.len - 1:
          let b = sizes[i + 1][0] - 1
          css.content.add "@media only screen and (max-width: " & $b & "px) and (min-width: " & $s & "px) { .size" & $s & " {display: " & w & ";}}\n"
        else:
          css.content.add "@media only screen and (min-width: " & $s & "px) { .size" & $s & " {display: " & w & ";}}\n"
      style.children.add(css)
      head.children.add(style)

    let body = Element(tagName: "body")
    # Body is a special node as it gets some fills and layout from regular nodes
    # but more limited.
    body.htmlFills(node)
    body.htmlAutoLayout(node)

    for c in node.children:
      body.children.add(htmlNode(c))

    html.children.add(body)

    let htmlPath = rootPath / node.name
    writeFile(htmlPath, prettyPrint(html))

  for page in node.children:
    scanForHtml(page)

proc generate(fileUrl: string) =
  echo "Generating HTML"
  use(fileUrl)

  let
    cssPath = rootPath / "style.css"

  scanForHtml(figmaFile.document)

  # Setup common "reset-css-style".
  var css: seq[Selector]

  let star = Selector(cssName: "*")
  star.style["box-sizing"] = "border-box"
  star.style["margin"] = "0"
  star.style["padding"] = "0"
  star.style["text-decoration"] = "inherit"
  css.add(star)

  let a = Selector(cssName: "a")
  a.style["text-decoration"] = "none"
  css.add(a)

  let aHover = Selector(cssName: "a:hover")
  aHover.style["text-decoration"] = "underline"
  css.add(aHover)

  # Add fonts to CSS.
  var usedFonts: HashSet[string]
  proc walkFonts(node: Node) =
    if node.kind == TextNode:
      if node.style.fontPostScriptName notin usedFonts:
        usedFonts.incl(node.style.fontPostScriptName)
        let fontFace = Selector(cssName: "@font-face")
        fontFace.style["font-family"] = node.style.fontFamily
        fontFace.style["src"] = "url(fonts/" & node.style.fontPostScriptName & ".ttf)"
        fontFace.style["font-weight"] = $node.style.fontWeight
        css.add(fontFace)
    for c in node.children:
      walkFonts(c)
  walkFonts(figmaFile.document)

  writeFile(cssPath, prettyPrint(css))

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
