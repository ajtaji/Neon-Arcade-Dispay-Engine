# GlUIChrome.pbi

The application kit (chapter 12 is the guide). Sizes given as numbers here are logical: the kit multiplies them by `Neon_UIScale`.

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `#NEON_FACES_WINDOWS`, `#NEON_FACES_OPEN` | 0, 1 | the two typeface sets of `Neon_UseFaceSet` |
| `#NEON_MAXHOT` | 512 | the most hot zones a frame records (more are not recorded) |
| `#NEON_MENU_MAXROOTS` | 32 | the most names a menu bar holds (more are not shown) |
| `#NEON_MENU_ROWH`, `#NEON_MENU_SEPH`, `#NEON_MENU_PADX`, `#NEON_MENU_GAPX`, `#NEON_MENU_ARROWH` | 24, 9, 14, 46, 16 | a menu row's height, a separator's, the side padding, the gap before a shortcut, an arrow strip's height (the menu code uses the same numbers directly) |
| `#NEON_TAB_PADL`, `#NEON_TAB_PADR`, `#NEON_TAB_GAPX` | 12, 8, 6 | a tab's left margin, its right margin without a close box, the gap before the close box |
| `#NEON_TAB_LINES` | 26 | the widest tab, in line heights of the UI font |
| `#NEON_TAB_SCROLL`, `#NEON_TAB_REVEAL` | 1, 2 | `Neon_TabStrip`'s flags: a strip that scrolls; bring the active tab into view |
| `#NEON_CARET_BLINK_MS` | 530 | the caret's blink, on and off, in milliseconds |
| `#NEON_NAV_NONE`, `#NEON_NAV_NEXT`, `#NEON_NAV_PREV`, `#NEON_NAV_ACTIVATE`, `#NEON_NAV_BACK`, `#NEON_NAV_LEFT`, `#NEON_NAV_RIGHT`, `#NEON_NAV_UP`, `#NEON_NAV_DOWN`, `#NEON_NAV_PAGEUP`, `#NEON_NAV_PAGEDOWN` | 0 to 10, in that order | the actions of `Neon_ChromeBeginNav` (chapter 12) |

## Globals

| Global | Meaning |
|---|---|
| `Neon_C_BgR`, `Neon_C_BgG`, `Neon_C_BgB`, `Neon_C_PanelR`, `Neon_C_PanelG`, `Neon_C_PanelB`, `Neon_C_HeadR`, `Neon_C_HeadG`, `Neon_C_HeadB`, `Neon_C_LineR`, `Neon_C_LineG`, `Neon_C_LineB`, `Neon_C_TextR`, `Neon_C_TextG`, `Neon_C_TextB`, `Neon_C_DimR`, `Neon_C_DimG`, `Neon_C_DimB`, `Neon_C_FaintR`, `Neon_C_FaintG`, `Neon_C_FaintB`, `Neon_C_AccR`, `Neon_C_AccG`, `Neon_C_AccB`, `Neon_C_AmbR`, `Neon_C_AmbG`, `Neon_C_AmbB`, `Neon_C_GrnR`, `Neon_C_GrnG`, `Neon_C_GrnB`, `Neon_C_RedR`, `Neon_C_RedG`, `Neon_C_RedB`, `Neon_C_VioR`, `Neon_C_VioG`, `Neon_C_VioB` | the kit's colours, red, green and blue of each, floats 0 to 1, which a program may change: the ground, panels, headers, hairlines, text, dim and faint text, and the accents cyan, amber, green, red and violet |
| `*Neon_FontUI`, `*Neon_FontSmall`, `*Neon_FontBold`, `*Neon_FontMono`, `*Neon_FontItalic` | the five fonts the widgets draw with (`Neon_FontUI` ... `Neon_FontItalic`) |
| `Neon_FaceUI`, `Neon_FaceMono` | the selected typefaces' family names ("Segoe UI", "Consolas" at the start) |
| `Neon_UIScale` | the display's scale; 1 at the start |
| `Neon_MX`, `Neon_MY` | the pointer in canvas units for this frame |
| `Neon_MouseDown`, `Neon_MouseClicked`, `Neon_MouseReleased` | the button now; went down this frame; came up this frame |
| `Neon_Wheel`, `Neon_KeyCode`, `Neon_KeyChar` | this frame's wheel notches, key and character, until a widget uses them |
| `Neon_KeyCtrl` | Ctrl is held for this frame's key: set by the program after `Neon_ChromeBeginFrame` |
| `Neon_DeltaTime` | this frame's time in seconds |
| `Neon_AnimationActive` | some animated value is still moving, or a menu needs its corrected frame: draw again |
| `Neon_FocusID` | the text field that has the keyboard (its ID), 0 for none; a program may set it |
| `Neon_TextAllID` | the text field whose whole text is selected, 0 for none |
| `Neon_TextScroll()` | each text field's horizontal scroll in pixels, by `Str(ID)` (absent: 0) |
| `Neon_CaretDrawn` | a text field with the keyboard was drawn this frame |
| `Neon_CaretPhase` | advanced by the frame time and reset by typing, for a program that reads it; the caret is not drawn from it |
| `Neon_ListCount()` | each list's row count from the frame before, by `Str(ID)` |
| `Neon_MenuOpenRoot` | the open menu's place on the bar from 0, -1 when none is open |
| `Neon_SubOpenKey` | the open submenu, as "menu place:label", "" for none |
| `Neon_HotPrev()`, `Neon_HotPrevCount` | the hot zones of the frame just drawn (`NeonHotZone`), in the order drawn |
| `Neon_TabLayout()` | each tab strip's layout from its last frame, by `Str(ID)` (`Neon_TabRowLayout`) |
| `Neon_NavOn` | this frame was driven by `Neon_ChromeBeginNav` |
| `Neon_NavID`, `Neon_NavX`, `Neon_NavY`, `Neon_NavW`, `Neon_NavH` | the focused control's hot-zone identity and rectangle |

