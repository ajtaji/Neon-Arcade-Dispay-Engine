# Errors, ownership and other conventions

## How a call says it could not do something

The engine reports trouble in five ways, and which one a module uses is fixed for the whole module.

| How | Where | What the program does |
|---|---|---|
| **A message box, then the program ends** | `LoadModernGL` (called by `OpenGLWindow`) when the driver lacks shaders, vertex array objects, framebuffer objects or instanced drawing; `Util_CompileProgram` when a shader does not compile or link (the box shows the driver's log) | nothing can be done after it; these happen only at start-up, on a machine whose OpenGL is too old |
| **A message box, and the program goes on** | `InitRetroCRT` when the canvas framebuffer is not complete | treat it as fatal: nothing drawn into the canvas will show |
| **0 or `#False`, and the reason as a sentence** | tiles and layers (`GL_TileError()`), palettes and indexed images (`GL_PaletteError()`), the 3D renderer (`G3D_Error()`), the typefaces (`Neon_FaceError()`), a shared context (its `Error` field), a memory watch (its `error` field) | test the result; show or log the sentence |
| **A negative result code** | the network module: `#GL_NET_WOULDBLOCK`, `#GL_NET_REFUSED` and the rest (chapter 16) | compare with the constants; never treat a negative count as bytes |
| **Nothing happens** | most drawing calls given a null pointer or nothing to draw (`DrawGLSprite` with sprite 0, `DrawGLText` with font 0 or an empty text, `DrawGLPolygon` with fewer than three sides) | check the pointer when it was made |

The error sentences say what was asked and why it was refused, for example `GL_TileMapCreate: a map is 1 to 65535 cells each way.` A procedure that succeeds does not clear the sentence of an earlier failure (except `G3D_Load`, which clears it at its start); read it only after a call has returned 0 or `#False`.

> Two failures are silent and look like other faults. A font whose face the system cannot load is still returned, and draws nothing (its line height is 0 and every glyph has no width): check `GLFontLineHeight` of a new font. And `LoadGLSprite` returns 0 for a file PureBasic cannot decode: enable the decoder (`UsePNGImageDecoder()` and the others) first.

## Who frees what

Everything the engine makes is the program's to free, with the procedure named for it, while the OpenGL context that made it is still current.

| Made by | Freed by |
|---|---|
| `CreateGLFont`, `CreateGLFontFixed`, `CreateGLFontPx`, `CreateGLFontFixedPx` | `FreeGLFont`; fonts from `GLFontFor` by `GLFontsPurgeUnused` |
| `Neon_ChromeFonts` | the next `Neon_ChromeFonts` frees the five fonts the last one made |
| `GL_CreateRenderTarget` | `GL_FreeRenderTarget` |
| `GL_TileSetCreate`, `GL_TileSetCreateIndexed` | `GL_TileSetFree` (not the sprite or image it was cut from) |
| `GL_TileMapCreate`, `GL_TileMapLoad` | `GL_TileMapFree` |
| `GL_LayersCreate` | `GL_LayersFree` (not the maps and sprites the layers show) |
| `GL_PaletteCreate`, `GL_PaletteLoad` | `GL_PaletteFree` |
| `GL_IndexedCreate`, `GL_IndexedFromImage`, `GL_IndexedLoad` | `GL_IndexedFree` (which frees the palettes too when `GL_IndexedLoad` made them) |
| the palette back end | `GL_PaletteShutdown`, before the context goes |
| `G3D_Load`, `G3D_Mesh` | `G3D_Free`; the pass `G3D_Init` set up by `G3D_Shutdown` |
| `GL_SharedContextCreate` | `GL_SharedContextFree` |
| `GL_WorkerCreate` | `GL_WorkerClose` |
| `GL_MemoryWatchCreate` | `GL_MemoryWatchFree` |
| `GL_ReserveZeroed` | `GL_ReleaseReserved` |
| `GL_NetOpen`, `GL_NetAccept` | `GL_NetClose` |
| `GL_AudioOpen` | `GL_AudioClose` |

Three things the engine makes have no procedure to free them:

- **A sprite** (`LoadGLSprite`, `LoadGLSpriteMemory`, `CreateProceduralRopeSprite`, `GL_IndexedToSprite`): free it with `glDeleteTextures_(1, @*Sprite\TextureID)`, `FreeMemory(*Sprite\AlphaMask)` and `FreeMemory(*Sprite)`.
- **A polygon** from `GenerateSpriteHull`: `FreeMemory(*Poly\Vertices)` and `FreeMemory(*Poly)`.
- **A line mesh** from `CreateGLStaticLines`: its vertex array and buffer (`VAO`, `VBO`) and then `FreeMemory(*Mesh)`.

The engine's own objects - its shaders, the batcher, the particle buffers, the glyph scratch image - live until the program ends.

## Pointers, structures and fields

Most things the engine makes are returned as a pointer to a structure (`*Map.GLTileMap`). A program may read the fields freely. Where a chapter says a structure's fields **are** the interface (a layer's `X`, `ParallaxX`, `Opacity`; a layer sprite's `W`, `Angle`, `Orient`; the 3D model's `transform`), the program sets them directly and the change shows on the next draw. Other fields are the engine's bookkeeping, documented so that they can be read, not written.

## One OpenGL context, one thread

OpenGL objects belong to the context that made them. Every engine call that draws or makes a texture uses the context current on the calling thread, which for an ordinary program is the window's, made current by `OpenGLWindow`. A program with two windows keeps a `GLWindowContext` for each (`GL_ContextCapture` after making the window, `GL_ContextActivate` before working in it). A worker thread that uploads textures uses a second context that shares the first one's objects (`GL_SharedContextCreate`, chapter 15).

The engine's globals (the canvas sizes, the camera, the batcher, the UI kits' state) are shared by the whole program and are not protected against two threads at once. Draw from one thread.

## Names

- `GL_` and `Util_` - the core and the host services; `GL_Tile`, `GL_Layer`, `GL_Palette`, `GL_Indexed` - the 2D modules; `GL_Net` - sockets.
- `Neon_` and `UI_` - the two user-interface kits; `#NEON_` their constants.
- `G3D_` - the 3D renderer.
- `DrawGL...`, `CreateGL...`, `LoadGL...`, `CheckCollision...`, `Math_...` - the oldest calls, named before the prefixes.
