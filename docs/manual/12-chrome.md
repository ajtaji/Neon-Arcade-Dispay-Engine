# The application kit (GlUIChrome)

`GlUIChrome.pbi` is the kit for an application's window: a menu bar with drop-downs and submenus, panels, buttons, single-line text fields, scroll bars, lists and trees, tab strips, clipping, and the means to drive all of it without a pointer. Include it after `GlUI.pbi`.

## Immediate mode

Unlike the arcade kit, this one is **immediate**: there is no list of widgets. A program calls a widget where it wants it, every frame; the call draws the widget and returns what the user did to it this frame. A list's rows, a menu's items, a strip's tabs are whatever the program emits that frame, so they follow live data with nothing to keep in step. The little a widget must remember between frames (a hover fade, how far a list is scrolled, a menu's measured size) is kept by the kit under the widget's ID.

Everything is drawn in canvas units, with the camera ignored, in the kit's own colours.

## Hosting the kit

A program gives the kit four things.

**The window**, made by `OpenGLWindow` (which compiles the shaders every widget draws with).

**Its fonts.** The widgets draw through five font globals: `*Neon_FontUI` (labels, 14 pixels), `*Neon_FontSmall` (shortcuts, list rows, 12), `*Neon_FontBold` (15, bold), `*Neon_FontMono` (13, monospaced) and `*Neon_FontItalic` (14, italic: a tab styled "i"; the UI font is used when it is 0). Left unset, every widget draws its frame and no text. `Neon_ChromeFonts(Scale)` makes all five from the selected typefaces at those sizes times `Scale`, snapped to the pixel, and frees the five it made the time before; fonts a program made itself and put in the globals are never freed by it. The typefaces are selected with `Neon_UseFaceSet` or `Neon_SetFaces` (chapter 6); `Neon_CreateFontPx` and `Neon_PointsForPixelHeight` are the kit's own copies of `CreateGLFontPx` and `GLFontPointsForPixelHeight`.

**Its sizes and scale.** The kit's measurements - a menu row of 24, a tab's padding of 12 - are logical sizes, multiplied by `Neon_UIScale` through `Neon_S(Value)`. A program that lets the letterbox do its scaling leaves `Neon_UIScale` at 1. An application that draws one canvas unit to one physical pixel sets it to the display's scale (physical pixels over logical units), builds its fonts at that scale, and writes its own sizes as `Neon_S(12)` rather than 12. Such a program does not call `GL_HandleResize`; each time the window changes it sets the three size globals itself:

```pb
Define pw.i, ph.i, Win.i = Util_MainWindowID
Util_WinWidth = WindowWidth(Win, #PB_Window_InnerCoordinate)     ; logical units
Util_WinHeight = WindowHeight(Win, #PB_Window_InnerCoordinate)
GL_ClientPixels(Win, @pw, @ph)                                    ; physical pixels
Util_BaseWidth = pw : Util_BaseHeight = ph                        ; the canvas: one unit a pixel
GL_ViewportX = 0 : GL_ViewportY = 0 : GL_ViewportW = pw : GL_ViewportH = ph
Neon_UIScale = pw / Util_WinWidth
UI_UseCRT = #False
```

> `Util_WinWidth` and `Util_WinHeight` must stay in logical units: the kit's clipping converts them to physical pixels itself (`Neon_PhysWinHeight`), and a physical value there is converted twice, which puts every clipped rectangle off the screen without an error. For the same reason the kit's clipping is wrong in `#GL_VIEWPORT_NATIVE` mode on a scaled desktop, because that mode stores physical pixels in `Util_WinWidth` and `Util_WinHeight`.

**Its input, once a frame.** `Neon_ChromeBeginFrame(PointerX, PointerY, ButtonDown, Wheel, KeyCode, KeyChar, Dt)` takes a snapshot of the input for the frame, so every widget agrees about the same instant: the pointer (as the window gives it: physical pixels on Windows) into `Neon_MX`, `Neon_MY` in canvas units, the left button's state (`Neon_MouseDown`; the kit works out `Neon_MouseClicked` and `Neon_MouseReleased` from the last frame's), the wheel's notches (positive up), a key (`#PB_Shortcut_...`, or 0), a typed character (or 0) and the frame's time in seconds. A program that has Ctrl held sets `Neon_KeyCtrl = #True` after the call. `Neon_ChromeEndFrame()` ends the frame: anything not used is dropped (a key nothing took does not fire later), and the frame's hot zones are kept for the questions below. The frame is then:

