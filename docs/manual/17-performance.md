# Performance

## What costs time

On the GPU, a frame of 2D drawing costs mostly in **draw calls**: each call sets up the GPU's state and is worth hundreds of quads. The engine's drawing is arranged round that:

| What is drawn | Draw calls |
|---|---|
| `DrawGLBox`, `DrawGLPolygon`, `DrawGLSprite` | one each |
| `DrawGLText` | one for each run of characters on the same atlas page, at most 256 characters a call: a line of ASCII is one |
| a batch (`BeginBatch` ... `EndBatch`) | one, for up to 10,000 sprites of one picture |
| `RenderParticles` | one, for up to 10,000 particles |
| `GL_TileMapDraw` | one for every 10,000 visible cells: one for any normal screenful |
| a sprite layer | one for each run of consecutive sprites that share a picture |
| indexed images and tiles (palettes) | one for each run sharing a picture, whatever their palettes |
| `DrawGLStaticLines` | one, for any number of segments |
| `G3D_Draw` | one for each primitive of the model |
| `DrawPassthrough`, `DrawRetroCRT` | one |

So the habits that keep a frame cheap are: put many small pictures on one sheet and draw them through a tile map, a sprite layer or a batch; draw text in as few calls as there are lines; keep sprites that share a picture next to each other in a sprite layer.

On the CPU, the per-call costs are small but real: `DrawGLBox`, `DrawGLPolygon` and `DrawGLSprite` each allocate and free a small buffer; text looks every glyph up in two table reads; a tile map submits only the cells in view, whatever the map's size. A palette operation touches at most 256 colours; the shown colours go to the GPU as one 1 KB row when they changed, and an image's colour numbers only after a pixel changed. `GL_IndexedToSprite` and `GL_IndexedBake`, by contrast, recolour every pixel on the CPU and send the whole picture.

## Counting

The engine counts as it draws, into globals a program can read and reset:

| Global | Counts |
|---|---|
| `GL_StatDrawCalls` | draw calls issued by text, boxes, polygons, static lines, tile maps, layers, indexed drawing, the 3D pass, and the presentation calls |
| `GL_StatTextDraws` | of those, the text draws |
| `GL_StatTextCalls` | `DrawGLText` calls made |
| `GL_StatGlyphs` | glyph quads drawn |
| `GL_StatBufferUploads` | uploads of vertex data and of skin matrices |

`GL_StatsReset()` sets them all to 0; read them at the end of a frame:

```pb
GL_StatsReset()
; ... draw the frame ...
Debug "draw calls this frame: " + Str(GL_StatDrawCalls) + ", glyphs: " + Str(GL_StatGlyphs)
```

`DrawGLSprite`, the batcher's own `EndBatch` and `RenderParticles` do not add to `GL_StatDrawCalls`; a tile map's batch is counted by the map's draw.

## What the check tools measure

The engine's own check programs (appendix B) prove counts as well as pictures: that the cells a map submits are exactly the visible ones at 400 camera positions, that a full 320 by 240 screen of 16 by 16 tiles is at most 21 by 16 cells in one batch, that a zoomed-out view of a big map takes more batches of 10,000, and that two indexed sprites with different palettes on one layer are one call.