Internal: `Neon_FaceErr`, `Neon_FacesMade`, `Neon_MousePrev`, `Neon_Animation`, `Neon_NavPage`, `Neon_NavMenuRoot`, `Neon_Hot`, `Neon_HotCount`, `Neon_MenuBlockX`, `Neon_MenuBlockY`, `Neon_MenuBlockW`, `Neon_MenuBlockH`, `Neon_MenuBlockActive`, `Neon_DragScrollID`, `Neon_DragScrollGrab`, `Neon_MenuBarX`, `Neon_MenuBarY`, `Neon_MenuBarW`, `Neon_MenuBarH`, `Neon_MenuRootIdx`, `Neon_MenuCursorX`, `Neon_MenuAnyOpenLastFrame`, `Neon_MenuRootCountLastFrame`, `Neon_MenuPreflightRoot`, `Neon_MenuLayoutChanged`, `Neon_MenuMeasW`, `Neon_MenuMeasH`, `Neon_MenuTabX`, `Neon_MenuTabW`, `Neon_DropOpen`, `Neon_DropX`, `Neon_DropY`, `Neon_DropW`, `Neon_DropCursorY`, `Neon_DropMaxW`, `Neon_DropRows`, `Neon_DropScroll`, `Neon_DropViewY`, `Neon_DropViewH`, `Neon_DropScrolls`, `Neon_SubActive`, `Neon_SubOpen`, `Neon_SubKey`, `Neon_SubX`, `Neon_SubY`, `Neon_SubW`, `Neon_SubCursorY`, `Neon_SubMaxW`, `Neon_SubRows`, `Neon_SubScroll`, `Neon_SubViewY`, `Neon_SubViewH`, `Neon_SubScrolls`, `Neon_SaveDropCursorY`, `Neon_SubMeasW`, `Neon_SubMeasH`, `Neon_SubScrollMap`, `Neon_TabScrollPos`, `Neon_CaretMs`, `Neon_CaretFocusID`, `Neon_ListX`, `Neon_ListY`, `Neon_ListW`, `Neon_ListH`, `Neon_ListRowH`, `Neon_ListRow`, `Neon_ListID`, `Neon_ListTop`, `Neon_ListTopPtr`, `Neon_ListInside`, `Neon_NavTakes`, `Neon_MenuSelectRoot`

## Structures

### Structure NeonHotZone

A rectangle (`x`, `y`, `w`, `h`, canvas units) that changes its look under the pointer, and its identity (`id`, from `Neon_HotKey`).

