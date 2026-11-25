# Testing a program the way the engine tests itself

The engine proves its own behaviour with check programs that need no person at the screen. The same means are open to a program built on it.

## A window nobody sees

An OpenGL context needs a window, but not a visible one: `OpenGLWindow(Title, W, H, #PB_Window_Invisible)` makes an invisible window with a working context. A console program (built with `/CONSOLE`) can then draw, read pixels back, and print what it found.

## Compare what was drawn, not pictures of it

Two machines draw the same text differently - the same face is rasterised differently by different systems - so a picture of a user interface is a poor reference. What a screen **did** draw is a good one: which primitive, where, how large, in what colour, with which text and inside which clip. The **draw log** records exactly that.

- `GL_DrawLogStart()` empties the list `GL_DrawLog()` and starts recording; `GL_DrawLogStop()` stops (the entries stay until the next start). `GL_DrawLogOn` says whether it is recording.
- While it records, each `DrawGLBox`, `DrawGLText` and `DrawGLPolygon` adds a `GLDrawLogEntry`: its `Kind` (`#GL_LOG_BOX`, `#GL_LOG_TEXT`, `#GL_LOG_POLY`), the rectangle as the caller passed it (canvas units, before the camera: a box's `X, Y, W, H`; a text's position, its measured width and its font's line height; a polygon's centre and radii), the colour, the text and its font, a polygon's sides (and `Solid` in bit 16 of `Sides`), `Flags` (bit 0 `Scaled`, bit 1 `IgnoreCamera`), and the clip in force (`Clip`, and its rectangle `CX, CY, CW, CH`).
- Whatever sets the scissor for a canvas rectangle reports it with `GL_DrawLogClip(On, X, Y, W, H)`; the application kit's `Neon_ScissorSet` and `Neon_ScissorClear` do. That also adds a `#GL_LOG_CLIP` or `#GL_LOG_NOCLIP` entry.

Drawing is the same with the log on; with it off, the log costs one test a draw. `DrawGLSprite`, the batcher, tile maps, layers and the 3D pass are not logged.

## Fonts whose sizes are round numbers

The application kit's layout depends on only two numbers of each font: its glyphs' advance and its line height. A check that makes its fonts with a fixed advance and sets the line height itself - `CreateGLFontFixed(Name, Size, Style, 8)` and then `*Font\LineHeight = 16` - gets layouts whose every width is a whole number it can work out in advance, on any machine. The engine's UI check calls these **metric faces**.

## A worked example

Two widgets of the application kit drawn in an invisible window, with metric fonts, and the draw log printed:

@include examples/drawlog.pb

## Scripts, with the mouse and with a pad

`examples/WidgetGalleryScreens.pbi` holds the widget gallery's screens and a **script**: a list of steps, each naming what is done to which control ("press the button at 36, 110", "the second tab", "page the list down"). One procedure turns a step into frames of input either as the mouse and keys would give it (a pointer moved to the control's centre, pressed and released) or as a pad would (the focus walked to the control with `#NEON_NAV_NEXT`, then `#NEON_NAV_ACTIVATE`). A control is named the way the kit names it - by its hot-zone identity (`Neon_HotKey`) - so the script finds it wherever the layout puts it.

`tools/ui_check.pb` plays that script twice from `Neon_ChromeReset`, once each way, checks the state and the event log after every step against values worked out from the kit's layout rules, requires the two runs to agree, and compares the record of both - every state and every primitive of every step's last frame - line by line with `tools/ui_check_expected.txt`. The record's format is in the repository's README ("The UI check"). The same approach serves any program: drive it by script, log what it draws, and compare lists.

## Proving behaviour against a slow reference

The engine's other checks compare each fast procedure with a slow one written for clarity: the cells a tile map submits against a pass over every cell, the collision queries against a reference that visits every cell by other methods, the palette operations against arithmetic in floating point, the drawn pixels of a map against a CPU look-up that walks from each pixel back to the sheet. Appendix B lists them and how to run them.
