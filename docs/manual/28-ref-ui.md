# GlUI.pbi

The arcade kit (chapter 11 is the guide).

## Constants and globals

| Name | Meaning |
|---|---|
| `#NEON_BASE_W`, `#NEON_BASE_H` | 1280.0 and 720.0: the canvas the kit's sizes are made for (no engine procedure reads them) |
| `#NEON_BUTTON`, `#NEON_SLIDER`, `#NEON_TOGGLE`, `#NEON_METER`, `#NEON_LABEL`, `#NEON_BREADCRUMB`, `#NEON_DIPBANK`, `#NEON_CAROUSEL` | the gadget types, in a gadget's `Type` |
| `#NEON_CHECKBOX` | a gadget type with no procedure to add it and no drawing |
| `#STYLE_CLASSIC`, `#STYLE_MODERN`, `#STYLE_GLOW` | a button's `Style`; kept, not drawn differently |
| `UI_Gadgets()` | the list of gadgets (`NeonGadget`) |
| `UI_ActiveFont` | the font a gadget added now is given |
| `UI_FocusIndex` | the focused gadget's place in the list, from 0 |
| `UI_MouseX`, `UI_MouseY` | the pointer in canvas units, from the last `Neon_UpdateInput` |
| `UI_UseCRT` | `#True` (the start value): `MapPhysicalToVirtual` applies the CRT shader's curve |

## Mapping the pointer

### MapPhysicalToVirtual

Turns a pointer position from the window into canvas units, into `*VirtX`, `*VirtY`: on Linux it multiplies by `Linux_DPIScale` first; then it subtracts `GL_ViewportX`, `GL_ViewportY` and divides by `GL_ViewportW / Util_BaseWidth` and `GL_ViewportH / Util_BaseHeight`; with `UI_UseCRT` it then applies the CRT shader's barrel curve. On Windows pass the pointer in physical pixels (`WindowMouseX`); on Linux in the toolkit's units.

## Adding gadgets

Each returns the new `NeonGadget`. The gadget keeps `UI_ActiveFont`. `ID` is the program's; `X`, `Y`, `W`, `H` are canvas units; `Text` is the label; `*Callback` a `NeonEventCallback` procedure, or 0.

### Neon_AddLabel

A heading at `X`, `Y`, drawn in amber. It has no size and never takes the focus.

### Neon_AddBreadcrumb

A path at `X`, `Y`, drawn in blue and underlined. No size; never takes the focus.

### Neon_AddButton

A button. Narrower than its label plus 40 units, it is widened to that, about its centre. `Style` is kept and not drawn.

### Neon_AddSlider

A slider with `InitialValue` (0 to 1) and its label above. Narrower than its label, it is widened to it, about its centre.

### Neon_AddToggle

A label and a switch, on when `InitialState` is 1. Narrower than its label plus 80, it is widened, about its centre.

### Neon_AddMeter

A meter of 20 segments showing `InitialValue` (0 to 1), its label above. It takes the focus but has no input of its own; the program sets its `Value`.

### Neon_AddDipBank

`SwitchCount` switches, `InitialBitmask` giving which are on (bit 0 the first), the label above: `SwitchCount * 40 + 20` units wide (at least the label's width, about its centre) and 70 high. Its `Value` holds `SwitchCount`.

### Neon_AddCarousel

One of `Options` (separated by "|") shown between arrows, starting at `InitialIndex` (from 0).

## Each frame

### Neon_UpdateInput

Takes the frame's input. `MousePhysX`, `MousePhysY` the pointer (through `MapPhysicalToVirtual`); `MouseClicked`, `MouseReleased` the frame the button went down and came up; `DPadX`, `DPadY` -1, 0 or 1; `ActionPressed` the action button's press.

1. `DPadY` moves `UI_FocusIndex` by one, round the ends, past labels and breadcrumbs.
2. The gadget under the pointer (not a label or breadcrumb) is hovered and takes the focus.
3. The focused gadget: `DPadX` changes a slider by 0.05 (kept between 0 and 1), a carousel by one option (round the ends), a DIP bank's selected switch; a click on it acts (a DIP switch flips, a carousel steps by the half clicked, a slider jumps to the pointer, a button is pressed); a release fires a button and flips a toggle; `ActionPressed` flips the selected DIP switch or a toggle, or fires a button.
4. A change of value or a firing calls the gadget's callback with `EventType` 1 and **ends the call**: the gadgets after it are not updated this frame.

### Neon_DrawUI

Draws every gadget in list order, in canvas units with the camera ignored, advancing the hover glow (6 a second) and the focus pulse by `DeltaTime` seconds; then draws the pointer as a red dot of radius 4 at `UI_MouseX`, `UI_MouseY`.
