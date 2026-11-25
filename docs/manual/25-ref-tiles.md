# GlTiles.pbi

Tile sets, tile maps, animated tiles and the map file (chapter 7 is the guide). A procedure that cannot do what it is asked returns 0 or `#False` and leaves the reason in `GL_TileError()`, unless its entry says otherwise.

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `#GL_TILE_EMPTY` | -1 | no tile: an empty cell |
| `#GL_TILE_MAX` | 4095 | the most tiles a set holds (tiles 0 to 4094) |
| `#GL_TILE_NUMBER` | $0FFF | the cell's bits that hold the tile number + 1 |
| `#GL_TILE_DIAG` | $1000 | swap the tile's x and y (applied first) |
| `#GL_TILE_FLIPX` | $4000 | mirror left-right |
| `#GL_TILE_FLIPY` | $8000 | mirror top-bottom |
| `#GL_TILE_ROT90` | $5000 | `DIAG` and `FLIPX`: a quarter turn clockwise |
| `#GL_TILE_ROT180` | $C000 | `FLIPX` and `FLIPY`: a half turn |
| `#GL_TILE_ROT270` | $9000 | `DIAG` and `FLIPY`: a quarter turn counter-clockwise |
| `#GL_TILE_ORIENT` | $D000 | all the orientation bits |
| `#GL_TILE_SOLID` | 1 | collision: the whole tile is solid |
| `#GL_TILE_ONEWAY` | 2 | collision: solid from one side, the top of the unturned tile |
| `#GL_TILE_SLOPE` | 4 | collision: solid below the diagonal from bottom-left to top-right |

## Structures

### Structure GLTileSet

A set of tiles: the sheet (`Sprite`, or `Indexed` for an indexed image; the set does not own it), the sheet's size (`ImageW`, `ImageH`), the tile size (`TileW`, `TileH`), `Spacing`, `Margin`, the grid (`Columns`, `Rows`), the number of tiles (`Count`), how many are animated (`Animated`), and one entry a tile in each of `Anim()` (`GLTileAnim`), `Collide()` (the collision byte) and `PalSlot()` (the palette slot).

### Structure GLTileAnim

A tile's animation: `Count` frames (`GLTileFrame`, at `Frames`) lasting `TotalMs` milliseconds in all.

### Structure GLTileFrame

One frame: show `Tile` for `Ms` milliseconds.

### Structure GLTileMap

A grid: `Width` by `Height` cells, each `TileW` by `TileH` world units, the cells at `Cells` (`Width * Height` 16-bit words, row 0 first), and the set it is drawn with (`Set`).

### Structure GLTileRange

The cells a draw submits: columns `Col0` to `Col1` and rows `Row0` to `Row1`, inclusive.

Internal: `GLTileXform`, `GLTileSlotRows`

## Tile sets

### GL_TileSetCreate

Cuts `*Sprite` into tiles of `TileW` by `TileH` pixels, `Spacing` pixels apart, inside a `Margin`; returns the set. Refused: no sprite, a tile size below 1, a negative spacing or margin, a sheet with no whole tile, or more than 4095 tiles.

### GL_TileSetFree

Frees a set and its animations (not its sprite).

### GL_TileSetSource

The top-left pixel of `Tile` in the sheet, rows counted from the top, into `*X` and `*Y` (either may be 0). `#False` for a tile not in the set.

### GL_TileSetAnimAdd

Adds a frame to `Tile`'s animation: show `FrameTile` for `Ms` milliseconds (1 to 65535). Frames play in the order added and repeat. Refused: a tile or frame not in the set, a time out of range, more than 65535 frames.

### GL_TileSetAnimFrame

