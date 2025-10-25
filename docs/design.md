# Fidget 2: A random walk down the rabbit hole.



## Introduction

Fidget is a UI system based on Figma.

It is not based on the browser DOM or any desktop API. Those are too complicated with CSS and too many extra features. They also grew over time in random directions and are now full of hidden parts that are hard to control.

It could have been based on SVG, but SVG also has CSS and lacks real layout features. It is good for static shapes but not for living UI.

When I found Figma, I saw it had a clear way to do layout and a simple way to build visual trees. Designers already use it and already know its model. So if I build a system that mirrors that model, I can bring design files into real running apps without translation pain.

Other tools exist. PenPot is one, but it is not popular. Adobe has tools too, but I do not like their style or bloat. Sketch used to be good and inspired me first, but Figma replaced it in everyway. That is why I chose Figma as the base idea for Fidget.



## Core Design

Fidget is a Node based UI system, kind of like the browser or desktop API, but it has notible departures from the traditional model.

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



## Document and Node Model

Fidget mirrors Figma's document tree.

- `INode` is the internal node type that the engine uses for layout and rendering. Users should not use this type directly.
- `Node` is a thin user-facing wrapper over `INode` for app code convenience. Mostly surves to set the dirty flags and some convenience methods.
- Nodes have kinds such as `Frame`, `Rectangle`, `Text`, `Ellipse`, `Vector`, `Component`, `Instance`, and boolean operations.
- Each node tracks transform, size, geometry, fills, strokes, effects, opacity, visibility, masking flags, and text style.
- There is no CSS or extermal styling. Everything is done in the node itself. But it does have system of master components and instances that sort of surve styleing purposes but they are just another node in the tree and not a different concept.

Parents own their children in a simple tree. The engine stores both original and current positions/sizes so constraints can compute new values relative to the original master design.

The current display frame node does not have to be the root node, in fact its common to have many entry nodes and switch between them based on the current state of the app.



## Loading and Schema

The `schema` defines all types that match Figma concepts: paints, effects, layout modes, constraints, text auto-resize, and more.

The `loader` builds a runtime tree of `INode` from design data. Components and instances are represented explicitly, and nodes get unique IDs and stable paths so they can be found later by glob patterns.



## Layout and Constraints

Layout tries to match Figma.

- Auto-layout supports `Vertical` and `Horizontal` modes with padding and `itemSpacing`.
- `Stretch` vs `Inherit` layout align is honored for the cross axis.
- Text can auto-resize height or both width and height depending on `textAutoResize`.
- Constraints support `Min`, `Max` (pin to right/bottom), `Scale` (proportional), `Stretch` (fill), and `Center`.
- Original position and size are preserved so constraints can compute relative results.

The Layout pass walks children first, then computes the parent. Layout writes each child's `position` within its parent and may adjust `size` when auto-resize or stretch applies. After layout, each node's pixel bounds and transform are known.



## Rendering: CPU and Hybrid

There are two renderers.

- CPU renderer renders shapes and text to images using Pixie. It is exact and simple to reason about. It serves as a correctness reference.
- Hybrid renderer uses GPU layers via Boxy where possible and falls back to CPU for complex nodes or when images must be generated. It maintains an atlas of per-node images keyed by node IDs and optional mask IDs.

Rendering proceeds in three passes:

1. Layout pass: For each node that will draw something and is dirty, generate or update its image. Text, fills, strokes, masks, and effects that require CPU are rendered into images sized to node pixel bounds. Simple images that can be drawn directly on the GPU are skipped here and handled at composite time.

2. Raster pass: For each node that will draw something and is dirty, generate or update its image. Text, fills, strokes, masks, and effects that require CPU are rendered into images sized to node pixel bounds. Simple images that can be drawn directly on the GPU are skipped here and handled at composite time.

3. Composite pass: Walk the tree and draw layers onto the screen. Nodes that require intermediate blending, masking, clipping, opacity, or background blur push temporary GPU layers, draw children, apply masks or effects, and then pop layers with the node's `blendMode` and opacity.

