# Tile maps

`GlTiles.pbi` cuts a picture into tiles and draws grids of them. Include it after `GlSpriteFunctions.pbi` and `GlFile.pbi`; it brings `GlPalette.pbi` with it.

## Tile sets

A **tile set** (`GLTileSet`) is a picture cut into equal tiles. `GL_TileSetCreate(*Sprite, TileW, TileH, Spacing, Margin)` cuts a sprite: tiles of `TileW` by `TileH` pixels, `Spacing` pixels between neighbouring tiles, a `Margin` of pixels round the whole sheet. The tiles are numbered from 0, left to right, then top to bottom. The number of columns is `(Width - 2 * Margin + Spacing) / (TileW + Spacing)`, rounded down, and the same for rows; a set holds at most 4095 tiles (`#GL_TILE_MAX`), and a sheet that would give more, or none, is refused. `GL_TileSetCreateIndexed` cuts a colour-indexed image the same way (chapter 9). The set does not own its picture: free the sprite separately, after the set.

For each tile the set keeps three things: its animation, its collision byte (chapter 8) and, for an indexed set, the palette slot it is drawn with (chapter 9). `GL_TileSetSource(*Set, Tile, *X, *Y)` gives the pixel of the sheet a tile is cut from, rows counted from the top.

## Tile maps and cells

A **tile map** (`GLTileMap`) is a grid of cells, `Width` by `Height`, each 16 bits. `GL_TileMapCreate(Width, Height, *Set)` makes one, every cell empty; a map is 1 to 65535 cells each way, and its cells are the size of the set's tiles.

@figure cell 110 A cell: the tile number plus one, and three orientation bits.

The program speaks in tile numbers and never handles the cell's "+ 1":

- `GL_TileMapSet(*Map, X, Y, Tile, Flags)` puts tile `Tile` in a cell, or empties it with `#GL_TILE_EMPTY` (-1). `Flags` is the orientation: any of `#GL_TILE_FLIPX`, `#GL_TILE_FLIPY`, `#GL_TILE_DIAG`, or the turns `#GL_TILE_ROT90`, `#GL_TILE_ROT180`, `#GL_TILE_ROT270`. A tile number of 4095 or more, or a cell outside the map, is refused (`#False`).
- `GL_TileMapGet(*Map, X, Y)` gives the tile, or `#GL_TILE_EMPTY` for an empty cell and for any place outside the map; `GL_TileMapFlags` gives the orientation bits.
- `GL_TileMapFill(*Map, X, Y, W, H, Tile, Flags)` fills a rectangle, the part outside the map left out.
- `GL_TileMapCell` and `GL_TileMapSetCell` read and write the raw 16-bit cell.

A change shows on the next draw: nothing about a map is kept on the GPU.

@figure orient 112 The eight orientations of a tile.

The orientation is applied to the tile's picture in the order Tiled applies it: the diagonal flip first, then the left-right mirror, then the top-bottom mirror. So `#GL_TILE_ROT90`, which is `#GL_TILE_DIAG | #GL_TILE_FLIPX`, turns the tile a quarter clockwise, and a map made in Tiled keeps its meaning.

## Animated tiles

`GL_TileSetAnimAdd(*Set, Tile, FrameTile, Ms)` adds a frame to a tile's animation: show `FrameTile` for `Ms` milliseconds (1 to 65535). The frames play in the order added and repeat; every cell holding `Tile` shows the frame due, with its own orientation. A tile usually lists itself as its first frame:

```pb
Define Sheet.GLSprite : Sheet\Width = 64 : Sheet\Height = 16
Define *Set.GLTileSet = GL_TileSetCreate(@Sheet, 16, 16)
GL_TileSetAnimAdd(*Set, 2, 2, 250)        ; water: tile 2 for 250 ms,
GL_TileSetAnimAdd(*Set, 2, 3, 250)        ; then tile 3 for 250 ms, and again
Debug GL_TileSetAnimFrame(*Set, 2, 600)   ; 600 ms into the loop of 500: tile 2
```

The time is `GL_Micros() / 1000` unless the draw is given one; a paused game passes its own clock, which then stops the water too. `GL_TileSetAnimFrame(*Set, Tile, TimeMs)` says which tile is shown at a time, and `GL_TileSetAnimClear(*Set, Tile)` removes a tile's animation.

## Drawing a map

`GL_TileMapDraw(*Map, MapX, MapY, R, G, B, A, Scaled, IgnoreCamera, TimeMs)` draws the map with its top-left corner at `MapX, MapY` in the world (in canvas units when `IgnoreCamera`), placed through the camera exactly as `DrawGLSprite` places a sprite. `R, G, B, A` tint every tile. Only the cells the canvas can see are drawn: `GL_TileMapRange(*Map, MapX, MapY, *Range, Scaled, IgnoreCamera)` gives them, as the columns `Col0` to `Col1` and rows `Row0` to `Row1` (inclusive) of a `GLTileRange`.

The visible cells go into the sprite batcher's buffer and are drawn in one call: a 320 by 240 canvas of 16 by 16 tiles is at most 21 by 16 = 336 quads, and a batch holds 10,000. The procedure returns the number of draw calls it made (1 for any screenful that fits a batch; more only for a very zoomed-out view of a big map) and adds them to `GL_StatDrawCalls`. Neighbouring tiles share their edges exactly, so no gaps show between them at any camera position. It starts the batcher itself if the program has not. Draw maps outside a program's own `BeginBatch` and `EndBatch`: they share the batcher's buffer.

`GL_TileMapSubmit(*Map, MapX, MapY, ...)` adds the visible cells to a batch the program has begun (`BeginBatch` with the map's sheet) and returns the number added, so several maps cut from one sheet can share one draw call.

@include examples/tilemap.pb

## The map file

`GL_TileMapSave(*Map, Path, SaveSet)` writes a map to a `.ntm` file: the map's cells, and with `SaveSet` (the default) the set's animations, collision bytes and palette slots. The file is written to `Path.new` through the durable file store (chapter 14), and only when that file is complete on disk is the old `Path` deleted and the new file renamed to it.

`GL_TileMapLoad(Path, *Set, Index)` reads tile layer `Index` (0 for the first) of a file into a new map drawn with `*Set`, whose tile size must be the file's. `GL_TileSetLoad(*Set, Path)` replaces the set's animations, collision bytes and palette slots with the file's. `GL_TileMapFileLayers(Path)` says how many tile layers a file holds. A file may hold several tile layers, and `GL_TileMapLoad` reads any of them; `GL_TileMapSave` writes one. The format is in appendix A.

The program below makes a set and a map with no window at all (a set only needs the sheet's size to be cut), writes the file and reads it back:

@include examples/tilemap_file.pb

It prints:

@include examples/output/tilemap_file.txt

## When something is refused

Every procedure of the module that cannot do what it is asked returns 0 or `#False` and leaves the reason in `GL_TileError()`, as the last line above shows.
