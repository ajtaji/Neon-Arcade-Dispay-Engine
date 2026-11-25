# Neon Arcade Display Engine

A PureBasic rendering and user-interface framework built on OpenGL. The engine uses a fixed-resolution framebuffer for game rendering, preserves aspect ratio when the window changes size, and maps input back into virtual-canvas coordinates.

## Current features

- OpenGL constants, extensions, feature flags, and procedure bindings
- Window and OpenGL context setup for Windows and Linux
- Fixed-resolution framebuffer rendering with letterboxing
- Camera translation and zoom
- Sprite loading, batching, animation data, and instanced particles
- AABB, circle, pixel-perfect, SAT, and line collision helpers
- Tile sets and tile maps: flipped and rotated tiles, animated tiles, a map file
- Layers of tiles or sprites with parallax, opacity, tint and draw order; tile collision queries
- Colour-indexed images and palettes: swap, cycle and fade, drawn by a palette look-up in the shader
- Runtime glyph caching with Unicode code-point lookup and paged texture atlases
- Immediate-mode neon UI controls and application chrome
- The UI driven by a game pad or keys alone (`Neon_ChromeBeginNav`), the UI's typefaces selectable, a widget gallery and a UI check
- A draw log: what was drawn as a list (kind, rectangle, colour, text, clip), for checks that do not compare pixels
- CRT and passthrough presentation paths
- HiDPI-aware viewport and input mapping

## Requirements

- PureBasic
- An OpenGL-capable desktop environment

The platform-specific code currently covers Windows and Linux. Applications are responsible for selecting the PureBasic subsystems they use, such as image decoders, before loading assets.

## Include order

Place the engine files where the compiler can resolve the include paths, then include the modules needed by the application:

```purebasic
XIncludeFile "GlTypes.pbi"
XIncludeFile "GlUtilities.pbi"
XIncludeFile "GlMath.pbi"
XIncludeFile "GlSpriteFunctions.pbi"
XIncludeFile "GlUI.pbi"
XIncludeFile "GlUIChrome.pbi"
```

`GlUtilities.pbi` loads the OpenGL binding files. `GlUI.pbi` uses the collision helpers in `GlMath.pbi`. `GlUIChrome.pbi` provides the higher-level application chrome and can be omitted when it is not needed.

## Optional 3D module

Include `Gl3D.pbi` after `GlUtilities.pbi` for desktop OpenGL 3.3 and up.
Create the window as usual, call `InitRetroCRT`, capture the window context
with `GL_ContextCapture`, and initialize a `G3DPass` with `G3D_Init`.
The pass owns a depth renderbuffer on the existing Neon canvas. With
`Util_FBO` bound, render between `G3D_Begin` and `G3D_End`, draw the UI,
then present with `DrawPassthrough` or `DrawRetroCRT`. Free models with
`G3D_Free` and release the pass with `G3D_Shutdown` before closing the
owning context.

`G3D_Load` reads a glTF 2.0 `.glb` with PureBasic’s JSON reader. The loader
accepts triangle primitives with float positions and normals, indexed or
non-indexed geometry, one embedded buffer, and up to four joint influences
per vertex. It supports TRS and matrix nodes, inverse bind matrices, and
opaque factor-based metallic, roughness and emissive materials, including
emissive strength. Reflection comes from a studio environment defined in
the shader. External buffers, texture maps, sparse accessors, compressed
mesh extensions and morph targets are outside the current format support.

Use `G3D_Play(model, clip, blendSeconds)` for looping clips and crossfades,
`G3D_Update(model, deltaSeconds)` to advance animation and springs, and
`G3D_Draw(model, camera)` during the pass. The CPU builds the joint palette
and the vertex shader skins the vertices. `G3D_Spring` enables gravity and
damped motion for a named bone. `G3D_Impulse(model, x, y, z)` applies a
velocity impulse in model space. `G3D_Load` enables springs for common bust
and hip secondary-bone names. Use `G3D_LookAt` for a perspective camera and
`G3D_Mesh` to upload procedural triangles.

Applications can supply a vertex projection to the 3D pass when they
initialize it. Pass GLSL defining
`projectVertex(inout vec3 point, inout vec3 normal)` to `G3D_Init`.
Set its four `projectionParams` values with `G3D_SetProjection` between
`G3D_Begin` and `G3D_End`. The default pass uses the supplied mesh
positions and normals directly.

## Network host services (`GlNet.pbi`, optional)