Effects supported include drop shadows, inner shadows, layer blur, and background blur. Background blur is implemented by sampling the lower composited content into a temporary layer, blurring it, masking it by the node's shape, and then compositing.

Right-to-left rendering flips the X axis when enabled. Content scaling from the window is applied to the root transform, so drawing remains pixel-perfect on HiDPI.



## Dirty Flags and Invalidation

Nodes set `dirty = true` when properties change. Some property sets, such as `size=` or text changes, mark the whole subtree dirty and clear cached text arrangements.

Before each frame, a quick pass propagates child dirtiness up to parents to ensure raster/composite see affected ancestors. If nothing is dirty, native builds may sleep to save CPU.



## Text and Editing

Text uses a typeset arrangement that is recomputed when content or style changes.

- `Fixed` keeps size fixed and draws with clipping if needed.
- `Height` auto-resizes height downwards.
- `WidthAndHeight` auto-resizes both dimensions to the text bounds.

Editable text uses a focused textbox model. When focused, cursor blink is timed per frame and the text node is marked dirty on toggles so the caret renders. IME is enabled while a textbox has focus. Mouse and keyboard events are routed to the focused textbox first.



## Events and Glob Selectors

Events are attached to node path globs, not to specific node instances. This keeps code short and expressive.

- Supported events include clicks, right-clicks, mouse move, display/frame ticks, show/hide, button press/release, drag start/drag/drag end/drop, resize, focus/unfocus, and edit.
- `find` and `findAll` resolve globs to nodes. A relative glob is resolved against the current `thisSelector` when dispatching an event.
- `OnDisplay` runs when `redisplay` is true, which is toggled by inputs and other triggers. `OnFrame` runs every frame regardless.
- Dragging is initiated after a small pixel threshold is exceeded while mouse left is down and the node has drag handlers.

Hover state is implemented by tracking the nodes under the mouse and toggling component variant properties such as `State=Hover` or `State=Down` when present.



## Hit Testing

Hit testing uses the same geometry used for drawing. The system computes which nodes are under the current mouse position in screen space after layout and transforms. This list is used for hovering, clicking, and drag targets.


## Window, Frame, and Timing

The platform layer provides a window, event pump, and content scale. The main tick does:

1. Process input and dispatch events.
2. Display: check dirty state, run layout if needed, raster dirty nodes, composite to the screen, and swap buffers.
3. Poll for the next batch of window events.

The root node size and the window size stay in sync. For resizable decorated windows, the root contents are scaled to the window content scale. Otherwise the window is resized to match the root document size.



## Components, Instances, and Variants

Components in the document act like masters. Instances can override specific properties. When an instance switches to a different master, a tri-merge keeps local overrides while adopting properties from the new master.

Variants (for example `State=Default/Hover/Down`) are implemented as named properties in node names. Utility helpers parse names into key-value pairs and let code set variants quickly.



## Performance Notes

- The hybrid renderer avoids re-rasterizing nodes that did not change. It compares bounds and fractional translations to decide if cached images can be reused.
- Simple images with `Fit` scale mode and no strokes or corner radius are drawn directly on the GPU.
- Raster images are stored in a cache keyed by resource IDs and added to the GPU atlas when first used.
- Masking and complex blend modes use temporary layers and only wrap nodes that need them.



## Code Conventions

This project follows simple, minimal-abstraction Nim conventions.

- Prefer clear data over deep abstraction.
- Keep modules focused, use singular names except for collections.
- Imports are grouped as std, external, then local.
- Use camelCase for variables/procs, PascalCase for types/constants/enums.

See the `AGENTS.md` document for full guidelines applied across the codebase.



## Platform Layer

Fidget is built on top of my own libraries.

**Boxy** handles the OpenGL rendering.
**Windy** handles the window and event layer across all platforms.

Windy gives one simple API for all systems. Because of that, Fidget does not care if it runs on Windows, Mac, Linux, or Emscripten.

Emscripten is treated like its own platform, the same as any other. Windy hides all the platform details, so Fidget can focus only on layout, drawing, and input.



