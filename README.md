<img src="docs/banner.png">

👏 Check out video about the library: [Fidget: Let's rethink UI development with Nim (NimConf 2020)](https://www.youtube.com/watch?v=IB8Yt2dqZbo) 👏 

# Fidget - A cross platform UI library for nim

⚠️ WARNING: This library is still in heavy development. ⚠️

`nimble install fidget2`

![Github Actions](https://github.com/treeform/fidget2/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/fidget2)

## About

Fidget aims to provide natively compiled cross platform UIs for any platform - Web with HTML5 (WASM), Windows, macOS, Linux with OpenGL.

Fidget leverages [Figma](https://www.figma.com/) - an app that is taking the design world by storm. Fidget uses Figma API to load designs directly. No more counting pixels, no more CSS puzzles. Want to change some spaces? Change it in Figma, press F5 in your see the changes in real time!


## Examples:

See all of the examples in the
[example folder](https://github.com/treeform/fidget2/blob/master/examples/).

### Simple counter

<img src="docs/Counter.png">

Figma file: https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa

```nim
var count = 0
find "/UI/CounterFrame":
  find "Count1Up":
    onClick:
      inc count
  find "CounterDisplay/text":
    onDisplay:
      thisNode.text = $count
```

### Performance

Because the entire lib is compiled with your program you should compile with
`-d:release -d:noAutoGLerrorCheck`
if you want it to run fast.

### Calculator

<img src="examples\calculator\calculator.png">

[See the source code here](https://github.com/treeform/fidget2/blob/master/examples/calculator/calculator.nim)


### Nim Form

The style was copied form the current HTML forum, but nothing here uses HTML. Its all native rectangles, images and text.

<img src="examples\nimforum\nimforum.png">

[See the source code here](https://github.com/treeform/fidget2/blob/master/examples/nimforum/nimforum.nim)


## Getting the API key.

Before using the Fidget integrated Figma API you will need a Figma account and the API key. After creating account go to your profile's settings, add new `Personal access token` and download your key and put it into `.figmatoken` in your home directory or the root file of your project.

<img src="docs/figmaApiKey.png">

## Figma for Programmers

Figma is the fastest growing UI tool. Its demanded by almost all new UI job postings. Chances are your friendly UI designer knows of or users Figma.

If you don't know how to use Figma or how to do UI design I highly recommend giving Figma's YouTube channel a try: https://www.youtube.com/channel/UCQsVmhSa4X-G3lHlUtejzLA its full of great tutorials.

Figma also has a whole library of designs https://www.figma.com/community licensed under CC BY 4.0! Yes that means you can use these designs for free, by simply giving credit! Just duplicate them into your account, modify and remix them. The amount of high quality designs there can really boost any UI project!

> "Let somebody else figure out how to make it look pretty, as long as you can move rectanges around you are good." - Ryan 

## Philosophy

As an industry we design too much of the UI by hand. And we do it many times. A designer builds the UI. We throw that away. Then programmers code up layouts, set colors, and push pixels around. Sometimes several different times for web and mobile.

**It is madness!**

Music is not coded by hand, we use tools. Images are not coded by hand, we use tools. Nor are 3D models, which can be very complex, with bones, sockets, and animations. They have editors and tools. Why do we do this for UI? Why has no good UI editor appeared?

**It is madness!**

This happens because of the wrong programming model. What you want is the design side and the action side. The design side is a tree of nodes made in a UX design program like Figma. The action side is also a tree of event handlers, display functions, and other mutators. A designer should be able to change the design a bit and it should stay working. Likewise a programmer should be able to change the handlers and the design should not need to change. You should be able to rig a UI design and puppet it from code.

You can start with design and make a very pretty UI, then attach code to it.
Or you can start with code and just have ugly boxes at first, then make a pretty design later. It is never this simple though. On any large project you go back and forth. The faster you can iterate with the two halves the better.

## Making an app

To open a window and start the app call `startFidget` with the figma file and other window properties.

```nim
startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Temperature",
  entryFrame = "/UI/TemperatureFrame",
  windowStyle = Decorated
)
```

Then use `find` to build the event tree using glob patterns:

```nim
find "/UI/TemperatureFrame":
  find "CelsiusInput/text":
    onDisplay:
      ...
    onEdit:
      ...
    ofFocus:
      ...
    onUnfocus:
      ...
```

In every event hander you get `thisNode` and it has many properties:

```nim
thisNode.text = "hello world"
```

## Find and Glob Patters

* Absolute path from the mounted frame: `/UI/TemperatureFrame/...`
* Relative to the current `find` scope: `find "CelsiusInput/text"`
* Globs are supported: `find "**/Button*"` (descendants), `find "*/icon"` (children by name)

Find works both as top level thing: 

```nim
find "/UI/TemperatureFrame":
  find "CelsiusInput/text":
    ...
```

And as a function:

```nim
let nodeA = find("/UI/TemperatureFrame")
let nodeB = find("../bg")
```

And even as part of the node itself so that it only looks for chindren:

```nim
let subNode = node.find("text")
```

You can also use `finds` to find multiple nodes:

```nim
for button in finds("Button*"):
```

You can use `*` or `?` and even `**` to select multiple nodes at once:

```nim
find "Button?":
  # Selects all buttons: Button0 - Button9
  onClick:
    echo thisNode.name[^1]
```

## Event model

Attach any subset of these inside a `find` block:

* `onDisplay` - Runs during render when the node is painted. Use for idempotent view updates (for example, set text or value if not focused) **Best practice:** keep `onDisplay` cheap, prefer mutating only what actually changed.
* `onFocus` / `onUnfocus` - Focus or blur notifications for interactive nodes for when `thisNode.focused` changes.
* `onEdit` - Content changed (for example, text input keystrokes)
* `onShow` / `onHide` - Visibility toggles (when `thisNode.shown` changes)
* `onClick` - Mouse left click.
* `onClickOutside` - Useful to cancel actions.
* `onRightClick` - Mouse right click.
* `onMouseMove` - When mouse moves over the element.

## What if I don't want to use Figma?

This does go against the Fidget philosophy, but I get it. You are a propgrammer, you don't want to learn another tool. You just want to write code and that's it. Well you can construct your own nodes and attach handlers to them. See the pure code examples folder [here](https://github.com/treeform/fidget2/tree/master/examples/purecode).

## Node key properties and fields

`thisNode` is a `Node` that mirrors Figma’s model with extra runtime fields for interactivity, layout, and caching.

### Identity and type

* `id: string` - Stable unique id
* `name: string` - Node name from the design tool
* `kind: NodeKind` - One of `FrameNode`, `TextNode`, `RectangleNode`, etc
* `children: seq[Node]`, `parent: Node`
* `componentId: string`, `prototypeStartNodeID: string`

### Transform

* `position: Vec2` - Top left in parent coords
* `size: Vec2` - Width and height in px
* `scale: Vec2`, `rotation: float32`
* `flipHorizontal: bool`, `flipVertical: bool`

### Text

* `text: string` - Main way to get and set text.
* `style: TypeStyle` - Font family, size, weight, decoration, auto resize, etc
* `characterStyleOverrides: seq[int]`, `styleOverrideTable: Table[string, TypeStyle]`
* Helpers: `cursor: int`, `selector: int` (selection), `multiline`, `wordWrap`, `spans`, `arrangement`
* Undo or redo for text only: `undoStack`, `redoStack`

### Layout and constraints

* `constraints: LayoutConstraint` - (min, max, scale, stretch, center per axis)
* `layoutAlign: LayoutAlign`, `layoutMode: LayoutMode`
* `layoutGrids: seq[LayoutGrid]`
* `itemSpacing: float32`
* `counterAxisSizingMode: AxisSizingMode`
* Padding: `paddingLeft`, `paddingRight`, `paddingTop`, `paddingBottom`
* Overflow: `overflowDirection: OverflowDirection`

### Visuals and shape

* `fillGeometry: seq[Geometry]`
* `strokes: seq[Paint]`, `strokeWeight: float32`, `strokeAlign: StrokeAlign`
* `cornerRadius: float32`, `rectangleCornerRadii: array[4, float32]`
* `effects: seq[Effect]`, `blendMode: BlendMode`, `opacity: float32`, `visible: bool`
* Masking: `isMask`, `isMaskOutline`, `booleanOperation`, `clipsContent`

### Runtime and caching

* `dirty: bool` - Needs redraw
* `pixels: Image`, `pixelBox: Rect` - Render cache and bounds
* `editable: bool` - Whether the user can edit text
* `mat: Mat3` - World transform helper
* `collapse: bool` - Draw as a single texture (internal optimization)
* `frozen: bool`, `frozenId: string` - Snapshot linkage
* `shown: bool` - Visibility flag backing `onShow` or `onHide`
* Scrolling: `scrollable: bool`, `scrollPos: Vec2`


## How is it different form Fitget 1?

It is a little bit of a departure from the Fidget1 model, but the main idea is the same. You should not need to design a UI once in a design program like Figma, and then rebuild it again in code using boxes, elements, CSS, or whatever. The basic idea is that you design your UI in Figma, and it just stays in Figma forever. You take that UI and bring it into programming land. You add hooks, events, and small pieces of logic, but you continue to work with the design itself. You can always go back to the Figma file and modify it slightly, and you should not need to modify the code very much. If you add new nodes, new elements, or rename things, in your design: then you will need code changes. But if you only move things around or change colors, sizes, or fonts, then no code changes are necessary!

## Live reload.

One really cool aspect of this new system is that I use the Figma API directly. In Fidget1 you had to use a plugin to export Figma code. After export you could no longer really design, since the code was stuck. If you wanted to make changes you had to go back to Figma, export new code, and copy paste it in. That was cumbersome, and I wanted to fix it. That is why I went full Figma API. No more copying code around. The library connects to Figma and downloads the design directly.

Another cool feature is "live reload" using the F5 button. In development mode, every Fidget app has a keyboard shortcut. You press F5, and it reloads the Figma file. It fetches the new design and re-renders the app. If the names and node structure remain the same, it updates live without changes to the code. This means you can design and test features at the same time. A designer can run the app, make changes in Figma, press F5, and immediately see the new design in the live app. This makes very rapid iteration possible, something that designers have not had access to before.

## Testing

Another really important feature of Fidget2 is the extensive test suite. I have built a system that tests a very wide range of features, far beyond what most UI libraries even attempt. Most UI libraries just draw boxes, text, images, and maybe some clipping or masking. Fidget2 goes much further. It tries to support almost all Figma features, and hopefully in the future every single one. It supports masking modes, blending modes, vector operations, boolean operations, text features, components and component variants, multiple layout systems, layouts and more. Absolute layout and box layout, where you can pin things to corners or centers or make them stretchable, and auto layout, which stretches and skews based on parent constraints. The idea is that Figma is the source of truth. What you design in Figma should render the same in Fidget. The test suite enforces this. You can run it yourself with `tests/run_frames.nim` and see how broad the coverage is.

## Node addressing

I also thought a lot about how to address nodes. At first I looked at IDs like node 1, node 2, and so on, but that was very user-hostile. Nobody wants to attach a handler to node 3000. Then I looked at CSS selectors, but they are too complicated, with IDs and classes and specificity rules. The answer came from Figma itself. Every node has a name and a path with slashes, just like a file system. So Fidget represents nodes as a file system. You can use glob patterns like in a shell. A star matches unknown names, a question mark matches unknown characters, and double star matches across multiple levels. When you are in a handler and want to access a subnode, you can use relative paths or .. to go up a level. Every programmer already knows how file systems work, so this is a natural fit. The only major difference is that nodes can have exact same name wich is not true of files. There is also no file extensions, unless you add them.

In Fidget, action handlers are attached to glob paths, not nodes. This is powerful, because you can create or remove nodes freely. As long as they match the glob path, the handler will fire. This avoids a big mistake I beleave happened with HTML and JavaScript. In HTML, CSS selectors are used for styling, but not for events. You cannot see which handlers are attached to a node, and you cannot copy handlers easily. It is a mess. Fidget fixes this with a simple glob path system. Handlers are attached to paths, and if a node matches, it works. Easy and simple.

## Minimal and fully custom

Another thing I want to emphasize is philosophy. Many UI libraries give you complicated controls like tree views, tab controls, color pickers, and date pickers. They look simple, but once you try to style them, they become very cumbersome. Every app wants its own style. In Fidget2 I do not provide high level widgets like that. Instead, I provide simple Figma primitives from which you can build any control you need. This makes it easy to build advanced controls that match the style of your app.
