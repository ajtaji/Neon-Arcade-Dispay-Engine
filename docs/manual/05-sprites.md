@part Guides
# Sprites, the batcher and render targets

## Sprites

A **sprite** is a picture in an OpenGL texture, described by a `GLSprite`: the texture (`TextureID`), its size in pixels (`Width`, `Height`), and an **alpha mask** (`AlphaMask`), one byte a pixel, 1 where the picture's alpha is above 0 and 0 where it is fully clear. The mask is what the pixel-exact collision test and the hull generator read (chapter 10). `CollisionPoly` is a field for the program's own use; no engine procedure fills or reads it.

Three procedures make one:

- `LoadGLSprite(File, ColorKey)` loads a picture file (any format whose PureBasic decoder the program has enabled);
- `LoadGLSpriteMemory(*Address, ColorKey)` takes an encoded picture already in memory, for example a file included in the executable with `IncludeBinary`, or one made with `EncodeImage`;
- `CreateProceduralRopeSprite()` draws a 32 by 64 picture (a twisted orange rope) in code, with no file.

With a **colour key** (an `RGB()` value), every pixel of exactly that colour is made fully transparent. The texture is sampled with nearest filtering and clamped at its edges, so a sprite drawn at a whole multiple of its size stays sharp.

## Drawing one sprite

`DrawGLSprite(*Sprite, X, Y, Angle, Scale, R, G, B, A, Scaled, SrcX, SrcY, SrcW, SrcH, IgnoreCamera)` draws the sprite with its top-left corner at `X, Y`, turned by `Angle` radians about its centre and multiplied in size by `Scale`, its colours multiplied by `R, G, B, A`. With a **source rectangle** (`SrcX` not -1; all four are then used) only that part of the picture is drawn, at `SrcW` by `SrcH` times `Scale`: the way to draw one frame of a sheet.

> Which rows `SrcY` names depends on the system: the source maps `SrcY` from the bottom of the picture on Windows and from the top on Linux (the engine's `tools/draw_check` prints which it found). A sheet whose frames are laid out in one row, drawn with `SrcY = 0` and `SrcH` the picture's height, is the same on both. A sprite layer's source rectangle (chapter 8) counts rows from the top on both systems.

Each `DrawGLSprite` is one OpenGL draw call. For a few sprites that is nothing; for hundreds of copies of one picture, use the batcher.

## The batcher

`InitSpriteBatcher()` makes, once, a buffer for 10,000 sprites (`GL_MaxBatch`). A batch is then:

```pb
Define *Star.GLSprite = CreateProceduralRopeSprite(), i.i, Column.i, Row.i
InitSpriteBatcher()                        ; once, after the window is open
BeginBatch(*Star)                          ; every sprite of the batch is this picture
For i = 0 To 999
  Column = i % 40 : Row = i / 40
  AddBatchedSprite(Column * 8, Row * 8, 4, 4, 0, 1, 1, 1, 0.8)
Next
EndBatch()                                 ; one draw call for the thousand
```

`AddBatchedSprite(X, Y, W, H, Angle, R, G, B, A, IgnoreCamera)` places the **whole** picture at `X, Y`, `W` by `H`, turned about its centre, through the camera unless `IgnoreCamera`. A sprite past the 10,000th of a batch is dropped without a word. The tile maps and layers (chapters 7 and 8) write into the same buffer.

> `AddBatchedSprite` has no `Scaled` parameter: it always measures against the window's size, `Util_WinWidth` by `Util_WinHeight`. It places sprites correctly where that is the size being drawn - inside a render target (whose `GL_BeginRenderTarget` sets it to the target's size), in `#GL_VIEWPORT_NATIVE` mode, or straight into the window - and not in a canvas of another size. The example below draws its batch into a render target of the canvas's size for that reason. The same holds for the particles.

## Particles

The particle engine draws up to 10,000 quads (`#MAX_PARTICLES`) in one instanced draw call. `InitParticleEngine()` makes its buffers once. Each frame, `ClearParticles()` empties the list, `AddParticle(X, Y, Size, Angle, R, G, B, A)` adds one (`Size` is the side of its square, `Angle` turns it), and `RenderParticles()` draws them all through the camera. The list is in the global array `GL_Particles()`, with `GL_ParticleCount` entries used; a program may change entries in place between `AddParticle` and `RenderParticles`.

> The source's comment calls these "perfect circles", and the fragment shader is written to cut a circle with a soft edge. As written, the shader's circle has a radius of 1 while the quad's corners are at most 0.71 from its centre, so nothing is cut and each particle is drawn as a solid square.

## Render targets

A **render target** is an offscreen picture: draw into it, then draw it like a sprite. `GL_CreateRenderTarget(Width, Height, Linear)` makes one of that many pixels (RGBA, 8 bits a channel); `Linear = #True` smooths it when it is drawn larger or smaller. Between `GL_BeginRenderTarget(*T)` and `GL_EndRenderTarget(*T)`, everything drawn lands in the target, in its own pixels: `Begin` saves the size globals and the viewport, sets `Util_BaseWidth`, `Util_BaseHeight`, `Util_WinWidth` and `Util_WinHeight` to the target's size, and sets the viewport to it; `End` puts them back. Draw into a target with `Scaled = #True`. The target's `Sprite` field is a `GLSprite` for it, so `DrawGLSprite(@*T\Sprite, ...)` shows it.

- `Begin` and `End` pair, and do not nest.
- `End` binds framebuffer 0, the window. A program that began the target while drawing into the canvas binds `Util_FBO` again after `End`.
- `GL_ResizeRenderTarget(*T, W, H)` changes the size and loses the contents. `GL_FreeRenderTarget(*T)` frees it, before the context goes.
- The application kit's scissors and menus are not for use inside a target: they read the window's pointer and size.

## A worked example

The program below draws 2000 batched stars and 200 particles into a render target of the canvas's size, then draws the target, one frame of a four-frame sheet and a turning sprite into the canvas.

@include examples/sprites.pb

## Lines that do not change

`CreateGLStaticLines(Array Lines.f(1))` uploads a list of line segments once: the array holds x, y pairs, two points a segment, in canvas units (measured against `Util_BaseWidth` and `Util_BaseHeight` when it is called). `DrawGLStaticLines(*Mesh, R, G, B, A, LimitVertices)` draws them in one call, all of them or the first `LimitVertices` points. The camera is not applied. A grid, a wireframe or a graph's axes drawn this way cost one call however many segments they have.

## Boxes and polygons

`DrawGLBox(X, Y, W, H, R, G, B, A, Scaled, IgnoreCamera)` fills a rectangle; `DrawGLPolygon(X, Y, RadiusX, RadiusY, Sides, R, G, B, A, Solid, Scaled, IgnoreCamera)` draws a regular polygon about its centre (a circle with enough sides, an ellipse with two radii), filled when `Solid` or as an outline. Both apply the camera unless told not to, and each is one draw call.
