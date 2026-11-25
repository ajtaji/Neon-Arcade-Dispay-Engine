# Known limits and open design points

What the engine does today that a programmer could expect to be otherwise, each as the source has it. Where the matter is a choice still open, it says so.

## Drawing

- **The batcher and the particles measure against the window.** `AddBatchedSprite` and `RenderParticles` have no `Scaled` parameter and place everything against `Util_WinWidth` by `Util_WinHeight`. They are right inside a render target, in `#GL_VIEWPORT_NATIVE` mode or straight into the window, and wrong in a canvas of another size (chapter 5).
- **Particles are squares.** The particle shader is written to cut each quad to a soft circle, but its circle's radius is larger than the quad, so nothing is cut (chapter 5).
- **`DrawGLSprite`'s source rectangle counts rows differently on the two systems**: from the picture's bottom on Windows, from its top on Linux. A render target drawn with `DrawGLSprite` is upright on Windows; by the same arithmetic it would be upside down on Linux. Sprite layers and indexed images count rows from the top on both.
- **`GL_EndRenderTarget` binds framebuffer 0**, not the framebuffer that was bound before `GL_BeginRenderTarget`.
- **Sprites, hulls and line meshes have no procedure to free them** (chapter 4).
- **A font whose face cannot be loaded is still returned**, with a line height of 0, and draws nothing.
- **`DrawGLText` ignores the camera by default**, where the other drawing calls apply it.
- **`UI_UseCRT` starts as `#True`**, so the pointer mapping bends by the CRT curve until a program that presents with `DrawPassthrough` turns it off.
- **`DrawRetroCRT` takes the elapsed time**; the README's frame shows it without one.

## The arcade kit

- `#NEON_CHECKBOX` names a gadget type that has no procedure to add it and no drawing.
- The three button styles are stored and drawn alike.
- A slider jumps to the pointer when clicked and cannot be dragged (with the press edge as `Clicked`, as the kit expects).
- A button has no pressed look: its drawing does not use `IsActive`.
- The pointer over a gadget takes the focus from wherever the D-pad left it.
- A callback ends `Neon_UpdateInput` for the frame; the gadgets after it keep the last frame's state until the next.
- `Neon_DrawUI` always draws the pointer as a red dot.

These are open questions of design, not faults the engine's checks report.

## The application kit

- A list knows its length one frame late; on the frame it is first drawn, a first row set beforehand is brought back to 0.
- A drop-down and a submenu are sized from the frame before; on the frame a menu first opens it is laid out generously and corrected on the next.
- Submenus are one level deep.
- A tab strip without `#NEON_TAB_SCROLL` cuts off the tabs past its end, which then cannot be reached.
- The text field is a single line; its only selection is the whole text, and Ctrl+X cuts only that.
- Driven by a pad, a scroll bar's thumb is paged, not dragged, and text is typed only from a character the program passes.
- A frame records at most 512 hot zones and a bar at most 32 menu names.
- The kit's clipping assumes `Util_WinWidth` and `Util_WinHeight` in logical units, which `#GL_VIEWPORT_NATIVE` mode does not keep on a scaled desktop (chapter 12).
- `#NEON_MENU_ROWH` and the other menu constants describe the sizes the menu code uses; the code writes the numbers itself, so changing a constant changes nothing.

## Tiles, palettes and files

- `GL_TileMapSave` writes one tile layer a file; `GL_TileMapLoad` reads any layer of a file that holds several.
- A save deletes the old file and then renames the new one into its place: a failure between the two leaves only `Path.new`.
- `GL_TileSetCollision` keeps any byte from 0 to 255; the queries test only the three documented bits.
- At most 256 palettes are drawn at once; an image has 8 slots.
- `GL_PaletteFade` keeps a transparent entry's alpha but mixes its red, green and blue like any other entry's.

## The 3D renderer

- Materials are factors only: no textures, no transparency; the light is fixed in the shader.
- `G3D_Init` needs a current `GLWindowContext` (`GL_ContextCapture`).
- The canvas cannot change size while a pass is set up.

## The host services

- Dirty-page tracking (`GL_MemoryWatch`) works on Windows only; elsewhere `GL_MemoryWatchCollect` returns -1, which means "compare everything".
- `GL_SetVSync`, `GL_NoPowerThrottling` and `GL_TimerFine` act on Windows only.
- On Linux, `#GL_Key_Shift`, `#GL_Key_Control` and `#GL_Key_Alt` are the left keys only, and key codes are X keysyms, not the Windows codes.
- When the OpenGL entry points are missing, `LoadModernGL`'s message box has a fixed title that is not the program's own.

## Networking

- `#GL_NET_NORESOLVE` is defined and not returned; a name that cannot be resolved gives "" from `GL_NetResolve`.
- Addresses must be numeric for `GL_NetBind`, `GL_NetConnect` and `GL_NetSendTo`.
- IPv6 addresses are written as eight full groups, never shortened with `::`.