The tile shown for `Tile` at `TimeMs` (any time, negative too: it is taken modulo the animation's length): `Tile` itself when it has no animation or is not in the set.

### GL_TileSetAnimClear

Removes `Tile`'s animation.

### GL_TileSetCollision

Sets `Tile`'s collision byte: 0, `#GL_TILE_SOLID`, `#GL_TILE_ONEWAY`, `#GL_TILE_SLOPE` (any value 0 to 255 is kept). `#False` for a tile not in the set; no error sentence.

### GL_TileSetCollisionGet

`Tile`'s collision byte (0 for a tile not in the set).

### GL_TileSetPaletteSlot

For an indexed set, the palette slot (0 to 7) `Tile` is drawn with. `#False` for a tile or slot out of range; no error sentence.

### GL_TileSetPaletteSlotGet

`Tile`'s palette slot (0 for a tile not in the set).

## Tile maps

### GL_TileMapCreate

An empty map of `Width` by `Height` cells (1 to 65535 each way) drawn with `*Set`, its cells the size of the set's tiles. Refused: no set, a size out of range, no memory.

### GL_TileMapFree

Frees a map.

### GL_TileMapSet

Puts `Tile` in cell `X`, `Y` with the orientation bits of `Flags` (other bits are ignored), or empties the cell with `#GL_TILE_EMPTY`. `#False` for a cell outside the map or a tile of 4095 or more (no error sentence). The change shows on the next draw.

### GL_TileMapGet

The tile in cell `X`, `Y`, or `#GL_TILE_EMPTY` for an empty cell or a place outside the map.

### GL_TileMapFlags

The orientation bits of cell `X`, `Y` (0 outside the map).

### GL_TileMapFill

Puts `Tile` with `Flags` in every cell of the `W` by `H` rectangle at `X`, `Y`; cells outside the map are left out.

### GL_TileMapCell

The raw 16-bit cell (tile number + 1 and orientation bits), 0 outside the map.

### GL_TileMapSetCell

Writes a raw cell (its low 16 bits). `#False` outside the map.

## Drawing

### GL_TileMapRange

The cells of `*Map`, placed with its top-left at `MapX`, `MapY`, that the canvas shows, into `*R`; returns how many (0 for none, or a camera zoom of 0 or less). With `Scaled` the canvas is `Util_BaseWidth` by `Util_BaseHeight`, else the window's size; with `IgnoreCamera`, `MapX`, `MapY` are canvas units and the camera is left out. The first column is the one holding the canvas's left edge, the last the one holding its right edge, and the same for rows.

### GL_TileMapDraw

Draws the visible cells of a map, top-left at `MapX`, `MapY`, tinted by `R`, `G`, `B`, `A`, through the camera unless `IgnoreCamera`; animated tiles at `TimeMs` (the clock, `GL_Micros() / 1000`, when -1). For an indexed set, `*Palettes` is the address of eight `GLPalette` pointers that replace the image's slots (0 in the list keeps a slot; 0 for none). Returns the draw calls made, 1 for any screenful; 0 when there was nothing to draw. Starts the batcher if needed. Do not call it between a program's own `BeginBatch` and `EndBatch`.

### GL_TileMapSubmit

Adds the visible cells of a map to the batch the program has begun (with the map's sheet as its texture) without drawing it, and returns the number added; for drawing several maps of one sheet in one call. Parameters as `GL_TileMapDraw`.

## The map file

### GL_TileMapSave

Writes `*Map` to `Path`, with the set's animations, collision bytes and palette slots when `SaveSet` (the default). It writes `Path.new` through `GL_FileStore`, then deletes `Path` and renames the new file to it. Refused: no map, no memory, a file that cannot be written, removed or renamed.

### GL_TileMapLoad

Reads tile layer `Index` (0 the first) of `Path` into a new map drawn with `*Set`. Refused: no set, a file that cannot be read or is not a version 1 map file, no such layer, a layer whose length is wrong, a tile size other than the set's.

### GL_TileSetLoad

Replaces `*Set`'s animations, collision bytes and palette slots with those in `Path`; a table the file does not have is cleared. Refused: a file that cannot be read, a table for a set of another size, an animation that does not fit the set.

### GL_TileMapFileLayers

How many tile layers `Path` holds, or -1 when it cannot be read.

### GL_TileError

The sentence that says why the last refused call of the tile and layer procedures was refused.