### Structure Neon_TabRowLayout

A tab strip as last drawn: its `Y` and `H`, the part of it tabs show in (`ViewL` to `ViewR`), its number of tabs (`Count`), and each tab's shown part (`X()`, `W()`; a width of 0 is a tab scrolled out of view).

## Fonts and the scale

### Neon_PointsForPixelHeight

The point size at which `FontName` in `Style` has a line height of `WantPixels`: as `GLFontPointsForPixelHeight`.

### Neon_CreateFontPx

`CreateGLFont` at `Neon_PointsForPixelHeight`: a font `WantPixels` pixels high.

### Neon_SetFaces

Selects the proportional (`UIFace`) and monospaced (`MonoFace`) typefaces by family name; with a file, registers the file for the process first (`RegisterFontFile`), and the name must be the family the file holds. Returns `#True`; `#False` with the reason in `Neon_FaceError()` and the selection unchanged when a name is empty or a file cannot be registered.

### Neon_UseFaceSet

Selects `#NEON_FACES_WINDOWS` ("Segoe UI" and "Consolas") or `#NEON_FACES_OPEN` ("Lato" from `Lato-Regular.ttf` and "JetBrains Mono" from `JetBrainsMono-Regular.ttf`, both in `FontDir`, a "/" added when it lacks one). As `Neon_SetFaces`; `#False` for another set.

### Neon_FaceError

Why the last `Neon_SetFaces`, `Neon_UseFaceSet` or `Neon_ChromeFonts` was refused.

### Neon_ChromeFonts

Makes the five fonts from the selected typefaces at 14, 12, 15 (bold), 13 (monospaced) and 14 (italic) pixels, times `Scale` (1 when 0 or less), rounded, each snapped to the pixel; puts them in the five font globals; frees the five it made the last time, unless the program has put its own font in that global since. Returns `#True`; `#False` (and nothing changed) when a font cannot be made.

### Neon_S

`v * Neon_UIScale`: a logical size in canvas units.

## The frame

### Neon_ChromeBeginFrame

Takes the frame's input: the pointer through `MapPhysicalToVirtual` into `Neon_MX`, `Neon_MY`; `MouseIsDown` into `Neon_MouseDown` and the edges against the frame before; `Wheel`, `KeyCode` (a `#PB_Shortcut_` code), `KeyChar` (a character code), `Dt` (seconds). Clears this frame's hot zones, `Neon_AnimationActive`, `Neon_CaretDrawn` and `Neon_NavOn`. `Neon_KeyCtrl` is not changed: the program sets it after the call.

### Neon_ChromeEndFrame

Ends the frame: the wheel, key, character and Ctrl not used are dropped, and this frame's hot zones become `Neon_HotPrev()` for `Neon_HoverIdAt` and navigation.

### Neon_ChromeBeginNav

In place of `Neon_ChromeBeginFrame`, for a frame driven without a pointer: moves the focus by `Action` among the hot zones of the frame just drawn (only the menu bar's and its drop-downs' while a menu is open), turns the action into input (`ACTIVATE` a press, `BACK` Escape, `LEFT` and `RIGHT` the arrow keys, `UP` and `DOWN` a notch of the wheel, `PAGEUP` and `PAGEDOWN` a page of what is under the focus, `ACTIVATE` on the text field with the keyboard Return), puts `Neon_MX`, `Neon_MY` at the focused control's centre, and sets `Neon_NavOn`. `KeyChar` is a character to type (0 none). When the focused control has gone, the focus moves to the nearest control, or back to the menu's name when it was in a menu that closed. With nothing to focus, the pointer is put far off the canvas.

### Neon_ChromeReset

Forgets what the kit remembers between frames: hover fades and other animations, tab strip scrolls and layouts, text field scrolls, list counts, menu measurements, the open menu and submenu, the hot zones, the keyboard, the whole-text selection, a scroll bar drag, the button's state, the navigation focus. The colours, fonts, typefaces and `Neon_UIScale` stay.

### Neon_Animate

