; ============================================================================
; ui_check.pb - the UI kit (GlUI.pbi, GlUIChrome.pbi) driven by a script, with
; no hand on the mouse and nothing on the screen (#PB_Window_Invisible)
; ============================================================================
; What is compared is never a picture of text (two machines rasterise a face
; differently) but what the kit DID: return values, the event log (which
; widget, which event, in which order), rectangles and states, the text as
; fitted, scroll positions, the caret and the selection, and the list of
; primitives drawn - kind, rectangle, colour, text, face, the clip in force -
; from the engine's draw log (GL_DrawLogStart).
;
; THE FACES are "metric faces": fixed-advance fonts whose advance and line
; height are set to round numbers (ui 8 / 16, small 7 / 14, bold 9 / 18,
; mono 8 / 16, italic 8 / 16, arcade 12 / 24). The kit's layout depends only
; on those two numbers per face (the advance of each glyph and LineHeight),
; so every expected value below is exact, on any machine, and on a port
; that makes the same faces.
;
;   1. the new engine calls: the draw log, the selectable faces
;   2. Neon_FitText against a reference that walks code points
;   3. GlUI's layout rules (a gadget's rectangle from its label)
;   4. THE GALLERY'S SCRIPT (examples/WidgetGalleryScreens.pbi), played twice
;      from the same start: with the mouse and keys, then with a pad's
;      actions (Neon_ChromeBeginNav, GlUI's D-pad). After each step its state
;      and its event-log entries are checked against values worked out from
;      the kit's layout rules, and the two runs must agree where the step
;      says they do (#GS_BOTH: state and log; #GS_SAME_END: state).
;   5. GlUI's two input faults fixed (a list of labels only, an empty list)
;   6. THE EXPECTED LIST: every step of both runs - its state and the
;      primitives of its last frame - compared line for line with
;      tools/ui_check_expected.txt, or written there with --write. The format
;      is in README.md ("The UI check"); a port reads that file as its
;      reference.
;
; Usage: check.exe [--write] <expected file>
; Built and run by tools/ui_check.py.
; ============================================================================
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlMath.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUI.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUIChrome.pbi"
XIncludeFile #PB_Compiler_FilePath + "../examples/WidgetGalleryScreens.pbi"
OpenConsole()

Global Checks.i, Fails.i
Procedure Check(ok.i, message.s)
  Checks + 1
  If Not ok
    Fails + 1
    PrintN("FAIL " + message)
    If Fails > 40 : PrintN("too many failures") : End 1 : EndIf
  EndIf
EndProcedure
Procedure.b Near(a.f, b.f, eps.f = 0.001)
  ProcedureReturn Bool(Abs(a - b) <= eps)
EndProcedure

Define WritePath.s, WriteMode.b, a.i
For a = 0 To CountProgramParameters() - 1
  If ProgramParameter(a) = "--write" : WriteMode = #True : Else : WritePath = ProgramParameter(a) : EndIf
Next
If WritePath = "" : PrintN("usage: check [--write] <expected file>") : End 2 : EndIf

Define Gadget.i = OpenGLWindow("neon ui check", 64, 64, #PB_Window_Invisible)
Check(Bool(Gadget), "an OpenGL context in an invisible window")
If Not Gadget : End 1 : EndIf
Util_BaseWidth = #GAL_W : Util_BaseHeight = #GAL_H
Util_WinWidth = #GAL_W : Util_WinHeight = #GAL_H
GL_ViewportX = 0 : GL_ViewportY = 0 : GL_ViewportW = #GAL_W : GL_ViewportH = #GAL_H
UI_UseCRT = #False
Neon_UIScale = 1.0

; ----------------------------------------------------------------------------
; 1. THE NEW ENGINE CALLS
; ----------------------------------------------------------------------------
Check(Bool(Neon_FaceUI = "Segoe UI" And Neon_FaceMono = "Consolas"), "the faces default to Segoe UI and Consolas")
Check(Bool(GL_DrawLogOn = #False), "the draw log is off until started")

Procedure.i MetricFace(Name.s, Style.i, Advance.f, Line.f)
  Protected *f.GLFont = CreateGLFontFixed(Name, 12, Style, Advance)
  If *f : *f\LineHeight = Line : EndIf
  ProcedureReturn *f
EndProcedure
Global *FUI.GLFont = MetricFace("Consolas", 0, 8, 16)
Global *FSmall.GLFont = MetricFace("Consolas", 0, 7, 14)
Global *FBold.GLFont = MetricFace("Consolas", #PB_Font_Bold, 9, 18)
Global *FMono.GLFont = MetricFace("Consolas", 0, 8, 16)
Global *FItalic.GLFont = MetricFace("Consolas", #PB_Font_Italic, 8, 16)
Global *FArcade.GLFont = MetricFace("Consolas", #PB_Font_Bold, 12, 24)
Check(Bool(*FUI And *FSmall And *FBold And *FMono And *FItalic And *FArcade), "the metric faces")
Global Tail.s = Chr($2026)
If GLFontGlyphState(*FUI, $2026) <> #GLF_RESIDENT : Tail = "..." : EndIf

Procedure.s FaceName(*f)
  Select *f
    Case *FUI : ProcedureReturn "ui"
    Case *FSmall : ProcedureReturn "small"
    Case *FBold : ProcedureReturn "bold"
    Case *FMono : ProcedureReturn "mono"
    Case *FItalic : ProcedureReturn "italic"
    Case *FArcade : ProcedureReturn "arcade"
  EndSelect
  ProcedureReturn "other"
EndProcedure

; the draw log, alone
GL_DrawLogStart()
DrawGLBox(1, 2, 3, 4, 0.5, 0.25, 0.125, 1.0, #True, #True)
Neon_ScissorSet(10, 20, 30, 40)
DrawGLText(*FUI, 5, 6, "abc", 1, 1, 1, 0.5, #True, #True)
DrawGLText(*FUI, 5, 6, "", 1, 1, 1, 1, #True, #True)              ; nothing drawn: nothing logged
Neon_ScissorClear()
DrawGLPolygon(7, 8, 2, 3, 16, 1, 0, 0, 1, #True, #True, #True)
GL_DrawLogStop()
DrawGLBox(9, 9, 9, 9, 1, 1, 1, 1, #True, #True)                    ; after the stop: not logged
Check(Bool(ListSize(GL_DrawLog()) = 5), "draw log: five entries (" + Str(ListSize(GL_DrawLog())) + ")")
If ListSize(GL_DrawLog()) = 5
  FirstElement(GL_DrawLog())
  Check(Bool(GL_DrawLog()\Kind = #GL_LOG_BOX And GL_DrawLog()\X = 1 And GL_DrawLog()\Y = 2 And GL_DrawLog()\W = 3 And GL_DrawLog()\H = 4 And
             GL_DrawLog()\R = 0.5 And GL_DrawLog()\G = 0.25 And GL_DrawLog()\B = 0.125 And GL_DrawLog()\Flags = 3 And GL_DrawLog()\Clip = #False), "draw log: the box")
  NextElement(GL_DrawLog())
  Check(Bool(GL_DrawLog()\Kind = #GL_LOG_CLIP And GL_DrawLog()\X = 10 And GL_DrawLog()\Y = 20 And GL_DrawLog()\W = 30 And GL_DrawLog()\H = 40), "draw log: the clip")
  NextElement(GL_DrawLog())
  Check(Bool(GL_DrawLog()\Kind = #GL_LOG_TEXT And GL_DrawLog()\X = 5 And GL_DrawLog()\W = 24 And GL_DrawLog()\H = 16 And GL_DrawLog()\Text = "abc" And
             GL_DrawLog()\Font = *FUI And GL_DrawLog()\A = 0.5 And GL_DrawLog()\Clip And GL_DrawLog()\CX = 10 And GL_DrawLog()\CH = 40), "draw log: the text, measured, inside the clip")
  NextElement(GL_DrawLog())
  Check(Bool(GL_DrawLog()\Kind = #GL_LOG_NOCLIP), "draw log: the clip taken away")
  NextElement(GL_DrawLog())
  Check(Bool(GL_DrawLog()\Kind = #GL_LOG_POLY And GL_DrawLog()\W = 2 And GL_DrawLog()\H = 3 And GL_DrawLog()\Sides = 16 | (1 << 16) And GL_DrawLog()\Clip = #False), "draw log: the polygon")
EndIf

; the faces
Define FontDir.s = #PB_Compiler_FilePath + "../assets/fonts/"
Check(Bool(Neon_SetFaces("Nothing", "Nothing", FontDir + "no-such-face.ttf") = #False And FindString(Neon_FaceError(), "no-such-face.ttf") And
           Neon_FaceUI = "Segoe UI"), "a face file that is not there is refused, named, and the faces stay")
Check(Bool(Neon_SetFaces("Lato", "Consolas", FontDir + "Lato-Regular.ttf")), "Lato registered from the engine's assets: " + Neon_FaceError())
Check(Bool(Neon_ChromeFonts(1.0)), "the five fonts made from Lato and Consolas")
Check(Bool(*Neon_FontUI And Abs(*Neon_FontUI\LineHeight - 14) <= 1 And Abs(*Neon_FontSmall\LineHeight - 12) <= 1 And Abs(*Neon_FontBold\LineHeight - 15) <= 1 And
           Abs(*Neon_FontMono\LineHeight - 13) <= 1 And Abs(*Neon_FontItalic\LineHeight - 14) <= 1),
      "the five at 14 / 12 / 15 / 13 / 14 pixels (" + StrF(*Neon_FontUI\LineHeight, 0) + " " + StrF(*Neon_FontSmall\LineHeight, 0) + " " +
      StrF(*Neon_FontBold\LineHeight, 0) + " " + StrF(*Neon_FontMono\LineHeight, 0) + " " + StrF(*Neon_FontItalic\LineHeight, 0) + ")")
Define HaveMono.b = Bool(FileSize(FontDir + "JetBrainsMono-Regular.ttf") > 0)
If HaveMono
  Check(Bool(Neon_UseFaceSet(#NEON_FACES_OPEN, FontDir) And Neon_FaceUI = "Lato" And Neon_FaceMono = "JetBrains Mono"), "the open set")
Else
  Check(Bool(Neon_UseFaceSet(#NEON_FACES_OPEN, FontDir) = #False And FindString(Neon_FaceError(), "JetBrainsMono-Regular.ttf") And
             Neon_FaceMono = "Consolas"), "the open set refused while its mono file is not in assets/fonts (it is said, and the faces stay)")
  PrintN("note: assets/fonts/JetBrainsMono-Regular.ttf is not there; the open set is refused until it is")
EndIf
Check(Bool(Neon_UseFaceSet(#NEON_FACES_WINDOWS) And Neon_FaceUI = "Segoe UI" And Neon_FaceMono = "Consolas"), "back to the Windows set")
; from here on the metric faces
*Neon_FontUI = *FUI : *Neon_FontSmall = *FSmall : *Neon_FontBold = *FBold : *Neon_FontMono = *FMono : *Neon_FontItalic = *FItalic

; ----------------------------------------------------------------------------
; 2. Neon_FitText against a reference
; ----------------------------------------------------------------------------
; The width of a text in a metric face: its code points (a surrogate pair is
; one), controls aside, times the advance.
Procedure.f RefWidth(Text.s, Adv.f)
  Protected i.i, c.i, n.i
  For i = 1 To Len(Text)
    c = Asc(Mid(Text, i, 1))
    If c >= $DC00 And c <= $DFFF And i > 1 And Asc(Mid(Text, i - 1, 1)) >= $D800 And Asc(Mid(Text, i - 1, 1)) <= $DBFF : Continue : EndIf
    If c < 32 Or c = 127 : Continue : EndIf
    n + 1
  Next
  ProcedureReturn n * Adv
EndProcedure
; The longest start of the text, cut where no character is split (not in front of the second half of a
; surrogate pair, a combining mark U+0300-036F, a variation selector U+FE00-FE0F or a joiner U+200D), with
; trailing spaces dropped, that fits with the ellipsis; the text itself when it fits; "" when the ellipsis
; does not.
Procedure.s RefFit(Text.s, MaxW.f, Adv.f)
  Protected k.i, c.i, cand.s
  If Text = "" Or RefWidth(Text, Adv) <= MaxW : ProcedureReturn Text : EndIf
  If RefWidth(Tail, Adv) > MaxW : ProcedureReturn "" : EndIf
  For k = Len(Text) - 1 To 0 Step -1
    c = Asc(Mid(Text, k + 1, 1))
    If k > 0 And ((c >= $DC00 And c <= $DFFF) Or (c >= $300 And c <= $36F) Or (c >= $FE00 And c <= $FE0F) Or c = $200D) : Continue : EndIf
    cand = RTrim(Left(Text, k)) + Tail
    If RefWidth(cand, Adv) <= MaxW : ProcedureReturn cand : EndIf
  Next
  ProcedureReturn Tail
EndProcedure
Define pair.s = Space(2), t.s, w.i
PokeU(@pair, $D83D) : PokeU(@pair + 2, $DE00)
Dim FitTexts.s(5)
FitTexts(0) = "The quick brown fox jumps over the lazy dog"
FitTexts(1) = "Cafe" + Chr($301) + " au lait"
FitTexts(2) = "ab" + pair + "cd" + pair
FitTexts(3) = "a  b   c    d"
FitTexts(4) = "x" + Chr($FE0F) + "y" + Chr($200D) + "z"
FitTexts(5) = "abc"
Define fitChecks.i
For a = 0 To 5
  For w = 0 To 360 Step 1
    t = Neon_FitText(*FUI, FitTexts(a), w)
    If t <> RefFit(FitTexts(a), w, 8) Or GetGLTextWidth(*FUI, t) > w
      Check(#False, "Neon_FitText(" + Str(a) + ", " + Str(w) + ") = [" + t + "], the reference [" + RefFit(FitTexts(a), w, 8) + "]")
      Break
    EndIf
    fitChecks + 1
  Next
Next
Check(Bool(fitChecks = 6 * 361), "Neon_FitText at every width 0 - 360 for six texts")
Check(Bool(Neon_FitText(*FUI, "abc", 23) = "a" + Tail Or Tail = "..."), "a three-letter text cut to 23: one letter and the ellipsis")
Check(Bool(Neon_FitText(*FUI, "abc", 7) = ""), "no room even for the ellipsis: nothing")

; ----------------------------------------------------------------------------
; 3. GlUI's layout rules, on the gallery's Arcade screen
; ----------------------------------------------------------------------------
Procedure CheckRect(ID.i, x.f, y.f, w.f, h.f)
  Protected *g.NeonGadget = Gallery_UIGadget(ID)
  Check(Bool(*g And Near(*g\X, x) And Near(*g\Y, y) And Near(*g\W, w) And Near(*g\H, h)),
        "GlUI gadget " + Str(ID) + " at " + StrF(x, 1) + ", " + StrF(y, 1) + " size " + StrF(w, 1) + " x " + StrF(h, 1))
EndProcedure
Gallery_ShowHost = #False
Gallery_Init(*FArcade)
CheckRect(#GAL_UI_TITLE, 80, 84, 0, 0)                              ; a label has no size
CheckRect(#GAL_UI_START, 80, 190, 220, 50)                          ; 220 >= 5 x 12 + 40: as asked
CheckRect(#GAL_UI_LONG, 80 - (16 * 12 + 40 - 120) / 2, 330, 16 * 12 + 40, 50)  ; widened to label + 40 about its centre
CheckRect(#GAL_UI_VOLUME, 440, 210, 320, 30)
CheckRect(#GAL_UI_SOUND, 440, 270, 320, 40)                         ; 320 >= 5 x 12 + 80
CheckRect(#GAL_UI_DIP, 820, 220, 8 * 40 + 20, 70)                   ; 8 switches x 40 + 20 (the label, 144, is narrower)
CheckRect(#GAL_UI_MODE, 820, 380, 380, 50)

; ----------------------------------------------------------------------------
; 4. THE SCRIPT, TWICE
; ----------------------------------------------------------------------------
Global RunNav.b
Global NewList Out.s()
Procedure Emit(s.s)
  AddElement(Out()) : Out() = s
EndProcedure
Procedure.s F3(v.f)
  Protected s.s = StrF(v, 3)
  If s = "-0.000" : s = "0.000" : EndIf
  ProcedureReturn s
EndProcedure
Procedure.s F4(v.f)
  Protected s.s = StrF(v, 4)
  If s = "-0.0000" : s = "0.0000" : EndIf
  ProcedureReturn s
EndProcedure
; A text as the file holds it: between quotes, with \ " and the control characters written \uXXXX.
Procedure.s Quote(t.s)
  Protected i.i, c.i, s.s = Chr(34)
  For i = 1 To Len(t)
    c = Asc(Mid(t, i, 1))
    If c < 32 Or c = 127 Or c = 34 Or c = 92
      s + "\u" + RSet(Hex(c), 4, "0")
    Else
      s + Mid(t, i, 1)
    EndIf
  Next
  ProcedureReturn s + Chr(34)
EndProcedure
Procedure.s ClipText(*e.GLDrawLogEntry)
  If *e\Clip : ProcedureReturn "clip " + F3(*e\CX) + " " + F3(*e\CY) + " " + F3(*e\CW) + " " + F3(*e\CH) : EndIf
  ProcedureReturn "clip -"
EndProcedure
Procedure EmitPrims()
  Protected s.s, *e.GLDrawLogEntry
  ForEach GL_DrawLog()
    *e = @GL_DrawLog()
    Select *e\Kind
      Case #GL_LOG_BOX
        s = "box " + F3(*e\X) + " " + F3(*e\Y) + " " + F3(*e\W) + " " + F3(*e\H) + " " + F4(*e\R) + " " + F4(*e\G) + " " + F4(*e\B) + " " + F4(*e\A) + " " + ClipText(*e)
      Case #GL_LOG_TEXT
        s = "text " + F3(*e\X) + " " + F3(*e\Y) + " " + F3(*e\W) + " " + F3(*e\H) + " " + F4(*e\R) + " " + F4(*e\G) + " " + F4(*e\B) + " " + F4(*e\A) + " " +
            ClipText(*e) + " " + FaceName(*e\Font) + " " + Quote(*e\Text)
      Case #GL_LOG_POLY
        s = "poly " + F3(*e\X) + " " + F3(*e\Y) + " " + F3(*e\W) + " " + F3(*e\H) + " " + F4(*e\R) + " " + F4(*e\G) + " " + F4(*e\B) + " " + F4(*e\A) + " " +
            ClipText(*e) + " " + Str(*e\Sides & $FFFF) + " " + Str(Bool(*e\Sides >> 16))
      Case #GL_LOG_CLIP
        s = "clip " + F3(*e\X) + " " + F3(*e\Y) + " " + F3(*e\W) + " " + F3(*e\H)
      Case #GL_LOG_NOCLIP
        s = "noclip"
    EndSelect
    Emit(s)
  Next
EndProcedure

; the check's frame: the caret's blink held on (it is the host's clock), the frame recorded
Procedure CheckFrame(*inp.GalleryInput)
  Neon_CaretMs = ElapsedMilliseconds()
  GL_DrawLogStart()
  Gallery_Frame(*inp)
  GL_DrawLogStop()
EndProcedure

; primitives of the last frame
Procedure.i FindBox(x.f, y.f, w.f, h.f)
  ForEach GL_DrawLog()
    If GL_DrawLog()\Kind = #GL_LOG_BOX And Near(GL_DrawLog()\X, x, 0.01) And Near(GL_DrawLog()\Y, y, 0.01) And Near(GL_DrawLog()\W, w, 0.01) And Near(GL_DrawLog()\H, h, 0.01)
      ProcedureReturn @GL_DrawLog()
    EndIf
  Next
  ProcedureReturn 0
EndProcedure
Procedure.i FindText(t.s, x.f = -99999, y.f = -99999)
  ForEach GL_DrawLog()
    If GL_DrawLog()\Kind = #GL_LOG_TEXT And GL_DrawLog()\Text = t
      If (x = -99999 Or Near(GL_DrawLog()\X, x, 0.01)) And (y = -99999 Or Near(GL_DrawLog()\Y, y, 0.01)) : ProcedureReturn @GL_DrawLog() : EndIf
    EndIf
  Next
  ProcedureReturn 0
EndProcedure
Procedure.b SameRGB(*e.GLDrawLogEntry, r.f, g.f, b.f)
  ProcedureReturn Bool(*e And Near(*e\R, r, 0.0005) And Near(*e\G, g, 0.0005) And Near(*e\B, b, 0.0005))
EndProcedure
Procedure.b ClipIs(*e.GLDrawLogEntry, x.f, y.f, w.f, h.f)
  ProcedureReturn Bool(*e And *e\Clip And Near(*e\CX, x) And Near(*e\CY, y) And Near(*e\CW, w) And Near(*e\CH, h))
EndProcedure
Procedure.s LastLog()
  If LastElement(GalleryLog()) : ProcedureReturn GalleryLog()\Text : EndIf
  ProcedureReturn ""
EndProcedure
Procedure.i ZoneOf(Tag.i, A.i, B.i)
  ProcedureReturn Gallery_Zone(Neon_HotKey(Tag, A, B))
EndProcedure
Procedure.b ZoneIs(Tag.i, A.i, B.i, x.f, y.f, w.f, h.f)
  Protected z.i = ZoneOf(Tag, A, B)
  ProcedureReturn Bool(z >= 0 And Near(Neon_HotPrev(z)\x, x) And Near(Neon_HotPrev(z)\y, y) And Near(Neon_HotPrev(z)\w, w) And Near(Neon_HotPrev(z)\h, h))
EndProcedure

; Every step's expected values, worked out from the kit's rules with the metric faces.
Procedure StepChecks(Name.s)
  Protected run.s = " (" + StringField("mouse|pad", RunNav + 1, "|") + ")"
  Protected *e.GLDrawLogEntry, *g.NeonGadget, thumbY.f, i.i, lbl.s
  Select Name
    Case "arcade START"
      Check(Bool(G\Starts = 1 And LastLog() = "ui 102 event 1 value 0.000 active 0"), Name + run + ": one callback from gadget 102")
      Check(Bool(UI_FocusIndex = 2), Name + run + ": GlUI focus on START (index 2)")
      ; the focused button's boxes: focus ring, shadow, border, face; its label centred
      Check(Bool(FindBox(76, 186, 228, 58) And FindBox(84, 194, 220, 50) And FindBox(80, 190, 220, 50) And FindBox(82, 192, 216, 46)), Name + run + ": the button's four boxes")
      *e = FindText("START", 80 + 110 - 30, 190 + 25 - 12)
      Check(Bool(*e And SameRGB(*e, 0.902, 0.902, 0.902) And *e\Font = *FArcade), Name + run + ": START centred in the arcade face")
    Case "arcade SOUND off"
      Check(Bool(G\Sound = 0 And LastLog() = "ui 106 event 1 value 0.000 active 0"), Name + run)
      ; off: the left half of the switch, drawn twice over (dark red, then light red: the second covers the first)
      Protected nOff.i
      ForEach GL_DrawLog()
        If GL_DrawLog()\Kind = #GL_LOG_BOX And Near(GL_DrawLog()\X, 700) And Near(GL_DrawLog()\Y, 275) And Near(GL_DrawLog()\W, 30) And Near(GL_DrawLog()\H, 30)
          If SameRGB(@GL_DrawLog(), 0.8, 0.1, 0.1) Or SameRGB(@GL_DrawLog(), 1.0, 0.5, 0.5) : nOff + 1 : EndIf
        EndIf
      Next
      Check(Bool(nOff = 2 And FindBox(730, 275, 30, 30) = 0), Name + run + ": the switch drawn off, nothing on its right half")
    Case "arcade VOLUME up"
      Check(Bool(Near(G\Volume, 0.55, 0.0001) And G\Meter And Near(G\Meter\Value, 0.55, 0.0001)), Name + run + ": 0.5 + 0.05 (" + StrF(G\Volume, 4) + ")")
      Check(Bool(FindString(LastLog(), "ui 105 event 1 value 0.550")), Name + run + ": the slider's callback")
      ; the meters: segment i lit when the value passes its start, i / 20: empty none, full all twenty, and the
      ; level as many as starts its value passes (0.5 + 0.05 in single precision is just above 0.55, so twelve)
      Protected lit.i, lit0.i, lit1.i, sw.f = (320 - 6) / 20.0, wantLit.i
      For i = 0 To 19 : If i / 20.0 < G\Meter\Value : wantLit + 1 : EndIf : Next
      For i = 0 To 19
        *e = FindBox(443 + i * sw, 423, sw - 2, 24) : If *e And *e\G > 0.5 : lit0 + 1 : EndIf
        *e = FindBox(443 + i * sw, 493, sw - 2, 24) : If *e And *e\G > 0.5 : lit + 1 : EndIf
        *e = FindBox(443 + i * sw, 563, sw - 2, 24) : If *e And *e\G > 0.5 : lit1 + 1 : EndIf
      Next
      Check(Bool(lit0 = 0 And lit = wantLit And lit1 = 20 And wantLit = 12), Name + run + ": meters lit 0 / 12 / 20 (" + Str(lit0) + " / " + Str(lit) + " / " + Str(lit1) + ")")
    Case "arcade DIP 2"
      *g = Gallery_UIGadget(#GAL_UI_DIP)
      Check(Bool(G\Dip = %10100111 And *g\SubFocus = 1), Name + run + ": switch 2 on, the cursor on it")
      ; switch 1 (the second) of eight centred in 340: starts at 820 + 170 - 160 + 40
      *e = FindBox(870 + 2, 240, 16, 20)
      Check(Bool(*e And SameRGB(*e, 0.8, 0.9, 1.0)), Name + run + ": switch 2's lever up")
    Case "arcade MODE right"
      Check(Bool(G\Mode = 2 And FindText("HARD", 820 + 190 - 24, 380 + 25 - 12)), Name + run + ": HARD, centred")
    Case "arcade MODE left"
      Check(Bool(G\Mode = 1 And FindText("NORMAL")), Name + run)
    Case "arcade VIBRATION on"
      Check(Bool(G\Vibrate = 1), Name + run)
    Case "arcade LONG button"
      Check(Bool(G\Longs = 1 And FindBox(24 - 4, 326, 232 + 8, 58)), Name + run + ": the widened button, focused")
    Case "to Controls"
      Check(Bool(G\Screen = #GAL_CONTROLS), Name + run)
      For i = 0 To #GAL_FITS - 1
        lbl = Gallery_FitSample
        If i = 6 : lbl = Gallery_FitMark : ElseIf i = 7 : lbl = Gallery_FitAstral : ElseIf i = 8 : lbl = "Fits exactly" : EndIf
        Check(Bool(G\Fit[i] = RefFit(lbl, Gallery_FitW(i), 8)), Name + run + ": fitted text " + Str(i) + " [" + G\Fit[i] + "]")
      Next
      Check(Bool(G\Fit[8] = "Fits exactly" And G\Fit[4] = Tail And G\Fit[5] = ""), Name + run + ": exactly fitting, the ellipsis alone, nothing")
      ; the disabled button: no hot zone, faint label
      Check(Bool(ZoneOf(1, 36, 190) < 0 And ZoneOf(1, 36, 110) >= 0), Name + run + ": the disabled button takes no part")
      *e = FindText("Disabled", 36 + (160 - 64) / 2, 190 + 7)
      Check(Bool(SameRGB(*e, Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB)), Name + run + ": the disabled label faint")
      ; the inert bar: a track, no thumb, nothing to scroll
      Check(Bool(FindBox(356, 436, 10, 220) And ZoneOf(7, #GAL_ID_INERT, 0) < 0 And G\InertTop = 0), Name + run + ": the inert bar")
      ; the placeholder of the empty field
      *e = FindText("Search the gallery...", 876, 108 + 6)
      Check(Bool(SameRGB(*e, Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB) And ClipIs(*e, 869, 109, 374, 26)), Name + run + ": the placeholder, faint, clipped to the field")
    Case "button Normal"
      Check(Bool(G\Clicks1 = 1 And LastLog() = "button Normal"), Name + run)
      Check(Bool(FindBox(36, 110, 160, 30) And FindText("Normal", 36 + 56, 117)), Name + run + ": the button and its centred label")
    Case "button Lit"
      *e = FindText("Lit", 36 + 68, 157)
      Check(Bool(G\Clicks2 = 1 And SameRGB(*e, 0.588, 0.816, 0.867)), Name + run + ": lit label colour")
    Case "input 2 takes the keyboard"
      Check(Bool(Neon_FocusID = #GAL_ID_INPUT2 And G\Caret2 = 12), Name + run + ": the keyboard, the caret at the end (" + Str(G\Caret2) + ")")
      *e = FindBox(868 + 8 + 12 * 8, 154, 1.5, 16)
      Check(Bool(SameRGB(*e, Neon_C_AccR, Neon_C_AccG, Neon_C_AccB) And ClipIs(*e, 869, 149, 374, 26)), Name + run + ": the caret, inside the field's clip")
      Check(Bool(FindBox(868, 148, 376, 1) And SameRGB(FindBox(868, 148, 376, 1), Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)), Name + run + ": the focused frame")
    Case "input 2 Left"
      Check(Bool(G\Caret2 = 11 And FindBox(876 + 88, 154, 1.5, 16)), Name + run)
    Case "input 2 Left again"
      Check(Bool(G\Caret2 = 10), Name + run)
    Case "input 2 Right"
      Check(Bool(G\Caret2 = 11), Name + run)
    Case "input 2 types !"
      Check(Bool(G\Text2\s = "Hello, worl!d" And G\Caret2 = 12 And FindText("Hello, worl!d", 876, 154)), Name + run)
    Case "input 2 submitted"
      Check(Bool(G\Submits = 1 And G\LastSubmit = "Hello, worl!d" And Neon_FocusID = #GAL_ID_INPUT2 And LastLog() = "submit 202 Hello, worl!d"), Name + run)
    Case "input 2 whole text selected"
      Check(Bool(Neon_TextAllID = #GAL_ID_INPUT2 And G\Caret2 = 13), Name + run)
      *e = FindBox(868 + 6, 154, 13 * 8 + 4, 16)
      Check(Bool(*e And Near(*e\A, 0.35)), Name + run + ": the selection drawn over the whole text")
    Case "input 2 Right (lets the selection go)"
      Check(Bool(Neon_TextAllID = 0 And G\Caret2 = 13), Name + run)
    Case "input 2 Home"
      Check(Bool(G\Caret2 = 0 And FindBox(876, 154, 1.5, 16)), Name + run)
    Case "input 2 Delete"
      Check(Bool(G\Text2\s = "ello, worl!d" And G\Caret2 = 0), Name + run)
    Case "input 2 types H"
      Check(Bool(G\Text2\s = "Hello, worl!d" And G\Caret2 = 1), Name + run)
    Case "input 2 End"
      Check(Bool(G\Caret2 = 13), Name + run)
    Case "input 2 Backspace"
      Check(Bool(G\Text2\s = "Hello, worl!" And G\Caret2 = 12), Name + run)
    Case "input 2 types d"
      Check(Bool(G\Text2\s = "Hello, worl!d" And G\Caret2 = 13), Name + run)
    Case "input 2 lets go (Esc)", "input 3 lets go (Esc)"
      Check(Bool(Neon_FocusID = 0), Name + run)
    Case "input 3 takes the keyboard"
      ; the click at the field's centre, 968: (968 - 876) = 92 lies before the middle of character 13 (100)
      Check(Bool(Neon_FocusID = #GAL_ID_INPUT3 And G\Caret3 = 12), Name + run + ": caret " + Str(G\Caret3))
    Case "input 3 caret right"
      Check(Bool(G\Caret3 = 13), Name + run)
    Case "vbar a page down", "vbar another page down", "vbar to the end", "vbar a page up from the end", "vbar to the start"
      Protected want.i
      Select Name
        Case "vbar a page down" : want = 10
        Case "vbar another page down" : want = 20
        Case "vbar to the end" : want = 90
        Case "vbar a page up from the end" : want = 80
        Case "vbar to the start" : want = 0
      EndSelect
      thumbY = 436 + (220 - 22) * want / 90.0                          ; the thumb 22 (220 x 10 / 100), the travel 198
      Check(Bool(G\VTop = want And FindBox(42, thumbY, 10, 22) And ZoneIs(7, #GAL_ID_VBAR, 0, 40, thumbY, 14, 22)), Name + run + ": top " + Str(G\VTop) + ", want " + Str(want))
      *e = FindText("Row " + RSet(Str(want), 3, "0") + " of 100", 66, 438)
      Check(Bool(ClipIs(*e, 60, 436, 290, 220)), Name + run + ": the first row shown, clipped to its box")
    Case "hbar a page right"
      Check(Bool(G\HLeft = 12 And FindBox(380 + 344 * 12 / 48.0, 662, 86, 10)), Name + run + ": left 12, the thumb 86 wide")
    Case "to Lists and tabs"
      ; strip A: each tab as wide as its label + 26 + the close box (18); from x 16 + 4
      Check(Bool(ZoneIs(5, #GAL_ID_TABSA, 0, 20, 100, 7 * 8 + 44, 29) And ZoneIs(6, #GAL_ID_TABSA, 0, 20 + 100 - 19, 105.5, 18, 18)), Name + run + ": tab 0 and its close box")
      *e = FindText("GlUIChrome.pbi")
      Check(Bool(*e And *e\Font = *FItalic), Name + run + ": the italic tab in the italic face")
      ; strip B's long tab is not yet in view; tab 1 sits at 20 + 66
      Check(Bool(ZoneIs(5, #GAL_ID_TABSB, 1, 86, 148, 66, 29) And ZoneOf(5, #GAL_ID_TABSB, 11) < 0 And ZoneOf(11, #GAL_ID_TABSB, 1) >= 0 And ZoneOf(11, #GAL_ID_TABSB, 0) < 0),
            Name + run + ": strip B from its start, a right arrow and no left one")
      ; the long list: 26 rows of 22 in 572; rows clipped to the list less its bar
      *e = FindText("Arduino", 664 + 8, 100 + 4)
      Check(Bool(SameRGB(*e, Neon_C_AmbR, Neon_C_AmbG, Neon_C_AmbB) And ClipIs(*e, 664, 100, 590, 572)), Name + run + ": a group row, amber, clipped")
      lbl = "A board whose name is much too long for this pane, so it is cut short"
      Check(Bool(FindText(RefFit(lbl, 1264 - 16 - (664 + 8 + 14), 7), 664 + 8 + 14)), Name + run + ": the long label cut to its row")
      ; the empty list: an inert bar, no rows
      Check(Bool(FindBox(16 + 620 - 10, 302, 10, 110) And ZoneOf(7, #GAL_ID_LIST2 + 900000, 0) < 0), Name + run + ": the empty list")
    Case "tabs A pin of the pinned tab"
      Check(Bool(G\PinnedA = 4 And G\TabA = 1 And LastLog() = "tabs A pin 4"), Name + run)
    Case "tabs A close the first tab"
      Check(Bool(G\ClosedA = 0 And G\TabA = 0 And G\TabsA = "GlUI.pbi|GlUIChrome.pbi|README.md|Pinned notes.txt" And G\StylesA = " i p"), Name + run + ": [" + G\TabsA + "] active " + Str(G\TabA))
    Case "tabs B right arrow", "tabs B right arrow again", "tabs B right arrow a third time"
      ; tabs of 66 (Tab 1 - 9) and 74 (Tab 10 - 24), the long one 416 (26 line heights); the view is the strip less
      ; the arrows (22); each click brings the first tab cut off on the right fully into view
      Protected off.f
      Select Name
        Case "tabs B right arrow" : off = 74
        Case "tabs B right arrow again" : off = 148
        Default : off = 564
      EndSelect
      Check(Bool(Near(Neon_TabScrollOffset(#GAL_ID_TABSB), off)), Name + run + ": moved left " + StrF(Neon_TabScrollOffset(#GAL_ID_TABSB), 1) + ", want " + StrF(off, 0))
    Case "tabs B the long tab"
      lbl = "A tab whose label is far too long to be shown whole in any tab of this strip"
      Check(Bool(G\TabB = 11 And Near(Neon_TabScrollOffset(#GAL_ID_TABSB), 564)), Name + run)
      Check(Bool(FindText(RefFit(lbl, 416 - 12 - 8, 8), 20 + 742 - 564 + 12)), Name + run + ": its label cut to the tab's room")
    Case "tabs C third tab"
      Check(Bool(G\TabC = 2 And FindText("a|b") And FindText("esc" + Chr(27) + "x")), Name + run + ": the escaped labels shown as they were")
    Case "list 501 row 3"
      *e = FindBox(664, 100 + 3 * 22, 590, 22)
      Check(Bool(G\Sel1 = 3 And SameRGB(*e, Neon_C_AccR * 0.30, Neon_C_AccG * 0.30, Neon_C_AccB * 0.34)), Name + run + ": row 3 selected")
    Case "list 501 wheel down"
      Check(Bool(G\ListTop1 = 3), Name + run + ": three rows a notch (" + Str(G\ListTop1) + ")")
    Case "list 501 a page down"
      Check(Bool(G\ListTop1 = 29), Name + run + ": a page of 26 rows (" + Str(G\ListTop1) + ")")
      ; the list's bar: 78 rows, 26 shown; the thumb 572 x 26 / 78
      thumbY = 100 + (572 - 572 * 26 / 78.0) * 29 / 52.0
      Check(Bool(FindBox(1254 + 2, thumbY, 6, 572 * 26 / 78.0)), Name + run + ": the list's thumb")
    Case "list 503 second row"
      Check(Bool(G\Sel3 = 1 And ZoneOf(7, #GAL_ID_LIST3 + 900000, 0) < 0), Name + run + ": a list that fits has no thumb")
    Case "menu File opens"
      Check(Bool(Neon_MenuOpenRoot = 0 And Neon_MenuBlocksMouse()), Name + run)
      ; names 8 wide each side of their label, from x 8; the drop-down measured from its rows
      Check(Bool(Near(Neon_MenuTabX(0), 8) And Near(Neon_MenuTabW(0), 56) And Near(Neon_MenuTabX(1), 64) And Near(Neon_MenuTabX(3), 176)), Name + run + ": the names along the bar")
      Check(Bool(Near(Neon_MenuMeasW(0), 28 + 18 + 56 + 46 + 42) And Near(Neon_MenuMeasH(0), 24 * 5 + 9 * 2)), Name + run + ": the drop-down 190 x 138 (" +
            StrF(Neon_MenuMeasW(0), 1) + " x " + StrF(Neon_MenuMeasH(0), 1) + ")")
      Check(Bool(ZoneIs(3, 8, 32, 8, 32, 190, 24)), Name + run + ": the first item")
      *e = FindText("Disabled item", 8 + 18, 32 + 24 * 3 + 18 + 4)
      Check(Bool(SameRGB(*e, Neon_C_FaintR, Neon_C_FaintG, Neon_C_FaintB) And ClipIs(*e, 8, 32, 190, 138)), Name + run + ": the disabled item faint, inside the drop-down's clip")
      Check(Bool(FindText("Ctrl+N", 8 + 190 - 14 - 42, 32 + 4 + 1)), Name + run + ": the shortcut, right-aligned in the small face")
    Case "menu File New"
      Check(Bool(Neon_MenuOpenRoot = -1 And LastLog() = "menu File New"), Name + run)
      If RunNav : Check(Bool(Neon_NavID = Neon_HotKey(2, 0, 0)), Name + run + ": the focus back on File") : EndIf
    Case "menu View Pointer mark"
      Check(Bool(G\Marks = 1 And Neon_MenuOpenRoot = -1 And LastLog() = "menu View Mark 1"), Name + run)
    Case "menu File Recent opens"
      Check(Bool(Neon_SubOpenKey = "0:Recent" And Neon_MenuOpenRoot = 0), Name + run)
      Check(Bool(FindText("gallery.pb") And FindText(">")), Name + run + ": the submenu's items and the row's arrow")
    Case "menu closes (Esc)"
      Check(Bool(Neon_MenuOpenRoot = -1 And Neon_SubOpenKey = ""), Name + run)
    Case "menu Long opens"
      ; 60 rows of 24 are taller than the 684 below the bar: the body scrolls between two arrow strips of 16
      Check(Bool(Neon_MenuOpenRoot = 2 And Neon_DropScrolls And Near(Neon_DropViewY, 48) And Near(Neon_DropViewH, 644) And Neon_DropScroll = 0), Name + run)
      Check(Bool(FindText("^") And FindText("v")), Name + run + ": the arrow strips")
    Case "menu Long scrolls"
      ; a notch is two rows (48): Board 3 is the first row showing, and Board 2, which only touches the view's top, has no zone
      Check(Bool(Neon_DropScroll = 48 And ZoneIs(3, 120, 48, 120, 48, 160, 24) And FindText("Board 2") = 0), Name + run + ": scrolled " + Str(Neon_DropScroll))
      *e = FindText("Board 3", 120 + 18, 48 + 4)
      Check(Bool(ClipIs(*e, 120, 48, 160, 644)), Name + run + ": Board 3 at the top of the view, in its clip")
    Case "menu Long Board 3"
      Check(Bool(G\Board = 3 And Neon_MenuOpenRoot = -1 And LastLog() = "menu Long Board 3"), Name + run)
    Case "tabs A second tab"
      Check(Bool(G\TabA = 1 And LastLog() = "tabs A active 1" And Neon_TabAt(#GAL_ID_TABSA, Neon_MX, Neon_MY) = 1), Name + run + ": and Neon_TabAt names it under the pointer")
    Case "the log shows"
      Check(Bool(G\Screen = #GAL_LOG), Name + run + ": the log screen")
      LastElement(GalleryLog())
      Check(Bool(FindText(RSet(Str(GalleryLog()\Frame), 6) + "   " + GalleryLog()\Text)), Name + run + ": the newest entry listed")
  EndSelect
EndProcedure

Gallery_Host = @CheckFrame()
Gallery_ScriptDt = 1.0 / 60.0
Gallery_MakeScript()
Define steps.i = ListSize(GalleryScript()), si.i, logFrom.i
Dim States.s(1, steps)
Emit("# neon-ui-expected 1")
Emit("# the UI kit's expected record, written by tools/ui_check.pb --write; the format is in README.md, The UI check")
Emit("canvas " + Str(#GAL_W) + " " + Str(#GAL_H))
Emit("face ui 8 16") : Emit("face small 7 14") : Emit("face bold 9 18") : Emit("face mono 8 16") : Emit("face italic 8 16") : Emit("face arcade 12 24")
If Tail = "..." : Emit("ellipsis ...") : Else : Emit("ellipsis U+2026") : EndIf
Define r.i, state.s, ln.i
For r = 0 To 1
  RunNav = r
  Gallery_Init(*FArcade)
  Gallery_PtrX = 640 : Gallery_PtrY = 700
  Gallery_MakeScript()
  logFrom = 0 : si = 0
  Emit("run " + StringField("mouse|pad", r + 1, "|"))
  ForEach GalleryScript()
    Check(Gallery_RunStep(@GalleryScript(), r), "step '" + GalleryScript()\Name + "': " + Gallery_StepError)
    state = Gallery_StateText(logFrom) : logFrom = ListSize(GalleryLog())
    States(r, si) = state
    If Not (r = 1 And GalleryScript()\Only = #GS_KEYS_ONLY) : StepChecks(GalleryScript()\Name) : EndIf
    Emit("step " + Str(si + 1) + " " + GalleryScript()\Name)
    For ln = 1 To CountString(state, #LF$)
      Emit("state " + StringField(state, ln, #LF$))
    Next
    EmitPrims()
    Emit("end")
    si + 1
  Next
Next

; the two runs agree
Procedure.s NoLog(s.s)
  Protected out.s, ln.i, l.s
  For ln = 1 To CountString(s, #LF$)
    l = StringField(s, ln, #LF$)
    If Left(l, 4) <> "log " : out + l + #LF$ : EndIf
  Next
  ProcedureReturn out
EndProcedure
si = 0
Define agree.i
ForEach GalleryScript()
  Select GalleryScript()\Only
    Case #GS_BOTH
      Check(Bool(States(0, si) = States(1, si)), "the mouse and the pad disagree after '" + GalleryScript()\Name + "':" + #LF$ + States(0, si) + "--- pad:" + #LF$ + States(1, si))
      agree + 1
    Case #GS_SAME_END
      Check(Bool(NoLog(States(0, si)) = NoLog(States(1, si))), "the mouse and the pad end differently after '" + GalleryScript()\Name + "':" + #LF$ + States(0, si) + "--- pad:" + #LF$ + States(1, si))
      agree + 1
  EndSelect
  si + 1
Next
PrintN("script: " + Str(steps) + " steps, each run with the mouse and with the pad; " + Str(agree) + " compared between the two")

; what only a pad does: a page of a long drop-down, and the focus put back on the menu's name
Gallery_Init(*FArcade)
Gallery_AddStep(#GS_SCREEN, "pad: to Lists", 0, 0, 0, #GAL_LISTS) : Check(Gallery_RunStep(@GalleryScript(), #True), "pad: to Lists")
Gallery_AddStep(#GS_PRESS, "pad: Long opens", 2, 2, 0) : Check(Gallery_RunStep(@GalleryScript(), #True), "pad: Long opens")
Gallery_AddStep(#GS_PAGE, "pad: Long a page down", 3, -1, 0, 1) : Check(Gallery_RunStep(@GalleryScript(), #True), "pad: Long a page down " + Gallery_StepError)
Check(Bool(Neon_DropScroll = 644), "pad: a page of a long drop-down is its view, 644 (" + Str(Neon_DropScroll) + ")")
Gallery_AddStep(#GS_KEY, "pad: back", 0, 0, 0, #PB_Shortcut_Escape) : Check(Gallery_RunStep(@GalleryScript(), #True), "pad: back")
Check(Bool(Neon_MenuOpenRoot = -1 And Neon_NavID = Neon_HotKey(2, 2, 0)), "pad: BACK closes the menu and the focus goes back to its name")
; ACTIVATE on a field that has not got the keyboard is a click (it takes it); on the one that has, Return
Gallery_AddStep(#GS_SCREEN, "pad: to Controls", 0, 0, 0, #GAL_CONTROLS) : Gallery_RunStep(@GalleryScript(), #True)
Gallery_AddStep(#GS_PRESS, "pad: input 1", 9, #GAL_ID_INPUT1) : Gallery_RunStep(@GalleryScript(), #True)
Check(Bool(Neon_FocusID = #GAL_ID_INPUT1 And G\Submits = 0), "pad: ACTIVATE gives the field the keyboard")
Gallery_AddStep(#GS_SUBMIT, "pad: input 1 submits") : Gallery_RunStep(@GalleryScript(), #True)
Check(Bool(G\Submits = 1 And LastLog() = "submit 201 "), "pad: ACTIVATE again submits it")

; the pointer through the CRT curve: the centre stays, a corner is pushed out by the curve's 1.5 %
Define vx.f, vy.f
UI_UseCRT = #True
MapPhysicalToVirtual(640, 360, @vx, @vy)
Check(Bool(Near(vx, 640) And Near(vy, 360)), "MapPhysicalToVirtual: the centre unchanged by the CRT curve")
MapPhysicalToVirtual(0, 0, @vx, @vy)
Check(Bool(Near(vx, -0.03 * 0.5 * 1280, 0.01) And Near(vy, -0.03 * 0.5 * 720, 0.01)), "MapPhysicalToVirtual: a corner bent out (" + StrF(vx, 2) + ", " + StrF(vy, 2) + ")")
UI_UseCRT = #False

; ----------------------------------------------------------------------------
; 5. GlUI's input faults, fixed
; ----------------------------------------------------------------------------
ClearList(UI_Gadgets())
UI_ActiveFont = *FArcade
Neon_AddLabel(1, 0, 0, "a") : Neon_AddLabel(2, 0, 40, "b")
UI_FocusIndex = 0
Neon_UpdateInput(-1000, -1000, 0, 0, 0, 1, 0)                     ; only labels: once looped for ever
Check(#True, "GlUI: D-pad over a list of labels only returns")
ClearList(UI_Gadgets())
Neon_UpdateInput(-1000, -1000, 0, 0, 0, 1, 0)                     ; nothing: once read a gadget that was not there
Check(#True, "GlUI: D-pad over an empty list returns")

; ----------------------------------------------------------------------------
; 6. THE EXPECTED LIST
; ----------------------------------------------------------------------------
Define fh.i, line.s, n.i, mism.i
If WriteMode
  fh = CreateFile(#PB_Any, WritePath, #PB_UTF8)
  Check(Bool(fh), "write " + WritePath)
  If fh
    ForEach Out() : WriteString(fh, Out() + #LF$, #PB_UTF8) : Next
    CloseFile(fh)
    PrintN("written " + WritePath + ": " + Str(ListSize(Out())) + " lines")
  EndIf
Else
  fh = ReadFile(#PB_Any, WritePath, #PB_UTF8)
  Check(Bool(fh), "read " + WritePath + " (make it with --write)")
  If fh
    FirstElement(Out())
    n = 0
    While Not Eof(fh)
      line = ReadString(fh, #PB_UTF8)
      n + 1
      If n > ListSize(Out()) : mism = n : Break : EndIf
      SelectElement(Out(), n - 1)
      If line <> Out() : mism = n : Break : EndIf
    Wend
    CloseFile(fh)
    If mism = 0 And n <> ListSize(Out()) : mism = n + 1 : EndIf
    If mism
      If SelectElement(Out(), mism - 1) : PrintN("this run, line " + Str(mism) + ": " + Out()) : EndIf
      PrintN("the file,  line " + Str(mism) + ": " + line)
    EndIf
    Check(Bool(mism = 0), "the record matches " + WritePath + " (" + Str(ListSize(Out())) + " lines)")
  EndIf
EndIf

If Fails
  PrintN(Str(Fails) + " of " + Str(Checks) + " checks FAILED")
  End 1
EndIf
PrintN("ui_check: " + Str(Checks) + " checks, pass")
End 0
