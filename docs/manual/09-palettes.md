# Palettes and indexed images

`GlPalette.pbi` comes with `GlTiles.pbi`. It draws pictures made of colour numbers through tables of colours, and changes those tables: cycling a range of colours, fading toward a colour or another table, swapping one table for another.

## Why a palette, on a machine that draws in true colour

A PC's GPU draws every pixel in full colour, so a palette is never needed to show a picture. It is there for what it does cheaply:

- **Cycling.** Rotating eight blues makes water flow, a waterfall fall and stars twinkle, by changing 32 bytes, not one pixel of the picture.
- **Swapping.** One picture drawn with several tables is several characters, several teams, several times of day, with one copy of the pixels.
- **Fading.** A dusk, a flash or a fade to black is 256 colour operations whatever the size of the scene.
- **Data that other machines can use.** A picture of colour numbers and its tables are what hardware with palettes draws natively; the engine's `.nti` file keeps them in that form (appendix A).

The cost on the GPU is small: the colour numbers of a picture are sent once (and again only after a pixel is changed), a changed table is sent as one row of 1 KB, and pictures drawn with different tables still go in one draw call.

## Palettes

A **palette** (`GLPalette`) is up to 256 colours (`#GL_PALETTE_SIZE`), each a PureBasic `RGBA()` value. `GL_PaletteCreate(Count)` makes one of `Count` entries (1 to 256), every one transparent black. An entry whose alpha is 0 is drawn transparent, which is how a picture has holes.

A palette keeps **two copies** of its colours: the colours as set, and the colours as shown. `GL_PaletteSet(*Pal, Index, Colour)` sets an entry in both (and raises `Count` to cover it); `GL_PaletteGet` reads the set colour and `GL_PaletteShown` the shown one. The operations change only the shown colours, in the order they are called, and `GL_PaletteReset(*Pal)` puts the set colours back. So a frame that animates a palette resets it, then applies its operations:

| Operation | What it does to the shown colours |
|---|---|
| `GL_PaletteCycle(*Pal, First, Count, Steps)` | rotates entries `First` to `First + Count - 1`: each colour moves `Steps` places up the range (down for a negative `Steps`), the last ones wrapping to the first |
| `GL_PaletteCycleTime(*Pal, First, Count, StepMs, TimeMs)` | the same, one step every `StepMs` milliseconds, worked out from the time (`GL_Micros() / 1000` unless given): call it after a reset, and a frame that comes late does not drift |
| `GL_PaletteFade(*Pal, Colour, Amount, First, Count)` | mixes red, green and blue toward `Colour` by `Amount` (0 none, 1 all the way); alpha is kept, so a transparent entry stays transparent |
| `GL_PaletteFadeTo(*Pal, *Other, Amount, First, Count)` | mixes all four channels toward the other palette's shown colours |
| `GL_PaletteCopy(*Dest, *Src)` | copies both the set and the shown colours |

A `Count` of -1 means "to the end of the palette" (`GL_PaletteCycle`, `GL_PaletteCycleTime`, the fades). A fade mixes each channel in whole numbers, the same on every machine:

```
result = (a * (256 - k) + b * k + 128) >> 8
k      = Amount * 256, rounded to the nearest whole number, kept between 0 and 256
```

## Indexed images

An **indexed image** (`GLIndexedImage`) is a picture of colour numbers, one byte a pixel, row 0 at the top. `GL_IndexedCreate(Width, Height, *Indices)` makes one (1 to 16384 pixels each way), from the bytes at `*Indices` or all 0. `GL_IndexedSet` and `GL_IndexedGet` change and read a pixel. `GL_IndexedFromImage(Image, *Pal)` makes one from a PureBasic image: each colour is looked up in the palette, alpha included, and added at the end of it when it is new; a picture with more colours than the palette has room for is refused.

An image has eight **palette slots** (`#GL_PALETTE_SLOTS`). `GL_IndexedPalette(*Img, Slot, *Pal)` puts a palette in a slot (the image does not own it); `GL_IndexedPaletteOf` reads it back. Slot 0 is the image's own palette.

`GL_IndexedResolve(*Img, *Pal, *Dest)` is the look-up on the CPU: the image through the palette's shown colours (`*Pal` 0 uses slot 0), into `Width * Height` `RGBA()` values. It is the reference the GPU's drawing is checked against.

## Drawing

The drawing is done in a fragment shader: the colour numbers are a one-channel texture, every palette in use is one row of a 256 by 256 texture, and each vertex carries its palette's row. `GL_PaletteInit()` sets this up; the drawing procedures call it themselves, but calling it after the window opens lets a program report a machine without OpenGL 3.0 at once. `GL_PaletteShutdown()` frees it before the context goes; every palette then gets a row again at its next draw.

- `GL_IndexedDraw(*Img, X, Y, *Pal, Slot, Angle, Scale, R, G, B, A, Scaled, SrcX, SrcY, SrcW, SrcH, IgnoreCamera, Orient)` draws an image as `DrawGLSprite` draws a sprite: top-left at `X, Y`, turned about its centre, scaled, tinted, a part of it (`SrcW` -1: all of it, rows counted from the top), through the camera unless `IgnoreCamera`, flipped or turned by `Orient` as a tile. `*Pal` swaps the palette for this draw; 0 uses slot `Slot`.
- `GL_LayerImageAdd(*Layer, *Img, X, Y, *Pal, Slot)` puts an image on a sprite layer, with its own palette or a slot. Images of one picture on a layer are one draw call, whatever their palettes.
- `GL_LayerPalette(*Layer, Slot, *Pal)` replaces a slot's palette for everything a layer draws: a swap for a whole layer (0 puts the image's own palette back).
- `GL_TileSetCreateIndexed(*Img, TileW, TileH, Spacing, Margin)` cuts an indexed image into tiles, and `GL_TileSetPaletteSlot(*Set, Tile, Slot)` picks the slot each tile is drawn with, so one picture can show several palettes at once in one map.

Which palette a draw uses is decided in this order: a palette given to the draw; else the layer's replacement for the slot; else the image's palette in that slot; else the image's slot 0. A draw with no palette at all is refused.

At most 256 palettes can be in use at once (one row each); a palette gives its row back when it is freed or at `GL_PaletteShutdown`.

## Back to an ordinary sprite

`GL_IndexedToSprite(*Img, *Pal)` makes an ordinary `GLSprite` of an image through a palette, with its alpha mask, for code that needs one (`DrawGLSprite`, the pixel-exact collision test). `GL_IndexedBake(*Img, *Pal, *Sprite)` colours that sprite again after a palette changed. Both look up every pixel on the CPU and send the whole picture to the GPU each time, so they suit occasional changes, not a cycle every frame.

## Files

`GL_IndexedSave(*Img, Path, Packed)` writes an image and the palettes in its slots to a `.nti` file, eight bits a pixel or, with `Packed`, four (refused if a pixel is above 15). `GL_IndexedLoad(Path)` reads one back; the image then owns its palettes, and `GL_IndexedFree` frees them with it. `GL_PaletteSave(*Pal, Path)` writes a palette alone; `GL_PaletteLoad(Path, Slot)` reads the palette in a slot of either kind of file. The format is in appendix A. Failures return 0 or `#False` with the reason in `GL_PaletteError()`.

## Worked examples

The operations, an image and the file, with no window:

@include examples/palette_ops.pb

It prints:

@include examples/output/palette_ops.txt

One picture drawn with three palettes, one of them cycling by the clock and one fading:

@include examples/palette_draw.pb