Eases the value remembered under `Key` toward `Target`, by `1 - exp(-Speed * dt)` of the way each frame (`dt` the frame time, kept between 0 and 0.05 s), and returns it; within 0.002 it lands on the target. The first call starts it at `Initial`, or at `Target` when `Initial` is left at its default. While it is moving, `Neon_AnimationActive` is set.

## Hot zones

### Neon_HotZone

Records a rectangle and its identity for this frame (up to `#NEON_MAXHOT`). Every widget of the kit calls it for what changes under the pointer; a program's own widgets may too.

### Neon_HotKey

An identity for a widget with no ID of its own: `(Tag << 42) | ((Int(a) & $1FFFFF) << 21) | (Int(b) & $1FFFFF)`. The kit's tags: 1 a button, 2 a menu name, 3 a menu item, 4 a submenu row, 5 a tab, 6 a close box or pin, 7 a vertical scroll-bar thumb, 8 a horizontal one, 9 a text field, 10 a list row, 11 a tab-strip arrow.

### Neon_NavKind

The tag of a hot-zone identity.

### Neon_HoverIdAt

The identity of the last hot zone of the frame just drawn that contains `mx`, `my` (the topmost), or 0.

## Primitives

### Neon_Box

`DrawGLBox` in canvas units with the camera ignored; alpha 1 by default.

### Neon_Frame

A one-unit outline of the rectangle.

### Neon_Glow

Four outlines of decreasing strength round the rectangle (`strength` 0.10 by default): a soft halo.

### Neon_Text

`DrawGLText` in canvas units with the camera ignored; nothing for font 0.

### Neon_TextRight

Text whose right end is at `xRight`.

### Neon_TextCentre

Text centred in the span `x` to `x + w`.

### Neon_Panel

A panel: the body, and when `title` is not "", a header `HeaderH` high (26 by default) with a 3-unit accent mark in `ar`, `ag`, `ab`, the title in capitals, and a hairline frame.

### Neon_Hit

`#True` when the pointer is in the rectangle: left and top edges in, right and bottom out.

### Neon_IsJoinedUnit

`#True` for a string unit that belongs to the character before it: the second half of a surrogate pair (U+DC00 to U+DFFF), a combining accent (U+0300 to U+036F), a variation selector (U+FE00 to U+FE0F), the joiner U+200D.

### Neon_FitText

`Text` unchanged when it fits `MaxW` in `*f`; else the longest beginning that fits with an ellipsis after it (never cut before a joined unit, trailing spaces dropped), the ellipsis "..." when the face lacks U+2026; "" when not even the ellipsis fits. Font 0 or "" returns `Text`.

## Clipping

### Neon_PhysWinWidth

`Util_WinWidth` in physical pixels (`DesktopScaledX` on Windows, times `Linux_DPIScale` on Linux).

### Neon_PhysWinHeight

`Util_WinHeight` in physical pixels.

### Neon_ScissorSet

Clips drawing to a canvas rectangle: the OpenGL scissor box at `GL_ViewportX + x * GL_ViewportW / Util_BaseWidth` and the same in y, flipped to the drawable's bottom with `Neon_PhysWinHeight()`. Reported to the draw log.

### Neon_ScissorClear

Lifts the clip; reported to the draw log.

## Widgets

### Neon_Button

A button; `#True` on the frame it is clicked. `lit` draws it in the accent colours; a button not `enabled` is faint and never fires. Its label is centred in the UI font.

### Neon_ScrollBarV

A vertical scroll bar over `Total` rows of which `Visible` fit, `*Top` the first shown. Clamps `*Top`; a click on the track pages, the thumb (at least 18 units) drags, a navigation page pages; `#True` when `*Top` changed. With nothing to scroll it draws an empty track and sets `*Top` to 0. `ID` names it for the drag.

### Neon_ScrollBarH

The same, horizontal, with `*Left`.

### Neon_TextInput

A single-line text field over `*Text` (a `String` structure); `#True` on the frame Return is pressed in it. `Placeholder` is shown while it is empty and without the keyboard; `*CaretPos` (an integer, optional) is the caret's place, kept between 0 and the length. Chapter 12 lists the keys.

### Neon_CaretOn

Whether the caret is in the shown half of its blink now.

### Neon_CaretFlipInMs

Milliseconds (1 to 530) until the caret's blink changes.

