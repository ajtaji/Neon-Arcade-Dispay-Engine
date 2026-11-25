# GlPalette.pbi

Indexed images and palettes (chapter 9 is the guide); `GlTiles.pbi` includes this module. A procedure that cannot do what it is asked returns 0 or `#False` and, where its entry says so, leaves the reason in `GL_PaletteError()`.

## Constants

- `#GL_PALETTE_SIZE` - 256, the entries of a palette.
- `#GL_PALETTE_SLOTS` - 8, the palette slots of an indexed image and of a layer.

## Structures

### Structure GLPalette

A palette: `Count` entries in use (what is saved; the operations reach all 256), the colours as set (`Base[]`) and as shown (`Shown[]`), each an `RGBA()` value, `Changed` (the shown colours changed since they were last sent to the GPU) and `Row` (its row of the palette texture, -1 when it has none).

### Structure GLIndexedImage

An indexed image: `Width` by `Height` bytes at `Index`, row 0 at the top; its eight palette slots (`Palette[]`, `GLPalette` addresses); `OwnsPalettes` (made by `GL_IndexedLoad`: its palettes are freed with it); `Changed` (pixels changed since the last upload) and `TextureID` (its colour numbers on the GPU).

Internal: `GLPalCorners`

## Palettes

### GL_PaletteCreate

A palette of `Count` entries (1 to 256; 256 by default), each transparent black. Refused (with a sentence) outside that range.

### GL_PaletteFree

Frees a palette and gives its row of the palette texture back. An image that still holds it in a slot must not be drawn afterwards.

### GL_PaletteSet

Sets entry `Index` (0 to 255) to `Colour`, as set and as shown, and raises `Count` to cover it. `#False` for an index out of range.

### GL_PaletteGet

Entry `Index` as set (0 out of range).

### GL_PaletteShown

Entry `Index` as it is drawn now (0 out of range).

### GL_PaletteReset

The shown colours become the set colours again.

### GL_PaletteCopy

`*Dest` takes `*Src`'s colours, set and shown, and its `Count`.

### GL_PaletteCycle

Rotates the shown entries `First` to `First + Count - 1` by `Steps` places (negative: the other way). `Count` -1 runs to entry 255. `#False` for a range outside the palette.

### GL_PaletteCycleTime

Rotates by one step every `StepMs` milliseconds of `TimeMs` (`GL_Micros() / 1000` when -1): `(TimeMs / StepMs) mod Count` steps, so call it after `GL_PaletteReset`. `#False` for `StepMs` below 1 or a `Count` of 0.

### GL_PaletteFade

Mixes the shown entries `First` to `First + Count - 1` (all, by default) toward `Colour` by `Amount` (0 to 1): red, green and blue each `(a * (256 - k) + b * k + 128) >> 8` with `k = Amount * 256` rounded and kept between 0 and 256; alpha unchanged.

### GL_PaletteFadeTo

As `GL_PaletteFade`, toward the matching shown entries of `*Other`, all four channels.

## Indexed images

### GL_IndexedCreate

A `Width` by `Height` image (1 to 16384 each way), its pixels copied from `*Indices` or all 0. Refused, with a sentence, outside that size or without memory.

### GL_IndexedFree

Frees an image, its texture, and its palettes when it owns them.

### GL_IndexedGet

The colour number at `X`, `Y`, or -1 outside the image.

### GL_IndexedSet

Sets the colour number (0 to 255) at `X`, `Y`; the image's colour numbers are sent to the GPU again at its next draw. `#False` out of range.

### GL_IndexedPalette

Puts `*Pal` in slot `Slot` (0 to 7) of the image, or empties it with 0; the image does not own it. `#False` for a slot out of range.

### GL_IndexedPaletteOf

The palette in a slot (0 when empty or out of range).

### GL_IndexedFromImage

A new indexed image of a PureBasic image (`Img`): each pixel's colour, alpha included (an image without alpha counts as opaque), is looked up in `*Pal`'s set colours and added at the end of the palette when it is not there. The image's slot 0 holds `*Pal`. Refused, with a sentence and nothing changed, when the colours do not fit 256 entries.

### GL_IndexedResolve

The image through `*Pal`'s shown colours (`*Pal` 0: slot 0's palette) into `*Dest`: `Width * Height` `RGBA()` values, row 0 first. Refused, with a sentence, when there is no palette.

### GL_IndexedToSprite

A new `GLSprite` of the image through `*Pal` (0: slot 0), with its alpha mask, looked up on the CPU.

### GL_IndexedBake

Colours `*Sprite` (made by `GL_IndexedToSprite` from this image) through `*Pal` again. `#False` when the sizes differ.

## Drawing

### GL_PaletteInit

Sets up the palette drawing: its shader, the 256 by 256 palette texture and its batch. Called by the drawing procedures; returns `#True` when ready. Refused, with a sentence, before a window is open or on OpenGL older than 3.0.

### GL_IndexedDraw

Draws an image as `DrawGLSprite` draws a sprite.

- `X`, `Y` - the top-left; `AngleRadians` - a turn about the centre; `Scale` - the size multiplier.
- `*Pal` - a palette for this draw; 0 uses slot `Slot`, falling back to slot 0.
- `R`, `G`, `B`, `A` - a tint; `Scaled` - canvas units; `IgnoreCamera` - no camera.
- `SrcX`, `SrcY`, `SrcW`, `SrcH` - a part of the image, rows counted from the top; `SrcW` or `SrcH` 0 or less draws all of it.
- `Orient` - the tile orientation bits.

Returns the draw calls made (1). Refused, with a sentence, when the image has no palette.

### GL_PaletteShutdown

Frees the palette drawing's shader, texture and batch; every palette loses its row (it gets one again after a new `GL_PaletteInit`). Call it before the context goes, after freeing the images' textures (`GL_IndexedFree`).

### GL_TileSetCreateIndexed

Cuts an indexed image into a tile set, as `GL_TileSetCreate` cuts a sprite; each tile drawn with its palette slot (`GL_TileSetPaletteSlot`). Refused with a sentence in `GL_TileError()`.

## Files

### GL_IndexedSave

Writes the image and the palettes in its slots to `Path` (a `.nti` file), eight bits a pixel, or four with `Packed` (refused, with a sentence, when a pixel is above 15). Written as the map file is: `Path.new`, then in place of `Path`.

### GL_IndexedLoad

Reads an image and its palettes from `Path`; the image owns the palettes. Refused, with a sentence: a file that cannot be read, is not a version 1 file, is damaged, or holds no image.

### GL_PaletteSave

Writes one palette, as slot 0, to a file of its own.

### GL_PaletteLoad

Reads the palette in `Slot` (0 by default) of an image file or a palette file; the program owns it. Refused, with a sentence, when the slot is empty.

### GL_PaletteError

The sentence that says why the last refused palette or indexed-image call was refused.
