@part Getting started
# Introduction

## What the engine is

The Neon Arcade Display Engine is a set of source files, written in PureBasic, that a PureBasic program includes to draw with OpenGL. It opens a window with an OpenGL context, draws everything into a canvas of a fixed size, and shows that canvas in the window at the largest size that keeps its shape. On top of that it provides:

- sprites, a sprite batcher that draws many sprites of one picture in one call, and instanced particles;
- text in any TrueType face the system can load, with a glyph cache that covers the whole of Unicode;
- tile sets and tile maps, with flipped, rotated and animated tiles and a map file;
- layers of tiles or sprites, with parallax, opacity and tint, and collision queries against tile maps;
- colour-indexed images and palettes, with palette cycling, fades and swaps done in the shader;
- collision tests: boxes, circles, pixel masks, convex polygons, lines;
- two user-interface kits: an arcade kit driven by a pointer or a D-pad, and an application kit of menus, tabs, buttons, text fields, lists and scroll bars that can also be driven without a pointer;
- a 3D renderer for glTF binary models with skinning, animation and simple spring bones;
- host services an application would otherwise ask the operating system for: a microsecond clock, keys, game pads, sound output, full screen, a second OpenGL context, worker threads, durable file writes, dirty-page tracking and network sockets.

It is meant for games and for applications that want the same look on Windows and Linux without calling either system themselves.

## What it needs

- **The language.** PureBasic, 64-bit. Every example in this manual was compiled with PureBasic 6.41 (Windows, x64).
- **OpenGL.** The engine's shaders are written for GLSL 1.40, which is OpenGL 3.1; `LoadModernGL` stops the program if the driver does not supply shaders, vertex array objects, framebuffer objects and instanced drawing. The palette look-up needs OpenGL 3.0 or later and checks for it (`GL_PaletteInit`). The 3D module needs OpenGL 3.3 and checks for it (`G3D_Init`).
- **Platforms.** The source has a Windows branch and a Linux branch for every call it makes to the operating system; those two are what it supports. Where a module has no branch for another system it refuses (the clock returns -1, the file store returns `#False`). On ARM processors the drawing procedures re-allocate their vertex buffers before each upload (the driver behaviour some ARM boards need); nothing else depends on the processor.
- **Linux specifics.** The engine runs on X11; `GL_HostPrepare` sets `GDK_BACKEND=x11` so that a Wayland desktop gives it an X11 window. It links `libGL`, `libX11` and `libasound`, and loads `libpulse-simple` at run time when a sound server is running.
- **Image decoders.** `LoadGLSprite` loads whatever PureBasic's `LoadImage` can read. The program enables the decoders it needs (`UsePNGImageDecoder()` and the others) before it loads a picture.

## Getting the source

The engine is its repository: clone it, or download an archive of it, and keep its files together in one folder. A program refers to that folder in its include lines (chapter 2). The repository holds:

| Path | What it is |
|---|---|
| `GlTypes.pbi` | the structures every other module uses: points, polygons, sprites, the arcade kit's gadget |
| `GlUtilities.pbi` | the window, the canvas, the camera, boxes, polygons, text and fonts, render targets, the draw log and the host services |
| `GlSpriteFunctions.pbi` | sprites, the sprite batcher, instanced particles |
| `GlMath.pbi` | collision tests and a Bezier curve |
| `GlTiles.pbi`, `GlPalette.pbi` | tile sets, tile maps, the map file; indexed images, palettes, the image file (`GlTiles.pbi` includes `GlPalette.pbi`) |
| `GlLayers.pbi` | layers, parallax, collision against tile maps |
| `GlUI.pbi`, `GlUIChrome.pbi` | the arcade kit; the application kit |
| `Gl3D.pbi` and `Gl3D*.pbi` | the 3D renderer (`Gl3D.pbi` includes the other five) |
| `GlClock.pbi`, `GlFile.pbi`, `GlMemoryWatch.pbi`, `GlNet.pbi` | the wall clock, the durable file store, dirty-page tracking, sockets |
| `opengl_*.pbi` | the OpenGL constants, extension and version flags and function prototypes (`GlUtilities.pbi` includes them) |
| `assets/fonts/` | the open typefaces Lato and JetBrains Mono and their licences |
| `examples/` | `TileWorld.pb` (tile layers, palettes, collision) and `WidgetGallery.pb` (every widget of both kits) |
| `tools/` | the check programs that prove the engine's behaviour (appendix B) |
| `tests/` | two console tests: the idle wait and the network sockets |
| `docs/` | this manual and its sources |

## Which files to include, and in what order

A program includes the modules it uses, each once, in this order; a module needs the ones listed before it in its row.

| Module | Needs, included before it |
|---|---|
| `GlTypes.pbi` | nothing; always first |
| `GlUtilities.pbi` | `GlTypes.pbi` |
| `GlMath.pbi` | `GlTypes.pbi` |
| `GlFile.pbi`, `GlClock.pbi`, `GlMemoryWatch.pbi`, `GlNet.pbi` | nothing of the engine (`GlNet.pbi` is placed after `GlUtilities.pbi` by convention) |
| `GlSpriteFunctions.pbi` | `GlTypes.pbi`, `GlUtilities.pbi` |
| `GlTiles.pbi` | `GlSpriteFunctions.pbi`, `GlFile.pbi`; it brings `GlPalette.pbi` |
| `GlLayers.pbi` | `GlTiles.pbi` |
| `GlUI.pbi` | `GlUtilities.pbi`, `GlMath.pbi` |
| `GlUIChrome.pbi` | `GlUI.pbi` |
| `Gl3D.pbi` | `GlUtilities.pbi`; it brings `Gl3DMath.pbi`, `Gl3DLoader.pbi`, `Gl3DAnimation.pbi`, `Gl3DRender.pbi`, `Gl3DMesh.pbi` |

A module is included with `XIncludeFile`, so naming a file twice is harmless. The engine's modules find the binding files and their own sub-files beside themselves, wherever the program is.

## Building a program

On Windows, from a command prompt, with the program's include lines pointing at the engine's folder:

```
pbcompiler Game.pb /EXE Game.exe /THREAD /DPIAWARE
```

On Linux the switches are spelled differently: `/EXE` is `-o`, `/THREAD` is `-t`, `/CONSOLE` is `-cl`, and there is no DPI switch (the scale is read at run time, chapter 3):

```
pbcompiler Game.pb -o Game -t
```

- `/THREAD` builds the thread-safe runtime. The engine's worker (`GL_WorkerCreate`) needs it, and the engine's own examples are built with it.
- `/DPIAWARE` is required on Windows. Without it, Windows draws the whole window magnified by the desktop's scale factor, so a 1180-unit-wide layout becomes 1475 pixels wide at 125 percent and can run off the monitor, and the text is soft.
- A program with no window (the console examples of this manual, the check tools) is built with `/CONSOLE` (`-cl` on Linux).