`XIncludeFile "GlNet.pbi"` after `GlUtilities.pbi` gives an application TCP and UDP sockets and name resolution
without calling the OS: `GL_NetInit`, `GL_NetOpen`, `GL_NetBind`, `GL_NetListen`, `GL_NetAccept`, `GL_NetConnect`,
`GL_NetSend`/`GL_NetSendTo`, `GL_NetRecv`/`GL_NetRecvFrom`, `GL_NetPoll`, `GL_NetShutdown`, `GL_NetClose`,
`GL_NetResolve`, `GL_NetLocalPort`, `GL_NetError`. Windows uses ws2_32.dll and Linux uses libc, both loaded at run
time. Every socket is non-blocking, and every failure is a fixed result code (`#GL_NET_*`, the same on both
systems), never an assert. The one call that waits is `GL_NetResolve`, which uses the system resolver. The model
and the codes are at the top of the file. `tests/GlNetTest.pb` proves loopback TCP and UDP (31 checks; run on
Windows and on Linux).

**Security.**
- Nothing listens unless the application calls `GL_NetListen`, or binds a UDP socket. `GL_NetInit` opens nothing.
- Bind to loopback (`127.0.0.1` / `::1`) unless the user asked for the network. `0.0.0.0` or `::` is reachable from
  every machine that can reach this one. The engine never chooses an address for you.
- An emulator that hands sockets to a guest program gives untrusted code network access with the user's rights. Put
  a policy in front of it (what may be connected to, what may listen, whether at all), off by default. The engine
  is the mechanism; the policy is the application's.
- Received bytes come from anyone. `GL_NetRecv` never writes past its capacity. On Linux, a send to a closed peer
  returns `#GL_NET_RESET` and raises no SIGPIPE.

## Rendering flow

The usual frame renders the game into the engine framebuffer and then presents that framebuffer to the window:

```purebasic
glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)

; Draw the game world and interface here.

glBindFramebuffer(#GL_FRAMEBUFFER, 0)
glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
DrawRetroCRT() ; or DrawPassthrough()
```

Set `Util_BaseWidth` and `Util_BaseHeight` to the authored canvas size. Call `GL_HandleResize()` after creating the window and whenever PureBasic reports a window-size event. Pass mouse coordinates through `MapPhysicalToVirtual()` before UI hit testing.

**On Windows, give it `WindowMouseX(Win)` / `WindowMouseY(Win)` exactly as they are.** In a DPI-aware window they are already physical pixels (measured: 400 at physical x = 400 on a 125% desktop), while `WindowWidth`/`GadgetWidth` are logical. Multiplying the mouse by the scale, by `DesktopResolutionX()` or by physical/logical "to convert it" scales it twice. For a 1:1 application also set `Neon_UIScale` to physical/logical and build the fonts at that scale, or the chrome's tabs, rows and menus are sized at 100% beside a 125% layout. The full, measured checklist is section 5a of the hosting block in `GlUIChrome.pbi`.

For DPI-aware builds, enable PureBasic's **DPI aware** compiler option.

## Building an application against the engine

The engine's location is passed in, so no file needs editing per machine
(the trailing slash matters):

**Windows** (x64, from PowerShell)

```
pbcompiler App.pb /EXE App.exe /THREAD /DPIAWARE ^
   /CONSTANT GL_ENGINE_DIR$=C:/path/to/engine/
```

**Linux** — the flags differ: `/EXE` → `-o`, `/CONSOLE` → `-cl`, `/THREAD` → `-t`

```
pbcompiler App.pb -o App -t \
   --constant GL_ENGINE_DIR$=/path/to/engine/
```

`/DPIAWARE` is Windows-only and is not optional there: without it the OS
scales the whole window by the desktop factor, so a 1180-wide layout becomes
1475 at 125% and runs off the monitor. Linux has no equivalent switch and
needs none — GTK reports the backing scale at run time into `Linux_DPIScale`.

### Before you write any drawing code

Two comment blocks carry the things that otherwise get rediscovered:

- **`GlUtilities.pbi`, "HiDPI: THE FIVE THINGS"** — DPI, window sizing, the
  authored canvas, font sizing, and the three size globals and their units.
- **`GlUIChrome.pbi`, "HOSTING THIS ENGINE IN AN APPLICATION"** — the host
  checklist: let `OpenGLWindow()` make the window (it compiles the shaders
  every `Neon_` call needs), assign the chrome's four font globals, the
  per-frame pipeline, pixel snapping for sharp text, and `Neon_S()`.

