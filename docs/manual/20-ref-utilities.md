# GlUtilities.pbi: the window, the canvas and drawing

`GlUtilities.pbi` includes the OpenGL bindings and holds the core of the engine. This chapter covers the window, the canvas, the camera, drawing, presentation, render targets, the draw log and the counters; chapter 21 covers text and fonts, chapter 22 the host services.

## Globals

| Global | Type | Meaning |
|---|---|---|
| `Util_BaseWidth`, `Util_BaseHeight` | float | the canvas, in canvas units (chapter 3) |
| `Util_WinWidth`, `Util_WinHeight` | float | the window's client area in logical units |
| `GL_ViewportX`, `GL_ViewportY`, `GL_ViewportW`, `GL_ViewportH` | integer | where the canvas is shown, in physical pixels |
| `GL_ViewportMode` | integer | `#GL_VIEWPORT_LETTERBOX` (0, the default), `#GL_VIEWPORT_NATIVE` (1) or `#GL_VIEWPORT_STRETCH` (2) |
| `GL_CameraX`, `GL_CameraY`, `GL_CameraZoom` | float | the 2D camera: 0, 0, 1 when a window opens |
| `Linux_DPIScale` | double | the window's scale factor on Linux (1 until read) |
| `Util_MainWindowID`, `Util_MainGadgetID` | integer | the window and OpenGL gadget `OpenGLWindow` made (PureBasic `#PB_Any` numbers) |
| `Util_FBO`, `Util_FBOTex` | 32-bit | the canvas framebuffer and its texture (`InitRetroCRT`) |
| `Util_TextShader`, `Util_TextVAO`, `Util_TextVBO`, `Util_TextLoc_Tex`, `Util_TextLoc_Color` | 32-bit | the text and sprite shader, its vertex array and buffer, its uniforms |
| `Util_ShapeShader`, `Util_ShapeVAO`, `Util_ShapeVBO`, `Util_ShapeLoc_Color` | 32-bit | the plain-colour shader for boxes, polygons and lines |
| `Util_PostShader`, `Util_PassShader`, `Util_PostVAO`, `Util_PostVBO`, `Util_PostLoc_Tex`, `Util_PostLoc_Time` | 32-bit | the CRT and plain presentation shaders and their quad |
| `Util_OrigX`, `Util_OrigY`, `Util_OrigW`, `Util_OrigH`, `Util_OrigStyle`, `Util_IsFullscreen` | | the window's place and style saved by `GL_ToggleFullscreen` |
| `GL_CurrentContext` | pointer | the `GLWindowContext` last captured or activated (`*GL_CurrentContext`) |
| `GL_StatDrawCalls`, `GL_StatTextDraws`, `GL_StatTextCalls`, `GL_StatGlyphs`, `GL_StatBufferUploads` | 64-bit | the counters (chapter 17) |
| `GL_DrawLogOn`, `GL_DrawLog()` | byte, list | the draw log: recording or not, and its entries (`GLDrawLogEntry`) |

The shader, array and buffer names are the engine's; a program reads them (to draw with the same shader, for instance) and does not change them. The constants `#GL_VIEWPORT_LETTERBOX`, `#GL_VIEWPORT_NATIVE` and `#GL_VIEWPORT_STRETCH` name the viewport modes, and `#GL_LOG_BOX` (1), `#GL_LOG_TEXT` (2), `#GL_LOG_POLY` (3), `#GL_LOG_CLIP` (4) and `#GL_LOG_NOCLIP` (5) the kinds of draw-log entry.

Internal: `GL_DeleteFramebuffers_Type`, `GL_DeleteFramebuffersFn`, `GL_WorkerLoop`

## The window and the OpenGL entry points

### OpenGLWindow

Opens a window with an OpenGL gadget over its whole client area, makes its context current, loads the OpenGL entry points (`LoadModernGL`), binds Escape to menu event 1001, compiles the text and shape shaders and turns on alpha blending.

- `Title` - the window's title.
- `Width`, `Height` - the client area, in logical units.
- `Flags` - PureBasic window flags (`#PB_Window_SizeGadget` to allow resizing, `#PB_Window_Invisible` for a check program).

Returns the OpenGL gadget, or 0 if the window could not be opened. It sets `Util_MainWindowID`, `Util_MainGadgetID`, and `Util_WinWidth`, `Util_WinHeight`, `Util_BaseWidth`, `Util_BaseHeight` to `Width` and `Height`; it resets the camera and the viewport globals, and first saves the current `GLWindowContext` (if any) so a second window does not lose the first one's objects. A machine without the OpenGL features the engine needs ends the program with a message box (in `LoadModernGL`).

