# GlLayers.pbi

Layers, parallax and collision against tile maps (chapter 8 is the guide).

## Constants and structures

`#GL_LAYER_TILES` (1) and `#GL_LAYER_SPRITES` (2) are the two kinds of layer, in a layer's `Kind` field.

### Structure GLLayers

A set of layers: the list `Layers()` and the sequence number the next layer added gets (`NextSeq`).

### Structure GLLayer

A layer. Set directly: `X`, `Y`, `ScrollX`, `ScrollY`, `ParallaxX`, `ParallaxY`, `Opacity`, `TintR`, `TintG`, `TintB`, `Visible`, `Fixed` (chapter 8 gives each one's meaning and default). Read: `Kind`, `Map` (a tile layer's map), `Sprites()` (a sprite layer's entries), `Order` (change it with `GL_LayerSetOrder`), `Seq` (when it was added) and `Palette[]` (the replacements `GL_LayerPalette` set).

### Structure GLLayerSprite

An entry of a sprite layer: the picture (`Sprite`; or `Image`, an indexed image, with `Palette` and `Slot`), `X`, `Y`, `W`, `H`, `Angle`, `SrcX`, `SrcY`, `SrcW`, `SrcH`, `Orient`, `R`, `G`, `B`, `A`, `Visible` (chapter 8). Every field can be changed at any time.

### Structure GLTileHit

One cell a collision query touched: `Col`, `Row`, `Tile`, its orientation `Flags`, the tile's collision `Kind`, `Blocks` (the shape is inside a solid part), `T` (lines: 0 to 1 where it enters the cell, or the solid part when it blocks) and `NormalX`, `NormalY` (a one-way tile: the side it stops things from).

Internal: `GLLayerQuad`, `GLTilePoly`

## Layers

### GL_LayersCreate

A new, empty set of layers.

### GL_LayersFree

Frees a set and its layers' records (not the maps and pictures they show).

### GL_LayerAddTiles

Adds a layer showing `*Map` at `Order` (0 by default) and returns it with its defaults set. Refused, with a sentence in `GL_TileError()`, without a map.

### GL_LayerAddSprites

Adds an empty sprite layer at `Order` and returns it.

### GL_LayerRemove

Takes a layer out of the set; its pointer is then invalid.

### GL_LayerSetOrder

Gives a layer a new `Order`, drawn in front of every layer that already has it.

### GL_LayersSorted

The set's layers in drawing order, back first, as `GLLayer` addresses in `Out()` (grown to fit); returns how many.

### GL_LayerOrigin

Where the layer's content point 0, 0 is drawn now, into `*X`, `*Y`: `X - ScrollX + GL_CameraX * (1 - ParallaxX)` (and the same in y), or `X - ScrollX` for a fixed layer, which is in canvas units.

### GL_LayerDraw

Draws one layer (nothing when it is not visible or its opacity is 0 or less) and returns the draw calls made. `Scaled` and `TimeMs` as `GL_TileMapDraw`.

### GL_LayersDraw

Draws every visible layer of a set, back to front, with one time for all of them (`TimeMs`, the clock when -1), and returns the draw calls made.

## Sprite layers

### GL_LayerSpriteAdd

Adds `*Sprite` at `X`, `Y` to a sprite layer and returns its entry, with full colour and visible. 0 for a layer that is not a sprite layer, or no sprite.

### GL_LayerImageAdd

Adds an indexed image to a sprite layer, drawn with `*Pal` (a swap for this entry) or, when 0, with slot `Slot` (or the layer's replacement for that slot). Returns the entry, or 0.

### GL_LayerPalette

Draws everything on the layer that uses palette slot `Slot` (0 to 7) with `*Pal` instead; 0 puts the image's own palette back. `#False` for a slot out of range.

### GL_LayerSpriteRemove

Takes an entry out of a sprite layer.

### GL_LayerSpritesClear

Takes every entry out of a sprite layer.

## Collision

The queries fill `Hits()` (emptied first) with every non-empty cell the shape overlaps, and return `#True` when the shape is inside the solid part of a solid or slope tile. Touching an edge is not overlapping. A map of 0 or without a set gives `#False` and no hits.

### CheckCollisionTileBox

A box (top-left `X`, `Y`, size `W`, `H`) against `*Map` placed at `MapX`, `MapY`.

### CheckCollisionTileCircle

A circle (centre `CX`, `CY`, `Radius`) against `*Map` placed at `MapX`, `MapY`.

### CheckCollisionTileLine

A segment from `X1`, `Y1` to `X2`, `Y2` against `*Map` placed at `MapX`, `MapY`; the hits sorted nearest first by `T`. A segment of zero length is a point.

### CheckCollisionLayerBox

`CheckCollisionTileBox` against a tile layer's map, placed at the layer's origin (`GL_LayerOrigin`). `#False` and no hits for a sprite layer.

### CheckCollisionLayerCircle

`CheckCollisionTileCircle` against a tile layer, at its origin.

### CheckCollisionLayerLine

`CheckCollisionTileLine` against a tile layer, at its origin.