- **`GlUtilities.pbi`, "HOST SERVICES"** — everything an application needs
  from the OS beyond a window, with a Windows and a Linux branch each, so the
  application itself never calls the OS: `GL_HostPrepare()` (first thing),
  a microsecond clock, physical core count, large zeroed memory, keys held and
  key names, full screen on the window's monitor, the pointer, the program's
  load address for crash reports, a second GL context for a worker thread,
  16-bit stereo sound out, the work area and the window's place, and game
  controllers. An application that needs something more from the OS adds it
  there, documented, rather than calling the OS itself.

Every item in both lists produces a *wrong-looking UI* rather than an error:
a blank window, controls with frames but no labels, soft text, or widgets
that vanish inside a scissor. None of them raise anything.

`GlClock.pbi` provides `GL_UtcMicroseconds()`: the host wall clock as Unix
microseconds in UTC, using Windows FILETIME or Linux CLOCK_REALTIME. It is
separate from the monotonic `GL_Micros()` timer and returns -1 when unavailable.
It inherits the host's time synchronization; it does not contact a time server
or apply a local timezone. Zentaji uses a recorded boot sample to seed its RTC.

## Tile maps (`GlTiles.pbi`, optional)

`XIncludeFile "GlTiles.pbi"` after `GlSpriteFunctions.pbi` (and `GlFile.pbi`, which saves the map file).
`GL_TileSetCreate(*Sprite, TileW, TileH, Spacing, Margin)` cuts a sprite sheet into tiles numbered left to
right, top to bottom from 0; a set holds at most 4095. `GL_TileMapCreate(Width, Height, *Set)` makes an empty
grid of 16-bit cells. `GL_TileMapSet(*Map, X, Y, Tile, Flags)` puts a tile in a cell, or `#GL_TILE_EMPTY`;
the flags are `#GL_TILE_FLIPX`, `#GL_TILE_FLIPY`, `#GL_TILE_DIAG` and the rotations `#GL_TILE_ROT90`,
`#GL_TILE_ROT180`, `#GL_TILE_ROT270` (applied as Tiled applies them). `GL_TileMapGet` and
`GL_TileMapFlags` read a cell back. A change shows on the next draw.

`GL_TileMapDraw(*Map, MapX, MapY, R, G, B, A, Scaled, IgnoreCamera, TimeMs)` draws the map with its top-left
corner at `MapX, MapY` through the 2D camera, placed as `DrawGLSprite` places a sprite. Only the cells the
camera can see are submitted, into the sprite batcher, so a whole screen of one tile set is one `glDrawArrays`:
a 320x240 canvas of 16x16 tiles is at most 21 x 16 = 336 quads, and a batch holds 10000. The map may be any
size up to 65535 x 65535 cells. Draw maps outside the program's own `BeginBatch` / `EndBatch`. Each draw counts
its calls in `GL_StatDrawCalls`. `GL_TileMapRange` tells which cells a draw would submit, and
`GL_TileMapSubmit` adds them to a batch the program has begun, so maps that share a sheet can share one call.

`GL_TileSetAnimAdd(*Set, Tile, FrameTile, Ms)` gives a tile frames; every cell that holds the tile shows the
frame for the time, keeping the cell's flips. The time is `GL_Micros() / 1000` unless `TimeMs` is passed.

```purebasic
*Sheet = LoadGLSprite("tiles.png")
*Set = GL_TileSetCreate(*Sheet, 16, 16)
GL_TileSetAnimAdd(*Set, 40, 40, 150) : GL_TileSetAnimAdd(*Set, 40, 41, 150)   ; water
*Map = GL_TileMapCreate(200, 30, *Set)
GL_TileMapFill(*Map, 0, 25, 200, 5, 3)
GL_TileMapSet(*Map, 10, 24, 7, #GL_TILE_FLIPX)
; each frame, inside the canvas
GL_CameraX = PlayerX - Util_BaseWidth / 2
GL_TileMapDraw(*Map, 0, 0, 1, 1, 1, 1, #True)
```

`GL_TileMapSave(*Map, Path, SaveSet)` writes the map file through `GL_FileStore` (into `Path.new`, which then
replaces `Path`); `GL_TileMapLoad(Path, *Set, Index)` reads tile layer `Index` back and `GL_TileSetLoad(*Set,
Path)` reads the set's animations (and collision table) from the same file. Failures return 0 and say why in
`GL_TileError()`.

**The map file (`.ntm`).** Big-endian. Header: `"NTMP"`, version (2 bytes, 1), number of chunks (2). Then
chunks: a 4-byte id, a 4-byte payload length, the payload, zero bytes to a multiple of 4. A reader skips ids it
does not know.

