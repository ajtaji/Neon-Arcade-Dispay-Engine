# GlSpriteFunctions.pbi

Sprites, the batcher and the particles (chapter 5 is the guide).

## Constants and globals

- `#GL_SpriteRowsBottomUp` - 1 on Windows, 0 on Linux: whether the first row of pixels uploaded to a sprite's texture is drawn at the bottom. A program that fills a texture from memory itself computes the source row as `Height - 1 - y` when it is 1, else `y`.
- `#MAX_PARTICLES` - 10000, the particle engine's capacity.
- `GL_MaxBatch` - 10000, the batcher's capacity in sprites; `GL_BatchCount` - the sprites in the batch now; `GL_CurrentBatchTexture` - the batch's texture; `GL_BatchBuffer` (`*GL_BatchBuffer`) - its vertex data, 8 floats a vertex, 6 vertices a sprite; `GL_BatchShader`, `GL_BatchVAO`, `GL_BatchVBO`, `GL_BatchTexLoc` - its shader, array, buffer and uniform. The tile maps and layers write into the same buffer.
- `GL_Particles()` - the particles, an array of `InstancedParticle`; `GL_ParticleCount` - how many are in use.

### Structure InstancedParticle

One particle: `X`, `Y` (its centre), `Size` (the side of its square), `Angle` (radians), and its colour `R`, `G`, `B`, `A`.

## Sprites

### LoadGLSprite

Loads a picture file into a new sprite and returns it, or 0 when PureBasic cannot load the file (enable the decoders first).

- `Filename` - the file.
- `ColorKey` - an `RGB()` colour made fully transparent wherever it is exactly matched; -1 (the default) for none.

The texture is RGBA, nearest-filtered and clamped at its edges; the alpha mask is filled from the picture's alpha after the key is applied.

### LoadGLSpriteMemory

As `LoadGLSprite`, from an encoded picture in memory (`CatchImage`): a file included with `IncludeBinary`, or a picture made with `EncodeImage`.

### CreateProceduralRopeSprite

Draws a 32 by 64 picture of a twisted orange rope in code and returns it as a sprite: a picture that needs no file.

### DrawGLSprite

Draws a sprite: one draw call.

- `ScreenX`, `ScreenY` - the top-left corner; `AngleRadians` - a turn about the centre; `Scale` - the size multiplier.
- `R`, `G`, `B`, `A` - multiplies the picture's colours.
- `Scaled` - `#True`: canvas units.
- `SrcX`, `SrcY`, `SrcW`, `SrcH` - a part of the picture, in pixels; `SrcX` -1 (the default) draws all of it. `SrcY` counts from the picture's bottom on Windows and its top on Linux (chapter 5).
- `IgnoreCamera` - `#True`: the camera is not applied (default: applied).

A sprite of 0 draws nothing.

## The batcher

### InitSpriteBatcher

Makes the batcher's shader and its buffer for `GL_MaxBatch` sprites. Call it once, after the window opens; the tile maps and layers call it themselves if it has not been called.

### BeginBatch

Starts a batch of sprites of one picture: sets the batch's texture and empties it. A sprite of 0 does nothing.

### AddBatchedSprite

Adds the whole picture at `ScreenX`, `ScreenY`, `Width` by `Height`, turned by `AngleRadians` about its centre, in a colour, through the camera unless `IgnoreCamera`. Measured against `Util_WinWidth` by `Util_WinHeight` (there is no `Scaled`). Past `GL_MaxBatch` sprites it does nothing.

### EndBatch

Draws the batch in one call. An empty batch draws nothing. The batch is not emptied: `BeginBatch` does that.

## Particles

### InitParticleEngine

Makes the particle shader and its buffers. Call it once after the window opens.

### ClearParticles

Empties the particle list.

### AddParticle

Adds a particle, unless `#MAX_PARTICLES` are already there.

- `X`, `Y` - its centre, in window units through the camera.
- `Size` - the side of its square. `Angle` - radians.
- `R`, `G`, `B`, `A` - its colour.

### RenderParticles

Draws every particle in the list in one instanced call, through the camera, measured against `Util_WinWidth` by `Util_WinHeight`. An empty list draws nothing. Each particle is drawn as a solid square (chapter 5).
