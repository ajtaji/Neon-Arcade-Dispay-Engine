@part Reference
# GlTypes.pbi

The structures every other module uses. Include it first. Each entry below prints the structure's fields as the source declares them.

### Structure GLPoint

A point: `x`, `y`, floats, in whatever units the caller uses (`GlMath.pbi` uses world or canvas units). The vertices of a `GLPolygon` are an array of these.

See also: `GLPolygon`.

### Structure GLPolygon

A polygon: `VertexCount` points at `Vertices`, in order round the outline. `CheckCollisionSAT` needs it convex. `GenerateSpriteHull` makes one with both blocks allocated by `AllocateMemory`; the program frees `Vertices` and then the structure.

See also: `GenerateSpriteHull`, `CheckCollisionSAT`.

### Structure GLSprite

A picture in an OpenGL texture.

- `TextureID` - the OpenGL texture name.
- `Width`, `Height` - the picture's size in pixels.
- `AlphaMask` - `Width * Height` bytes, row 0 at the top: 1 where the pixel's alpha is above 0, else 0. Read by `CheckCollisionPixelPerfect` and `GenerateSpriteHull`. A render target's sprite has none (0).
- `CollisionPoly` - for the program's own use; no engine procedure sets or reads it.

Made by `LoadGLSprite`, `LoadGLSpriteMemory`, `CreateProceduralRopeSprite`, `GL_IndexedToSprite`; a render target carries one in its `Sprite` field. There is no procedure that frees a sprite (chapter 4).

### Structure GLAnimation

Fields to describe an animation on a sprite sheet: the `Sprite`, a frame's size (`FrameW`, `FrameH`), the number of frames (`TotalFrames`), how many frames a row of the sheet holds (`Columns`), a speed and the time reached (`Speed`, `CurrentTime`). No engine procedure reads or writes it; it is there for a program's own animation code.

### Prototype NeonEventCallback

The shape of an arcade-kit callback: `Procedure OnGadget(GadgetID.i, EventType.i)`. `GadgetID` is the ID the gadget was added with; `EventType` is always 1. It is called from inside `Neon_UpdateInput`, with the list's current element (`UI_Gadgets()`) on the gadget that fired, and that frame's input handling ends when it returns.

See also: `Neon_UpdateInput`, `NeonGadget`.

### Structure NeonGadget

One gadget of the arcade kit, an element of the list `UI_Gadgets()`.

- `ID` - the program's ID for it. `Type` - one of `#NEON_BUTTON`, `#NEON_SLIDER`, `#NEON_TOGGLE`, `#NEON_METER`, `#NEON_LABEL`, `#NEON_BREADCRUMB`, `#NEON_DIPBANK`, `#NEON_CAROUSEL`. `Style` - the style it was added with (not used in drawing).
- `X`, `Y`, `W`, `H` - its rectangle in canvas units, after the kit widened it for its label.
- `IsHovered`, `IsFocused` - this frame's pointer and focus. `SubFocus` - a DIP bank's selected switch.
- `IsActive` - a button: pressed; a toggle: on (1) or off (0); a DIP bank: the switches as bits.
- `Value` - a slider or meter: 0 to 1; a carousel: the option's index; a DIP bank: its number of switches.
- `Text` - the label; a carousel's options separated by "|".
- `FocusPulse`, `HoverAlpha` - the focus pulse's phase and the hover glow, advanced by `Neon_DrawUI`.
- `Callback` - the procedure called when it fires. `Font` - the font it was added with.

See also: chapter 11.