| Chunk | Payload |
|---|---|
| `MAP ` | width, height, tile width, tile height (2 bytes each), then width x height cells (2 bytes each), row 0 first. One chunk per tile layer, back to front. |
| `ANIM` | entries (2); each: tile (2), frames (2), then per frame tile (2) and milliseconds (2) |
| `TFLG` | count (2), then one collision byte per tile (see layers) |
| `TPAL` | count (2), then one palette slot per tile of an indexed set (see palettes) |

A cell: bits 0-11 the tile number + 1 (0 is an empty cell), bit 12 diagonal, bit 13 reserved (0), bit 14 flip
X, bit 15 flip Y - the tile word of the console's 2D engine (LibPureMetalN64 `lpm_2d_tile`), so one map file
serves both. `tools/tiles_check.py` proves the cut of a sheet, the cells submitted for 400
camera positions against a pass over every cell, the eight orientations, animation by the clock and the file
round trip; `tools/draw_check.py` draws maps into a render target of an invisible window and compares every
pixel with a CPU reference.

## Layers and tile collision (`GlLayers.pbi`, optional)

`XIncludeFile "GlLayers.pbi"` after `GlTiles.pbi`. `GL_LayersCreate()` makes a set of layers;
`GL_LayerAddTiles(*Layers, *Map, Order)` and `GL_LayerAddSprites(*Layers, Order)` add one.
`GL_LayersDraw(*Layers, Scaled, TimeMs)` draws them back to front: the lowest `Order` first, equal orders in the
order they were added (`GL_LayerSetOrder` moves one). A layer's fields are set directly: `X`, `Y` (where its
top-left sits), `ScrollX`, `ScrollY`, `ParallaxX`, `ParallaxY` (1 moves with the world, 0.5 half as fast, 0 not
at all), `Opacity`, `TintR`, `TintG`, `TintB`, `Visible`, and `Fixed`, which pins the layer to the screen in
canvas pixels for a UI layer. A layer's content point P is drawn at the world position
`X - ScrollX + P + GL_CameraX * (1 - ParallaxX)`; `GL_LayerOrigin` returns it for P = 0. The camera's zoom
applies to every layer that is not fixed.

`GL_LayerSpriteAdd(*Layer, *Sprite, X, Y)` returns an entry whose fields can be changed at any time: `W`, `H`
(drawn size), `Angle`, `SrcX`, `SrcY`, `SrcW`, `SrcH` (a part of the picture, rows counted from the top on every
OS), `Orient` (the tile flips and rotations), `R`, `G`, `B`, `A`, `Visible`. A sprite layer batches consecutive
sprites on one sheet into one draw call and skips sprites off the canvas; a tile layer is one call per screen.

```purebasic
*World = GL_LayersCreate()
*Sky = GL_LayerAddTiles(*World, *SkyMap, 0) : *Sky\ParallaxX = 0.25 : *Sky\ParallaxY = 0
*Hills = GL_LayerAddTiles(*World, *HillMap, 1) : *Hills\ParallaxX = 0.5
*Ground = GL_LayerAddTiles(*World, *GroundMap, 2)
*Actors = GL_LayerAddSprites(*World, 3)
*Hero = GL_LayerSpriteAdd(*Actors, *HeroSheet, 100, 180)
*Hud = GL_LayerAddTiles(*World, *HudMap, 9) : *Hud\Fixed = #True
; each frame
*Hero\X = PlayerX : *Hero\SrcX = Frame * 16 : *Hero\SrcW = 16 : *Hero\SrcH = 24
GL_LayersDraw(*World, #True)
```

**Collision.** `GL_TileSetCollision(*Set, Tile, Kind)` gives each tile a collision byte: `#GL_TILE_SOLID`,
`#GL_TILE_ONEWAY` (stops things from its top side only) or `#GL_TILE_SLOPE` (45 degrees, solid below the line
from the bottom-left to the top-right corner). A cell's flips and rotations turn the slope and the one-way side
with the picture. The table is saved in the map file (`TFLG`). The queries follow `GlMath.pbi`:

```purebasic
NewList Hits.GLTileHit()
If CheckCollisionTileBox(*Map, MapX, MapY, X, Y, W, H, Hits())    ; or CheckCollisionLayerBox(*Ground, X, Y, W, H, Hits())
  ; inside a solid part
EndIf
ForEach Hits()        ; every non-empty cell the box overlaps: Col, Row, Tile, Flags, Kind, Blocks
  If Hits()\Kind & #GL_TILE_ONEWAY And VelocityY > 0 And Hits()\NormalY < 0 And OldBottom <= Hits()\Row * 16 + MapY
    ; landed on a platform
  EndIf
Next
```

