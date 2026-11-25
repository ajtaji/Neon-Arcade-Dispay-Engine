# Layers, parallax and tile collision

`GlLayers.pbi` stacks tile maps and lists of sprites into a scene, moves them at different speeds as the camera moves, and answers what a box, a circle or a line touches in a tile map. Include it after `GlTiles.pbi`.

## Layers

`GL_LayersCreate()` makes a set of layers (`GLLayers`). `GL_LayerAddTiles(*Layers, *Map, Order)` adds a layer that shows a tile map, `GL_LayerAddSprites(*Layers, Order)` an empty sprite layer; both return the new `GLLayer`. `GL_LayersDraw(*Layers, Scaled, TimeMs)` draws them back to front: the lowest `Order` first, and layers of equal `Order` in the order they were added. `GL_LayerSetOrder(*Layers, *Layer, Order)` gives a layer a new order as if it had just been added: it is drawn in front of every layer that already has that order. `GL_LayersSorted(*Layers, Array Out())` lists the layers in drawing order. `GL_LayerRemove` takes a layer out (its pointer is then invalid), and `GL_LayersFree` frees the set; neither frees the maps and pictures the layers show, which stay the program's.

A layer's fields are its interface, set directly:

| Field | Meaning | Default |
|---|---|---|
| `X`, `Y` | where the layer's top-left sits: in the world, or on the canvas when `Fixed` | 0, 0 |
| `ScrollX`, `ScrollY` | move the content as a camera would: a larger `ScrollX` shows content further right | 0, 0 |
| `ParallaxX`, `ParallaxY` | how fast the layer follows the camera: 1 with the world, 0.5 half as fast, 0 not at all | 1, 1 |
| `Opacity` | 0 to 1, multiplies the alpha of everything on the layer; 0 skips the layer | 1 |
| `TintR`, `TintG`, `TintB` | multiply every colour | 1, 1, 1 |
| `Visible` | `#False` skips the layer | `#True` |
| `Fixed` | `#True`: fixed to the screen in canvas units, the camera ignored (a status bar, a HUD) | `#False` |

## The parallax arithmetic

A point `P` of a layer's content is drawn at the world position

```
X - ScrollX + P + GL_CameraX * (1 - ParallaxX)          (and the same in y)
```

and then through the camera like everything else, so on the screen it moves `ParallaxX` times as fast as the camera. `GL_LayerOrigin(*Layer, *X, *Y)` gives that position for `P = 0`: in world units, or in canvas units for a fixed layer. The camera's zoom applies to every layer that is not fixed.

@figure parallax 210 Four layers moving at different speeds.

## Sprite layers

`GL_LayerSpriteAdd(*Layer, *Sprite, X, Y)` adds a sprite to a sprite layer, with its top-left at `X, Y` in the layer, and returns its entry (`GLLayerSprite`). The entry's fields can be changed at any time and show on the next draw:

| Field | Meaning | Default |
|---|---|---|
| `X`, `Y` | top-left, in the layer | as added |
| `W`, `H` | the size drawn; 0 draws it the size of its picture rectangle | 0, 0 |
| `Angle` | radians, about the sprite's centre | 0 |
| `SrcX`, `SrcY`, `SrcW`, `SrcH` | the part of the picture drawn, rows counted from the top on every system; `SrcW` or `SrcH` 0 draws the whole picture | 0 |
| `Orient` | the tile orientations: `#GL_TILE_FLIPX`, `#GL_TILE_FLIPY`, `#GL_TILE_DIAG`, `#GL_TILE_ROT90` ... | 0 |
| `R`, `G`, `B`, `A` | the sprite's colour, multiplied by the layer's tint and opacity | 1, 1, 1, 1 |
| `Visible` | `#False` skips it | `#True` |

`GL_LayerSpriteRemove(*Layer, *Entry)` and `GL_LayerSpritesClear(*Layer)` take sprites out. `GL_LayerImageAdd` adds a colour-indexed image with its own palette (chapter 9).

Sprites are drawn in the order added. Consecutive sprites that share a picture go in one draw call; a change of picture starts a new call. A sprite whose bounding circle is wholly off the canvas is not drawn. A tile layer is one call per screenful, as its map is.

## Collision against a tile map

Each tile of a set has a **collision byte**, set with `GL_TileSetCollision(*Set, Tile, Kind)`:

| Kind | Meaning |
|---|---|
| 0 | nothing: the tile is scenery |
| `#GL_TILE_SOLID` | the whole tile stops things |
| `#GL_TILE_ONEWAY` | a platform: it stops things coming from one side only, its top unless the cell is turned |
| `#GL_TILE_SLOPE` | 45 degrees: solid below the line from the bottom-left corner to the top-right corner |

A cell's orientation turns the slope's triangle and the one-way side with its picture. The bytes are saved in the map file.

The queries have the shape of `GlMath.pbi`'s tests. Each fills a list with every non-empty cell the shape overlaps and returns `#True` when the shape is inside the solid part of a solid or slope tile:

- `CheckCollisionTileBox(*Map, MapX, MapY, X, Y, W, H, List Hits.GLTileHit())`
- `CheckCollisionTileCircle(*Map, MapX, MapY, CX, CY, Radius, List Hits.GLTileHit())`
- `CheckCollisionTileLine(*Map, MapX, MapY, X1, Y1, X2, Y2, List Hits.GLTileHit())` - the hits nearest first
- `CheckCollisionLayerBox`, `CheckCollisionLayerCircle`, `CheckCollisionLayerLine` - the same against a tile layer, placed where the layer is drawn now (its origin, above)

Each hit (`GLTileHit`) carries the cell (`Col`, `Row`), its `Tile`, its orientation `Flags`, the tile's collision `Kind`, `Blocks` (the shape is inside the solid part), for a line `T` (0 to 1 along the line where it enters the cell, or its solid part when it blocks), and for a one-way tile `NormalX`, `NormalY` (the side it stops things from: 0, -1 for the top of an unturned tile).

Three rules decide the borderline cases:

- **Touching an edge is not overlapping.** A box standing exactly on the floor hits nothing; a box one pixel into it hits the floor.
- **A one-way tile never blocks by itself.** Its hit carries the side it stops things from, and the program decides from the direction of travel: land on it when moving down and the bottom of the thing was above it before the move.
- **A slope blocks only in its solid triangle.** A shape in the cell but above the diagonal is reported with `Blocks = #False`.

@include examples/tile_collision.pb

It prints:

@include examples/output/tile_collision.txt

## A worked example

A far layer of hills at a third of the camera's speed and darkened by its tint, the ground at full speed, a hero on a sprite layer who stands on the ground by the box query, and a strip of coins fixed to the screen:

@include examples/layers.pb

`examples/TileWorld.pb` in the repository is a larger scene of the same kind: three tile layers at three speeds, heroes that share one picture and differ only by palette, palette cycling and a dusk fade, animated coins, slopes and one-way ledges.
