# Coordinates, the canvas and the window

## Canvas units

A program draws in **canvas units**. The canvas is `Util_BaseWidth` by `Util_BaseHeight` units; its origin is the top-left corner, x grows to the right and y grows downwards. When the canvas framebuffer made by `InitRetroCRT` is the same size as the canvas (the usual case), one canvas unit is one pixel of that framebuffer.

@figure coords 250 The canvas's coordinates, and where a sprite's position and angle apply.

Every drawing call of the engine takes its rectangle in the units of a target size, chosen by its `Scaled` parameter:

| `Scaled` | The call's units | Use it for |
|---|---|---|
| `#True` | the canvas: `Util_BaseWidth` by `Util_BaseHeight` | everything drawn into the canvas framebuffer, and into a render target (chapter 5) |
| `#False` | the window: `Util_WinWidth` by `Util_WinHeight` | drawing straight into the window with no canvas |

The call turns its numbers into OpenGL's device coordinates as `x / Width * 2 - 1` and `1 - y / Height * 2`, so a value of the target's width is the right edge of whatever viewport is in force. Most calls default `Scaled` to `#False`; a program that draws into the canvas passes `#True` every time.

- **Rectangles** (`DrawGLBox`, a sprite's `X, Y`) are given by their top-left corner and their width and height.
- **Polygons and circles** (`DrawGLPolygon`) are given by their centre and their two radii. Vertex 0 is to the right of the centre and the vertices follow clockwise on the screen.
- **Angles** are radians. Because y grows downwards, a positive angle turns a sprite clockwise as seen on the screen. A sprite turns about its centre.

## The camera

`GL_CameraX`, `GL_CameraY` and `GL_CameraZoom` are a 2D camera that every drawing call applies unless its `IgnoreCamera` parameter is `#True`. A point drawn at world position `P` lands on the canvas at

```
screen = C + (P - camera - C) * GL_CameraZoom
C      = the centre of the target: (Width / 2, Height / 2)
```

so with zoom 1 the camera position is the world point shown at the canvas's top-left, and a zoom above 1 magnifies about the canvas's centre. Sizes are multiplied by the zoom too.

@figure camera 180 The 2D camera: what part of the world the canvas shows.

The defaults differ from call to call, and are worth knowing: `DrawGLText` ignores the camera unless told otherwise (`IgnoreCamera = #True`), because text is usually a label on the screen; `DrawGLBox`, `DrawGLPolygon`, `DrawGLSprite`, the batcher, the tile maps and the particles apply it (`#False`). The application kit (chapter 12) always draws with the camera ignored.

## From the canvas to the window

`GL_HandleResize(Gadget)` measures the window's client area and decides where the canvas is shown in it. How it decides is the **viewport mode**, set with `GL_SetViewportMode` before the call:

| Mode | What `GL_HandleResize` does | For |
|---|---|---|
| `#GL_VIEWPORT_LETTERBOX` (the default) | keeps the canvas's shape: the largest rectangle of that shape that fits, centred, with bars on the two other sides; `Util_BaseWidth` and `Util_BaseHeight` are not changed | a game authored at a fixed size |
| `#GL_VIEWPORT_NATIVE` | the whole client area, and one canvas unit is one physical pixel: it sets `Util_BaseWidth`, `Util_BaseHeight`, `Util_WinWidth` and `Util_WinHeight` to the client area's physical size | an application whose bigger window must show more, not larger |
| `#GL_VIEWPORT_STRETCH` | the whole client area; the canvas keeps its size and is stretched, x and y each by its own factor | a fixed, dense layout that must fill the window |

In every mode it also resizes the OpenGL gadget to the whole client area and sets `Util_WinWidth`, `Util_WinHeight` to the client area in logical units (except in `#GL_VIEWPORT_NATIVE`, as above). The result is in `GL_ViewportX`, `GL_ViewportY`, `GL_ViewportW`, `GL_ViewportH`, in physical pixels, measured from the client area's bottom-left as `glViewport_` wants them. A window that is minimised (a client area of zero) leaves everything as it was.

@figure letterbox 240 The canvas shown in the window in letterbox mode.

## Three sizes, three units

The engine keeps three sizes, and they are in three different units. Mixing them up produces a layout that looks wrong rather than an error.

| Globals | Unit | Set by |
|---|---|---|
| `Util_BaseWidth`, `Util_BaseHeight` | canvas units: whatever the program's layout is written in | the program (and `GL_HandleResize` in native mode) |
| `Util_WinWidth`, `Util_WinHeight` | the window's client area in **logical** units, the units `OpenWindow` takes | `OpenGLWindow`, `GL_HandleResize` |
| `GL_ViewportX`, `GL_ViewportY`, `GL_ViewportW`, `GL_ViewportH` | **physical** pixels of the drawable | `GL_HandleResize`, or the program |

On a desktop scaled to 125 percent, a window opened as 800 logical units wide is 1000 physical pixels wide: `Util_WinWidth` is 800 and `GL_ViewportW` up to 1000.

## Screens with a scale factor

A desktop scaled above 100 percent needs five things from a program, and each one missed produces a wrong-looking picture, not an error:

1. **Build with `/DPIAWARE`** on Windows (chapter 1), and call `GL_HostPrepare()` before the first window: it asks Windows for per-monitor awareness, so a window moved to a monitor with a different scale is not stretched as a bitmap.
2. **On Linux, read the scale** after the window exists: `GL_HostScaleRead(Gadget)` puts the window's scale factor in `Linux_DPIScale`. `GL_HandleResize` and `MapPhysicalToVirtual` both use it; left at 1, the viewport and the pointer disagree on a scaled desktop.
3. **Never open a window larger than the desktop.** `GL_WorkArea(*Rect)` gives the primary desktop's work area in logical units; clamp the size asked of `OpenGLWindow` to it, keeping the shape.
4. **Set `Util_BaseWidth` and `Util_BaseHeight` to the authored size** after `OpenGLWindow` (which sets them to the window's size), then call `GL_HandleResize`.
5. **Ask for fonts in pixels.** A font's size in points is scaled by the desktop factor in a DPI-aware program, while the glyph atlas is drawn for the canvas. `CreateGLFontPx` and `Neon_CreateFontPx` take the height wanted in canvas pixels and find the point size that gives it (chapter 6).

## The pointer

A pointer position from the window goes through `MapPhysicalToVirtual(PhysX, PhysY, *VirtX.Float, *VirtY.Float)` before it is compared with anything drawn: it takes the letterbox offset off and divides by the scale `GL_ViewportW / Util_BaseWidth` (and `GL_ViewportH / Util_BaseHeight`), giving canvas units.

- **On Windows**, pass `WindowMouseX(Window)` and `WindowMouseY(Window)` as they are. In a DPI-aware window they are already physical pixels; multiplying them by a scale factor scales them twice, and clicks then land further from the pointer the further it is from the top-left.
- **On Linux**, pass the toolkit's logical position; `MapPhysicalToVirtual` multiplies it by `Linux_DPIScale` itself.
- **`UI_UseCRT`** is `#True` when the program starts. While it is `#True`, `MapPhysicalToVirtual` also applies the CRT shader's barrel curve, so that a pointer over the curved picture maps to the canvas point shown under it. A program that presents with `DrawPassthrough` sets `UI_UseCRT = #False`, or the pointer is slightly off near the canvas's edges.

## Colours and transparency

- Colours passed to drawing calls are four floats, red, green, blue and alpha, from 0.0 to 1.0. A sprite's or a tile's colour multiplies the picture's own colour, so 1, 1, 1, 1 draws it as it is.
- `OpenGLWindow` turns on blending with `glBlendFunc_(#GL_SRC_ALPHA, #GL_ONE_MINUS_SRC_ALPHA)`: what is drawn is mixed over what is there by its alpha. The engine does not change the blend function afterwards (the 3D pass turns blending off while it draws and puts it back).
- Palettes and the indexed-image procedures take colours as one 32-bit value made by PureBasic's `RGBA(R, G, B, A)`, each channel 0 to 255 (in memory: red, green, blue, alpha). An entry whose alpha is 0 is transparent.
- A sprite loaded with a colour key (`LoadGLSprite(File, ColorKey)`) has every pixel of exactly that `RGB()` colour made fully transparent.
- **Clear the canvas with an alpha of 1.** Blending stays on when the canvas is presented, so a canvas cleared with alpha 0 lets the window's own clear colour show through every pixel that nothing opaque covers.