`CheckCollisionTileCircle(*Map, MapX, MapY, CX, CY, Radius, Hits())` and `CheckCollisionTileLine(*Map, MapX,
MapY, X1, Y1, X2, Y2, Hits())` work the same; a line's hits are nearest first, each with `T` (0..1) where the
line enters the cell, or its solid part when `Blocks`. The `Layer` forms use the layer's origin. Touching an
edge is not overlapping, so a box standing exactly on the floor hits nothing. `tools/layers_check.py` proves the
draw order, the parallax arithmetic at 300 camera positions, the sprite quads, and 600 each of boxes, circles
and lines against a slow reference that visits every cell by other methods; `tools/draw_check.py` draws a
parallax layer, a half-transparent flipped sprite layer and a fixed layer and compares every pixel.

## Palettes and indexed images (`GlPalette.pbi`, comes with `GlTiles.pbi`)

An indexed image is a picture of colour numbers, one byte a pixel, with up to eight palettes in slots.
`GL_IndexedCreate(Width, Height, *Indices)` makes one; `GL_IndexedSet` / `GL_IndexedGet` change and read a pixel;
`GL_IndexedPalette(*Img, Slot, *Pal)` puts a palette in a slot; `GL_IndexedFromImage(Img, *Pal)` turns a
PureBasic image of up to 256 colours into one, adding its colours to the palette. `GL_PaletteCreate(Count)` makes
a palette of up to 256 `RGBA()` colours; an entry whose alpha is 0 is transparent. A palette keeps the colours as
set (`GL_PaletteSet`, `GL_PaletteGet`) and as shown (`GL_PaletteShown`). The operations work on the shown
colours, in the order called, and `GL_PaletteReset` puts the set colours back:

- `GL_PaletteCycle(*Pal, First, Count, Steps)` rotates a range; `GL_PaletteCycleTime(*Pal, First, Count, StepMs,
  TimeMs)` rotates it one step every `StepMs` by the clock (worked out from the time, so it does not drift)
- `GL_PaletteFade(*Pal, Colour, Amount, First, Count)` mixes toward a colour, alpha kept;
  `GL_PaletteFadeTo(*Pal, *Other, Amount, First, Count)` mixes toward another palette, all four channels. Every
  channel is `(a * (256 - k) + b * k + 128) >> 8` with `k = Amount * 256` rounded - whole numbers, the same on
  every back end
- swapping: `GL_IndexedDraw(*Img, X, Y, *Pal, Slot, Angle, Scale, R, G, B, A, Scaled, SrcX, SrcY, SrcW, SrcH,
  IgnoreCamera, Orient)` draws as `DrawGLSprite` does with any palette; `GL_LayerImageAdd(*Layer, *Img, X, Y,
  *Pal)` gives a sprite its own palette; `GL_LayerPalette(*Layer, Slot, *Pal)` replaces a slot for a whole layer

`GL_TileSetCreateIndexed(*Img, TileW, TileH, Spacing, Margin)` cuts tiles from an indexed image, and
`GL_TileSetPaletteSlot(*Set, Tile, Slot)` picks the palette each tile is drawn with, so one image shows several
palettes at once.

```purebasic
*Water = GL_PaletteCreate() : *Night = GL_PaletteCreate()
; ... GL_PaletteSet the colours; entry 0 transparent
*Img = GL_IndexedLoad("world.nti")                ; indices and their palettes
*Set = GL_TileSetCreateIndexed(*Img, 16, 16)
*Base = GL_IndexedPaletteOf(*Img, 0)
; each frame
GL_PaletteReset(*Base)
GL_PaletteCycleTime(*Base, 200, 8, 120)           ; the waterfall's eight blues
GL_PaletteFade(*Base, RGBA(0, 0, 40, 255), Dusk)  ; evening falls
GL_LayersDraw(*World, #True)
```

The OpenGL back end looks the colour up in the fragment shader: the indices are an R8 texture, each palette in
use is one row of a 256 x 256 texture, and every vertex carries its palette's row, so tiles and sprites with
different palettes are still one draw call. A changed palette re-sends its row (1 KB) at its next draw; the
indices are sent again only after `GL_IndexedSet`. It needs GLSL 1.30 and R8 textures (OpenGL 3.0), inside what
the engine already requires. `GL_IndexedToSprite(*Img, *Pal)` and `GL_IndexedBake(*Img, *Pal, *Sprite)` re-colour
on the CPU into an ordinary sprite - width x height look-ups and an upload every time the palette changes - for
code that needs a `GLSprite`. `GL_PaletteShutdown()` frees the back end before the context goes;
`GL_IndexedFree` frees an image's texture.

