# The arcade UI kit (GlUI)

`GlUI.pbi` is a small kit for a game's menu screens: labels, buttons, sliders, toggles, meters, banks of DIP switches and carousels, driven by a pointer, by the keys or by a game pad's D-pad. Include it after `GlUtilities.pbi` and `GlMath.pbi`.

## Retained gadgets

The kit is **retained**: a program adds its gadgets once, into the list `UI_Gadgets()`, and each frame calls `Neon_UpdateInput` with what the input did and `Neon_DrawUI` to draw them all. Each gadget is a `NeonGadget`; the `Neon_Add...` procedures return a pointer to it, which stays valid while the gadget is in the list. The program reads a gadget's `Value` and `IsActive` at any time and may set them (a meter shows whatever `Value` the program gives it).

The kit is laid out for a canvas of 1280 by 720 units (`#NEON_BASE_W`, `#NEON_BASE_H`): its switches are 40 units apart, its buttons are padded by 40 units, and so on. Give the canvas that size, or scale the positions.

## The gadgets

Set `UI_ActiveFont` to a font **before** adding gadgets: each gadget keeps the font it was added with, and a gadget's width is worked out from its label in that font when it is added. A program that changes face clears the list and adds its gadgets again.

| Procedure | The gadget | Its value | How its size is decided |
|---|---|---|---|
| `Neon_AddLabel(ID, X, Y, Text)` | a heading in amber | - | no size; never takes the focus |
| `Neon_AddBreadcrumb(ID, X, Y, Text)` | a path in blue, underlined | - | no size; never takes the focus |
| `Neon_AddButton(ID, X, Y, W, H, Text, Style, @Callback)` | a button | `IsActive` while pressed | widened to the label's width plus 40, about its centre |
| `Neon_AddSlider(ID, X, Y, W, H, Value, Text, @Callback)` | a track and a handle, the label above | `Value` 0 to 1 | at least the label's width, about its centre |
| `Neon_AddToggle(ID, X, Y, W, H, Text, State, @Callback)` | a label and a two-way switch at the right | `IsActive` 0 or 1 | at least the label's width plus 80, about its centre |
| `Neon_AddMeter(ID, X, Y, W, H, Value, Text)` | 20 segments, the label above | `Value` 0 to 1, set by the program | as given |
| `Neon_AddDipBank(ID, X, Y, Count, Bits, Text, @Callback)` | `Count` switches, numbered, the label above | `IsActive` a bit mask, bit i switch i | `Count * 40 + 20` by 70, at least the label's width |
| `Neon_AddCarousel(ID, X, Y, W, H, Options, Index, @Callback)` | one of several options with arrows; `Options` separated by "\|" | `Value` the option's index from 0 | as given |

A meter lights segment `i` (0 to 19) when its value is above `i / 20`: an empty meter shows nothing and a full one all twenty. `Style` is kept in the gadget's `Style` field (`#STYLE_CLASSIC`, `#STYLE_MODERN`, `#STYLE_GLOW`); the drawing does not use it, so the three styles look the same.

## Input

`Neon_UpdateInput(PointerX, PointerY, Clicked, Released, DPadX, DPadY, Action)` is called once a frame:

- `PointerX`, `PointerY` are the pointer as the window gives it; they go through `MapPhysicalToVirtual` into `UI_MouseX`, `UI_MouseY` in canvas units (chapter 3). A program with no pointer passes a position off the canvas.
- `Clicked` and `Released` are the frame the button went down and the frame it came up: edges, not the button's state.
- `DPadY` (-1 up, +1 down) moves the **focus** to the previous or next gadget in the list, round the ends, skipping labels and breadcrumbs. `DPadX` (-1, +1) changes the focused gadget: a slider by 0.05, a carousel by one option, the DIP bank's selected switch by one. `Action` presses the focused gadget: a button fires, a toggle flips, the selected DIP switch flips.
- The pointer over a gadget **gives it the focus**: hovering moves the focus wherever the D-pad left it.

What a gadget under the pointer does: a button is pressed while held and fires when released; a toggle flips when released; a slider jumps to the pointer when clicked; a carousel steps back or on when its left or right half is clicked; a DIP switch flips when clicked.

## Callbacks

A gadget given a callback (a procedure of the shape `NeonEventCallback(GadgetID, EventType)`) has it called when its value changes or it fires, whether by the pointer, the keys or the pad. `EventType` is always 1. While the callback runs, the list's current element is the gadget that fired, so `UI_Gadgets()\Value` and `UI_Gadgets()\IsActive` are its new value. **A callback ends `Neon_UpdateInput` for that frame**: the gadgets after it in the list are not updated until the next frame, so a callback may change the list (clear it, add a new screen) safely.

## Drawing

`Neon_DrawUI(DeltaTime)` draws every gadget in list order, in canvas units with the camera ignored, and advances their animations by `DeltaTime` seconds: the hover glow fades in and out at six times a second, and the focused gadget's outline pulses. It then draws the pointer as a small red dot at `UI_MouseX`, `UI_MouseY`; a program that does not want the dot passes a pointer position off the canvas to `Neon_UpdateInput`.

## A worked example

A screen of each kind of gadget, driven by the mouse, the arrow keys with Return, or pad 0's D-pad and A button:

@include examples/arcade_ui.pb

`examples/WidgetGallery.pb` shows every gadget in every state, and `tools/ui_check.pb` plays a script over them with the mouse and with a pad and checks each step (appendix B).