See also: `GL_HandleResize`, `InitRetroCRT`, `GL_HostPrepare`.

### LoadModernGL

Loads the OpenGL entry points the engine uses into its function-pointer globals (chapter 33). If shaders, vertex arrays, framebuffers or instanced drawing are missing it shows a message box listing what is missing, and ends the program. `OpenGLWindow` calls it; a program that makes its own context calls it after making the context current.

### GetGLProc

Returns the address of an OpenGL function by name (`wglGetProcAddress` on Windows, `glXGetProcAddressARB` on Linux), or 0 when the driver does not have it. A context must be current.

- `Name` - the function's name, for example `"glDeleteProgram"`.

### Util_CompileProgram

Compiles a vertex shader and a fragment shader from source and links them into a program; returns the program's name. A shader that does not compile or a program that does not link shows the driver's log in a message box and **ends the program**. Used by the engine for all its shaders and available to a program for its own.

- `VertSrc`, `FragSrc` - GLSL source text.

### GL_SetVSync

Turns vertical sync on (`State` 1) or off (0) on Windows, when the driver offers it. On Linux it does nothing.

### GL_GetHardwareInfo

Returns the OpenGL vendor, renderer and version, one a line, and the swap interval (Windows; -1 when unknown), or a sentence saying the context is not alive.

### GL_ToggleFullscreen

On Windows, makes the main window a borderless window the size of the primary display, or puts it back; on Linux, maximises or restores it. It records the state in `Util_IsFullscreen` and calls `GL_HandleResize`. `GL_FullscreenEnter` (chapter 22) covers the monitor the window is on instead.

## The canvas and the viewport

### InitRetroCRT

Makes the canvas framebuffer (`Util_FBO`) with a texture of `Width` by `Height` pixels (`Util_FBOTex`, linearly filtered), the CRT presentation shader (`Util_PostShader`), the plain one (`Util_PassShader`) and the full-window quad they draw. Give it the canvas's size. A framebuffer the driver does not accept shows a message box and the program goes on, but nothing drawn into the canvas will show.

### DrawRetroCRT

Draws the canvas texture over the viewport through the CRT shader: a barrel curve of 1.5 percent, black outside it, scanlines that drift with `ElapsedSeconds`, and a vignette. Bind framebuffer 0 and set the viewport to the letterbox first.

- `ElapsedSeconds` - a running time in seconds; it moves the scanlines.

> The repository's README shows this call without an argument; the source requires `ElapsedSeconds`.

### DrawPassthrough

Draws the canvas texture over the viewport as it is. Bind framebuffer 0 and set the viewport first.

### GL_HandleResize

Measures the window's client area and sets the viewport for the current viewport mode (chapter 3); also resizes the OpenGL gadget to the whole client area and sets `Util_WinWidth`, `Util_WinHeight`. On Windows the client area's physical size comes from the system's own client rectangle. A client area of zero (a minimised window) changes nothing.

- `GadgetID` - the gadget `OpenGLWindow` returned.

### GL_SetViewportMode

Sets `GL_ViewportMode` for the next `GL_HandleResize`: `#GL_VIEWPORT_LETTERBOX`, `#GL_VIEWPORT_NATIVE` or `#GL_VIEWPORT_STRETCH`.

## Several windows

### Structure GLWindowContext

A copy of the engine's per-window globals - the window and gadget, the sizes, the shader, array, buffer and framebuffer names, the camera, the saved full-screen place, the scale, the viewport and its mode - so each OpenGL window can have its own. `Valid` is set when it was captured from a window that exists.

### GL_ContextCapture

Copies the engine's per-window globals into `*Context` and makes it the current context (`*GL_CurrentContext`). Call it after making a window and setting it up.

### GL_ContextActivate

Makes `*Context`'s window's OpenGL context current and copies its values back into the globals. Returns 1, or 0 when the context is not valid or its window or gadget no longer exists.

### GL_ContextForget

Clears `*Context` and, if it was the current one, leaves no current context.

### GL_ContextIsAlive

Returns `#True` when the current OpenGL context answers (it asks for the version string), `#False` when it is lost, which can happen after the display sleeps or the GPU resets. It never waits.

## Drawing