**The indexed image file (`.nti`)**, also a palette file with no image chunk: big-endian, header `"NTIX"`,
version (2, 1), number of chunks (2), then chunks as the map file.

| Chunk | Payload |
|---|---|
| `IDX8` | width, height (2 each), then one byte a pixel, row 0 first |
| `IDX4` | width, height (2 each), then two pixels a byte, the first in the high half, each row starting on a byte |
| `PAL ` | slot (1), 0 (1), count (2), then the colours as R, G, B, A bytes (`$RRGGBBAA`) |

`GL_IndexedSave(*Img, Path, Packed)`, `GL_IndexedLoad(Path)` (the image then owns its palettes),
`GL_PaletteSave(*Pal, Path)`, `GL_PaletteLoad(Path, Slot)`; failures say why in `GL_PaletteError()`.
`examples/TileWorld.pb` puts the three together: a starry sky, far hills and the ground at three parallax
speeds, two heroes that share one picture and differ by palette, a status strip fixed to the screen, water and
stars cycling by the clock, coins as animated tiles, D for dusk (a fade), arrows to scroll, the heroes standing
on the ground through the collision queries. Five draw calls a frame. Build it with
`pbcompiler TileWorld.pb /EXE TileWorld.exe /THREAD /DPIAWARE` in its folder.

`tools/palette_check.py` proves the cycles, the clock, 2000 fades and 300 palette fades against references, their
order, the slot rules, the look-up, pictures and the file; `tools/draw_check.py` draws an indexed map with two
palettes, after a cycle and a fade, with a layer's swap, two sprites with their own palettes in one call, and the
CPU re-colour, and compares every pixel with the CPU look-up.

## The widget gallery (`examples/WidgetGallery.pb`)

Every widget and call of `GlUI.pbi` and `GlUIChrome.pbi`, in every state it has, laid out with the kit's public
calls on a 1280 x 720 canvas, on four screens chosen by a tab strip under the menu bar:

