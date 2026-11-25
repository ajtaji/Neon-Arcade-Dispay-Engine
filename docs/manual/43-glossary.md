# Glossary

**Alpha mask.** A sprite's byte-per-pixel record of which pixels are solid (1) and which clear (0), used by collision.

**Atlas page.** A 1024 by 1024 texture a font's glyphs are drawn into as they are needed.

**Batch.** Many quads of one texture sent to the GPU and drawn in one call.

**Canvas.** The fixed-size picture a program draws into, `Util_BaseWidth` by `Util_BaseHeight` canvas units, shown in the window by the presentation calls.

**Canvas unit.** The unit of the canvas: one pixel of the canvas framebuffer.

**Cell.** One 16-bit place of a tile map: a tile number plus one, and orientation bits.

**Chrome.** The application kit (`GlUIChrome.pbi`): the widgets an application's window is made of.

**Collision byte.** A tile's kind for the collision queries: solid, one-way or slope.

**Draw call.** One request to the GPU to draw; the main cost of a 2D frame.

**Draw log.** A list of the primitives drawn while it is recording, for checks that compare lists rather than pixels.

**Fixed advance.** A font in which every character is the same width.

**Fixed layer.** A layer drawn in canvas units, unmoved by the camera.

**Focus.** The control the D-pad or the navigation actions act on.

**Framebuffer.** An OpenGL drawing surface; framebuffer 0 is the window.

**Gadget.** A widget of the arcade kit, held in the list `UI_Gadgets()`.

**Hot zone.** A rectangle a widget declares as it draws, because its look changes under the pointer; also the set of things the navigation focus can move to.

**Immediate mode.** A UI style in which widgets are called every frame and keep no list; the application kit.

**Indexed image.** A picture of colour numbers drawn through a palette.

**Letterbox.** Showing the canvas at the largest size that keeps its shape, with bars on two sides.

**Logical unit.** The desktop's unit for window sizes; on a desktop scaled by 125 percent, 4 logical units are 5 physical pixels.

**Metric face.** A font made with a fixed advance and a set line height, so that a layout's every width is known in advance.

**Palette.** A table of up to 256 colours, kept as set and as shown.

**Palette slot.** One of the eight places in an indexed image (or a layer) that holds a palette.

**Parallax.** A layer following the camera at a fraction of its speed, to look far away.

**Pass.** The 3D renderer's drawing on the canvas, between `G3D_Begin` and `G3D_End`.

**Physical pixel.** A pixel of the screen.

**Render target.** An offscreen picture drawn into and then drawn like a sprite.

**Retained mode.** A UI style in which widgets are added once and kept in a list; the arcade kit.

**Scissor.** OpenGL's clipping rectangle; set from canvas units by `Neon_ScissorSet`.

**Sheet.** One picture holding many smaller ones (tiles, animation frames).

**Spring bone.** A model's node that lags behind and swings back under gravity.

**Tile set.** A sheet cut into equal tiles, numbered from 0.

**Tofu.** The hollow box drawn for a character the face cannot draw.

**Viewport.** Where on the drawable OpenGL draws, `GL_ViewportX`, `GL_ViewportY`, `GL_ViewportW`, `GL_ViewportH`, in physical pixels.
