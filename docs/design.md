# Fidget 2 Design Doc



## Introduction

Fidget is a UI system based on Figma.

It is not based on the browser DOM or any web API. Those are too complicated with CSS and too many extra features. They also grew over time in random directions and are now full of hidden parts that are hard to control.

It could have been based on SVG, but SVG also has CSS and lacks real layout features. It is good for static shapes but not for living UI.

When I found Figma, I saw it had a clear way to do layout and a simple way to build visual trees. Designers already use it and already know its model. So if I build a system that mirrors that model, I can bring design files into real running apps without translation pain.

Other tools exist. PenPot is one, but it is not popular. Adobe has tools too, but I do not like their style or bloat. Sketch used to be good and inspired me first, but Figma replaced it in most ways. That is why I chose Figma as the base idea for Fidget.



## Core Design

Fidget is a DOM based UI system, kind of like the browser, but that is where it stops being like the browser.

Fidget runs in three passes.

1. **Layout**
   Every node computes its size and position. This follows simple rules from Figma like horizontal and vertical layout, padding, and alignment.

2. **Raster**
   Once the layout is done, every node is rasterized into small rectangles. These rectangles are drawn into OpenGL textures. Every visual element owns its own rectangle.

3. **Composite**
   The rectangles are drawn onto the screen. This pass runs each frame and merges all the parts into one view.

Each node has dirty flags. When a node changes something visual, it marks itself dirty.
If a change affects layout, it also marks the layout dirty. That can move up or down the tree.
If a child grows, the parent might need to grow too.
If a parent shrinks, the children must fit again.

A layout change also makes the raster dirty, so it will redraw next frame. The composite pass is always active, but it only repaints areas that changed.

## Platform Layer

Fidget is built on top of my own libraries.

**Boxy** handles the OpenGL rendering.
**Windy** handles the window and event layer across all platforms.

Windy gives one simple API for all systems. Because of that, Fidget does not care if it runs on Windows, Mac, Linux, or Emscripten.

Emscripten is treated like its own platform, the same as any other. Windy hides all the platform details, so Fidget can focus only on layout, drawing, and input.



## Event System

The event system in Fidget is not like the browser.
In most systems, you attach handlers to nodes, like `onClick` on a button. Fidget does not work this way.

In Fidget, events are attached using glob patterns.
Glob patterns work like file paths. They are simple and familiar.
You can match single nodes or whole groups with one pattern.

This idea came from how Figma already organizes layers and nodes in a file tree. Using the same kind of structure for events makes sense.
CSS selectors could do this, but CSS is too complex. Glob patterns are easy and predictable.

Because of this, you can create many buttons in a loop and not attach a handler to each one.
You can define one event rule like `**/button*` and it will match all nodes that fit the pattern.
When an event happens, Fidget checks which nodes match the pattern and triggers the right handler.

This makes the code shorter and keeps the logic in one place instead of scattered across nodes.

One special event in Fidget is **onDisplay**.
This runs when the system thinks some code should update the view.
It acts like a reactive hook that fires when the node is visible or when redraw is needed.
You can use it to drive animations or dynamic content without setting up complex watchers.

The result is a clean and simple event model that matches how designers think in layers and how developers think in trees.



