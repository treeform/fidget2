<img src="docs/banner.png">

👏 👏 👏 Check out video about the library: [Fidget: Let's rethink UI development with Nim (NimConf 2020)](https://www.youtube.com/watch?v=IB8Yt2dqZbo) 👏 👏 👏

# Fidget - A cross platform UI library for nim

⚠️ WARNING: This library is still in heavy development. ⚠️

`nimble install fidget2`

![Github Actions](https://github.com/treeform/fidget2/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/fidget2)

## About

Fidget aims to provide natively compiled cross platform UIs for any platform - Web with HTML5 (WASM), Windows, macOS, Linux with OpenGL.

Fidget leverages [Figma](https://www.figma.com/) - an app that is taking the design world by storm. Fidget uses Figma API to load designs directly. No more counting pixels, no more CSS puzzles. Want to change some spaces? Change it in Figma, press F5 in your see the changes in real time!


## Simple Example Counter:

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

## Getting the API key.

Before using the Figma API you will need a Figma account and the API key. After creating account go to your profile's settings, add new `Personal access token` and download your key and put it into `.figmakey` in your home directory or the root file of your project.

<img src="docs/figmaApiKey.png">

## Figma for Programmers

Figma is the fastest growing UI tool. Its demanded by almost all new UI job postings. Chances are your friendly UI designer knows of or users Figma.

If you don't know how to use Figma or how to do UI design I highly recommend giving Figma's YouTube channel a try: https://www.youtube.com/channel/UCQsVmhSa4X-G3lHlUtejzLA its full of great tutorials.

Figma also has a whole library of designs https://www.figma.com/community licensed under CC BY 4.0! Yes that means you can use these designs for free, by simply giving credit! Just duplicate them into your account, modify and remix them. The amount of high quality designs there can really boost any UI project!

"Let somebody else figure out how to make it look pretty, as long as you can move rectanges around you are good." - Ryan

## Philosophy

As an industry we design too much of the UI by hand. And we do it many times. A designer builds the UI. We throw that away. Then programmers code up layouts, set colors, and push pixels around. Sometimes several different times for web and mobile. It is madness.

Music is not coded by hand, we use tools. Images are not coded by hand, we use tools. Nor are 3D models, which can be very complex, they have editors and tools. Why do we do this for UI? Why has no good UI editor appeared? It is madness.

This happens because of the wrong programming model. What you want is the design side and the action side. The design side is a tree of nodes made in a UX design program like Figma. The action side is also a tree of event handlers, display functions, and other mutators. A designer should be able to change the design a bit and it should stay working. Likewise a programmer should be able to change the handlers and the design should not need to change. Like rigging a 3D model, you should be able to breathe life into a layout through code.