### Neon_ClipboardLine

The clipboard's text up to its first line break, a tab turned into a space.

### Neon_ListBegin

Starts a list in the rectangle, rows `RowH` high, `*Top` the first row shown (clamped to last frame's row count): the wheel over it scrolls three rows, a navigation page a page. Draws its background and clips to it (less the scroll bar's 10 units).

### Neon_ListItem

Emits the next row: `Label` indented by `Depth` (14 units a step), `Selected` highlighted, `Group` drawn as an amber heading, `Detail` at the right, both cut to fit. `#True` on the frame it is clicked. A row out of view is counted and not drawn.

### Neon_ListEnd

Ends the list: records its row count for the next frame and draws its scroll bar (ID `ID + 900000`).

### Neon_TabStrip

A row of tabs from `Labels` (separated by "|"; each one unescaped with `Neon_TabUnescape`), `Active` the active one; returns the index clicked, else `Active`. `WithClose` adds close boxes and reports a click on one in `*ClosedIndex` (-1 otherwise). `Flags`: `#NEON_TAB_SCROLL`, `#NEON_TAB_REVEAL`. `Styles`: a character per tab, "i" italic, "p" pinned (a pin instead of the close box, its click reported in `*PinIndex`). Records its layout for `Neon_TabAt`.

### Neon_TabAt

Which tab of strip `ID` is under `PX`, `PY` in its last frame, or -1 (none there, under an arrow, or a strip never drawn).

### Neon_TabEscape

A label made safe for `Labels`: ESC (27) becomes ESC "e" and "|" becomes ESC "b". A label with neither comes back unchanged.

### Neon_TabUnescape

Undoes `Neon_TabEscape`.

### Neon_TabCloseSide

The side of a tab's close box in a strip `h` high: 18 units, or the small font's line height plus 2 when larger; at most `h - 1`.

### Neon_TabMaxWidth

The widest tab in a strip `w` wide: 26 line heights of the UI font, at least 300 units, at most `w - 8`.

### Neon_TabLabelRoom

The room for a label in a tab `TabW` wide, with or without a close box.

### Neon_TabArrowWidth

The width of a scrolling strip's arrow: the close box's side plus 4.

### Neon_TabStripRoom

The width to give `Neon_TabMaxWidth` for a strip `w` wide with `Flags`: less two arrows when it scrolls.

### Neon_TabScrollOffset

How far strip `ID`'s tabs are moved left, in canvas units (0 when it never scrolled).

### Neon_TabScrollToShow

The scroll position at which tab `i` is wholly in view, changed as little as possible from `Scroll`; `px()` and `pw()` are the tabs' places and widths along the row, `Lead` the margin before the first, `ArrowW` an arrow's width.

## Menus

### Neon_MenuBarBegin

Starts the menu bar in the rectangle: draws it, lets an open menu move to the name under the pointer, and closes an open menu on Escape.

### Neon_MenuBegin

The next name on the bar; `#True` when its drop-down is open and its items are to be emitted. A click opens or closes it; with another menu open, the pointer on it opens it. Always followed by `Neon_MenuEnd`.

### Neon_MenuItem

An item of the open drop-down or submenu: `Shortcut` shown at the right (text only), a disabled item faint and inert, `Checked` drawn with a tick. `#True` on the frame it is clicked, closing the menu.

### Neon_MenuSeparator

A dividing line in the open drop-down or submenu.

### Neon_SubMenuBegin

An item that opens a submenu beside the drop-down while the pointer is on it; `#True` when it is open and its items are to be emitted. One level only. Always followed by `Neon_SubMenuEnd`.

### Neon_SubMenuEnd

Ends a submenu: records its size for the next frame.

### Neon_MenuEnd

Ends a name's drop-down: records its size for the next frame. Call it after every `Neon_MenuBegin`.

### Neon_MenuBarEnd

Ends the bar: a click outside the bar and the open drop-downs closes the menu.

### Neon_MenuBlocksMouse

`#True` while a menu is open, the pointer is on the bar, or it is over the drop-down the frame before drew: the rest of the window should not react to the pointer.

### Neon_MenuIsOpen

`#True` while a menu is open.

### Neon_MenuCloseAll

Closes the open menu and submenu.
