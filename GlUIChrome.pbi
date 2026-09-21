; ======================================================================
; GlUIChrome.pbi - the Neon widget kit's APPLICATION CHROME half
; ======================================================================
;
; GlUI.pbi has the pieces an arcade front-end needs: buttons, sliders,
; toggles, meters, carousels, DIP banks. This file adds the pieces an
; APPLICATION needs and that one lacks:
;
;   Neon_MenuBar*   a real menu bar with drop-downs, submenus, keyboard
;                   shortcut text, check marks, disabled items, and
;                   drop-downs that SCROLL when they are taller than the
;                   canvas (the caller that motivated this has a Board
;                   menu of five categories and ~50 boards)
;   Neon_TabStrip   a row of tabs, optionally with close boxes
;   Neon_ScrollBarV / Neon_ScrollBarH
;   Neon_TextInput  a single-line text field with a caret and selection-
;                   free editing (backspace/delete/arrows/home/end)
;   Neon_List*      a scrolling list/tree pane with indent levels,
;                   group rows, hover and selection
;   Neon_Scissor*   canvas-space clipping, which every scrolling thing
;                   above needs and the engine had no way to express
;
; RELATIONSHIP TO GlUI.pbi
; ------------------------
; GlUI.pbi is RETAINED mode: you Neon_Add* once and Neon_DrawUI walks the
; list. That is right for a menu screen whose contents never change, and
; wrong for an application whose menus, tabs and lists are rebuilt from
; live data every frame. This file is IMMEDIATE mode: you call the widget
; where you want it, it draws itself and returns what the user did.
;
; The two are deliberately not merged. They share the naming, the palette
; and MapPhysicalToVirtual's canvas; they do not share a widget list, and
; a program may use either or both.
;
; REQUIRES: GlTypes.pbi, GlUtilities.pbi, GlMath.pbi, GlUI.pbi (for the
; canvas globals and MapPhysicalToVirtual).
;
; NO POST-PROCESSING. This kit draws widgets. It applies no filter of any
; kind - no scanlines, no curvature, no grain - and it never will. The
; engine's DrawRetroCRT still exists for programs that want it; chrome is
; not one of them.
; ======================================================================

; ----------------------------------------------------------------------
; PALETTE
; ----------------------------------------------------------------------
; Dark, low-chroma, so the CONTENT is the brightest thing on screen. The
; ground is deliberately grey (33,34,37) rather than black: against true
; black, light text halates and every glyph wears a glow.
;
; Accents mean something and are never decoration:
;   accent (cyan)  = the thing you are on / the active selection
;   amber          = attention, changed, in progress
;   green          = success / live
;   red            = failure
; ----------------------------------------------------------------------
Global Neon_C_BgR.f = 0.129, Neon_C_BgG.f = 0.133, Neon_C_BgB.f = 0.145
Global Neon_C_PanelR.f = 0.145, Neon_C_PanelG.f = 0.149, Neon_C_PanelB.f = 0.161
Global Neon_C_HeadR.f = 0.169, Neon_C_HeadG.f = 0.173, Neon_C_HeadB.f = 0.184
Global Neon_C_LineR.f = 0.196, Neon_C_LineG.f = 0.200, Neon_C_LineB.f = 0.212
Global Neon_C_TextR.f = 0.863, Neon_C_TextG.f = 0.863, Neon_C_TextB.f = 0.863
Global Neon_C_DimR.f = 0.576, Neon_C_DimG.f = 0.596, Neon_C_DimB.f = 0.635
Global Neon_C_FaintR.f = 0.435, Neon_C_FaintG.f = 0.459, Neon_C_FaintB.f = 0.498
Global Neon_C_AccR.f = 0.353, Neon_C_AccG.f = 0.741, Neon_C_AccB.f = 0.816
Global Neon_C_AmbR.f = 0.882, Neon_C_AmbG.f = 0.647, Neon_C_AmbB.f = 0.259
Global Neon_C_GrnR.f = 0.361, Neon_C_GrnG.f = 0.749, Neon_C_GrnB.f = 0.596
Global Neon_C_RedR.f = 0.867, Neon_C_RedG.f = 0.494, Neon_C_RedB.f = 0.494
Global Neon_C_VioR.f = 0.663, Neon_C_VioG.f = 0.596, Neon_C_VioB.f = 0.878

; ----------------------------------------------------------------------
; FONTS - set by the host once, after CreateGLFont.
; ----------------------------------------------------------------------
Global *Neon_FontUI.GLFont      ; proportional, chrome
Global *Neon_FontSmall.GLFont   ; proportional, small
Global *Neon_FontMono.GLFont    ; monospaced, content
Global *Neon_FontBold.GLFont    ; proportional, headings