```
Neon_ChromeBeginFrame(...)  ->  clear  ->  panels, buttons, lists ...
                            ->  the menu bar, last  ->  Neon_ChromeEndFrame()
```

The menus are emitted last so that their drop-downs draw on top. Because they come last, a program asks `Neon_MenuBlocksMouse()` **before** its own hit tests: while a menu is open, or the pointer is on the bar, the pointer is the menu's, and the rest of the window must not react to it.

## Primitives and colours

`Neon_Box`, `Neon_Frame` (a one-unit outline), `Neon_Glow` (a soft outline four units wide), `Neon_Text`, `Neon_TextRight`, `Neon_TextCentre` and `Neon_Panel` (a titled panel with an accent mark) draw with the kit's conventions. `Neon_Hit(x, y, w, h)` says whether the pointer is in a rectangle (left and top edges in, right and bottom out). The colours are globals, red, green and blue each: the ground `Neon_C_Bg`, panels `Neon_C_Panel`, headers `Neon_C_Head`, hairlines `Neon_C_Line`, text `Neon_C_Text`, `Neon_C_Dim`, `Neon_C_Faint`, and the accents: `Neon_C_Acc` (cyan, the selection), `Neon_C_Amb` (amber, attention), `Neon_C_Grn` (success), `Neon_C_Red` (failure), `Neon_C_Vio`. A program may change them.

`Neon_FitText(*Font, Text, Width)` gives the text unchanged if it fits `Width`, else cut and ended with an ellipsis, keeping as much as fits; it never cuts in front of a character that belongs to the one before it (the second half of a surrogate pair, a combining accent, a variation selector, a joiner: `Neon_IsJoinedUnit`), drops spaces left before the ellipsis, uses three full stops where the face has no ellipsis character, and gives "" when not even the ellipsis fits. `Neon_Animate(Key, Target, Speed, Initial)` eases a value toward a target, independent of the frame rate, remembered under `Key`; while any value is still moving, `Neon_AnimationActive` is `#True` for the frame.

## Clipping