### DrawGLBox

Fills a rectangle with a colour: one draw call.

- `X`, `Y` - the top-left corner; `W`, `H` - the size. Canvas units with `Scaled`, else window units (chapter 3).
- `R`, `G`, `B`, `A` - the colour, 0 to 1.
- `Scaled` - `#True`: measured against the canvas.
- `IgnoreCamera` - `#True`: the camera is not applied (default: applied).

Logged by the draw log.

### DrawGLPolygon

Draws a regular polygon of `Sides` vertices about a centre - filled (`Solid`, the default) or as an outline - with radii `RadiusX`, `RadiusY` (equal for a circle, different for an ellipse). Vertex 0 is to the right of the centre and the vertices follow clockwise on the screen. Fewer than 3 sides draws nothing. The camera is applied unless `IgnoreCamera`; `Scaled` as `DrawGLBox`. One draw call; logged.

### Structure GLStaticMesh

A line mesh made by `CreateGLStaticLines`: its vertex array (`VAO`), buffer (`VBO`) and number of points (`VertexCount`).

### CreateGLStaticLines

Uploads a list of line segments once, and returns the mesh. The array holds x, y pairs of floats, two points (four floats) a segment, in canvas units, converted against `Util_BaseWidth` and `Util_BaseHeight` as they are at the call. The program frees the mesh (chapter 4).

### DrawGLStaticLines

Draws a line mesh in one call, in a colour, all of it or only its first `LimitVertices` points (0: all). The camera is not applied.

## Render targets

### Structure GLRenderTarget

An offscreen picture: its framebuffer (`FBO`) and texture (`Tex`), its size (`Width`, `Height`), the target as a sprite (`Sprite`, a `GLSprite` with no alpha mask), and the globals `GL_BeginRenderTarget` saved (`SavedBaseW` ... `SavedVH`).

### GL_CreateRenderTarget

Makes a render target of `Width` by `Height` pixels, RGBA, 8 bits a channel, linearly filtered when `Linear` (the default) else nearest. Returns it, or 0 when the driver has no framebuffer objects or does not accept this one.

### GL_ResizeRenderTarget

Gives a render target a new size. Its contents are lost.

### GL_BeginRenderTarget

Directs drawing into the target: saves the size globals and the viewport, binds the target's framebuffer, sets `Util_BaseWidth`, `Util_BaseHeight`, `Util_WinWidth`, `Util_WinHeight` to its size and the viewport to all of it. Draw with `Scaled = #True`. Does not nest.

### GL_EndRenderTarget

Ends drawing into the target: binds framebuffer 0 (the window, even if another framebuffer was bound before `Begin`) and puts back the globals and the viewport.

### GL_FreeRenderTarget

Frees a render target's framebuffer and texture, and the structure.

## The draw log

### Structure GLDrawLogEntry

One primitive drawn while the log was on: `Kind` (`#GL_LOG_BOX`, `#GL_LOG_TEXT`, `#GL_LOG_POLY`, `#GL_LOG_CLIP`, `#GL_LOG_NOCLIP`); `X`, `Y`, `W`, `H` (a box as passed; a text's origin, measured width and line height; a polygon's centre and radii; a clip's rectangle); the colour `R`, `G`, `B`, `A`; a text's `Text` and `Font`; a polygon's `Sides`, with bit 16 set when solid; `Flags` (bit 0 `Scaled`, bit 1 `IgnoreCamera`); `Clip` and `CX`, `CY`, `CW`, `CH`, the clip in force.

### GL_DrawLogStart

Empties `GL_DrawLog()` and starts recording.

### GL_DrawLogStop

Stops recording; the entries stay until the next start.

### GL_DrawLogClip

Reports the clip now in force, in canvas units (`On` `#False`: none), to the log; kept whether or not the log is recording, so a log started later still knows it. While recording it also adds a `#GL_LOG_CLIP` or `#GL_LOG_NOCLIP` entry. Code that sets the OpenGL scissor for a canvas rectangle calls it.

### GL_DrawLogAdd

Adds one entry to the log, with the clip in force. The drawing procedures call it while `GL_DrawLogOn`; a program that draws a primitive of its own can log it the same way.

## Counters

### GL_StatsReset

Sets the five counters (`GL_StatDrawCalls`, `GL_StatTextDraws`, `GL_StatTextCalls`, `GL_StatGlyphs`, `GL_StatBufferUploads`) to 0.