; ----------------------------------------------------------------------
; FONT SIZING - ASK, MEASURE, CORRECT
; ----------------------------------------------------------------------
; A fixed-canvas layout needs glyphs of a known number of CANVAS UNITS,
; and CreateGLFont takes POINTS. The conversion between them depends on
; the desktop scaling factor AND on whether the process is DPI-aware at
; the moment the font is loaded - which is not a thing to guess at, and
; guessing is what a layout that overflows at 150% looks like.
;
; So this does not compute the point size. It loads a font, measures the
; height the rasteriser actually produced with the SAME TextHeight("A")
; CreateGLFont measures with, and converges - at most six probes, each on
; an 8x8 scratch image, with no GL texture built until the answer is
; known. Returns the point size to hand to CreateGLFont.
; ----------------------------------------------------------------------
Procedure.i Neon_PointsForPixelHeight(FontName.s, WantPixels.i, Style.i = 0)
  Protected pt.i = Round(WantPixels * 0.75, #PB_Round_Nearest)
  Protected pass.i, h.i, fnt.i, img.i, np.i
  If pt < 5 : pt = 5 : EndIf
  For pass = 1 To 6
    h = 0
    fnt = LoadFont(#PB_Any, FontName, pt, Style)
    img = CreateImage(#PB_Any, 8, 8, 32)
    If fnt And img And StartDrawing(ImageOutput(img))
      DrawingFont(FontID(fnt))
      h = TextHeight("A")
      StopDrawing()
    EndIf
    If img : FreeImage(img) : EndIf
    If fnt : FreeFont(fnt) : EndIf
    If h <= 0 : Break : EndIf
    If Abs(WantPixels - h) <= 1 : Break : EndIf
    np = Round(pt * (WantPixels / h), #PB_Round_Nearest)
    If np < 5 : np = 5 : EndIf
    If np = pt : Break : EndIf
    pt = np
  Next
  ProcedureReturn pt
EndProcedure

; The whole job in one call: a font whose line height is WantPixels
; canvas units, whatever the desktop is doing.
Procedure.i Neon_CreateFontPx(FontName.s, WantPixels.i, Style.i = 0)
  ProcedureReturn CreateGLFont(FontName, Neon_PointsForPixelHeight(FontName, WantPixels, Style), Style)
EndProcedure

; ----------------------------------------------------------------------
; PER-FRAME INPUT SNAPSHOT
; ----------------------------------------------------------------------
; The engine draws; the host says what the mouse and keyboard did. Read
; ONCE a frame by Neon_ChromeBeginFrame so every widget in that frame
; agrees about the same instant - a widget that re-reads the mouse mid-
; frame can see a click that an earlier widget already consumed.
; ----------------------------------------------------------------------
Global Neon_MX.f, Neon_MY.f                  ; canvas coordinates
Global Neon_MouseDown.b, Neon_MousePrev.b
Global Neon_MouseClicked.b                   ; edge: went down this frame
Global Neon_MouseReleased.b                  ; edge: came up this frame
Global Neon_Wheel.i                          ; notches, consumed by whoever is under the pointer
Global Neon_KeyCode.i                        ; a #PB_Shortcut_* constant, or 0
Global Neon_KeyChar.i                        ; a printable character code, or 0
Global Neon_DeltaTime.f
Global Neon_AnimationActive.b
Global NewMap Neon_Animation.f()

; Focus for keyboard-taking widgets (currently Neon_TextInput). 0 = none.
Global Neon_FocusID.i = 0

; ----------------------------------------------------------------------
; UI SCALE - the DISPLAY's density, never the window's size
; ----------------------------------------------------------------------
; The kit's own metrics - menu row height, padding, arrow strips - were
; plain constants, which is correct for a host that draws onto a fixed
; virtual canvas and lets the letterbox do the scaling. A host that draws
; at the window's real pixel size (which is what an application must do -
; a bigger window has to mean MORE TEXT, not BIGGER TEXT) has to be able
; to say how dense the display is, or a 24-pixel menu row is half the
; height it should be on a 200% screen.
;
; So: every metric below is a LOGICAL size, and Neon_S() turns it into
; physical pixels. A host on the old letterbox model simply leaves this
; at 1.0 and nothing changes for it - which is what the emulator and the
; splash do.
Global Neon_UIScale.f = 1.0

Procedure.f Neon_S(v.f)
  ProcedureReturn v * Neon_UIScale
EndProcedure

; ----------------------------------------------------------------------
; HOT ZONES - "would moving the mouse HERE change any pixel?"
; ----------------------------------------------------------------------
; An application that redraws only when something changed has one hard
; question to answer: the mouse moved - does that matter? For most of a
; window it does not. A pointer sliding across a page of source text
; changes nothing at all, and redrawing on every motion event is exactly
; the "it's only a text editor, why is the fan on" failure.
;
; The honest answer cannot be a second copy of the layout kept in the
; host - that is the same two-models-one-truth mistake in a different
; costume, and it would go stale the first time a panel moved. So the
; WIDGETS DECLARE IT THEMSELVES, as they draw: anything whose appearance
; depends on the pointer being over it registers its rectangle here.
;
; The host then asks Neon_HoverIdAt() - using the rectangles from the
; frame just gone - whether the old pointer position and the new one land
; on different things. Same answer, no redraw. This is the only place
; that knows, and it is filled by the code that draws.
;
; LAST REGISTERED WINS, which is what "topmost" means in an immediate-
; mode kit: the menu is emitted after the panels, so its rows are found
; before theirs.
; ----------------------------------------------------------------------
#NEON_MAXHOT = 512

Structure NeonHotZone
  x.f : y.f : w.f : h.f
  id.i
EndStructure
Global Dim Neon_Hot.NeonHotZone(#NEON_MAXHOT)
Global Neon_HotCount.i = 0        ; being filled this frame
Global Dim Neon_HotPrev.NeonHotZone(#NEON_MAXHOT)
Global Neon_HotPrevCount.i = 0    ; complete, from the frame just gone

Procedure Neon_HotZone(x.f, y.f, w.f, h.f, ID.i)
  If Neon_HotCount >= #NEON_MAXHOT : ProcedureReturn : EndIf
  Neon_Hot(Neon_HotCount)\x = x
  Neon_Hot(Neon_HotCount)\y = y
  Neon_Hot(Neon_HotCount)\w = w
  Neon_Hot(Neon_HotCount)\h = h
  Neon_Hot(Neon_HotCount)\id = ID
  Neon_HotCount + 1
EndProcedure

; A stable identity for a widget that has no ID of its own: its kind and
; where it is. Stable across frames as long as the widget stays put,
; which is the only case the question is being asked about.
Procedure.i Neon_HotKey(Tag.i, a.f, b.f)
  ProcedureReturn (Tag << 42) | ((Int(a) & $1FFFFF) << 21) | (Int(b) & $1FFFFF)
EndProcedure

; 0 = nothing hover-sensitive is there.
Procedure.i Neon_HoverIdAt(mx.f, my.f)
  Protected i.i
  For i = Neon_HotPrevCount - 1 To 0 Step -1
    If mx >= Neon_HotPrev(i)\x And mx < Neon_HotPrev(i)\x + Neon_HotPrev(i)\w And
       my >= Neon_HotPrev(i)\y And my < Neon_HotPrev(i)\y + Neon_HotPrev(i)\h
      ProcedureReturn Neon_HotPrev(i)\id
    EndIf
  Next
  ProcedureReturn 0
EndProcedure

; Set while a drop-down is open, with that drop-down's rectangle, so the
; host can ask "is the mouse mine this frame?" BEFORE it hit-tests its own
; panels. See Neon_MenuBlocksMouse().
Global Neon_MenuBlockX.f, Neon_MenuBlockY.f, Neon_MenuBlockW.f, Neon_MenuBlockH.f
Global Neon_MenuBlockActive.b

Procedure Neon_ChromeBeginFrame(MousePhysX.i, MousePhysY.i, MouseIsDown.b, Wheel.i, KeyCode.i, KeyChar.i, Dt.f)
  MapPhysicalToVirtual(MousePhysX, MousePhysY, @Neon_MX, @Neon_MY)
  Neon_MouseDown     = MouseIsDown
  Neon_MouseClicked  = Bool(MouseIsDown And Not Neon_MousePrev)
  Neon_MouseReleased = Bool(Not MouseIsDown And Neon_MousePrev)
  Neon_MousePrev     = MouseIsDown
  Neon_Wheel         = Wheel
  Neon_KeyCode       = KeyCode
  Neon_KeyChar       = KeyChar
  Neon_DeltaTime     = Dt
  Neon_AnimationActive = #False
  Neon_HotCount      = 0
EndProcedure

; Frame-rate-independent exponential easing for immediate-mode widgets.
; State is keyed by the widget's stable ID, so callers keep no parallel
; retained widget tree. Initial is normally the resting value (0 for a
; hover); pass the target itself for an absolute position that must not
; fly in from the origin on its first frame.
Procedure.f Neon_Animate(Key.s, Target.f, Speed.f = 16.0, Initial.f = -999999.0)
  If Not FindMapElement(Neon_Animation(), Key)
    AddMapElement(Neon_Animation(), Key)
    If Initial <= -999998.0 : Neon_Animation() = Target : Else : Neon_Animation() = Initial : EndIf
  EndIf
  Protected current.f = Neon_Animation()
  Protected dt.f = Neon_DeltaTime
  If dt < 0.0 : dt = 0.0 : EndIf
  If dt > 0.05 : dt = 0.05 : EndIf
  Protected blend.f = 1.0 - Exp(-Speed * dt)
  current + (Target - current) * blend
  If Abs(Target - current) < 0.002
    current = Target
  Else
    Neon_AnimationActive = #True
  EndIf
  Neon_Animation() = current
  ProcedureReturn current
EndProcedure

; Anything the frame did not consume is dropped, not carried over. A
; keystroke that arrives while nothing wants it must not fire later when
; something does.
Procedure Neon_ChromeEndFrame()
  Neon_Wheel   = 0
  Neon_KeyCode = 0
  Neon_KeyChar = 0
  ; This frame's hot zones become the map the host consults while no
  ; frame is being drawn at all.
  Protected i.i
  Neon_HotPrevCount = Neon_HotCount
  For i = 0 To Neon_HotCount - 1
    Neon_HotPrev(i)\x  = Neon_Hot(i)\x
    Neon_HotPrev(i)\y  = Neon_Hot(i)\y
    Neon_HotPrev(i)\w  = Neon_Hot(i)\w
    Neon_HotPrev(i)\h  = Neon_Hot(i)\h
    Neon_HotPrev(i)\id = Neon_Hot(i)\id
  Next
EndProcedure

; ----------------------------------------------------------------------
; PRIMITIVES
; ----------------------------------------------------------------------
; Everything is drawn Scaled (against Util_BaseWidth/Height) and with the
; camera ignored: chrome lives in canvas space and does not pan or zoom.
; ----------------------------------------------------------------------
Procedure Neon_Box(x.f, y.f, w.f, h.f, r.f, g.f, b.f, a.f = 1.0)
  DrawGLBox(x, y, w, h, r, g, b, a, #True, #True)
EndProcedure

Procedure Neon_Text(*f.GLFont, x.f, y.f, t.s, r.f, g.f, b.f, a.f = 1.0)
  If *f : DrawGLText(*f, x, y, t, r, g, b, a, #True, #True) : EndIf
EndProcedure

Procedure Neon_TextRight(*f.GLFont, xRight.f, y.f, t.s, r.f, g.f, b.f, a.f = 1.0)
  If *f : DrawGLText(*f, xRight - GetGLTextWidth(*f, t), y, t, r, g, b, a, #True, #True) : EndIf
EndProcedure

Procedure Neon_TextCentre(*f.GLFont, x.f, w.f, y.f, t.s, r.f, g.f, b.f, a.f = 1.0)
  If *f : DrawGLText(*f, x + (w - GetGLTextWidth(*f, t)) / 2.0, y, t, r, g, b, a, #True, #True) : EndIf
EndProcedure

Procedure.b Neon_Hit(x.f, y.f, w.f, h.f)
  ProcedureReturn Bool(Neon_MX >= x And Neon_MX < x + w And Neon_MY >= y And Neon_MY < y + h)
EndProcedure

; A thin outward glow so a surface reads as lifted rather than pasted on.
Procedure Neon_Glow(x.f, y.f, w.f, h.f, r.f, g.f, b.f, strength.f = 0.10)
  Protected i.i
  For i = 1 To 4
    Neon_Box(x - i, y - i, w + i * 2, h + i * 2, r, g, b, strength / (i * 1.5))
  Next
EndProcedure

Procedure Neon_Frame(x.f, y.f, w.f, h.f, r.f, g.f, b.f, a.f = 1.0)
  Neon_Box(x, y, w, 1, r, g, b, a)
  Neon_Box(x, y + h - 1, w, 1, r, g, b, a)
  Neon_Box(x, y, 1, h, r, g, b, a)
  Neon_Box(x + w - 1, y, 1, h, r, g, b, a)
EndProcedure

; A titled panel: accent tab, header strip, body, hairline border. One
; procedure so every panel in a window is identical by construction.
Procedure Neon_Panel(x.f, y.f, w.f, h.f, title.s, ar.f, ag.f, ab.f, HeaderH.f = 26.0)
  Neon_Box(x, y, w, h, Neon_C_PanelR, Neon_C_PanelG, Neon_C_PanelB)
  If title <> ""
    Neon_Box(x, y, w, HeaderH, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB)
    Neon_Box(x, y, 3, HeaderH, ar, ag, ab)
    Neon_Box(x, y + HeaderH, w, 1, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_Text(*Neon_FontUI, x + 12, y + 5, UCase(title), ar, ag, ab)
  EndIf
  Neon_Frame(x, y, w, h, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
EndProcedure

Procedure.b Neon_Button(x.f, y.f, w.f, h.f, label.s, lit.b = #False, enabled.b = #True)
  Protected over.b = Bool(enabled And Neon_Hit(x, y, w, h))
  Protected hotKey.i = Neon_HotKey(1, x, y)
  If enabled : Neon_HotZone(x, y, w, h, hotKey) : EndIf
  Protected hover.f = Neon_Animate("button:" + Str(hotKey), Bool(over), 18.0, 0.0)
  Protected br.f = Neon_C_LineR, bg.f = Neon_C_LineG, bb.f = Neon_C_LineB
  Protected tr.f = Neon_C_TextR, tg.f = Neon_C_TextG, tb.f = Neon_C_TextB
  If lit
    br = 0.157 : bg = 0.365 : bb = 0.408
    tr = 0.588 : tg = 0.816 : tb = 0.867
  EndIf
  If Not enabled
    tr = Neon_C_FaintR : tg = Neon_C_FaintG : tb = Neon_C_FaintB
  EndIf
  If hover > 0.0
    br + 0.06 * hover : bg + 0.07 * hover : bb + 0.08 * hover
    Neon_Glow(x, y, w, h, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB, 0.16 * hover)
  EndIf
  Neon_Box(x, y, w, h, br, bg, bb)
  Neon_Box(x, y, w, 1, 0.216, 0.259, 0.325)
  Neon_Box(x, y + h - 1, w, 1, Neon_C_BgR, Neon_C_BgG, Neon_C_BgB)
  Protected th.f = 19.0 : If *Neon_FontUI : th = *Neon_FontUI\LineHeight : EndIf
  Neon_TextCentre(*Neon_FontUI, x, w, y + (h - th) / 2.0, label, tr, tg, tb)
  ProcedureReturn Bool(over And Neon_MouseClicked)
EndProcedure

; ----------------------------------------------------------------------
; CLIPPING - canvas rectangle to GL scissor box
; ----------------------------------------------------------------------
; Everything that scrolls needs this and the engine had no way to say it.
;
; TWO COORDINATE FLIPS IN ONE CALL, which is why it is written once:
; the canvas counts Y DOWNWARD from the top-left, glScissor counts Y
; UPWARD from the bottom-left of the DRAWABLE, and on a DPI-scaled
; Windows desktop the drawable is bigger than the logical window. Getting
; any one of the three wrong produces clipping that is plausible and
; wrong - content cut at the wrong edge, or fine until someone resizes.
; ----------------------------------------------------------------------
Procedure.f Neon_PhysWinWidth()
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    ProcedureReturn Util_WinWidth * Linux_DPIScale
  CompilerElse
    ProcedureReturn DesktopScaledX(Util_WinWidth)
  CompilerEndIf
EndProcedure

Procedure.f Neon_PhysWinHeight()
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    ProcedureReturn Util_WinHeight * Linux_DPIScale
  CompilerElse
    ProcedureReturn DesktopScaledY(Util_WinHeight)
  CompilerEndIf
EndProcedure

Procedure Neon_ScissorSet(x.f, y.f, w.f, h.f)
  If Util_BaseWidth <= 0 Or Util_BaseHeight <= 0 : ProcedureReturn : EndIf
  Protected sx.f = GL_ViewportW / Util_BaseWidth
  Protected sy.f = GL_ViewportH / Util_BaseHeight
  Protected px.i = GL_ViewportX + x * sx
  Protected pw.i = w * sx
  Protected ph.i = h * sy
  ; top edge in physical pixels from the top, then flipped to a bottom origin
  Protected ptop.i = GL_ViewportY + y * sy
  Protected py.i = Neon_PhysWinHeight() - (ptop + ph)
  If pw < 0 : pw = 0 : EndIf
  If ph < 0 : ph = 0 : EndIf
  glEnable_(#GL_SCISSOR_TEST)
  glScissor_(px, py, pw, ph)
EndProcedure

Procedure Neon_ScissorClear()
  glDisable_(#GL_SCISSOR_TEST)
EndProcedure

; ----------------------------------------------------------------------
; SCROLLBARS
; ----------------------------------------------------------------------
; Value semantics: *Top is the index of the first visible row, Total is
; how many rows exist, Visible is how many fit. When everything fits the
; bar draws as an inert track rather than vanishing - a control that
; appears and disappears reflows the layout under the pointer.
; ----------------------------------------------------------------------
Global Neon_DragScrollID.i = 0
Global Neon_DragScrollGrab.f

Procedure.b Neon_ScrollBarV(ID.i, x.f, y.f, w.f, h.f, Total.i, Visible.i, *Top.Integer)
  Protected changed.b = #False
  Neon_Box(x, y, w, h, Neon_C_BgR, Neon_C_BgG, Neon_C_BgB)
  If Total <= Visible Or Total <= 0
    *Top\i = 0
    ; Several scrollbars are drawn every frame. An inert bar must only
    ; release a drag that belongs to itself; clearing the shared owner here
    ; used to cancel an editor-thumb drag when a later console bar fit all
    ; of its content.
    If Neon_DragScrollID = ID : Neon_DragScrollID = 0 : EndIf
    ProcedureReturn #False
  EndIf

  Protected maxTop.i = Total - Visible
  If *Top\i > maxTop : *Top\i = maxTop : changed = #True : EndIf
  If *Top\i < 0      : *Top\i = 0      : changed = #True : EndIf

  Protected thumbH.f = h * (Visible / Total)
  If thumbH < Neon_S(18.0) : thumbH = Neon_S(18.0) : EndIf
  Protected travel.f = h - thumbH
  Protected thumbY.f = y + travel * (*Top\i / maxTop)

  Protected over.b = Neon_Hit(x, y, w, h)
  Protected onThumb.b = Neon_Hit(x, thumbY, w, thumbH)
  ; only the THUMB changes colour, so only the thumb is hover-sensitive
  Neon_HotZone(x, thumbY, w, thumbH, Neon_HotKey(7, ID, 0))

  If Neon_MouseClicked And over
    If onThumb
      Neon_DragScrollID = ID
      Neon_DragScrollGrab = Neon_MY - thumbY
    Else
      ; Click the track: page towards the pointer, as every scrollbar does.
      If Neon_MY < thumbY : *Top\i - Visible : Else : *Top\i + Visible : EndIf
      changed = #True
    EndIf
  EndIf
  If Not Neon_MouseDown And Neon_DragScrollID = ID : Neon_DragScrollID = 0 : EndIf

  If Neon_DragScrollID = ID And Neon_MouseDown And travel > 0
    Protected want.f = (Neon_MY - Neon_DragScrollGrab - y) / travel
    Protected newTop.i = Round(want * maxTop, #PB_Round_Nearest)
    If newTop <> *Top\i : *Top\i = newTop : changed = #True : EndIf
  EndIf

  If *Top\i > maxTop : *Top\i = maxTop : EndIf
  If *Top\i < 0      : *Top\i = 0      : EndIf
  thumbY = y + travel * (*Top\i / maxTop)

  Protected tr.f = 0.31, tg.f = 0.33, tb.f = 0.36
  If onThumb Or Neon_DragScrollID = ID : tr = Neon_C_AccR * 0.8 : tg = Neon_C_AccG * 0.8 : tb = Neon_C_AccB * 0.8 : EndIf
  Neon_Box(x + 2, thumbY, w - 4, thumbH, tr, tg, tb)
  ProcedureReturn changed
EndProcedure

Procedure.b Neon_ScrollBarH(ID.i, x.f, y.f, w.f, h.f, Total.i, Visible.i, *Left.Integer)
  Protected changed.b = #False
  Neon_Box(x, y, w, h, Neon_C_BgR, Neon_C_BgG, Neon_C_BgB)
  If Total <= Visible Or Total <= 0
    *Left\i = 0
    If Neon_DragScrollID = ID : Neon_DragScrollID = 0 : EndIf
    ProcedureReturn #False
  EndIf
  Protected maxLeft.i = Total - Visible
  If *Left\i > maxLeft : *Left\i = maxLeft : changed = #True : EndIf
  If *Left\i < 0       : *Left\i = 0       : changed = #True : EndIf

  Protected thumbW.f = w * (Visible / Total)
  If thumbW < Neon_S(18.0) : thumbW = Neon_S(18.0) : EndIf
  Protected travel.f = w - thumbW
  Protected thumbX.f = x + travel * (*Left\i / maxLeft)
  Protected onThumb.b = Neon_Hit(thumbX, y, thumbW, h)
  Neon_HotZone(thumbX, y, thumbW, h, Neon_HotKey(8, ID, 0))

  If Neon_MouseClicked And Neon_Hit(x, y, w, h)
    If onThumb
      Neon_DragScrollID = ID
      Neon_DragScrollGrab = Neon_MX - thumbX
    Else
      If Neon_MX < thumbX : *Left\i - Visible : Else : *Left\i + Visible : EndIf
      changed = #True
    EndIf
  EndIf
  If Not Neon_MouseDown And Neon_DragScrollID = ID : Neon_DragScrollID = 0 : EndIf
  If Neon_DragScrollID = ID And Neon_MouseDown And travel > 0
    Protected newLeft.i = Round(((Neon_MX - Neon_DragScrollGrab - x) / travel) * maxLeft, #PB_Round_Nearest)
    If newLeft <> *Left\i : *Left\i = newLeft : changed = #True : EndIf
  EndIf
  If *Left\i > maxLeft : *Left\i = maxLeft : EndIf
  If *Left\i < 0       : *Left\i = 0       : EndIf
  thumbX = x + travel * (*Left\i / maxLeft)

  Protected tr.f = 0.31, tg.f = 0.33, tb.f = 0.36
  If onThumb Or Neon_DragScrollID = ID : tr = Neon_C_AccR * 0.8 : tg = Neon_C_AccG * 0.8 : tb = Neon_C_AccB * 0.8 : EndIf
  Neon_Box(thumbX, y + 2, thumbW, h - 4, tr, tg, tb)
  ProcedureReturn changed
EndProcedure

; ----------------------------------------------------------------------
; MENU BAR
; ----------------------------------------------------------------------
; Usage, once per frame:
;
;   Neon_MenuBarBegin(0, 0, 1600, 30)
;     If Neon_MenuBegin("File")
;       If Neon_MenuItem("Open...", "Ctrl+O") : DoOpen() : EndIf
;       Neon_MenuSeparator()
;       If Neon_MenuItem("Exit", "") : DoExit() : EndIf
;     EndIf
;     Neon_MenuEnd()
;     If Neon_MenuBegin("Board")
;       If Neon_SubMenuBegin("Arduino")
;         If Neon_MenuItem("Uno", "") : Pick("Uno") : EndIf
;       EndIf
;       Neon_SubMenuEnd()
;     EndIf
;     Neon_MenuEnd()
;   Neon_MenuBarEnd()
;
; Neon_MenuEnd() must be called whether or not the Begin returned true -
; it is what advances to the next root menu.
;
; WIDTH AND HEIGHT ARE MEASURED, NOT DECLARED. An immediate-mode drop-down
; does not know how wide it is until after its items have been emitted, so
; each root remembers LAST frame's measurement and uses it for this one.
; The contents would have to change size for that to be visibly wrong, and
; it self-corrects on the next frame.
;
; DROP-DOWNS SCROLL. A menu taller than the canvas is otherwise a menu
; with items nobody can reach - which is exactly what a Board menu of ~50
; boards would be. Over-long lists get a wheel-scrollable body with a
; hairline indicator and arrow strips at top and bottom.
; ----------------------------------------------------------------------
#NEON_MENU_MAXROOTS = 32

Global Neon_MenuBarX.f, Neon_MenuBarY.f, Neon_MenuBarW.f, Neon_MenuBarH.f
Global Neon_MenuRootIdx.i = -1              ; root being emitted this frame
Global Neon_MenuOpenRoot.i = -1             ; which root is showing its drop-down
Global Neon_MenuCursorX.f
Global Neon_MenuAnyOpenLastFrame.b
Global Neon_MenuRootCountLastFrame.i         ; complete tab geometry available for preflight
Global Neon_MenuPreflightRoot.i = -1         ; root selected before any drop-down is drawn
Global Neon_MenuLayoutChanged.b              ; measured size changed; host owes one corrective frame

Global Dim Neon_MenuMeasW.f(#NEON_MENU_MAXROOTS)
Global Dim Neon_MenuMeasH.f(#NEON_MENU_MAXROOTS)
Global Dim Neon_MenuTabX.f(#NEON_MENU_MAXROOTS)
Global Dim Neon_MenuTabW.f(#NEON_MENU_MAXROOTS)

; Drop-down emission state
Global Neon_DropOpen.b                      ; the root currently being emitted is open
Global Neon_DropX.f, Neon_DropY.f, Neon_DropW.f
Global Neon_DropCursorY.f                   ; next row's y, BEFORE scrolling
Global Neon_DropMaxW.f                      ; widest row measured this frame
Global Neon_DropRows.f                      ; total emitted height this frame
Global Neon_DropScroll.i                    ; scroll offset in pixels, per open root
Global Neon_DropViewY.f, Neon_DropViewH.f   ; the clipped body rectangle
Global Neon_DropScrolls.b                   ; this drop-down is taller than its view

; Submenu emission state (ONE level - which is what a menu bar should ever
; need, and a second level would be a maze rather than a menu)
Global Neon_SubActive.b                     ; currently inside Neon_SubMenuBegin/End
Global Neon_SubOpen.b                       ; ...and that submenu is the open one
Global Neon_SubOpenKey.s                    ; "<root>:<label>" of the open submenu, "" = none
Global Neon_SubKey.s
Global Neon_SubX.f, Neon_SubY.f, Neon_SubW.f
Global Neon_SubCursorY.f, Neon_SubMaxW.f, Neon_SubRows.f
Global Neon_SubScroll.i
Global Neon_SubViewY.f, Neon_SubViewH.f
Global Neon_SubScrolls.b
Global Neon_SaveDropCursorY.f
Global NewMap Neon_SubMeasW.f()
Global NewMap Neon_SubMeasH.f()
Global NewMap Neon_SubScrollMap.i()

#NEON_MENU_ROWH   = 24.0
#NEON_MENU_SEPH   = 9.0
#NEON_MENU_PADX   = 14.0
#NEON_MENU_GAPX   = 46.0    ; space reserved between a label and its shortcut
#NEON_MENU_ARROWH = 16.0

; An open menu owns the mouse for the whole host window until it closes.
; Ask this BEFORE hit-testing panels: the menu is emitted LAST so it draws
; on top, but the workspace beneath it must never hover, scroll or activate.
; A click outside belongs to the menu too -- it dismisses the menu and must
; not also activate whatever happened to be underneath that click.
Procedure.b Neon_MenuBlocksMouse()
  If Neon_MenuOpenRoot >= 0 : ProcedureReturn #True : EndIf
  If Neon_Hit(Neon_MenuBarX, Neon_MenuBarY, Neon_MenuBarW, Neon_MenuBarH) : ProcedureReturn #True : EndIf
  If Neon_MenuBlockActive And Neon_Hit(Neon_MenuBlockX, Neon_MenuBlockY, Neon_MenuBlockW, Neon_MenuBlockH)
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure.b Neon_MenuIsOpen()
  ProcedureReturn Bool(Neon_MenuOpenRoot >= 0)
EndProcedure

Procedure Neon_MenuCloseAll()
  Neon_MenuOpenRoot = -1
  Neon_SubOpenKey = ""
EndProcedure

; Root ownership must change BEFORE root emission begins. Without this,
; moving from an earlier open root to a later root draws the old drop-down,
; then discovers and draws the new one later in the same frame. In an
; event-driven host that composite frame can remain on screen indefinitely.
Procedure Neon_MenuSelectRoot(idx.i)
  If idx < 0 Or idx >= #NEON_MENU_MAXROOTS : ProcedureReturn : EndIf
  Neon_MenuOpenRoot = idx
  Neon_SubOpenKey = ""
  Neon_DropScroll = 0
EndProcedure

Procedure Neon_MenuBarBegin(x.f, y.f, w.f, h.f)
  Neon_MenuBarX = x : Neon_MenuBarY = y : Neon_MenuBarW = w : Neon_MenuBarH = h
  Neon_MenuRootIdx = -1
  Neon_MenuCursorX = x + Neon_S(8)
  Neon_MenuBlockActive = #False
  Neon_MenuPreflightRoot = -1
  Neon_MenuLayoutChanged = #False

  ; Use the complete tab rectangles from the frame just gone to resolve a
  ; hover/click transfer atomically. Neon_MenuBegin still hit-tests the
  ; current frame as a fallback, but the normal adjacent-menu path no longer
  ; discovers its new owner after an earlier root has already painted.
  If Neon_MenuOpenRoot >= 0 And Neon_MenuRootCountLastFrame > 0 And
     Neon_MY >= y And Neon_MY < y + h
    Protected preflight.i
    For preflight = 0 To Neon_MenuRootCountLastFrame - 1
      If Neon_Hit(Neon_MenuTabX(preflight), y, Neon_MenuTabW(preflight), h)
        If Neon_MenuOpenRoot <> preflight
          Neon_MenuSelectRoot(preflight)
          Neon_MenuPreflightRoot = preflight
        EndIf
        Break
      EndIf
    Next
  EndIf

  Neon_Box(x, y, w, h, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB)
  Neon_Box(x, y + h - 1, w, 1, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
  ; Escape closes the menu, wherever the pointer is.
  If Neon_KeyCode = #PB_Shortcut_Escape And Neon_MenuOpenRoot >= 0
    Neon_MenuCloseAll()
    Neon_KeyCode = 0
  EndIf
EndProcedure

; Returns #True when this root's drop-down is open and its items should be
; emitted. ALWAYS pair with Neon_MenuEnd().
Procedure.b Neon_MenuBegin(Title.s)
  Neon_MenuRootIdx + 1
  Protected idx.i = Neon_MenuRootIdx
  If idx >= #NEON_MENU_MAXROOTS
    Neon_DropOpen = #False
    ProcedureReturn #False
  EndIf

  Protected tw.f = 40.0
  If *Neon_FontUI : tw = GetGLTextWidth(*Neon_FontUI, Title) : EndIf
  Protected tabW.f = tw + Neon_S(24.0)
  Protected tabX.f = Neon_MenuCursorX
  Neon_MenuTabX(idx) = tabX
  Neon_MenuTabW(idx) = tabW
  Neon_MenuCursorX + tabW

  Protected over.b = Neon_Hit(tabX, Neon_MenuBarY, tabW, Neon_MenuBarH)
  Protected isOpen.b = Bool(Neon_MenuOpenRoot = idx)
  Neon_HotZone(tabX, Neon_MenuBarY, tabW, Neon_MenuBarH, Neon_HotKey(2, idx, 0))

  If over And Neon_MouseClicked
    ; If preflight just transferred ownership to this root, this click is
    ; the transfer click, not a second click that should toggle it closed.
    If isOpen And Neon_MenuPreflightRoot <> idx
      Neon_MenuCloseAll()
    ElseIf Not isOpen
      Neon_MenuSelectRoot(idx)
    EndIf
    isOpen = Bool(Neon_MenuOpenRoot = idx)
  ElseIf over And Neon_MenuOpenRoot >= 0 And Neon_MenuOpenRoot <> idx
    ; A menu is already down: sliding along the bar switches to this one,
    ; which is what every menu bar since 1984 has done.
    Neon_MenuSelectRoot(idx)
    isOpen = #True
  EndIf

  Protected th.f = 19.0 : If *Neon_FontUI : th = *Neon_FontUI\LineHeight : EndIf
  If isOpen
    Neon_Box(tabX, Neon_MenuBarY, tabW, Neon_MenuBarH, Neon_C_AccR * 0.30, Neon_C_AccG * 0.30, Neon_C_AccB * 0.34)
    Neon_Box(tabX, Neon_MenuBarY + Neon_MenuBarH - 2, tabW, 2, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
    Neon_TextCentre(*Neon_FontUI, tabX, tabW, Neon_MenuBarY + (Neon_MenuBarH - th) / 2.0, Title, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  ElseIf over
    Neon_Box(tabX, Neon_MenuBarY, tabW, Neon_MenuBarH, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_TextCentre(*Neon_FontUI, tabX, tabW, Neon_MenuBarY + (Neon_MenuBarH - th) / 2.0, Title, Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
  Else
    Neon_TextCentre(*Neon_FontUI, tabX, tabW, Neon_MenuBarY + (Neon_MenuBarH - th) / 2.0, Title, Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
  EndIf

  Neon_DropOpen = isOpen
  If Not isOpen : ProcedureReturn #False : EndIf

  ; --- lay the drop-down out from LAST frame's measurements -----------
  Protected firstLayout.b = Bool(Neon_MenuMeasH(idx) <= 0.0)
  Neon_DropW = Neon_MenuMeasW(idx)
  ; An unopened immediate-mode menu has no measurement yet. Give its first
  ; emission enough room to show real content instead of a 160x24 sliver;
  ; MenuEnd records the exact size and schedules the immediate correction.
  If Neon_DropW <= 0.0 : Neon_DropW = Neon_S(420.0) : EndIf
  If Neon_DropW < Neon_S(160.0) : Neon_DropW = Neon_S(160.0) : EndIf
  If Neon_DropW > Util_BaseWidth - 6.0 : Neon_DropW = Util_BaseWidth - 6.0 : EndIf
  Neon_DropX = tabX
  If Neon_DropX + Neon_DropW > Util_BaseWidth - 4 : Neon_DropX = Util_BaseWidth - 4 - Neon_DropW : EndIf
  If Neon_DropX < 2 : Neon_DropX = 2 : EndIf
  Neon_DropY = Neon_MenuBarY + Neon_MenuBarH

  Protected wantH.f = Neon_MenuMeasH(idx)
  Protected availH.f = Util_BaseHeight - Neon_DropY - 8.0
  If firstLayout
    wantH = availH - 8.0
  ElseIf wantH < Neon_S(24.0)
    wantH = Neon_S(24.0)
  EndIf
  If wantH < Neon_S(24.0) : wantH = Neon_S(24.0) : EndIf
  Neon_DropScrolls = Bool(wantH > availH)
  Neon_DropViewY = Neon_DropY + 4.0
  If Neon_DropScrolls
    Neon_DropViewH = availH - 8.0 - (Neon_S(16.0) * 2)
    Neon_DropViewY = Neon_DropY + 4.0 + Neon_S(16.0)
  Else
    Neon_DropViewH = wantH
  EndIf

  Protected panelH.f = Neon_DropViewH + 8.0
  If Neon_DropScrolls : panelH + (Neon_S(16.0) * 2) : EndIf

  Neon_Glow(Neon_DropX, Neon_DropY, Neon_DropW, panelH, 0.0, 0.0, 0.0, 0.45)
  Neon_Box(Neon_DropX, Neon_DropY, Neon_DropW, panelH, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB)
  Neon_Frame(Neon_DropX, Neon_DropY, Neon_DropW, panelH, Neon_C_AccR * 0.55, Neon_C_AccG * 0.55, Neon_C_AccB * 0.55)

  Neon_MenuBlockActive = #True
  Neon_MenuBlockX = Neon_DropX : Neon_MenuBlockY = Neon_DropY
  Neon_MenuBlockW = Neon_DropW : Neon_MenuBlockH = panelH

  ; wheel over the drop-down scrolls it
  If Neon_DropScrolls And Neon_Wheel <> 0 And Neon_Hit(Neon_DropX, Neon_DropY, Neon_DropW, panelH)
    Neon_DropScroll - Neon_Wheel * Int(Neon_S(24.0) * 2)
    Neon_Wheel = 0
  EndIf
  If Not Neon_DropScrolls : Neon_DropScroll = 0 : EndIf
  Protected maxScroll.i = wantH - Neon_DropViewH
  If maxScroll < 0 : maxScroll = 0 : EndIf
  If Neon_DropScroll > maxScroll : Neon_DropScroll = maxScroll : EndIf
  If Neon_DropScroll < 0 : Neon_DropScroll = 0 : EndIf

  If Neon_DropScrolls
    ; Arrow strips: hovering one scrolls, so a machine without a wheel is
    ; not locked out of the far end of a long menu.
    Protected upY.f = Neon_DropY + 4.0
    Protected dnY.f = Neon_DropY + panelH - 4.0 - Neon_S(16.0)
    Neon_Box(Neon_DropX + 1, upY, Neon_DropW - 2, Neon_S(16.0), Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_Box(Neon_DropX + 1, dnY, Neon_DropW - 2, Neon_S(16.0), Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_TextCentre(*Neon_FontSmall, Neon_DropX, Neon_DropW, upY, "^", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
    Neon_TextCentre(*Neon_FontSmall, Neon_DropX, Neon_DropW, dnY, "v", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
    If Neon_Hit(Neon_DropX, upY, Neon_DropW, Neon_S(16.0)) : Neon_DropScroll - 6 : EndIf
    If Neon_Hit(Neon_DropX, dnY, Neon_DropW, Neon_S(16.0)) : Neon_DropScroll + 6 : EndIf
    If Neon_DropScroll > maxScroll : Neon_DropScroll = maxScroll : EndIf
    If Neon_DropScroll < 0 : Neon_DropScroll = 0 : EndIf
  EndIf

  Neon_DropCursorY = 0.0
  Neon_DropMaxW = 0.0
  Neon_DropRows = 0.0
  Neon_SubActive = #False
  Neon_ScissorSet(Neon_DropX, Neon_DropViewY, Neon_DropW, Neon_DropViewH)
  ProcedureReturn #True
EndProcedure

; A row inside the currently open drop-down (or submenu). Returns #True on
; the frame it is clicked, and closes the menu, because a menu item that
; leaves its menu open is a toggle wearing a menu item's clothes.
Procedure.b Neon_MenuItem(Label.s, Shortcut.s = "", Enabled.b = #True, Checked.b = #False)
  If Not Neon_DropOpen : ProcedureReturn #False : EndIf

  Protected x.f, w.f, rowY.f, viewY.f, viewH.f
  If Neon_SubActive
    If Not Neon_SubOpen : ProcedureReturn #False : EndIf
    x = Neon_SubX : w = Neon_SubW
    rowY = Neon_SubViewY + Neon_SubCursorY - Neon_SubScroll
    viewY = Neon_SubViewY : viewH = Neon_SubViewH
    Neon_SubCursorY + Neon_S(24.0)
    Neon_SubRows + Neon_S(24.0)
  Else
    x = Neon_DropX : w = Neon_DropW
    rowY = Neon_DropViewY + Neon_DropCursorY - Neon_DropScroll
    viewY = Neon_DropViewY : viewH = Neon_DropViewH
    Neon_DropCursorY + Neon_S(24.0)
    Neon_DropRows + Neon_S(24.0)
  EndIf

  ; measure for next frame's width
  Protected need.f = Neon_S(14.0) * 2 + Neon_S(18.0)
  If *Neon_FontUI
    need + GetGLTextWidth(*Neon_FontUI, Label)
    If Shortcut <> "" : need + Neon_S(46.0) + GetGLTextWidth(*Neon_FontSmall, Shortcut) : EndIf
  EndIf
  If Neon_SubActive
    If need > Neon_SubMaxW : Neon_SubMaxW = need : EndIf
  Else
    If need > Neon_DropMaxW : Neon_DropMaxW = need : EndIf
  EndIf

  ; entirely outside the clipped view: measured, not drawn
  If rowY + Neon_S(24.0) < viewY Or rowY > viewY + viewH
    ProcedureReturn #False
  EndIf

  Protected over.b = Bool(Enabled And Neon_Hit(x, rowY, w, Neon_S(24.0)) And Neon_MY >= viewY And Neon_MY < viewY + viewH)
  If Enabled : Neon_HotZone(x, rowY, w, Neon_S(24.0), Neon_HotKey(3, x, rowY)) : EndIf
  If over
    Neon_Box(x + 1, rowY, w - 2, Neon_S(24.0), Neon_C_AccR * 0.28, Neon_C_AccG * 0.28, Neon_C_AccB * 0.32)
  EndIf

  Protected tr.f = Neon_C_TextR, tg.f = Neon_C_TextG, tb.f = Neon_C_TextB
  If Not Enabled : tr = Neon_C_FaintR : tg = Neon_C_FaintG : tb = Neon_C_FaintB : EndIf
  Protected th.f = 17.0 : If *Neon_FontUI : th = *Neon_FontUI\LineHeight : EndIf
  Protected ty.f = rowY + (Neon_S(24.0) - th) / 2.0

  If Checked
    ; A menu state marker is geometry, not a font character. Chr(149) is not
    ; present in every UI face; the missing-glyph fallback is the empty green
    ; block reported by testers.
    ;
    ; SEVEN COLUMNS, NOT THREE RECTANGLES. The earlier three-rectangle form
    ; put a square corner where the tick's vertex belongs and gave the two
    ; arms almost the same length, so it read as a return arrow rather than
    ; as a check. Each column here overlaps its neighbour vertically, so the
    ; stroke stays continuous at every scale: the left arm falls to a single
    ; vertex and the right arm rises past it.
    Protected markU.f = Neon_S(1.5)
    If markU < 1.5 : markU = 1.5 : EndIf
    Protected markX.f = x + Neon_S(4.0)
    Protected markY.f = rowY + (Neon_S(24.0) - markU * 7.0) / 2.0
    Neon_Box(markX,             markY + markU * 2, markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    Neon_Box(markX + markU,     markY + markU * 3, markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    Neon_Box(markX + markU * 2, markY + markU * 4, markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    Neon_Box(markX + markU * 3, markY + markU * 3, markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    Neon_Box(markX + markU * 4, markY + markU * 2, markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    Neon_Box(markX + markU * 5, markY + markU,     markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
    Neon_Box(markX + markU * 6, markY,             markU, markU * 3, Neon_C_GrnR, Neon_C_GrnG, Neon_C_GrnB)
  EndIf
  Neon_Text(*Neon_FontUI, x + Neon_S(14.0) + 4, ty, Label, tr, tg, tb)
  If Shortcut <> ""
    Neon_TextRight(*Neon_FontSmall, x + w - Neon_S(14.0), ty + 1, Shortcut, Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB)
  EndIf

  If over And Neon_MouseClicked
    Neon_MenuCloseAll()
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure Neon_MenuSeparator()
  If Not Neon_DropOpen : ProcedureReturn : EndIf
  Protected x.f, w.f, rowY.f
  If Neon_SubActive
    If Not Neon_SubOpen : ProcedureReturn : EndIf
    x = Neon_SubX : w = Neon_SubW
    rowY = Neon_SubViewY + Neon_SubCursorY - Neon_SubScroll
    Neon_SubCursorY + Neon_S(9.0) : Neon_SubRows + Neon_S(9.0)
  Else
    x = Neon_DropX : w = Neon_DropW
    rowY = Neon_DropViewY + Neon_DropCursorY - Neon_DropScroll
    Neon_DropCursorY + Neon_S(9.0) : Neon_DropRows + Neon_S(9.0)
  EndIf
  Neon_Box(x + 10, rowY + Neon_S(9.0) / 2, w - 20, 1, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
EndProcedure

; A submenu row. Returns #True when the submenu is showing, in which case
; the caller emits its items and then calls Neon_SubMenuEnd().
Procedure.b Neon_SubMenuBegin(Label.s)
  If Not Neon_DropOpen : ProcedureReturn #False : EndIf
  If Neon_SubActive : ProcedureReturn #False : EndIf     ; one level only

  Protected rowY.f = Neon_DropViewY + Neon_DropCursorY - Neon_DropScroll
  Protected rowTop.f = Neon_DropCursorY
  Neon_DropCursorY + Neon_S(24.0)
  Neon_DropRows + Neon_S(24.0)

  Protected need.f = Neon_S(14.0) * 2 + Neon_S(40.0)
  If *Neon_FontUI : need + GetGLTextWidth(*Neon_FontUI, Label) : EndIf
  If need > Neon_DropMaxW : Neon_DropMaxW = need : EndIf

  Neon_SubKey = Str(Neon_MenuOpenRoot) + ":" + Label
  Protected isOpen.b = Bool(Neon_SubOpenKey = Neon_SubKey)

  Protected visible.b = Bool(rowY + Neon_S(24.0) >= Neon_DropViewY And rowY <= Neon_DropViewY + Neon_DropViewH)
  Protected over.b = Bool(visible And Neon_Hit(Neon_DropX, rowY, Neon_DropW, Neon_S(24.0)) And Neon_MY >= Neon_DropViewY And Neon_MY < Neon_DropViewY + Neon_DropViewH)
  If visible : Neon_HotZone(Neon_DropX, rowY, Neon_DropW, Neon_S(24.0), Neon_HotKey(4, Neon_DropX, rowY)) : EndIf
  If over And Neon_SubOpenKey <> Neon_SubKey
    ; hovering a submenu row opens it and closes any sibling
    Neon_SubOpenKey = Neon_SubKey
    Neon_SubScrollMap(Neon_SubKey) = 0
    isOpen = #True
  EndIf

  If visible
    If over Or isOpen
      Neon_Box(Neon_DropX + 1, rowY, Neon_DropW - 2, Neon_S(24.0), Neon_C_AccR * 0.28, Neon_C_AccG * 0.28, Neon_C_AccB * 0.32)
    EndIf
    Protected th.f = 17.0 : If *Neon_FontUI : th = *Neon_FontUI\LineHeight : EndIf
    Protected ty.f = rowY + (Neon_S(24.0) - th) / 2.0
    Neon_Text(*Neon_FontUI, Neon_DropX + Neon_S(14.0) + 4, ty, Label, Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
    Neon_TextRight(*Neon_FontUI, Neon_DropX + Neon_DropW - 8, ty, ">", Neon_C_DimR, Neon_C_DimG, Neon_C_DimB)
  EndIf

  Neon_SubActive = #True
  Neon_SubOpen = isOpen
  If Not isOpen : ProcedureReturn #False : EndIf

  ; --- lay the submenu out, to the right of the parent ----------------
  Neon_SubW = Neon_SubMeasW(Neon_SubKey)
  If Neon_SubW < Neon_S(180.0) : Neon_SubW = Neon_S(180.0) : EndIf
  Neon_SubX = Neon_DropX + Neon_DropW - 2
  If Neon_SubX + Neon_SubW > Util_BaseWidth - 4
    Neon_SubX = Neon_DropX - Neon_SubW + 2        ; flip to the left edge
    If Neon_SubX < 2 : Neon_SubX = 2 : EndIf
  EndIf

  Protected wantH.f = Neon_SubMeasH(Neon_SubKey)
  If wantH < Neon_S(24.0) : wantH = Neon_S(24.0) : EndIf
  Neon_SubY = Neon_DropViewY + rowTop - Neon_DropScroll - 4.0
  If Neon_SubY < Neon_MenuBarY + Neon_MenuBarH : Neon_SubY = Neon_MenuBarY + Neon_MenuBarH : EndIf

  Protected availH.f = Util_BaseHeight - Neon_SubY - 8.0
  Neon_SubScrolls = Bool(wantH > availH)
  If Neon_SubScrolls
    Neon_SubViewH = availH - 8.0 - (Neon_S(16.0) * 2)
    Neon_SubViewY = Neon_SubY + 4.0 + Neon_S(16.0)
  Else
    Neon_SubViewH = wantH
    Neon_SubViewY = Neon_SubY + 4.0
    ; keep a short submenu on screen when its parent row is near the bottom
    If Neon_SubY + wantH + 8.0 > Util_BaseHeight
      Neon_SubY = Util_BaseHeight - wantH - 10.0
      Neon_SubViewY = Neon_SubY + 4.0
    EndIf
  EndIf

  Protected panelH.f = Neon_SubViewH + 8.0
  If Neon_SubScrolls : panelH + (Neon_S(16.0) * 2) : EndIf

  ; The submenu is drawn OUTSIDE the parent's clip, or it would be cut off
  ; by the drop-down it hangs from.
  Neon_ScissorClear()
  Neon_Glow(Neon_SubX, Neon_SubY, Neon_SubW, panelH, 0.0, 0.0, 0.0, 0.45)
  Neon_Box(Neon_SubX, Neon_SubY, Neon_SubW, panelH, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB)
  Neon_Frame(Neon_SubX, Neon_SubY, Neon_SubW, panelH, Neon_C_AccR * 0.55, Neon_C_AccG * 0.55, Neon_C_AccB * 0.55)

  ; the submenu extends what the menu owns for hit-test purposes
  If Neon_SubX + Neon_SubW > Neon_MenuBlockX + Neon_MenuBlockW
    Neon_MenuBlockW = (Neon_SubX + Neon_SubW) - Neon_MenuBlockX
  EndIf
  If Neon_SubX < Neon_MenuBlockX
    Neon_MenuBlockW + (Neon_MenuBlockX - Neon_SubX)
    Neon_MenuBlockX = Neon_SubX
  EndIf
  If Neon_SubY + panelH > Neon_MenuBlockY + Neon_MenuBlockH
    Neon_MenuBlockH = (Neon_SubY + panelH) - Neon_MenuBlockY
  EndIf

  Neon_SubScroll = Neon_SubScrollMap(Neon_SubKey)
  If Neon_SubScrolls And Neon_Wheel <> 0 And Neon_Hit(Neon_SubX, Neon_SubY, Neon_SubW, panelH)
    Neon_SubScroll - Neon_Wheel * Int(Neon_S(24.0) * 2)
    Neon_Wheel = 0
  EndIf
  If Not Neon_SubScrolls : Neon_SubScroll = 0 : EndIf
  Protected maxScroll.i = wantH - Neon_SubViewH
  If maxScroll < 0 : maxScroll = 0 : EndIf

  If Neon_SubScrolls
    Protected upY.f = Neon_SubY + 4.0
    Protected dnY.f = Neon_SubY + panelH - 4.0 - Neon_S(16.0)
    Neon_Box(Neon_SubX + 1, upY, Neon_SubW - 2, Neon_S(16.0), Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_Box(Neon_SubX + 1, dnY, Neon_SubW - 2, Neon_S(16.0), Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
    Neon_TextCentre(*Neon_FontSmall, Neon_SubX, Neon_SubW, upY, "^", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
    Neon_TextCentre(*Neon_FontSmall, Neon_SubX, Neon_SubW, dnY, "v", Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
    If Neon_Hit(Neon_SubX, upY, Neon_SubW, Neon_S(16.0)) : Neon_SubScroll - 6 : EndIf
    If Neon_Hit(Neon_SubX, dnY, Neon_SubW, Neon_S(16.0)) : Neon_SubScroll + 6 : EndIf
  EndIf
  If Neon_SubScroll > maxScroll : Neon_SubScroll = maxScroll : EndIf
  If Neon_SubScroll < 0 : Neon_SubScroll = 0 : EndIf
  Neon_SubScrollMap(Neon_SubKey) = Neon_SubScroll

  Neon_SubCursorY = 0.0
  Neon_SubMaxW = 0.0
  Neon_SubRows = 0.0
  Neon_ScissorSet(Neon_SubX, Neon_SubViewY, Neon_SubW, Neon_SubViewH)
  ProcedureReturn #True
EndProcedure

Procedure Neon_SubMenuEnd()
  If Not Neon_DropOpen : ProcedureReturn : EndIf
  If Neon_SubOpen
    Neon_SubMeasW(Neon_SubKey) = Neon_SubMaxW
    Neon_SubMeasH(Neon_SubKey) = Neon_SubRows
  EndIf
  Neon_SubActive = #False
  Neon_SubOpen = #False
  ; back to the parent drop-down's clip
  Neon_ScissorSet(Neon_DropX, Neon_DropViewY, Neon_DropW, Neon_DropViewH)
EndProcedure

Procedure Neon_MenuEnd()
  If Neon_DropOpen
    Neon_ScissorClear()
    If Abs(Neon_MenuMeasW(Neon_MenuRootIdx) - Neon_DropMaxW) > 0.5 Or
       Abs(Neon_MenuMeasH(Neon_MenuRootIdx) - Neon_DropRows) > 0.5
      Neon_MenuLayoutChanged = #True
    EndIf
    Neon_MenuMeasW(Neon_MenuRootIdx) = Neon_DropMaxW
    Neon_MenuMeasH(Neon_MenuRootIdx) = Neon_DropRows
    Neon_DropOpen = #False
  EndIf
EndProcedure

Procedure Neon_MenuBarEnd()
  ; A click that landed on neither the bar nor an open drop-down closes
  ; the menu. Checked here, at the end of emission, because only now is
  ; the drop-down's true rectangle known.
  If Neon_MenuOpenRoot >= 0 And Neon_MouseClicked
    Protected onBar.b = Neon_Hit(Neon_MenuBarX, Neon_MenuBarY, Neon_MenuBarW, Neon_MenuBarH)
    Protected onDrop.b = Bool(Neon_MenuBlockActive And Neon_Hit(Neon_MenuBlockX, Neon_MenuBlockY, Neon_MenuBlockW, Neon_MenuBlockH))
    If Not onBar And Not onDrop : Neon_MenuCloseAll() : EndIf
  EndIf
  Neon_MenuRootCountLastFrame = Neon_MenuRootIdx + 1
  ; The first open frame is also the measurement pass. Event-driven hosts
  ; need an explicit second frame so the exact measured rectangle replaces
  ; the generous first-pass rectangle immediately instead of waiting for the
  ; next unrelated mouse or keyboard event.
  If Neon_MenuLayoutChanged And Neon_MenuOpenRoot >= 0
    Neon_AnimationActive = #True
  EndIf
  Neon_MenuAnyOpenLastFrame = Bool(Neon_MenuOpenRoot >= 0)
  Neon_ScissorClear()
EndProcedure

; ----------------------------------------------------------------------
; TAB STRIP
; ----------------------------------------------------------------------
; Labels arrive bar-separated, the same convention Neon_AddCarousel uses,
; so a caller can build one from live data without an array contract.
;
; Returns the index that should now be active. *ClosedIndex, if supplied,
; receives the index whose close box was clicked (-1 when none) - the
; caller decides what closing means, because only it knows whether the
; document is dirty.
; ----------------------------------------------------------------------
Procedure.i Neon_TabStrip(ID.i, x.f, y.f, w.f, h.f, Labels.s, Active.i, WithClose.b = #False, *ClosedIndex.Integer = 0)
  If *ClosedIndex : *ClosedIndex\i = -1 : EndIf
  Neon_Box(x, y, w, h, Neon_C_BgR, Neon_C_BgG, Neon_C_BgB)
  Neon_Box(x, y + h - 1, w, 1, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)

  Protected count.i = 0
  If Labels <> "" : count = CountString(Labels, "|") + 1 : EndIf
  If count = 0 : ProcedureReturn Active : EndIf

  Protected result.i = Active
  Protected cx.f = x + Neon_S(4)
  Protected i.i, lbl.s, tw.f, tabW.f
  Protected activeX.f = cx, activeW.f = 0.0
  Protected th.f = 17.0 : If *Neon_FontUI : th = *Neon_FontUI\LineHeight : EndIf

  Neon_ScissorSet(x, y, w, h)
  For i = 0 To count - 1
    lbl = StringField(Labels, i + 1, "|")
    tw = 60.0
    If *Neon_FontUI : tw = GetGLTextWidth(*Neon_FontUI, lbl) : EndIf
    tabW = tw + Neon_S(26.0)
    If WithClose : tabW + Neon_S(18.0) : EndIf
    If tabW > Neon_S(300.0) : tabW = Neon_S(300.0) : EndIf

    Protected isActive.b = Bool(i = Active)
    Protected over.b = Neon_Hit(cx, y, tabW, h - 1)
    Protected tabKey.i = Neon_HotKey(5, ID, i)
    Neon_HotZone(cx, y, tabW, h - 1, tabKey)
    Protected hover.f = Neon_Animate("tab-hover:" + Str(tabKey), Bool(over), 18.0, 0.0)

    If isActive
      activeX = cx : activeW = tabW
      Neon_Box(cx, y, tabW, h - 1, Neon_C_PanelR, Neon_C_PanelG, Neon_C_PanelB)
      Neon_Box(cx, y, 1, h - 1, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
      Neon_Box(cx + tabW - 1, y, 1, h - 1, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
      Neon_Text(*Neon_FontUI, cx + Neon_S(12), y + (h - th) / 2.0, lbl, Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
    Else
      If hover > 0.0
        Neon_Box(cx, y + 2, tabW, h - 3, Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB, hover)
      EndIf
      Neon_Text(*Neon_FontUI, cx + Neon_S(12), y + (h - th) / 2.0, lbl, Neon_C_DimR, Neon_C_DimG, Neon_C_DimB)
    EndIf

    If WithClose
      Protected bx.f = cx + tabW - 17.0
      Protected by.f = y + (h - 14) / 2.0
      Protected onX.b = Neon_Hit(bx - 2, by - 2, 18, 18)
      Neon_HotZone(bx - 2, by - 2, 18, 18, Neon_HotKey(6, ID, i))
      If onX : Neon_Box(bx - 2, by - 2, 18, 18, Neon_C_RedR * 0.5, Neon_C_RedG * 0.35, Neon_C_RedB * 0.35) : EndIf
      Neon_Text(*Neon_FontSmall, bx, by - 1, "x", Neon_C_DimR, Neon_C_DimG, Neon_C_DimB)
      If onX And Neon_MouseClicked
        If *ClosedIndex : *ClosedIndex\i = i : EndIf
        cx + tabW
        Continue
      EndIf
    EndIf

    If over And Neon_MouseClicked : result = i : EndIf
    cx + tabW
  Next
  If activeW > 0.0
    Protected indicatorX.f = Neon_Animate("tab-x:" + Str(ID), activeX, 22.0, activeX)
    Protected indicatorW.f = Neon_Animate("tab-w:" + Str(ID), activeW, 22.0, activeW)
    Neon_Box(indicatorX, y, indicatorW, 2, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  EndIf
  Neon_ScissorClear()
  ProcedureReturn result
EndProcedure

; ----------------------------------------------------------------------
; SINGLE-LINE TEXT INPUT
; ----------------------------------------------------------------------
; Deliberately SINGLE-LINE, and deliberately without selection. It is a
; find box, a filter, a name field. It is NOT a text editor, and the
; distance between the two is the whole of wave 2.
; ----------------------------------------------------------------------
Global Neon_CaretPhase.f

Procedure.b Neon_TextInput(ID.i, x.f, y.f, w.f, h.f, *Text.String, Placeholder.s = "", *CaretPos.Integer = 0)
  Protected submitted.b = #False
  Protected focused.b = Bool(Neon_FocusID = ID)
  Protected over.b = Neon_Hit(x, y, w, h)
  Neon_HotZone(x, y, w, h, Neon_HotKey(9, ID, 0))

  If Neon_MouseClicked
    If over
      Neon_FocusID = ID
      focused = #True
    ElseIf focused
      Neon_FocusID = 0
      focused = #False
    EndIf
  EndIf

  Protected caret.i = Len(*Text\s)
  If *CaretPos
    caret = *CaretPos\i
    If caret > Len(*Text\s) : caret = Len(*Text\s) : EndIf
    If caret < 0 : caret = 0 : EndIf
  EndIf

  If focused
    Neon_CaretPhase + Neon_DeltaTime * 3.4
    Select Neon_KeyCode
      Case #PB_Shortcut_Back
        If caret > 0
          *Text\s = Left(*Text\s, caret - 1) + Mid(*Text\s, caret + 1)
          caret - 1
        EndIf
        Neon_KeyCode = 0
      Case #PB_Shortcut_Delete
        If caret < Len(*Text\s)
          *Text\s = Left(*Text\s, caret) + Mid(*Text\s, caret + 2)
        EndIf
        Neon_KeyCode = 0
      Case #PB_Shortcut_Left
        If caret > 0 : caret - 1 : EndIf
        Neon_KeyCode = 0
      Case #PB_Shortcut_Right
        If caret < Len(*Text\s) : caret + 1 : EndIf
        Neon_KeyCode = 0
      Case #PB_Shortcut_Home
        caret = 0 : Neon_KeyCode = 0
      Case #PB_Shortcut_End
        caret = Len(*Text\s) : Neon_KeyCode = 0
      Case #PB_Shortcut_Return
        submitted = #True : Neon_KeyCode = 0
      Case #PB_Shortcut_Escape
        Neon_FocusID = 0 : focused = #False : Neon_KeyCode = 0
    EndSelect
    ; Printable characters only. The control range is where the key
    ; handling above lives, and letting it through would insert a glyph
    ; for every Backspace.
    If Neon_KeyChar >= 32 And Neon_KeyChar <> 127
      *Text\s = Left(*Text\s, caret) + Chr(Neon_KeyChar) + Mid(*Text\s, caret + 1)
      caret + 1
      Neon_KeyChar = 0
      Neon_CaretPhase = 0.0
    EndIf
  EndIf

  If *CaretPos : *CaretPos\i = caret : EndIf

  ; --- draw ---------------------------------------------------------
  Neon_Box(x, y, w, h, 0.09, 0.093, 0.102)
  If focused
    Neon_Frame(x, y, w, h, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  ElseIf over
    Neon_Frame(x, y, w, h, Neon_C_DimR, Neon_C_DimG, Neon_C_DimB)
  Else
    Neon_Frame(x, y, w, h, Neon_C_LineR, Neon_C_LineG, Neon_C_LineB)
  EndIf

  Protected th.f = 17.0 : If *Neon_FontUI : th = *Neon_FontUI\LineHeight : EndIf
  Protected ty.f = y + (h - th) / 2.0
  Neon_ScissorSet(x + 1, y + 1, w - 2, h - 2)
  If *Text\s = "" And Not focused
    Neon_Text(*Neon_FontUI, x + Neon_S(8), ty, Placeholder, Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB)
  Else
    Neon_Text(*Neon_FontUI, x + Neon_S(8), ty, *Text\s, Neon_C_TextR, Neon_C_TextG, Neon_C_TextB)
  EndIf
  If focused And Sin(Neon_CaretPhase) > -0.2
    Protected cw.f = 0.0
    If *Neon_FontUI : cw = GetGLTextWidth(*Neon_FontUI, Left(*Text\s, caret)) : EndIf
    Neon_Box(x + Neon_S(8) + cw, ty, Neon_S(1.5), th, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  EndIf
  Neon_ScissorClear()
  ProcedureReturn submitted
EndProcedure

; ----------------------------------------------------------------------
; LIST / TREE PANE
; ----------------------------------------------------------------------
;   Neon_ListBegin(id, x, y, w, h, rowH, @top)
;     If Neon_ListItem("src", 0, #False, #True)  : ... : EndIf
;     If Neon_ListItem("main.avr328p", 1, sel)   : ... : EndIf
;   Neon_ListEnd()
;
; The list does not know how many rows it has until it has emitted them,
; so the scrollbar is drawn from LAST frame's count - the same measured-
; not-declared trick the menus use, and for the same reason.
; ----------------------------------------------------------------------
Global Neon_ListX.f, Neon_ListY.f, Neon_ListW.f, Neon_ListH.f
Global Neon_ListRowH.f
Global Neon_ListRow.i
Global Neon_ListID.i
Global Neon_ListTop.i
Global *Neon_ListTopPtr.Integer
Global Neon_ListInside.b
Global NewMap Neon_ListCount.i()

Procedure Neon_ListBegin(ID.i, x.f, y.f, w.f, h.f, RowH.f, *Top.Integer)
  Neon_ListID = ID
  Neon_ListX = x : Neon_ListY = y : Neon_ListW = w : Neon_ListH = h
  Neon_ListRowH = RowH
  Neon_ListRow = 0
  *Neon_ListTopPtr = *Top
  Neon_ListInside = #True

  Protected visible.i = Int(h / RowH)
  Protected total.i = Neon_ListCount(Str(ID))
  Protected maxTop.i = total - visible
  If maxTop < 0 : maxTop = 0 : EndIf

  If Neon_Wheel <> 0 And Neon_Hit(x, y, w, h) And Not Neon_MenuBlocksMouse()
    *Top\i - Neon_Wheel * 3
    Neon_Wheel = 0
  EndIf
  If *Top\i > maxTop : *Top\i = maxTop : EndIf
  If *Top\i < 0 : *Top\i = 0 : EndIf
  Neon_ListTop = *Top\i

  Neon_Box(x, y, w, h, 0.118, 0.122, 0.133)
  Neon_ScissorSet(x, y, w - Neon_S(10), h)
EndProcedure

; depth indents; Group draws the row as a heading rather than an entry.
Procedure.b Neon_ListItem(Label.s, Depth.i = 0, Selected.b = #False, Group.b = #False, Detail.s = "")
  If Not Neon_ListInside : ProcedureReturn #False : EndIf
  Protected idx.i = Neon_ListRow
  Neon_ListRow + 1

  Protected rowY.f = Neon_ListY + (idx - Neon_ListTop) * Neon_ListRowH
  If rowY + Neon_ListRowH < Neon_ListY Or rowY > Neon_ListY + Neon_ListH
    ProcedureReturn #False
  EndIf

  Protected over.b = Bool(Neon_Hit(Neon_ListX, rowY, Neon_ListW - Neon_S(10), Neon_ListRowH) And
                          Neon_MY >= Neon_ListY And Neon_MY < Neon_ListY + Neon_ListH And
                          Not Neon_MenuBlocksMouse())
  Protected rowKey.i = Neon_HotKey(10, Neon_ListID, idx)
  Protected hover.f = Neon_Animate("list:" + Str(rowKey), Bool(over), 20.0, 0.0)
  If rowY >= Neon_ListY And rowY + Neon_ListRowH <= Neon_ListY + Neon_ListH
    Neon_HotZone(Neon_ListX, rowY, Neon_ListW - Neon_S(10), Neon_ListRowH, rowKey)
  EndIf

  If Selected
    Neon_Box(Neon_ListX, rowY, Neon_ListW - Neon_S(10), Neon_ListRowH, Neon_C_AccR * 0.30, Neon_C_AccG * 0.30, Neon_C_AccB * 0.34)
    Neon_Box(Neon_ListX, rowY, Neon_S(2), Neon_ListRowH, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  ElseIf hover > 0.0
    Neon_Box(Neon_ListX, rowY, Neon_ListW - Neon_S(10), Neon_ListRowH,
             Neon_C_HeadR, Neon_C_HeadG, Neon_C_HeadB, hover)
  EndIf

  Protected *f.GLFont = *Neon_FontSmall
  Protected tr.f = Neon_C_TextR, tg.f = Neon_C_TextG, tb.f = Neon_C_TextB
  If Group
    tr = Neon_C_AmbR : tg = Neon_C_AmbG : tb = Neon_C_AmbB
  ElseIf Selected
    tr = Neon_C_AccR : tg = Neon_C_AccG : tb = Neon_C_AccB
  EndIf
  Protected th.f = 15.0 : If *f : th = *f\LineHeight : EndIf
  Neon_Text(*f, Neon_ListX + Neon_S(8) + Depth * Neon_S(14), rowY + (Neon_ListRowH - th) / 2.0, Label, tr, tg, tb)
  If Detail <> ""
    Neon_TextRight(*f, Neon_ListX + Neon_ListW - Neon_S(16), rowY + (Neon_ListRowH - th) / 2.0, Detail, Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB)
  EndIf

  ProcedureReturn Bool(over And Neon_MouseClicked)
EndProcedure

Procedure Neon_ListEnd()
  If Not Neon_ListInside : ProcedureReturn : EndIf
  Neon_ScissorClear()
  Neon_ListCount(Str(Neon_ListID)) = Neon_ListRow
  Protected visible.i = Int(Neon_ListH / Neon_ListRowH)
  Neon_ScrollBarV(Neon_ListID + 900000, Neon_ListX + Neon_ListW - Neon_S(10), Neon_ListY, Neon_S(10), Neon_ListH,
                  Neon_ListRow, visible, *Neon_ListTopPtr)
  Neon_ListInside = #False
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; EnableXP
; DPIAware