`Neon_ScissorSet(x, y, w, h)` limits drawing to a canvas rectangle and `Neon_ScissorClear()` lifts the limit. They convert the rectangle to the OpenGL scissor box (physical pixels, y up from the drawable's bottom) and report it to the draw log. Every scrolling widget clips itself; a program clips its own scrolled content the same way.

## Buttons

`Neon_Button(x, y, w, h, Label, Lit, Enabled)` draws a button and returns `#True` on the frame it is clicked. `Lit` draws it in the accent colours (the current choice of several); a disabled button is drawn faint and never fires.

## Text fields

`Neon_TextInput(ID, x, y, w, h, @Text.String, Placeholder, @Caret)` is a single-line field. It takes the keyboard when clicked (`Neon_FocusID` is then its ID; a program can also set it) and lets it go on Escape or a click elsewhere. It returns `#True` on the frame Return is pressed in it.

| Key | Does |
|---|---|
| a character | inserted at the caret |
| Left, Right, Home, End | move the caret |
| Backspace, Delete | remove the character before or after the caret |
| Ctrl+A | selects the whole text (drawn highlighted); typing, Backspace or Delete then replace it, an arrow, Home or End let it go |
| Ctrl+C | copies the selected text, or the whole text when nothing is selected |
| Ctrl+X | cuts the selected text (only when the whole text is selected) |
| Ctrl+V | pastes the clipboard's first line at the caret, a tab turned into a space (`Neon_ClipboardLine`) |
| Return | submits |
| Escape | lets the keyboard go |

A click puts the caret on the nearer edge of the character under the pointer. A text wider than the field scrolls so the caret stays inside it. `Caret` is optional; without it the caret is kept at the end. The caret blinks by the clock, 530 milliseconds on and off (`#NEON_CARET_BLINK_MS`), and every key that moves or edits shows it at once. A program that draws only when something happens reads `Neon_CaretDrawn` after its frame and, when it is set, draws again in `Neon_CaretFlipInMs()` milliseconds to show the blink.

## Scroll bars

`Neon_ScrollBarV(ID, x, y, w, h, Total, Visible, @Top)` and `Neon_ScrollBarH(ID, x, y, w, h, Total, Visible, @Left)` draw a scroll bar over `Total` rows (or columns) of which `Visible` fit, `Top` being the first shown. Dragging the thumb, or clicking the track (a page towards the pointer), changes `Top`; the procedure returns `#True` when it changed. A bar with nothing to scroll is drawn as an empty track rather than hidden, so the layout does not move under the pointer, and sets `Top` to 0. The thumb is at least 18 units long.

## Lists and trees

```pb
Define ListTop.i, Picked.i = -1, k.i
Neon_ListBegin(3, 20, 60, 300, 400, 22, @ListTop)        ; ID, rectangle, row height, first row shown
Neon_ListItem("Sources", 0, #False, #True)                ; a group heading
For k = 1 To 40
  If Neon_ListItem("file" + Str(k) + ".pb", 1, Bool(Picked = k), #False, Str(k * 37) + " lines")
    Picked = k                                            ; clicked this frame
  EndIf
Next
Neon_ListEnd()                                            ; draws the scroll bar
```

`Neon_ListItem(Label, Depth, Selected, Group, Detail)` emits one row: indented by `Depth`, highlighted when `Selected`, drawn as an amber heading when `Group`, with `Detail` at the right. It returns `#True` on the frame the row is clicked. The label takes the room it needs and the detail what is left, both cut with an ellipsis when they do not fit. The wheel over the list scrolls three rows a notch. A list cannot know how many rows it has until it has emitted them, so it uses the count of the frame before: on the frame a list is first drawn, its scroll range is 0 and a `Top` set beforehand is brought back to 0.

## Tab strips

@figure tab 140 A tab's measurements.

`Neon_TabStrip(ID, x, y, w, h, Labels, Active, WithClose, @Closed, Flags, Styles, @Pinned)` draws a row of tabs and returns the index that should now be active (the one clicked, or `Active`). `Labels` are separated by "|"; a label that itself holds a "|" is passed through `Neon_TabEscape` first, and the strip undoes it. With `WithClose` each tab has a close box, and a click on it puts the tab's index in `Closed` (else -1): the program decides what closing means. `Styles` has a character per tab: "i" draws the label in the italic font, "p" pins the tab - a pin is drawn where the close box would be, and a click on it is reported in `Pinned`, never in `Closed`.

A tab is as wide as its label plus 26 units (and the close box), up to 26 line heights of the UI font and at least 300 units, never wider than the strip; a longer label is cut with an ellipsis. With `Flags` holding `#NEON_TAB_SCROLL`, a strip with more tabs than room scrolls: arrows appear at the ends that have tabs beyond them, a click on one or a notch of the wheel brings the next hidden tab into view, and `#NEON_TAB_REVEAL` (passed on the frame the active tab changed) brings the active tab into view. `Neon_TabAt(ID, x, y)` says which tab of a strip is under a point, from the last frame (for a right click or a double click: -1 for none), and `Neon_TabScrollOffset(ID)` how far it is scrolled. `Neon_TabCloseSide`, `Neon_TabMaxWidth`, `Neon_TabLabelRoom`, `Neon_TabArrowWidth`, `Neon_TabStripRoom` and `Neon_TabScrollToShow` answer the strip's own measurement questions for a program that lays tabs out itself.

## Menus

@figure menu 165 The menu bar with a drop-down open.

```pb
Define ShowGrid.b
Neon_MenuBarBegin(0, 0, Util_BaseWidth, 28)
If Neon_MenuBegin("File")
  If Neon_MenuItem("Open...", "Ctrl+O") : Debug "open" : EndIf
  Neon_MenuSeparator()
  If Neon_SubMenuBegin("Recent")
    If Neon_MenuItem("level1.ntm") : Debug "recent" : EndIf
  EndIf
  Neon_SubMenuEnd()
  If Neon_MenuItem("Quit", "Alt+F4") : End : EndIf
EndIf
Neon_MenuEnd()                         ; always, whether or not the menu was open
If Neon_MenuBegin("View")
  If Neon_MenuItem("Grid", "", #True, ShowGrid) : ShowGrid ! 1 : EndIf
EndIf
Neon_MenuEnd()
Neon_MenuBarEnd()
```

`Neon_MenuBegin(Title)` draws a name on the bar and returns `#True` when its drop-down is open; the program then emits its items. `Neon_MenuEnd()` is called whether or not it was open: it is what moves on to the next name. A click on a name opens its menu (and a second click closes it); with a menu open, moving along the bar opens the menu under the pointer. `Neon_MenuItem(Label, Shortcut, Enabled, Checked)` draws an item - the shortcut is text only, the program handles the key - and returns `#True` on the frame it is clicked, closing the menu. `Neon_SubMenuBegin(Label)` is an item that opens a submenu to its side while the pointer is on it; submenus go one level deep. Escape, or a click outside the bar and the drop-downs, closes the menu (`Neon_MenuCloseAll`). `Neon_MenuIsOpen()` says whether a menu is open.

A drop-down's size is measured, not declared: each menu uses the size it measured the frame before. The first frame a menu is open it is laid out generously, and on that frame the kit sets `Neon_AnimationActive`, so a program that draws only on events draws the corrected frame at once. A drop-down taller than the canvas scrolls: the wheel over it, or the pointer on the arrow strips at its ends.

## Redrawing only when something changed

An application that draws only when something happens has to know whether a pointer move matters. Every widget that changes its look under the pointer declares its rectangle as it draws (`Neon_HotZone`, with an identity from `Neon_HotKey(Kind, a, b)`); `Neon_HoverIdAt(x, y)` answers, from the frame just drawn, which of them is under a point (0 for none). If the old pointer position and the new one give the same answer, nothing needs drawing.

## Driving the kit without a pointer

A program with a game pad, a remote or only the keys calls, once a frame **in place of** `Neon_ChromeBeginFrame`:

```
Neon_ChromeBeginNav(Action, Dt [, KeyChar])
```

and draws its frame exactly as before. The things that can have the **focus** are the hot zones of the frame just drawn, in the order drawn: every button, menu name and item, submenu row, tab, close box, tab arrow, text field, list row and scroll-bar thumb. While a menu is open, only the bar and its drop-downs take part.

| Action | Does |
|---|---|
| `#NEON_NAV_NEXT`, `#NEON_NAV_PREV` | moves the focus to the next or previous control, round the ends |
| `#NEON_NAV_ACTIVATE` | a click on the focused control; on the text field that already has the keyboard, Return |
| `#NEON_NAV_BACK` | Escape: closes a menu, lets a text field go |
| `#NEON_NAV_LEFT`, `#NEON_NAV_RIGHT` | the Left and Right keys (a text field's caret) |
| `#NEON_NAV_UP`, `#NEON_NAV_DOWN` | a notch of the wheel over the focus: a list or a long drop-down scrolls, a scrolling tab strip steps a tab |
| `#NEON_NAV_PAGEUP`, `#NEON_NAV_PAGEDOWN` | a page of what scrolls under the focus: a scroll bar (as a click on its track), a list, a long drop-down |
| `#NEON_NAV_NONE` | nothing; the focus stays |

The kit puts its pointer at the centre of the focused control, so every widget does for the pad exactly what it does for a mouse, and the focused control shows its hover look - that look is the focus mark. `Neon_NavOn` says the frame was driven this way; `Neon_NavID` is the focused control's identity and `Neon_NavX`, `Neon_NavY`, `Neon_NavW`, `Neon_NavH` its rectangle. The focus follows its control from frame to frame; when the control is gone (scrolled away, its menu closed) it moves to the nearest control, or back to the menu's name. A program with both a mouse and a pad calls `Neon_ChromeBeginFrame` on the frames the mouse moves and `Neon_ChromeBeginNav` on the others. A pad cannot drag a scroll bar's thumb (it pages instead), and types only the `KeyChar` the program passes (from an on-screen keyboard, for instance).

`Neon_ChromeReset()` forgets everything the kit remembers between frames - hover fades, scroll positions, list counts, menu sizes, the open menu, the keyboard, the focus - so the next frame is drawn as the first one was: for a program that replaces its whole screen, and for a check or a replayed script. The colours, the fonts, the typefaces and `Neon_UIScale` are kept.

## A worked example

A 1:1 application canvas with a menu bar, a search field, two buttons, a tab strip and a long list, driven by the mouse and keys or by pad 0:

@include examples/chrome.pb

`examples/WidgetGallery.pb` shows every widget of the kit in every state, with an event log; F5 and F6 play its script with the mouse and with the pad (appendix B).