| Screen | What is on it |
|---|---|
| Arcade (GlUI) | a label, a breadcrumb, three buttons (one widened to its label), a slider, two toggles (on, off), three meters (empty, the slider's level, full), a DIP bank of eight, a carousel; hover and focus by mouse or pad |
| Controls | the chrome's buttons (normal, lit, disabled); the five faces; right-aligned and centred text; box, frame, glow; one text cut to nine widths with the ellipsis (and a cut that must not split an accent or a surrogate pair); three text inputs (placeholder, caret, a text that scrolls; Ctrl+A / C / X / V, Home, End, Backspace, Delete, Return, Esc); vertical and horizontal scroll bars over clipped content, and one with nothing to scroll; what the kit reports (`Neon_HoverIdAt`, `Neon_MenuBlocksMouse`, the navigation focus, `Neon_S`, the faces, `Neon_TabEscape`, `Neon_IsJoinedUnit`, `Neon_Animate`) |
| Lists and tabs | a tab strip with close boxes, an italic tab and a pinned one; a strip of 24 tabs that scrolls; labels holding a bar and an ESC; `Neon_TabAt`; a list of 78 rows in a box of 26 (groups, indents, details, a label cut short), an empty list, one that fits |
| Event log | every GlUI callback and every action a chrome widget reported, in the order it happened |

The menu bar is on every screen: shortcuts, separators, check marks, a disabled item, submenus, and a menu of 60
items that scrolls. View > Faces switches the typefaces (below).

It is driven as any engine program is, by the mouse and the keys, or by a game pad (`GL_PadRead`): the D-pad moves
the focus (up / down) and the value (left / right), A acts, B goes back, the right stick scrolls, the triggers
page, the shoulder buttons change screens. F5 plays the gallery's script with the mouse and keys, F6 the same
script with the pad's actions. The screens, the event log and the script are in
`examples/WidgetGalleryScreens.pbi`, which the UI check includes, so the check drives exactly what the gallery
shows. Build it with `pbcompiler WidgetGallery.pb /EXE WidgetGallery.exe /THREAD /DPIAWARE` in its folder;
`--faces open` starts it with the open faces.

## Driving the chrome without a pointer (`Neon_ChromeBeginNav`)

GlUI's widgets always took a D-pad: `Neon_UpdateInput(... DPadX, DPadY, ActionPressed)`. The chrome took only a
pointer. Now a host without one - a game pad, a remote, the keys alone - calls, once a frame, **in place of**
`Neon_ChromeBeginFrame`:

```purebasic
Neon_ChromeBeginNav(Action, Dt [, KeyChar])
```

and draws its frame exactly as before. The things that can have the focus are the ones the chrome already
declares as it draws: its hot zones (every button, menu name and item, submenu row, tab, close box, tab arrow,
text field, list row and scroll-bar thumb), in the order drawn. While a menu is open only the menu bar and its
drop-downs take part.

| Action | Does |
|---|---|
| `#NEON_NAV_NEXT` / `#NEON_NAV_PREV` | the focus to the next / previous control, round the end |
| `#NEON_NAV_ACTIVATE` | a click on the focused control (the button comes up on the next frame by itself); on the text field that already has the keyboard, Return (it submits) |
| `#NEON_NAV_BACK` | Escape: closes a menu, lets a text field go |
| `#NEON_NAV_LEFT` / `#NEON_NAV_RIGHT` | the Left / Right keys (a text field's caret) |
| `#NEON_NAV_UP` / `#NEON_NAV_DOWN` | one notch of the wheel over the focus: a list or a long drop-down scrolls, a scrolling tab strip steps a tab |
| `#NEON_NAV_PAGEUP` / `#NEON_NAV_PAGEDOWN` | a page of what scrolls under the focus: a scroll bar (as a click on its track), a list, a long drop-down |
| `#NEON_NAV_NONE` | nothing; the focus stays |

The pointer is put on the focus: the kit's snapshot is filled as if a mouse sat at the centre of the focused
control, so every widget does what it does for a mouse, by the same code, and the focused control shows the look
it has under a pointer - that hover look is the focus mark. The focus follows its control across frames by the
control's identity; when the control is gone (scrolled away, its menu closed) the focus goes to the nearest
control, or back to the menu's name on the bar. `Neon_NavOn` says a frame was driven this way, `Neon_NavID` and
`Neon_NavX / Y / W / H` say where the focus is. A host with both calls `Neon_ChromeBeginFrame` on the frames the
mouse moves and `Neon_ChromeBeginNav` on the others. A pad cannot drag a scroll bar's thumb (it pages instead), and
types only what the host passes as `KeyChar` (an on-screen keyboard). A host that never calls it sees no change.

```purebasic
; a pad's frame; Pressed() is the host's own "went down this frame" test of its pad
; (GlUI on the same screen takes DPadY / DPadX / ActionPressed as it always did)
If Pressed(#Up) : a = #NEON_NAV_PREV : ElseIf Pressed(#Down) : a = #NEON_NAV_NEXT
ElseIf Pressed(#A) : a = #NEON_NAV_ACTIVATE : ElseIf Pressed(#B) : a = #NEON_NAV_BACK : Else : a = #NEON_NAV_NONE : EndIf
Neon_ChromeBeginNav(a, dt)
; ... draw the frame, menus last ...
Neon_ChromeEndFrame()
```

`Neon_ChromeReset()` forgets everything the chrome remembers between frames (hover fades, scroll positions, list
counts, measured menus, the open menu, the keyboard, the focus), so the next frame is drawn as the first was - for
a host that replaces its whole screen, and for a check or a replayed script.

## The typefaces (`Neon_SetFaces`, `Neon_UseFaceSet`, `Neon_ChromeFonts`)

The chrome draws through five fonts the host gives it (`*Neon_FontUI`, `Small`, `Bold`, `Mono`, `Italic`). The
typefaces they are made from are now selected:

- `Neon_SetFaces(UIFace, MonoFace [, UIFile, MonoFile])` names the proportional and the monospaced face; with a
  file, the file is registered for the process first (`RegisterFontFile`) and the name is the family it holds.
  A file that cannot be registered is refused: `#False`, the reason in `Neon_FaceError()`, the selection as it was.
- `Neon_UseFaceSet(Set [, FontDir])` picks one of the two documented sets: `#NEON_FACES_WINDOWS` ("Segoe UI",
  "Consolas", the default) or `#NEON_FACES_OPEN` ("Lato" from `Lato-Regular.ttf`, "JetBrains Mono" from
  `JetBrainsMono-Regular.ttf`, both SIL Open Font License 1.1, in `assets/fonts/`).
- `Neon_ChromeFonts(Scale)` makes the five from the selection at the sizes of the hosting notes (UI 14, small
  12, bold 15, mono 13, italic 14 pixels, times Scale), snapped to the pixel, replacing the five it made before.

Nothing changes for a program that never calls them: the selection starts as Segoe UI and Consolas, and fonts a
host makes itself are never touched. Bold and italic of a face registered from one regular file are the system's
own emboldened and slanted forms. `assets/fonts/FONTS.txt` lists the files and their licences;
a face set whose file is missing is refused and says so.

## The draw log (`GlUtilities.pbi`)

`GL_DrawLogStart()` empties `GL_DrawLog()` and records; `GL_DrawLogStop()` stops. While it records, `DrawGLBox`,
`DrawGLText` and `DrawGLPolygon` each add one `GLDrawLogEntry`: `Kind` (`#GL_LOG_BOX`, `_TEXT`, `_POLY`), the
rectangle as passed (canvas units, before the camera; a text's measured width and its face's line height; a
polygon's centre and radii), the colour, the text and face, the sides, `Flags` (Scaled, IgnoreCamera) and the
clip in force (`Clip`, `CX, CY, CW, CH`). Whatever sets the GL scissor for a canvas rectangle reports it with
`GL_DrawLogClip(On, X, Y, W, H)` - the kit's `Neon_ScissorSet` / `Neon_ScissorClear` do - which also adds a
`#GL_LOG_CLIP` / `#GL_LOG_NOCLIP` entry. Drawing is unchanged with the log on; off, it costs one test a draw.

## The UI check (`tools/ui_check.py`)

`python tools/ui_check.py` builds `tools/ui_check.pb` into `build/ui_check/` and runs it in an invisible window.
The faces are "metric faces": fixed-advance fonts with round numbers (advance / line height: ui 8 / 16, small
7 / 14, bold 9 / 18, mono 8 / 16, italic 8 / 16, arcade 12 / 24), since the kit's layout depends on nothing else
of a face, so every expected value is exact on any machine. It proves the draw log and the faces; `Neon_FitText`
at every width 0 - 360 for six texts against a reference that walks code points; GlUI's sizing rules; then plays
the gallery's script twice from `Neon_ChromeReset` - with the mouse and keys, and with a pad's actions - and after
every step checks the state, the return values and the event log against values worked out from the kit's
layout rules (rectangles, hot zones, fitted text, scroll positions, the caret and the selection, colours and
clips of the primitives that show the state), and requires the two runs to agree (the state and the step's log;
for a drag, which a pad does as pages, the state). The record of both runs is compared line for line with
`tools/ui_check_expected.txt`; `python tools/ui_check.py --write` writes it.

**The expected record** (`tools/ui_check_expected.txt`, UTF-8, one item a line, numbers with 3 decimals,
colours with 4):

```
# neon-ui-expected 1          the format and its version; lines starting with # are comments
canvas 1280 720               the canvas
face <name> <advance> <line>  each metric face: ui, small, bold, mono, italic, arcade
ellipsis U+2026               the cut's ending: the character, or "..." where the face lacks it
run mouse | run pad           a run of the script
step <n> <name>               a step of it (the names are the script's, Gallery_MakeScript)
state <text>                  the state after the step, as Gallery_StateText gives it; "state log <text>" an
                              event-log entry the step added
box X Y W H R G B A clip CX CY CW CH | clip -
text X Y W H R G B A clip ... <face> "<text>"
poly X Y RX RY R G B A clip ... <sides> <solid>
clip X Y W H | noclip         the clip set / taken away
end                           the step's last frame ends
```

The primitives are those of the step's last frame, in the order drawn. In a text, `\`, `"` and the control
characters are written `\uXXXX`. A port compares its own record with this one: the states and the order, kind,
rectangles, texts and clips exactly, the colours to 1/255.

## Changes to the kit's behaviour (2026-11-24)

Found while working out the gallery's expected values; each is a fault, fixed where it lies:

- **GlUI, a value the pad changed reached no callback.** A slider or carousel moved with DPadX, a toggle or DIP
  switch flipped with ActionPressed changed on screen and the program was never told; the same change with the
  mouse always called back. Now it calls back too (and, as every callback does, ends the frame).
- **GlUI, two gadgets focused for a frame.** When the pointer moved onto a gadget later in the list than the
  focused one, the old one was still processed as focused in that frame (a DPadX in it moved the old one). Hover is
  now found for every gadget before any is processed.
- **GlUI, DPadY over a list of only labels looped for ever**, and over an empty list read a gadget that was not
  there.
- **GlUI, an empty meter showed one segment** (and a value of exactly k / 20 one too many): segment i is lit when
  the value passes its start.
- **The chrome, a menu row or list row that only touches its view's edge** was drawn and, for menus, given a hot
  zone, so a row with nothing in view could take the hover or the focus.
