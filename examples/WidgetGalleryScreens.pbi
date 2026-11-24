; ============================================================================
; WidgetGalleryScreens.pbi - the widget gallery's screens, its event log and
; its script, shared by the demo (examples/WidgetGallery.pb) and the check
; (tools/ui_check.pb), so the check drives exactly what the demo shows.
; ============================================================================
; Requires, included by the main file in this order: GlTypes.pbi,
; GlUtilities.pbi, GlMath.pbi, GlUI.pbi, GlUIChrome.pbi.
;
; A 1280 x 720 canvas: GlUI's widgets are authored for it (#NEON_BASE_W/H),
; and the chrome is drawn on it at Neon_UIScale 1.0.
;
;   Gallery_Init(*ArcadeFont)   once, after the chrome's fonts are made
;   Gallery_Frame(*In)          once a frame, between the host's clear and
;                               its flip; *In says what the input did
;   Gallery_RunStep(*Step, Nav) one step of the script, as many frames as it
;                               takes, through Gallery_Host (the host's frame)
;
; THE INPUT (GalleryInput): either the mouse and the keys (Nav = #False:
; MouseX / MouseY in the host's physical pixels, Down, Wheel, Key, KeyChar,
; Ctrl), or a pad (Nav = #True: one #NEON_NAV_* action a frame). On the
; Arcade screen a pad drives GlUI's own D-pad input (NEXT / PREV = DPadY,
; LEFT / RIGHT / UP / DOWN = DPadX, ACTIVATE = ActionPressed); on the other
; screens it drives the chrome through Neon_ChromeBeginNav. GoScreen is the
; pad's way between screens (its shoulder buttons): the gallery's own, not
; the kit's.
; ============================================================================

#GAL_W = 1280
#GAL_H = 720
#GAL_SCREENS$ = "Arcade|Controls|Lists and tabs|Event log"

Enumeration GalleryScreens
  #GAL_ARCADE
  #GAL_CONTROLS
  #GAL_LISTS
  #GAL_LOG
EndEnumeration

; The kit's widget identities the gallery uses (IDs of tab strips, inputs, lists, bars)
#GAL_ID_SCREENS = 1
#GAL_ID_INPUT1  = 201 : #GAL_ID_INPUT2 = 202 : #GAL_ID_INPUT3 = 203
#GAL_ID_VBAR    = 301 : #GAL_ID_HBAR   = 302 : #GAL_ID_INERT  = 303
#GAL_ID_TABSA   = 401 : #GAL_ID_TABSB  = 402 : #GAL_ID_TABSC  = 403
#GAL_ID_LIST1   = 501 : #GAL_ID_LIST2  = 502 : #GAL_ID_LIST3  = 503
#GAL_ID_LOG     = 601
; GlUI gadget IDs
#GAL_UI_TITLE = 100 : #GAL_UI_CRUMB = 101 : #GAL_UI_START = 102 : #GAL_UI_OPTIONS = 103 : #GAL_UI_LONG = 104
#GAL_UI_VOLUME = 105 : #GAL_UI_SOUND = 106 : #GAL_UI_VIBRATE = 107
#GAL_UI_EMPTY = 108 : #GAL_UI_HALF = 109 : #GAL_UI_FULL = 110 : #GAL_UI_DIP = 111 : #GAL_UI_MODE = 112

Structure GalleryInput
  Nav.b               ; #True: a pad (NavAction); #False: the mouse and the keys
  NavAction.i         ; #NEON_NAV_*
  MouseX.i            ; physical pixels, as the host has them
  MouseY.i
  Down.b
  Wheel.i
  Key.i               ; #PB_Shortcut_*
  KeyChar.i
  Ctrl.b
  GoScreen.i          ; -1, or the screen to go to
  Dt.f
EndStructure

Structure GalleryLogEntry
  Frame.i
  Text.s
EndStructure

#GAL_FITS = 9

Structure GalleryState
  Screen.i
  Frame.i
  Quit.b
  WantFaceSet.i                 ; -1, or the face set the View menu asked for (the host makes the fonts)
  FaceSet.i
  *ArcadeFont.GLFont
  ; Arcade (GlUI)
  Volume.f : Sound.i : Vibrate.i : Dip.i : Mode.i : Starts.i : Options.i : Longs.i
  UIPrevDown.b
  *Meter.NeonGadget
  ; Controls
  Clicks1.i : Clicks2.i : Clicks3.i
  Text1.String : Text2.String : Text3.String
  Caret2.i : Caret3.i
  Submits.i : LastSubmit.s
  Clip.s : ClipRead.b
  VTop.i : HLeft.i : InertTop.i
  Fit.s[#GAL_FITS]
  Points14.i
  ; Lists and tabs
  TabsA.s : StylesA.s : TabA.i : ClosedA.i : PinnedA.i
  TabB.i : RevealB.b : TabC.i : TabScreens.i
  ListTop1.i : Sel1.i : ListTop2.i : ListTop3.i : Sel3.i
  LogTop.i : LogSeen.i
  ; menus
  ShowStatus.b : Marks.b : Board.i
EndStructure

Global G.GalleryState
Global NewList GalleryLog.GalleryLogEntry()
Global Gallery_FitSample.s = "The quick brown fox jumps over the lazy dog"
Global Gallery_FitMark.s       ; set in Gallery_Init: a combining accent and an astral character
Global Gallery_FitAstral.s
Global Dim Gallery_FitW.f(#GAL_FITS - 1)
; #False: leave out the readouts that come from the host and its clock (the caret's blink timer, the
; window's physical size, a point size measured by the system), so a check's record is the same on any
; machine. The demo shows them.
Global Gallery_ShowHost.b = #True

Procedure Gallery_Log(Text.s)
  AddElement(GalleryLog())
  GalleryLog()\Frame = G\Frame
  GalleryLog()\Text = Text
EndProcedure

; ----------------------------------------------------------------------------
; ARCADE: GlUI's retained widgets
; ----------------------------------------------------------------------------
; Called by GlUI from inside Neon_UpdateInput, on the gadget that fired: the
; list's current element is that gadget.
Procedure Gallery_UICallback(GadgetID.i, EventType.i)
  Protected *g.NeonGadget = @UI_Gadgets()
  Select GadgetID
    Case #GAL_UI_START   : G\Starts + 1
    Case #GAL_UI_OPTIONS : G\Options + 1
    Case #GAL_UI_LONG    : G\Longs + 1
    Case #GAL_UI_VOLUME  : G\Volume = *g\Value : If G\Meter : G\Meter\Value = *g\Value : EndIf
    Case #GAL_UI_SOUND   : G\Sound = *g\IsActive
    Case #GAL_UI_VIBRATE : G\Vibrate = *g\IsActive
    Case #GAL_UI_DIP     : G\Dip = *g\IsActive
    Case #GAL_UI_MODE    : G\Mode = Int(*g\Value)
  EndSelect
  Gallery_Log("ui " + Str(GadgetID) + " event " + Str(EventType) + " value " + StrF(*g\Value, 3) + " active " + Str(*g\IsActive))
EndProcedure

; (Re)build the GlUI list from the gallery's values, in UI_ActiveFont (a
; GlUI gadget is sized from its label when it is added, so a new face needs
; the gadgets added again).
Procedure Gallery_BuildArcade()
  ClearList(UI_Gadgets())
  UI_FocusIndex = 0
  UI_ActiveFont = G\ArcadeFont
  Neon_AddLabel(#GAL_UI_TITLE, 80, 84, "ARCADE WIDGETS")
  Neon_AddBreadcrumb(#GAL_UI_CRUMB, 80, 124, "GALLERY > ARCADE")
  Neon_AddButton(#GAL_UI_START, 80, 190, 220, 50, "START", #STYLE_CLASSIC, @Gallery_UICallback())
  Neon_AddButton(#GAL_UI_OPTIONS, 80, 260, 220, 50, "OPTIONS", #STYLE_MODERN, @Gallery_UICallback())
  Neon_AddButton(#GAL_UI_LONG, 80, 330, 120, 50, "A VERY LONG NAME", #STYLE_GLOW, @Gallery_UICallback())
  Neon_AddSlider(#GAL_UI_VOLUME, 440, 210, 320, 30, G\Volume, "VOLUME", @Gallery_UICallback())
  Neon_AddToggle(#GAL_UI_SOUND, 440, 270, 320, 40, "SOUND", G\Sound, @Gallery_UICallback())
  Neon_AddToggle(#GAL_UI_VIBRATE, 440, 320, 320, 40, "VIBRATION", G\Vibrate, @Gallery_UICallback())
  Neon_AddMeter(#GAL_UI_EMPTY, 440, 420, 320, 30, 0.0, "EMPTY")
  G\Meter = Neon_AddMeter(#GAL_UI_HALF, 440, 490, 320, 30, G\Volume, "LEVEL")
  Neon_AddMeter(#GAL_UI_FULL, 440, 560, 320, 30, 1.0, "FULL")
  Neon_AddDipBank(#GAL_UI_DIP, 820, 220, 8, G\Dip, "DIP SWITCHES", @Gallery_UICallback())
  Neon_AddCarousel(#GAL_UI_MODE, 820, 380, 380, 50, "EASY|NORMAL|HARD|ARCADE", G\Mode, @Gallery_UICallback())
EndProcedure

; The list position of GlUI gadget ID (-1 when it is not there).
Procedure.i Gallery_UIIndex(ID.i)
  Protected i.i = 0
  ForEach UI_Gadgets()
    If UI_Gadgets()\ID = ID : ProcedureReturn i : EndIf
    i + 1
  Next
  ProcedureReturn -1
EndProcedure

Procedure.i Gallery_UIGadget(ID.i)
  ForEach UI_Gadgets()
    If UI_Gadgets()\ID = ID : ProcedureReturn @UI_Gadgets() : EndIf
  Next
  ProcedureReturn 0
EndProcedure

; ----------------------------------------------------------------------------
; INIT
; ----------------------------------------------------------------------------
Procedure Gallery_Init(*ArcadeFont)
  ClearList(GalleryLog())
  Protected keepFaces.i = G\FaceSet
  ClearStructure(@G, GalleryState)
  InitializeStructure(@G, GalleryState)
  G\FaceSet = keepFaces
  G\WantFaceSet = -1
  G\ArcadeFont = *ArcadeFont
  G\Volume = 0.5 : G\Sound = 1 : G\Vibrate = 0 : G\Dip = %10100101 : G\Mode = 1
  G\Text1\s = ""
  G\Text2\s = "Hello, world"
  G\Text3\s = "A text far longer than its box, so the field scrolls to keep the caret in view"
  G\Caret2 = Len(G\Text2\s) : G\Caret3 = 0
  G\TabsA = "main.pb|GlUI.pbi|GlUIChrome.pbi|README.md|Pinned notes.txt"
  G\StylesA = "  i p"
  G\ClosedA = -1 : G\PinnedA = -1
  G\Sel1 = -1 : G\Sel3 = -1
  G\ShowStatus = #True
  G\Board = 0
  Gallery_FitMark = "Cafe" + Chr($301) + " au lait, a long one"
  Protected pair.s = Space(2)                       ; U+1F600 as the surrogate pair a text holds it as
  PokeU(@pair, $D83D) : PokeU(@pair + 2, $DE00)
  Gallery_FitAstral = "Smile " + pair + " here, with more after it"
  Gallery_FitW(0) = 360 : Gallery_FitW(1) = 200 : Gallery_FitW(2) = 120 : Gallery_FitW(3) = 40
  Gallery_FitW(4) = 8 : Gallery_FitW(5) = 4 : Gallery_FitW(6) = 52 : Gallery_FitW(7) = 64 : Gallery_FitW(8) = 344
  UI_UseCRT = #False
  Neon_ChromeReset()
  Gallery_BuildArcade()
  If *Neon_FontUI : G\Points14 = Neon_PointsForPixelHeight(Neon_FaceUI, 14) : EndIf
EndProcedure

; ----------------------------------------------------------------------------
; THE SCREENS
; ----------------------------------------------------------------------------
Procedure Gallery_Line(*f.GLFont, x.f, y.f, t.s)
  Neon_Text(*f, x, y, t, Neon_C_DimR, Neon_C_DimG, Neon_C_DimB)
EndProcedure

Procedure Gallery_DrawArcade(*In.GalleryInput, Blocked.b)
  Neon_Panel(40, 70, 1200, 610, "Arcade widgets - GlUI.pbi, retained", Neon_C_AmbR, Neon_C_AmbG, Neon_C_AmbB)
  Gallery_Line(*Neon_FontSmall, 60, 650, "Mouse: hover, click.   Pad: up / down moves the focus, left / right the value, A acts.   Buttons pressed: START " +
                                       Str(G\Starts) + "  OPTIONS " + Str(G\Options) + "  LONG " + Str(G\Longs))
  ; GlUI's input: its own clicked / released edges from the button level
  Protected clicked.b, released.b, dx.i, dy.i, act.b, mx.i = -100000, my.i = -100000
  If *In\Nav
    Select *In\NavAction
      Case #NEON_NAV_NEXT : dy = 1
      Case #NEON_NAV_PREV : dy = -1
      Case #NEON_NAV_LEFT, #NEON_NAV_DOWN : dx = -1
      Case #NEON_NAV_RIGHT, #NEON_NAV_UP : dx = 1
      Case #NEON_NAV_ACTIVATE : act = #True
    EndSelect
    G\UIPrevDown = #False
  Else
    clicked = Bool(*In\Down And Not G\UIPrevDown)
    released = Bool(Not *In\Down And G\UIPrevDown)
    G\UIPrevDown = *In\Down
    If Not Blocked : mx = *In\MouseX : my = *In\MouseY : EndIf
    Select *In\Key
      Case #PB_Shortcut_Up : dy = -1
      Case #PB_Shortcut_Down : dy = 1
      Case #PB_Shortcut_Left : dx = -1
      Case #PB_Shortcut_Right : dx = 1
      Case #PB_Shortcut_Return, #PB_Shortcut_Space : act = #True
    EndSelect
  EndIf
  Neon_UpdateInput(mx, my, clicked, released, dx, dy, act)
  Neon_DrawUI(*In\Dt)
EndProcedure

Procedure Gallery_DrawControls()
  Protected i.i, y.f, t.s
  ; --- buttons and text
  Neon_Panel(16, 70, 400, 310, "Buttons and text", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  If Neon_Button(36, 110, 160, 30, "Normal") : G\Clicks1 + 1 : Gallery_Log("button Normal") : EndIf
  If Neon_Button(36, 150, 160, 30, "Lit", #True) : G\Clicks2 + 1 : Gallery_Log("button Lit") : EndIf
  If Neon_Button(36, 190, 160, 30, "Disabled", #False, #False) : G\Clicks3 + 1 : Gallery_Log("button Disabled") : EndIf
  Gallery_Line(*Neon_FontSmall, 216, 118, "Normal pressed " + Str(G\Clicks1))
  Gallery_Line(*Neon_FontSmall, 216, 158, "Lit pressed " + Str(G\Clicks2))
  Gallery_Line(*Neon_FontSmall, 216, 198, "Disabled pressed " + Str(G\Clicks3))
  Neon_Text(*Neon_FontUI, 36, 236, "Neon_Text, the UI face", Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
  Neon_Text(*Neon_FontSmall, 36, 258, "the small face", Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
  Neon_Text(*Neon_FontBold, 36, 278, "the bold face", Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
  Neon_Text(*Neon_FontMono, 36, 300, "the mono face 0123456789", Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
  Neon_Text(*Neon_FontItalic, 36, 322, "the italic face", Neon_C_VioR, Neon_C_VioG, Neon_C_VioB)
  Neon_TextRight(*Neon_FontUI, 396, 236, "right-aligned", Neon_C_AmbR, Neon_C_AmbG, Neon_C_AmbB)
  Neon_TextCentre(*Neon_FontUI, 216, 180, 350, "centred", Neon_C_RedR, Neon_C_RedG, Neon_C_RedB)
  Neon_Glow(236, 262, 140, 24, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB, 0.3)
  Neon_Box(236, 262, 140, 24, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB)
  Neon_Frame(236, 262, 140, 24, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  Neon_TextCentre(*Neon_FontSmall, 236, 140, 266, "box, frame, glow", Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)

  ; --- fitting text: one sample cut to several widths, and the two cuts that must not split a character
  Neon_Panel(432, 70, 400, 310, "Fitting text", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  For i = 0 To #GAL_FITS - 1
    y = 108 + i * 30
    t = Gallery_FitSample
    If i = 6 : t = Gallery_FitMark : ElseIf i = 7 : t = Gallery_FitAstral : ElseIf i = 8 : t = "Fits exactly" : EndIf
    If i = 8 And *Neon_FontUI : Gallery_FitW(8) = GetGLTextWidth(*Neon_FontUI, t) : EndIf
    G\Fit[i] = Neon_FitText(*Neon_FontUI, t, Gallery_FitW(i))
    Neon_Frame(450, y - 2, Gallery_FitW(i) + 4, 22, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_Text(*Neon_FontUI, 452, y, G\Fit[i], Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
    Neon_TextRight(*Neon_FontSmall, 822, y + 2, StrF(Gallery_FitW(i), 0), Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB)
  Next

  ; --- text input
  Neon_Panel(848, 70, 416, 310, "Text input", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  If Neon_TextInput(#GAL_ID_INPUT1, 868, 108, 376, 28, @G\Text1, "Search the gallery...")
    G\Submits + 1 : G\LastSubmit = G\Text1\s : Gallery_Log("submit 201 " + G\Text1\s)
  EndIf
  If Neon_TextInput(#GAL_ID_INPUT2, 868, 148, 376, 28, @G\Text2, "", @G\Caret2)
    G\Submits + 1 : G\LastSubmit = G\Text2\s : Gallery_Log("submit 202 " + G\Text2\s)
  EndIf
  If Neon_TextInput(#GAL_ID_INPUT3, 868, 188, 200, 28, @G\Text3, "", @G\Caret3)
    G\Submits + 1 : G\LastSubmit = G\Text3\s : Gallery_Log("submit 203 " + G\Text3\s)
  EndIf
  Protected scroll.f
  If FindMapElement(Neon_TextScroll(), Str(#GAL_ID_INPUT3)) : scroll = Neon_TextScroll() : EndIf
  Gallery_Line(*Neon_FontSmall, 1080, 194, "scroll " + StrF(scroll, 1))
  Gallery_Line(*Neon_FontSmall, 868, 228, "keyboard: " + Str(Neon_FocusID) + "   whole text selected: " + Str(Neon_TextAllID))
  Protected clock.s = "(the clock is the host's)"
  If Gallery_ShowHost : clock = "caret shown: " + Str(Neon_CaretOn()) + "   flips in " + Str(Neon_CaretFlipInMs()) + " ms" : EndIf
  Gallery_Line(*Neon_FontSmall, 868, 248, "caret 2: " + Str(G\Caret2) + "   caret 3: " + Str(G\Caret3) + "   " + clock)
  Gallery_Line(*Neon_FontSmall, 868, 268, "submitted " + Str(G\Submits) + ": " + G\LastSubmit)
  Gallery_Line(*Neon_FontSmall, 868, 288, "Ctrl+A selects all, Ctrl+C / X / V copy, cut, paste;")
  Gallery_Line(*Neon_FontSmall, 868, 306, "Left, Right, Home, End, Backspace, Delete, Return, Esc")
  If Neon_Button(868, 336, 200, 26, "Read the clipboard line")
    G\Clip = Neon_ClipboardLine() : G\ClipRead = #True : Gallery_Log("clipboard read")
  EndIf
  If G\ClipRead : Gallery_Line(*Neon_FontSmall, 1078, 342, Neon_FitText(*Neon_FontSmall, "[" + G\Clip + "]", 176)) : EndIf

  ; --- scroll bars, and content clipped to its box
  Neon_Panel(16, 396, 816, 292, "Scroll bars and clipping", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  If Neon_ScrollBarV(#GAL_ID_VBAR, 40, 436, 14, 220, 100, 10, @G\VTop) : Gallery_Log("vbar top " + Str(G\VTop)) : EndIf
  Neon_Box(60, 436, 290, 220, 0.118, 0.122, 0.133)
  Neon_ScissorSet(60, 436, 290, 220)
  For i = 0 To 10
    If G\VTop + i < 100
      Neon_Text(*Neon_FontMono, 66, 438 + i * 22, "Row " + RSet(Str(G\VTop + i), 3, "0") + " of 100", Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
    EndIf
  Next
  Neon_ScissorClear()
  If Neon_ScrollBarV(#GAL_ID_INERT, 356, 436, 10, 220, 5, 10, @G\InertTop) : Gallery_Log("inert bar moved") : EndIf
  Neon_Box(380, 436, 430, 216, 0.118, 0.122, 0.133)
  Neon_ScissorSet(380, 436, 430, 216)
  For i = 0 To 12
    If G\HLeft + i < 60
      Neon_Text(*Neon_FontMono, 384 + i * 36, 440, "C" + Str(G\HLeft + i), Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    EndIf
  Next
  Neon_ScissorClear()
  If Neon_ScrollBarH(#GAL_ID_HBAR, 380, 660, 430, 14, 60, 12, @G\HLeft) : Gallery_Log("hbar left " + Str(G\HLeft)) : EndIf
  Gallery_Line(*Neon_FontSmall, 66, 662, "top " + Str(G\VTop) + " of 0 - 90")
  Gallery_Line(*Neon_FontSmall, 600, 448 + 180, "left " + Str(G\HLeft) + " of 0 - 48")

  ; --- what the kit says about itself
  Neon_Panel(848, 396, 416, 292, "Kit state", Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
  Protected esc.s = Neon_TabEscape("a|b" + Chr(27) + "c")
  Gallery_Line(*Neon_FontSmall, 864, 432, "Neon_HoverIdAt: $" + Hex(Neon_HoverIdAt(Neon_MX, Neon_MY)))
  Gallery_Line(*Neon_FontSmall, 864, 450, "Neon_MenuBlocksMouse " + Str(Neon_MenuBlocksMouse()) + "   Neon_MenuIsOpen " + Str(Neon_MenuIsOpen()))
  Gallery_Line(*Neon_FontSmall, 864, 468, "Neon_NavOn " + Str(Neon_NavOn) + "   Neon_NavID $" + Hex(Neon_NavID))
  Gallery_Line(*Neon_FontSmall, 864, 486, "Neon_UIScale " + StrF(Neon_UIScale, 2) + "   Neon_S(12) = " + StrF(Neon_S(12), 1))
  If Gallery_ShowHost
    Gallery_Line(*Neon_FontSmall, 864, 504, "Neon_PhysWin " + StrF(Neon_PhysWinWidth(), 0) + " x " + StrF(Neon_PhysWinHeight(), 0))
    Gallery_Line(*Neon_FontSmall, 864, 522, "faces: " + Neon_FaceUI + " / " + Neon_FaceMono + "   14 px = " + Str(G\Points14) + " pt")
  EndIf
  Gallery_Line(*Neon_FontSmall, 864, 540, "Neon_TabEscape(a|b ESC c) = " + ReplaceString(esc, Chr(27), "^[") + "   back: " +
                                        Str(Bool(Neon_TabUnescape(esc) = "a|b" + Chr(27) + "c")))
  Gallery_Line(*Neon_FontSmall, 864, 558, "Neon_IsJoinedUnit: U+0301 " + Str(Neon_IsJoinedUnit($301)) + "  U+DE00 " + Str(Neon_IsJoinedUnit($DE00)) +
                                        "  U+200D " + Str(Neon_IsJoinedUnit($200D)) + "  'a' " + Str(Neon_IsJoinedUnit('a')))
  Protected over.b = Neon_Hit(848, 396, 416, 292)
  Protected grow.f = Neon_Animate("gallery:grow", Bool(over), 6.0, 0.0)
  Gallery_Line(*Neon_FontSmall, 864, 580, "Neon_Animate (pointer in this panel):")
  Neon_Box(864, 600, 384 * grow, 10, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  Neon_Frame(864, 600, 384, 10, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
  Gallery_Line(*Neon_FontSmall, 864, 620, "Neon_AnimationActive " + Str(Neon_AnimationActive) + "   frame " + Str(G\Frame))
EndProcedure

; The i-th (0-based) field of a bar-separated list taken out.
Procedure.s Gallery_RemoveField(Fields.s, i.i)
  Protected n.i = CountString(Fields, "|") + 1, k.i, out.s, first.b = #True
  For k = 0 To n - 1
    If k <> i
      If Not first : out + "|" : EndIf
      out + StringField(Fields, k + 1, "|") : first = #False
    EndIf
  Next
  ProcedureReturn out
EndProcedure

Procedure.s Gallery_TabsB()
  Protected i.i, s.s
  For i = 1 To 24
    If i > 1 : s + "|" : EndIf
    If i = 12
      s + "A tab whose label is far too long to be shown whole in any tab of this strip"
    Else
      s + "Tab " + Str(i)
    EndIf
  Next
  ProcedureReturn s
EndProcedure

Procedure Gallery_DrawLists()
  Protected closed.i, pinned.i, r.i, grp.i, k.i, row.i, label.s, flags.i, n.i
  Neon_Panel(8, 64, 640, 624, "Tab strips", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  ; A: close boxes, an italic tab (style "i") and a pinned one ("p")
  r = Neon_TabStrip(#GAL_ID_TABSA, 16, 100, 620, 30, G\TabsA, G\TabA, #True, @closed, 0, G\StylesA, @pinned)
  If r <> G\TabA : G\TabA = r : Gallery_Log("tabs A active " + Str(r)) : EndIf
  If pinned >= 0 : G\PinnedA = pinned : Gallery_Log("tabs A pin " + Str(pinned)) : EndIf
  If closed >= 0
    G\ClosedA = closed : Gallery_Log("tabs A close " + Str(closed))
    n = CountString(G\TabsA, "|") + 1
    If n > 1
      G\TabsA = Gallery_RemoveField(G\TabsA, closed)
      G\StylesA = Left(G\StylesA, closed) + Mid(G\StylesA, closed + 2)
      If closed < G\TabA Or G\TabA >= n - 1 : G\TabA - 1 : EndIf
      If G\TabA < 0 : G\TabA = 0 : EndIf
    EndIf
  EndIf
  ; B: more tabs than room, scrolling; the active one revealed on the frame after it changed
  flags = #NEON_TAB_SCROLL
  If G\RevealB : flags | #NEON_TAB_REVEAL : G\RevealB = #False : EndIf
  r = Neon_TabStrip(#GAL_ID_TABSB, 16, 148, 620, 30, Gallery_TabsB(), G\TabB, #False, 0, flags)
  If r <> G\TabB : G\TabB = r : G\RevealB = #True : Gallery_Log("tabs B active " + Str(r)) : EndIf
  ; C: labels holding a bar and an ESC, through Neon_TabEscape
  r = Neon_TabStrip(#GAL_ID_TABSC, 16, 196, 620, 30, Neon_TabEscape("a|b") + "|plain|" + Neon_TabEscape("esc" + Chr(27) + "x"), G\TabC)
  If r <> G\TabC : G\TabC = r : Gallery_Log("tabs C active " + Str(r)) : EndIf
  Gallery_Line(*Neon_FontSmall, 24, 236, "A: active " + Str(G\TabA) + "  closed " + Str(G\ClosedA) + "  pinned " + Str(G\PinnedA) +
                                       "     B: active " + Str(G\TabB) + "  moved left " + StrF(Neon_TabScrollOffset(#GAL_ID_TABSB), 1) +
                                       "     C: active " + Str(G\TabC))
  Gallery_Line(*Neon_FontSmall, 24, 254, "Neon_TabAt under the pointer: A " + Str(Neon_TabAt(#GAL_ID_TABSA, Neon_MX, Neon_MY)) +
                                       "  B " + Str(Neon_TabAt(#GAL_ID_TABSB, Neon_MX, Neon_MY)) + "  C " + Str(Neon_TabAt(#GAL_ID_TABSC, Neon_MX, Neon_MY)))
  ; an empty list and one that fits
  Gallery_Line(*Neon_FontSmall, 24, 284, "An empty list:")
  Neon_ListBegin(#GAL_ID_LIST2, 16, 302, 620, 110, 22, @G\ListTop2)
  Neon_ListEnd()
  Gallery_Line(*Neon_FontSmall, 24, 424, "A list that fits:")
  Neon_ListBegin(#GAL_ID_LIST3, 16, 442, 620, 110, 22, @G\ListTop3)
  For k = 0 To 3
    If Neon_ListItem("Short row " + Str(k + 1), 0, Bool(G\Sel3 = k), #False, "detail") : G\Sel3 = k : Gallery_Log("list 503 row " + Str(k)) : EndIf
  Next
  Neon_ListEnd()

  ; the long list: three groups of 25 rows, one label far too long, details at the right
  Neon_Panel(656, 64, 616, 624, "A list longer than its box", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  Neon_ListBegin(#GAL_ID_LIST1, 664, 100, 600, 572, 22, @G\ListTop1)
  row = 0
  For grp = 0 To 2
    If Neon_ListItem(StringField("Arduino|Pico|Others", grp + 1, "|"), 0, Bool(G\Sel1 = row), #True) : G\Sel1 = row : Gallery_Log("list 501 row " + Str(row)) : EndIf
    row + 1
    For k = 1 To 25
      label = "Board " + Str(grp * 25 + k)
      If grp = 0 And k = 7 : label = "A board whose name is much too long for this pane, so it is cut short" : EndIf
      If Neon_ListItem(label, 1 + Bool(k % 5 = 0), Bool(G\Sel1 = row), #False, "detail " + Str(k))
        G\Sel1 = row : Gallery_Log("list 501 row " + Str(row))
      EndIf
      row + 1
    Next
  Next
  Neon_ListEnd()
EndProcedure

Procedure Gallery_DrawLogScreen()
  Neon_Panel(8, 64, 1264, 624, "Event log - every callback and every reported action, in order", Neon_C_AmbR, Neon_C_AmbG, Neon_C_AmbB)
  Protected count.i = ListSize(GalleryLog()), visible.i = Int(560 / 20), drawn.i = -1
  ; New entries: show the newest. The list keeps the top within the rows it counted on the frame
  ; before (a list does not know its length until it has drawn), so the top is asked for again
  ; until the list has counted them all.
  If FindMapElement(Neon_ListCount(), Str(#GAL_ID_LOG)) : drawn = Neon_ListCount() : EndIf
  If count <> G\LogSeen
    G\LogTop = count - visible : If G\LogTop < 0 : G\LogTop = 0 : EndIf
    If drawn = count : G\LogSeen = count : EndIf
  EndIf
  Neon_ListBegin(#GAL_ID_LOG, 16, 100, 1248, 560, 20, @G\LogTop)
  ForEach GalleryLog()
    Neon_ListItem(RSet(Str(GalleryLog()\Frame), 6) + "   " + GalleryLog()\Text, 0, #False, #False, "")
  Next
  Neon_ListEnd()
  If Neon_Button(16, 664, 120, 20, "Clear the log")
    ClearList(GalleryLog()) : G\LogSeen = -1
  EndIf
EndProcedure

Procedure Gallery_Menus()
  Protected i.i
  Neon_MenuBarBegin(0, 0, #GAL_W, 28)
  If Neon_MenuBegin("File")
    If Neon_MenuItem("New", "Ctrl+N") : Gallery_Log("menu File New") : EndIf
    If Neon_MenuItem("Open...", "Ctrl+O") : Gallery_Log("menu File Open") : EndIf
    Neon_MenuSeparator()
    If Neon_SubMenuBegin("Recent")
      If Neon_MenuItem("gallery.pb") : Gallery_Log("menu Recent gallery.pb") : EndIf
      If Neon_MenuItem("tiles.ntm") : Gallery_Log("menu Recent tiles.ntm") : EndIf
      If Neon_MenuItem("palette.nti") : Gallery_Log("menu Recent palette.nti") : EndIf
    EndIf
    Neon_SubMenuEnd()
    Neon_MenuSeparator()
    If Neon_MenuItem("Disabled item", "", #False) : Gallery_Log("menu Disabled") : EndIf
    If Neon_MenuItem("Quit", "Alt+F4") : Gallery_Log("menu File Quit") : G\Quit = #True : EndIf
  EndIf
  Neon_MenuEnd()
  If Neon_MenuBegin("View")
    If Neon_MenuItem("Status line", "", #True, G\ShowStatus) : G\ShowStatus ! 1 : Gallery_Log("menu View Status " + Str(G\ShowStatus)) : EndIf
    If Neon_MenuItem("Pointer mark", "", #True, G\Marks) : G\Marks ! 1 : Gallery_Log("menu View Mark " + Str(G\Marks)) : EndIf
    Neon_MenuSeparator()
    If Neon_SubMenuBegin("Faces")
      If Neon_MenuItem("Windows: Segoe UI, Consolas", "", #True, Bool(G\FaceSet = #NEON_FACES_WINDOWS))
        G\WantFaceSet = #NEON_FACES_WINDOWS : Gallery_Log("menu Faces windows")
      EndIf
      If Neon_MenuItem("Open: Lato, JetBrains Mono", "", #True, Bool(G\FaceSet = #NEON_FACES_OPEN))
        G\WantFaceSet = #NEON_FACES_OPEN : Gallery_Log("menu Faces open")
      EndIf
    EndIf
    Neon_SubMenuEnd()
  EndIf
  Neon_MenuEnd()
  If Neon_MenuBegin("Long")
    For i = 1 To 60
      If Neon_MenuItem("Board " + Str(i), "", #True, Bool(G\Board = i)) : G\Board = i : Gallery_Log("menu Long Board " + Str(i)) : EndIf
    Next
  EndIf
  Neon_MenuEnd()
  If Neon_MenuBegin("Help")
    If Neon_MenuItem("About the gallery") : Gallery_Log("menu Help About") : EndIf
  EndIf
  Neon_MenuEnd()
  Neon_MenuBarEnd()
EndProcedure

; ----------------------------------------------------------------------------
; ONE FRAME
; ----------------------------------------------------------------------------
Procedure Gallery_Frame(*In.GalleryInput)
  G\Frame + 1
  If *In\Nav And G\Screen <> #GAL_ARCADE
    Neon_ChromeBeginNav(*In\NavAction, *In\Dt, *In\KeyChar)
  ElseIf *In\Nav
    Neon_ChromeBeginFrame(-100000, -100000, #False, 0, 0, 0, *In\Dt)     ; the pad is GlUI's on this screen
  Else
    Neon_ChromeBeginFrame(*In\MouseX, *In\MouseY, *In\Down, *In\Wheel, *In\Key, *In\KeyChar, *In\Dt)
    Neon_KeyCtrl = *In\Ctrl
  EndIf
  If *In\GoScreen >= 0 And *In\GoScreen <= #GAL_LOG And *In\GoScreen <> G\Screen
    G\Screen = *In\GoScreen : Gallery_Log("screen " + Str(G\Screen))
  EndIf

  ; An open menu owns the pointer: everything under it is drawn as if the pointer were elsewhere.
  Protected blocked.b = Neon_MenuBlocksMouse(), sx.f = Neon_MX, sy.f = Neon_MY
  If blocked : Neon_MX = -1000000.0 : Neon_MY = -1000000.0 : EndIf

  Neon_Box(0, 0, #GAL_W, #GAL_H, Neon_C_BgR, Neon_C_BgG, Neon_C_BgB)
  Select G\Screen
    Case #GAL_ARCADE   : Gallery_DrawArcade(*In, blocked)
    Case #GAL_CONTROLS : Gallery_DrawControls()
    Case #GAL_LISTS    : Gallery_DrawLists()
    Case #GAL_LOG      : Gallery_DrawLogScreen()
  EndSelect
  Protected r.i = Neon_TabStrip(#GAL_ID_SCREENS, 0, 28, #GAL_W, 30, #GAL_SCREENS$, G\Screen)
  If r <> G\Screen : G\Screen = r : Gallery_Log("screen " + Str(r)) : EndIf
  If G\ShowStatus
    Neon_Box(0, 696, #GAL_W, 24, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB)
    Protected how.s = "mouse and keys"
    If *In\Nav : how = "pad" : EndIf
    Gallery_Line(*Neon_FontSmall, 8, 700, "input: " + how + "   pointer " + StrF(sx, 0) + ", " + StrF(sy, 0) + "   under it: $" + Hex(Neon_HoverIdAt(sx, sy)) +
                                        "   focus $" + Hex(Neon_NavID) + "   menu owns the pointer: " + Str(blocked) +
                                        "   faces: " + Neon_FaceUI + ", " + Neon_FaceMono + "   F5 plays the script, F6 with the pad")
  EndIf
  If G\Marks And Not *In\Nav
    Neon_Box(sx - 6, sy, 13, 1, Neon_C_AmbR, Neon_C_AmbG, Neon_C_AmbB) : Neon_Box(sx, sy - 6, 1, 13, Neon_C_AmbR, Neon_C_AmbG, Neon_C_AmbB)
  EndIf

  Neon_MX = sx : Neon_MY = sy
  Gallery_Menus()
  Neon_ChromeEndFrame()
EndProcedure

; ----------------------------------------------------------------------------
; THE SCRIPT - one list of steps, played with the mouse and keys or with a pad
; ----------------------------------------------------------------------------
; A step names WHAT is done to WHICH control; Gallery_RunStep turns it into
; frames of input for either way of driving: a press is a click on the
; control's centre, or the focus walked to it and ACTIVATE. A control is
; named as the kit names it: its hot zone (Tag, A, B as in Neon_HotKey), a
; menu item by its place among the items now showing, or a GlUI gadget ID.
Enumeration GalleryStepKinds
  #GS_SCREEN        ; Arg: the screen (mouse: its tab; pad: GoScreen)
  #GS_PRESS         ; a hot zone
  #GS_ITEM          ; the Arg-th menu item showing (hot-zone tag 3)
  #GS_WHEEL         ; a hot zone; Arg notches (+ up)
  #GS_PAGE          ; a scroll bar's thumb zone or a list row; Arg -1 / +1 (mouse: a click on the track)
  #GS_DRAG          ; a scroll bar's thumb zone to an end, Arg -1 / +1 (pad: pages until it stops)
  #GS_KEY           ; Arg: #PB_Shortcut_Left / _Right / _Escape (pad: LEFT / RIGHT / BACK)
  #GS_TYPE          ; Arg: a character (pad: an on-screen keyboard's KeyChar)
  #GS_SUBMIT        ; Return in the focused text field (pad: ACTIVATE on the field with the keyboard)
  #GS_SELECTALL     ; Ctrl+A (keys only)
  #GS_UI_PRESS      ; GlUI gadget A
  #GS_UI_VALUE      ; GlUI slider / carousel A, Arg -1 / +1
  #GS_UI_DIP        ; GlUI DIP bank A, switch Arg
  #GS_IDLE          ; Arg frames of nothing
EndEnumeration

; How the two ways of driving compare after a step:
;   #GS_BOTH       the same state, and the same new entries in the event log
;   #GS_SAME_END   the same state; the log may differ on the way (a drag reports once,
;                  the pages a pad takes instead report each page)
;   #GS_KEYS_ONLY  not done with a pad at all (Ctrl+A: a pad has no Ctrl); not compared
#GS_BOTH = 0 : #GS_KEYS_ONLY = 1 : #GS_SAME_END = 2

Structure GalleryStep
  Kind.i
  Tag.i : A.i : B.i
  Arg.i
  Only.i            ; #GS_BOTH or #GS_KEYS_ONLY
  Name.s
EndStructure
Global NewList GalleryScript.GalleryStep()

Prototype GalleryHostFrame(*In.GalleryInput)
Global Gallery_Host.GalleryHostFrame          ; the host's frame: clear, Gallery_Frame, present (0: Gallery_Frame alone)
Global Gallery_StepError.s
Global Gallery_ScriptDt.f = 1.0 / 60.0

Procedure Gallery_AddStep(Kind.i, Name.s, Tag.i = 0, A.i = 0, B.i = 0, Arg.i = 0, Only.i = #GS_BOTH)
  AddElement(GalleryScript())
  GalleryScript()\Kind = Kind : GalleryScript()\Name = Name
  GalleryScript()\Tag = Tag : GalleryScript()\A = A : GalleryScript()\B = B
  GalleryScript()\Arg = Arg : GalleryScript()\Only = Only
EndProcedure

; The gallery's script: every widget through its states, in an order whose
; end state is the same whichever way it is driven.
Procedure Gallery_MakeScript()
  ClearList(GalleryScript())
  ; --- Arcade (GlUI)
  Gallery_AddStep(#GS_IDLE, "start", 0, 0, 0, 2)
  Gallery_AddStep(#GS_UI_PRESS, "arcade START", 0, #GAL_UI_START)
  Gallery_AddStep(#GS_UI_PRESS, "arcade SOUND off", 0, #GAL_UI_SOUND)
  Gallery_AddStep(#GS_UI_VALUE, "arcade VOLUME up", 0, #GAL_UI_VOLUME, 0, 1)
  Gallery_AddStep(#GS_UI_DIP, "arcade DIP 2", 0, #GAL_UI_DIP, 0, 1)
  Gallery_AddStep(#GS_UI_VALUE, "arcade MODE right", 0, #GAL_UI_MODE, 0, 1)
  Gallery_AddStep(#GS_UI_VALUE, "arcade MODE left", 0, #GAL_UI_MODE, 0, -1)
  Gallery_AddStep(#GS_UI_PRESS, "arcade VIBRATION on", 0, #GAL_UI_VIBRATE)
  Gallery_AddStep(#GS_UI_PRESS, "arcade LONG button", 0, #GAL_UI_LONG)
  ; --- Controls
  Gallery_AddStep(#GS_SCREEN, "to Controls", 0, 0, 0, #GAL_CONTROLS)
  Gallery_AddStep(#GS_PRESS, "button Normal", 1, 36, 110)
  Gallery_AddStep(#GS_PRESS, "button Lit", 1, 36, 150)
  Gallery_AddStep(#GS_PRESS, "input 2 takes the keyboard", 9, #GAL_ID_INPUT2)
  Gallery_AddStep(#GS_KEY, "input 2 Left", 0, 0, 0, #PB_Shortcut_Left)
  Gallery_AddStep(#GS_KEY, "input 2 Left again", 0, 0, 0, #PB_Shortcut_Left)
  Gallery_AddStep(#GS_KEY, "input 2 Right", 0, 0, 0, #PB_Shortcut_Right)
  Gallery_AddStep(#GS_TYPE, "input 2 types !", 0, 0, 0, '!')
  Gallery_AddStep(#GS_SUBMIT, "input 2 submitted")
  Gallery_AddStep(#GS_SELECTALL, "input 2 whole text selected", 0, 0, 0, 0, #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_KEY, "input 2 Right (lets the selection go)", 0, 0, 0, #PB_Shortcut_Right)
  ; the editing keys a pad does not have: undone again, so both ways go on from the same text
  Gallery_AddStep(#GS_KEY, "input 2 Home", 0, 0, 0, #PB_Shortcut_Home, #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_KEY, "input 2 Delete", 0, 0, 0, #PB_Shortcut_Delete, #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_TYPE, "input 2 types H", 0, 0, 0, 'H', #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_KEY, "input 2 End", 0, 0, 0, #PB_Shortcut_End, #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_KEY, "input 2 Backspace", 0, 0, 0, #PB_Shortcut_Back, #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_TYPE, "input 2 types d", 0, 0, 0, 'd', #GS_KEYS_ONLY)
  Gallery_AddStep(#GS_KEY, "input 2 lets go (Esc)", 0, 0, 0, #PB_Shortcut_Escape)
  Gallery_AddStep(#GS_PRESS, "input 3 takes the keyboard", 9, #GAL_ID_INPUT3)
  Gallery_AddStep(#GS_KEY, "input 3 caret right", 0, 0, 0, #PB_Shortcut_Right)
  Gallery_AddStep(#GS_KEY, "input 3 lets go (Esc)", 0, 0, 0, #PB_Shortcut_Escape)
  Gallery_AddStep(#GS_PAGE, "vbar a page down", 7, #GAL_ID_VBAR, 0, 1)
  Gallery_AddStep(#GS_PAGE, "vbar another page down", 7, #GAL_ID_VBAR, 0, 1)
  Gallery_AddStep(#GS_DRAG, "vbar to the end", 7, #GAL_ID_VBAR, 0, 1, #GS_SAME_END)
  Gallery_AddStep(#GS_PAGE, "vbar a page up from the end", 7, #GAL_ID_VBAR, 0, -1)
  Gallery_AddStep(#GS_DRAG, "vbar to the start", 7, #GAL_ID_VBAR, 0, -1, #GS_SAME_END)
  Gallery_AddStep(#GS_PAGE, "hbar a page right", 8, #GAL_ID_HBAR, 0, 1)
  ; --- Lists and tabs
  Gallery_AddStep(#GS_SCREEN, "to Lists and tabs", 0, 0, 0, #GAL_LISTS)
  Gallery_AddStep(#GS_PRESS, "tabs A second tab", 5, #GAL_ID_TABSA, 1)
  Gallery_AddStep(#GS_PRESS, "tabs A pin of the pinned tab", 6, #GAL_ID_TABSA, 4)
  Gallery_AddStep(#GS_PRESS, "tabs A close the first tab", 6, #GAL_ID_TABSA, 0)
  Gallery_AddStep(#GS_PRESS, "tabs B right arrow", 11, #GAL_ID_TABSB, 1)
  Gallery_AddStep(#GS_PRESS, "tabs B right arrow again", 11, #GAL_ID_TABSB, 1)
  Gallery_AddStep(#GS_PRESS, "tabs B right arrow a third time", 11, #GAL_ID_TABSB, 1)
  Gallery_AddStep(#GS_PRESS, "tabs B the long tab", 5, #GAL_ID_TABSB, 11)
  Gallery_AddStep(#GS_PRESS, "tabs C third tab", 5, #GAL_ID_TABSC, 2)
  Gallery_AddStep(#GS_PRESS, "list 501 row 3", 10, #GAL_ID_LIST1, 3)
  Gallery_AddStep(#GS_WHEEL, "list 501 wheel down", 10, #GAL_ID_LIST1, 3, -1)
  Gallery_AddStep(#GS_PAGE, "list 501 a page down", 10, #GAL_ID_LIST1, 3, 1)
  Gallery_AddStep(#GS_PRESS, "list 503 second row", 10, #GAL_ID_LIST3, 1)
  ; --- the menus
  Gallery_AddStep(#GS_PRESS, "menu File opens", 2, 0, 0)
  Gallery_AddStep(#GS_ITEM, "menu File New", 3, 0, 0, 0)
  Gallery_AddStep(#GS_PRESS, "menu View opens", 2, 1, 0)
  Gallery_AddStep(#GS_ITEM, "menu View Pointer mark", 3, 0, 0, 1)
  Gallery_AddStep(#GS_PRESS, "menu File opens again", 2, 0, 0)
  Gallery_AddStep(#GS_ITEM, "menu File Recent opens", 4, 0, 0, 0)
  Gallery_AddStep(#GS_KEY, "menu closes (Esc)", 0, 0, 0, #PB_Shortcut_Escape)
  Gallery_AddStep(#GS_PRESS, "menu Long opens", 2, 2, 0)
  Gallery_AddStep(#GS_WHEEL, "menu Long scrolls", 3, -1, 0, -1)
  Gallery_AddStep(#GS_ITEM, "menu Long Board 3", 3, 0, 0, 0)
  Gallery_AddStep(#GS_SCREEN, "to the event log", 0, 0, 0, #GAL_LOG)
  Gallery_AddStep(#GS_IDLE, "the log shows", 0, 0, 0, 2)
EndProcedure

Procedure Gallery_RunFrame(*In.GalleryInput)
  If Gallery_Host : Gallery_Host(*In) : Else : Gallery_Frame(*In) : EndIf
EndProcedure

; Canvas units to the host's physical pixels (what the mouse gives the kit).
Procedure.i Gallery_PhysX(cx.f)
  Protected v.f = GL_ViewportX + cx * GL_ViewportW / Util_BaseWidth
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    v / Linux_DPIScale
  CompilerEndIf
  ProcedureReturn Round(v, #PB_Round_Nearest)
EndProcedure
Procedure.i Gallery_PhysY(cy.f)
  Protected v.f = GL_ViewportY + cy * GL_ViewportH / Util_BaseHeight
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    v / Linux_DPIScale
  CompilerEndIf
  ProcedureReturn Round(v, #PB_Round_Nearest)
EndProcedure

Global Gallery_PtrX.f = 640, Gallery_PtrY.f = 700    ; where the scripted mouse is (canvas units)

Procedure Gallery_Input(*In.GalleryInput, Nav.b)
  ClearStructure(*In, GalleryInput)
  *In\Nav = Nav : *In\GoScreen = -1 : *In\Dt = Gallery_ScriptDt
  *In\MouseX = Gallery_PhysX(Gallery_PtrX) : *In\MouseY = Gallery_PhysY(Gallery_PtrY)
EndProcedure

; The zone of the frame just gone with this identity (-1: none).
Procedure.i Gallery_Zone(ID.i)
  Protected i.i
  For i = 0 To Neon_HotPrevCount - 1
    If Neon_HotPrev(i)\id = ID : ProcedureReturn i : EndIf
  Next
  ProcedureReturn -1
EndProcedure

; The identity of the target of *S as the frame just gone drew it (0: not there).
Procedure.i Gallery_TargetID(*S.GalleryStep)
  Protected i.i, n.i = 0, kind.i = *S\Tag, want.i = *S\Arg
  ; a menu row by its place among the rows showing: #GS_ITEM (the Arg-th), or Tag 3 / 4 with A = -1 (the B-th)
  If *S\Kind = #GS_ITEM Or ((kind = 3 Or kind = 4) And *S\A = -1)
    If kind = 0 : kind = 3 : EndIf
    If *S\Kind <> #GS_ITEM : want = *S\B : EndIf
    For i = 0 To Neon_HotPrevCount - 1
      If Neon_NavKind(Neon_HotPrev(i)\id) = kind
        If n = want : ProcedureReturn Neon_HotPrev(i)\id : EndIf
        n + 1
      EndIf
    Next
    ProcedureReturn 0
  EndIf
  Protected id.i = Neon_HotKey(*S\Tag, *S\A, *S\B)
  If Gallery_Zone(id) < 0 : ProcedureReturn 0 : EndIf
  ProcedureReturn id
EndProcedure

; Pad: walk the focus to the zone ID (one NEXT a frame). #False when it cannot be reached.
Procedure.b Gallery_WalkTo(*S.GalleryStep)
  Protected inp.GalleryInput, k.i, id.i
  For k = 0 To 800
    id = Gallery_TargetID(*S)
    If id And Neon_NavID = id And Neon_NavOn : ProcedureReturn #True : EndIf
    Gallery_Input(@inp, #True) : inp\NavAction = #NEON_NAV_NEXT
    Gallery_RunFrame(@inp)
  Next
  Gallery_StepError = "the focus never reached the target of '" + *S\Name + "'"
  ProcedureReturn #False
EndProcedure

; Mouse: put the pointer on canvas point (x, y) and give it one frame.
Procedure Gallery_MoveTo(x.f, y.f)
  Protected inp.GalleryInput
  Gallery_PtrX = x : Gallery_PtrY = y
  Gallery_Input(@inp, #False) : Gallery_RunFrame(@inp)
EndProcedure

Procedure Gallery_Click()
  Protected inp.GalleryInput
  Gallery_Input(@inp, #False) : inp\Down = #True : Gallery_RunFrame(@inp)
  Gallery_Input(@inp, #False) : Gallery_RunFrame(@inp)
EndProcedure

Procedure Gallery_NavDo(Action.i, KeyChar.i = 0)
  Protected inp.GalleryInput
  Gallery_Input(@inp, #True) : inp\NavAction = Action : inp\KeyChar = KeyChar : Gallery_RunFrame(@inp)
  Gallery_Input(@inp, #True) : Gallery_RunFrame(@inp)
EndProcedure

Procedure Gallery_KeyDo(Key.i, KeyChar.i = 0, Ctrl.b = #False)
  Protected inp.GalleryInput
  Gallery_Input(@inp, #False) : inp\Key = Key : inp\KeyChar = KeyChar : inp\Ctrl = Ctrl : Gallery_RunFrame(@inp)
  Gallery_Input(@inp, #False) : Gallery_RunFrame(@inp)
EndProcedure

; Pad, GlUI: move GlUI's focus to gadget ID with DPadY (labels are skipped by GlUI itself).
Procedure.b Gallery_UIFocus(ID.i)
  Protected inp.GalleryInput, k.i, want.i = Gallery_UIIndex(ID)
  For k = 0 To ListSize(UI_Gadgets()) + 1
    If UI_FocusIndex = want : ProcedureReturn #True : EndIf
    Gallery_Input(@inp, #True) : inp\NavAction = #NEON_NAV_NEXT : Gallery_RunFrame(@inp)
  Next
  Gallery_StepError = "GlUI focus never reached gadget " + Str(ID)
  ProcedureReturn #False
EndProcedure

; Run one step, either way. #False (and Gallery_StepError) when it cannot be done.
Procedure.b Gallery_RunStep(*S.GalleryStep, Nav.b)
  Protected inp.GalleryInput, i.i, id.i, z.i, k.i, *g.NeonGadget, cx.f, cy.f, before.i
  Gallery_StepError = ""
  If Nav And *S\Only = #GS_KEYS_ONLY : ProcedureReturn #True : EndIf
  Select *S\Kind
    Case #GS_IDLE
      For i = 1 To *S\Arg : Gallery_Input(@inp, Nav) : Gallery_RunFrame(@inp) : Next

    Case #GS_SCREEN
      If Nav
        Gallery_Input(@inp, #True) : inp\GoScreen = *S\Arg : Gallery_RunFrame(@inp)
        Gallery_Input(@inp, #True) : Gallery_RunFrame(@inp)
      Else
        z = Gallery_Zone(Neon_HotKey(5, #GAL_ID_SCREENS, *S\Arg))
        If z < 0 : Gallery_StepError = "no tab for screen " + Str(*S\Arg) : ProcedureReturn #False : EndIf
        Gallery_MoveTo(Neon_HotPrev(z)\x + Neon_HotPrev(z)\w / 2, Neon_HotPrev(z)\y + Neon_HotPrev(z)\h / 2)
        Gallery_Click()
      EndIf

    Case #GS_PRESS, #GS_ITEM, #GS_WHEEL, #GS_PAGE, #GS_DRAG
      If Nav
        If Not Gallery_WalkTo(*S) : ProcedureReturn #False : EndIf
        Select *S\Kind
          Case #GS_PRESS, #GS_ITEM : Gallery_NavDo(#NEON_NAV_ACTIVATE)
          Case #GS_WHEEL
            For i = 1 To Abs(*S\Arg)
              If *S\Arg > 0 : Gallery_NavDo(#NEON_NAV_UP) : Else : Gallery_NavDo(#NEON_NAV_DOWN) : EndIf
            Next
          Case #GS_PAGE
            If *S\Arg > 0 : Gallery_NavDo(#NEON_NAV_PAGEDOWN) : Else : Gallery_NavDo(#NEON_NAV_PAGEUP) : EndIf
          Case #GS_DRAG
            For i = 1 To 40
              If *S\Arg > 0 : Gallery_NavDo(#NEON_NAV_PAGEDOWN) : Else : Gallery_NavDo(#NEON_NAV_PAGEUP) : EndIf
            Next
        EndSelect
      Else
        id = Gallery_TargetID(*S)
        z = Gallery_Zone(id)
        If id = 0 Or z < 0 : Gallery_StepError = "the target of '" + *S\Name + "' is not on the screen" : ProcedureReturn #False : EndIf
        cx = Neon_HotPrev(z)\x + Neon_HotPrev(z)\w / 2 : cy = Neon_HotPrev(z)\y + Neon_HotPrev(z)\h / 2
        Select *S\Kind
          Case #GS_PRESS, #GS_ITEM
            Gallery_MoveTo(cx, cy) : Gallery_Click()
          Case #GS_WHEEL
            Gallery_MoveTo(cx, cy)
            Gallery_Input(@inp, #False) : inp\Wheel = *S\Arg : Gallery_RunFrame(@inp)
            Gallery_Input(@inp, #False) : Gallery_RunFrame(@inp)
          Case #GS_PAGE
            ; a click on the track beside the thumb: a list row pages through its own bar
            If *S\Tag = 10
              z = Gallery_Zone(Neon_HotKey(7, *S\A + 900000, 0))
              If z < 0 : Gallery_StepError = "the list's bar has no thumb" : ProcedureReturn #False : EndIf
            EndIf
            If *S\Tag = 8
              cy = Neon_HotPrev(z)\y + Neon_HotPrev(z)\h / 2
              If *S\Arg > 0 : cx = Neon_HotPrev(z)\x + Neon_HotPrev(z)\w + 2 : Else : cx = Neon_HotPrev(z)\x - 2 : EndIf
            Else
              cx = Neon_HotPrev(z)\x + Neon_HotPrev(z)\w / 2
              If *S\Arg > 0 : cy = Neon_HotPrev(z)\y + Neon_HotPrev(z)\h + 2 : Else : cy = Neon_HotPrev(z)\y - 2 : EndIf
            EndIf
            Gallery_MoveTo(cx, cy) : Gallery_Click()
          Case #GS_DRAG
            Gallery_MoveTo(cx, cy)
            Gallery_Input(@inp, #False) : inp\Down = #True : Gallery_RunFrame(@inp)
            If *S\Tag = 8 : Gallery_PtrX = cx + *S\Arg * 2000 : Else : Gallery_PtrY = cy + *S\Arg * 2000 : EndIf
            Gallery_Input(@inp, #False) : inp\Down = #True : Gallery_RunFrame(@inp)
            Gallery_Input(@inp, #False) : Gallery_RunFrame(@inp)
            Gallery_MoveTo(cx, cy)
        EndSelect
      EndIf

    Case #GS_KEY
      If Nav
        Select *S\Arg
          Case #PB_Shortcut_Left : Gallery_NavDo(#NEON_NAV_LEFT)
          Case #PB_Shortcut_Right : Gallery_NavDo(#NEON_NAV_RIGHT)
          Case #PB_Shortcut_Escape : Gallery_NavDo(#NEON_NAV_BACK)
          Default : Gallery_StepError = "a pad has no key " + Str(*S\Arg) : ProcedureReturn #False
        EndSelect
      Else
        Gallery_KeyDo(*S\Arg)
      EndIf

    Case #GS_TYPE
      If Nav : Gallery_NavDo(#NEON_NAV_NONE, *S\Arg) : Else : Gallery_KeyDo(0, *S\Arg) : EndIf

    Case #GS_SUBMIT
      If Nav : Gallery_NavDo(#NEON_NAV_ACTIVATE) : Else : Gallery_KeyDo(#PB_Shortcut_Return) : EndIf

    Case #GS_SELECTALL
      Gallery_KeyDo(#PB_Shortcut_A, 1, #True)

    Case #GS_UI_PRESS, #GS_UI_VALUE, #GS_UI_DIP
      *g = Gallery_UIGadget(*S\A)
      If *g = 0 : Gallery_StepError = "no GlUI gadget " + Str(*S\A) : ProcedureReturn #False : EndIf
      If Nav
        If Not Gallery_UIFocus(*S\A) : ProcedureReturn #False : EndIf
        Select *S\Kind
          Case #GS_UI_PRESS : Gallery_NavDo(#NEON_NAV_ACTIVATE)
          Case #GS_UI_VALUE
            If *S\Arg > 0 : Gallery_NavDo(#NEON_NAV_RIGHT) : Else : Gallery_NavDo(#NEON_NAV_LEFT) : EndIf
          Case #GS_UI_DIP
            *g = Gallery_UIGadget(*S\A)
            For k = 0 To Int(*g\Value)
              If *g\SubFocus = *S\Arg : Break : EndIf
              Gallery_NavDo(#NEON_NAV_RIGHT)
              *g = Gallery_UIGadget(*S\A)
            Next
            Gallery_NavDo(#NEON_NAV_ACTIVATE)
        EndSelect
      Else
        cx = *g\X + *g\W / 2 : cy = *g\Y + *g\H / 2
        Select *S\Kind
          Case #GS_UI_VALUE
            If *g\Type = #NEON_SLIDER
              cx = *g\X + *g\W * (*g\Value + 0.05 * *S\Arg)
            ElseIf *S\Arg > 0
              cx = *g\X + *g\W * 0.75
            Else
              cx = *g\X + *g\W * 0.25
            EndIf
          Case #GS_UI_DIP
            cx = *g\X + *g\W / 2.0 - Int(*g\Value) * 40.0 / 2.0 + *S\Arg * 40.0 + 10.0
        EndSelect
        Gallery_MoveTo(cx, cy) : Gallery_Click()
      EndIf
  EndSelect
  ProcedureReturn #True
EndProcedure

; The state the two ways of driving must agree on, one "name value" a line.
; LogFrom: how many log entries were reported before (only the newer ones are listed).
Procedure.s Gallery_StateText(LogFrom.i = 0)
  Protected s.s, i.i
  s + "screen " + Str(G\Screen) + #LF$
  ForEach UI_Gadgets()
    s + "ui " + Str(UI_Gadgets()\ID) + " value " + StrF(UI_Gadgets()\Value, 3) + " active " + Str(UI_Gadgets()\IsActive) +
        " sub " + Str(UI_Gadgets()\SubFocus) + #LF$
  Next
  s + "ui focus " + Str(UI_FocusIndex) + #LF$
  s + "clicks " + Str(G\Clicks1) + " " + Str(G\Clicks2) + " " + Str(G\Clicks3) + #LF$
  s + "text1 [" + G\Text1\s + "]" + #LF$
  s + "text2 [" + G\Text2\s + "] caret " + Str(G\Caret2) + #LF$
  s + "text3 caret " + Str(G\Caret3) + #LF$
  s + "keyboard " + Str(Neon_FocusID) + " all " + Str(Neon_TextAllID) + #LF$
  s + "submits " + Str(G\Submits) + " [" + G\LastSubmit + "]" + #LF$
  s + "bars " + Str(G\VTop) + " " + Str(G\HLeft) + " " + Str(G\InertTop) + #LF$
  s + "tabs A [" + G\TabsA + "] active " + Str(G\TabA) + " closed " + Str(G\ClosedA) + " pinned " + Str(G\PinnedA) + #LF$
  s + "tabs B " + Str(G\TabB) + " offset " + StrF(Neon_TabScrollOffset(#GAL_ID_TABSB), 2) + " C " + Str(G\TabC) + #LF$
  s + "list 501 top " + Str(G\ListTop1) + " sel " + Str(G\Sel1) + " list 503 sel " + Str(G\Sel3) + #LF$
  s + "menu open " + Str(Neon_MenuOpenRoot) + " sub [" + Neon_SubOpenKey + "] status " + Str(G\ShowStatus) + " mark " + Str(G\Marks) +
      " board " + Str(G\Board) + #LF$
  i = 0
  ForEach GalleryLog()
    If i >= LogFrom : s + "log " + GalleryLog()\Text + #LF$ : EndIf
    i + 1
  Next
  ProcedureReturn s
EndProcedure
