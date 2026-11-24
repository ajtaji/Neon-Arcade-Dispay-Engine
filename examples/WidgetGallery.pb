; ============================================================================
; WidgetGallery.pb - every widget of the UI kit (GlUI.pbi and GlUIChrome.pbi)
; in every state it has, on four screens
; ============================================================================
;   Arcade          GlUI's retained widgets: label, breadcrumb, buttons (one
;                   widened to its label), slider, two toggles, three meters
;                   (empty, the slider's level, full), a DIP bank, a carousel
;   Controls        the chrome's buttons (normal, lit, disabled), the five
;                   faces, right and centred text, box / frame / glow, one
;                   text cut to nine widths with the ellipsis, three text
;                   inputs (placeholder, caret, a text that scrolls), scroll
;                   bars (vertical, horizontal, one with nothing to scroll)
;                   over clipped content, and what the kit reports about
;                   itself (hover, menus, navigation, scale, faces)
;   Lists and tabs  a tab strip with close boxes, an italic and a pinned
;                   tab; one with more tabs than room; one whose labels hold
;                   a bar and an ESC; a list longer than its box (groups,
;                   indents, details, a label cut short), an empty list and
;                   one that fits
;   Event log       every callback and every action a widget reported, in
;                   the order it happened
; and the menu bar on all of them: shortcuts, separators, check marks, a
; disabled item, submenus, and a menu of 60 items that scrolls.
;
; DRIVING IT. The mouse and the keys, as any engine program. Or a game pad
; (an XInput pad, GL_PadRead): the D-pad moves the focus (up / down) and
; changes values (left / right), A acts, B goes back (Escape), the right
; stick scrolls, the triggers page, the shoulder buttons change screens.
; On the chrome's screens the pad goes through Neon_ChromeBeginNav, on the
; Arcade screen through GlUI's own D-pad input. F5 plays the gallery's
; script with the mouse and keys, F6 the same script with the pad's
; actions (examples/WidgetGalleryScreens.pbi; tools/ui_check.pb runs it
; without a window and checks every step).
;
; THE FACES. View > Faces picks the Windows faces (Segoe UI, Consolas: the
; default) or the open ones (Lato and JetBrains Mono, from assets/fonts/).
; "--faces open" on the command line starts with the open ones. A face
; file that is not there is said on the status line and in the log, and
; the faces stay as they were.
;
; Build (Windows, from this folder):
;   pbcompiler WidgetGallery.pb /EXE WidgetGallery.exe /THREAD /DPIAWARE
; ============================================================================
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlMath.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUI.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUIChrome.pbi"
XIncludeFile #PB_Compiler_FilePath + "WidgetGalleryScreens.pbi"

Global FontDir.s = #PB_Compiler_FilePath + "../assets/fonts/"
Global Gadget.i, Quit.b, FaceNote.s
Global Dim ArcadeFonts.i(1)

; The faces of set Set: the chrome's five, and GlUI's (one a set, kept for
; good: GlUI gadgets hold their font).
Procedure.b MakeFaces(Set.i)
  If Not Neon_UseFaceSet(Set, FontDir)
    FaceNote = "faces refused: " + Neon_FaceError()
    Gallery_Log(FaceNote)
    ProcedureReturn #False
  EndIf
  If Not Neon_ChromeFonts(1.0)
    FaceNote = "faces refused: " + Neon_FaceError()
    Gallery_Log(FaceNote)
    ProcedureReturn #False
  EndIf
  If ArcadeFonts(Set) = 0 : ArcadeFonts(Set) = Neon_CreateFontPx(Neon_FaceUI, 24, #PB_Font_Bold) : EndIf
  G\ArcadeFont = ArcadeFonts(Set)
  G\FaceSet = Set
  G\Points14 = Neon_PointsForPixelHeight(Neon_FaceUI, 14)
  FaceNote = ""
  ProcedureReturn #True
EndProcedure

; The host's frame: clear, the gallery's frame, show it.
Procedure PresentFrame(*inp.GalleryInput)
  SetGadgetAttribute(Gadget, #PB_OpenGL_SetContext, #True)
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glDisable_(#GL_SCISSOR_TEST)
  glViewport_(0, 0, DesktopScaledX(Util_WinWidth), DesktopScaledY(Util_WinHeight))
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  Gallery_Frame(*inp)
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
EndProcedure

; While the script plays: the window stays alive and the frames can be watched.
Procedure ScriptFrame(*inp.GalleryInput)
  Protected ev.i
  Repeat
    ev = WindowEvent()
    If ev = #PB_Event_CloseWindow : Quit = #True : EndIf
    If ev = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until ev = 0
  PresentFrame(*inp)
  Delay(12)
EndProcedure

Procedure PlayScript(Nav.b)
  Gallery_Init(G\ArcadeFont)
  Gallery_Log("script starts (" + StringField("mouse and keys|pad", Nav + 1, "|") + ")")
  Gallery_MakeScript()
  Gallery_Host = @ScriptFrame()
  ForEach GalleryScript()
    If Quit : Break : EndIf
    If Not Gallery_RunStep(@GalleryScript(), Nav)
      Gallery_Log("script stopped: " + Gallery_StepError)
      Break
    EndIf
  Next
  Gallery_Host = 0
  Gallery_Log("script ends")
EndProcedure

; --- the window
GL_HostPrepare()
Gadget = OpenGLWindow("Neon widget gallery", #GAL_W, #GAL_H, #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MaximizeGadget)
If Not Gadget : MessageRequester("Neon widget gallery", "No OpenGL window.") : End 1 : EndIf
Util_BaseWidth = #GAL_W : Util_BaseHeight = #GAL_H
GL_HandleResize(Gadget)
UI_UseCRT = #False
Neon_UIScale = 1.0

Define startSet.i = #NEON_FACES_WINDOWS, a.i
For a = 0 To CountProgramParameters() - 1
  If ProgramParameter(a) = "--faces" And a + 1 < CountProgramParameters() And ProgramParameter(a + 1) = "open" : startSet = #NEON_FACES_OPEN : EndIf
Next
If Not MakeFaces(startSet)
  Define why.s = FaceNote
  If Not MakeFaces(#NEON_FACES_WINDOWS) : MessageRequester("Neon widget gallery", FaceNote) : End 1 : EndIf
  FaceNote = why
EndIf
Gallery_Init(G\ArcadeFont)
If FaceNote <> "" : Gallery_Log(FaceNote) : EndIf
Gallery_Log("gallery starts, faces " + Neon_FaceUI + " / " + Neon_FaceMono)

; --- the loop
Define ev.i, inp.GalleryInput, down.b, wheel.i, key.i, char.i, ctrl.b, nav.b, k.i, now.q, last.q = GL_Micros()
Define pad.GLPadState, padPrev.u, padHave.i, padAction.i, stickPrev.i, trigPrev.i, stick.i, trig.i
Define lastMX.i = -1, lastMY.i = -1, mx.i, my.i, go.i, repeatAt.q, play.i
Repeat
  wheel = 0 : key = 0 : char = 0 : ctrl = #False : play = 0
  Repeat
    ev = WindowEvent()
    Select ev
      Case #PB_Event_CloseWindow : Quit = #True
      Case #PB_Event_SizeWindow : GL_HandleResize(Gadget)
      Case #PB_Event_Menu
        If EventMenu() = 1001 : key = #PB_Shortcut_Escape : nav = #False : EndIf   ; OpenGLWindow traps Escape as a shortcut
      Case #PB_Event_Gadget
        If EventGadget() = Gadget
          Select EventType()
            Case #PB_EventType_LeftButtonDown : down = #True : nav = #False
            Case #PB_EventType_LeftButtonUp : down = #False
            Case #PB_EventType_MouseWheel : wheel + GetGadgetAttribute(Gadget, #PB_OpenGL_WheelDelta) : nav = #False
            Case #PB_EventType_KeyDown
              k = GetGadgetAttribute(Gadget, #PB_OpenGL_Key)
              If k = #PB_Shortcut_F5 : play = 1 : ElseIf k = #PB_Shortcut_F6 : play = 2 : Else : key = k : nav = #False : EndIf
              ctrl = Bool(GetGadgetAttribute(Gadget, #PB_OpenGL_Modifiers) & #PB_OpenGL_Control)
            Case #PB_EventType_Input
              char = GetGadgetAttribute(Gadget, #PB_OpenGL_Input) : nav = #False
          EndSelect
        EndIf
    EndSelect
  Until ev = 0
  If play : PlayScript(Bool(play = 2)) : Continue : EndIf

  now = GL_Micros()
  ClearStructure(@inp, GalleryInput)
  inp\Dt = (now - last) / 1000000.0 : last = now
  If inp\Dt > 0.1 : inp\Dt = 0.1 : EndIf
  inp\GoScreen = -1

  ; the pad: one action a frame, on the press (the D-pad repeats while held)
  padAction = #NEON_NAV_NONE : go = -1
  padHave = GL_PadRead(0, @pad)
  If padHave
    If (pad\Buttons & ~padPrev) Or (pad\Buttons & $F And ElapsedMilliseconds() >= repeatAt)
      If pad\Buttons & ~padPrev : repeatAt = ElapsedMilliseconds() + 400 : Else : repeatAt = ElapsedMilliseconds() + 90 : EndIf
      If pad\Buttons & 1 : padAction = #NEON_NAV_PREV
      ElseIf pad\Buttons & 2 : padAction = #NEON_NAV_NEXT
      ElseIf pad\Buttons & 4 : padAction = #NEON_NAV_LEFT
      ElseIf pad\Buttons & 8 : padAction = #NEON_NAV_RIGHT
      ElseIf pad\Buttons & ~padPrev & $1000 : padAction = #NEON_NAV_ACTIVATE
      ElseIf pad\Buttons & ~padPrev & $2000 : padAction = #NEON_NAV_BACK
      ElseIf pad\Buttons & ~padPrev & $100 : go = G\Screen - 1 : If go < 0 : go = #GAL_LOG : EndIf
      ElseIf pad\Buttons & ~padPrev & $200 : go = G\Screen + 1 : If go > #GAL_LOG : go = 0 : EndIf
      ElseIf pad\Buttons & ~padPrev & $10 : PlayScript(#True)
      EndIf
    EndIf
    stick = 0 : If pad\RY > 16000 : stick = 1 : ElseIf pad\RY < -16000 : stick = -1 : EndIf
    If stick <> stickPrev And stick = 1 : padAction = #NEON_NAV_UP : ElseIf stick <> stickPrev And stick = -1 : padAction = #NEON_NAV_DOWN : EndIf
    stickPrev = stick
    trig = 0 : If pad\LT > 128 : trig = -1 : ElseIf pad\RT > 128 : trig = 1 : EndIf
    If trig <> trigPrev And trig = -1 : padAction = #NEON_NAV_PAGEUP : ElseIf trig <> trigPrev And trig = 1 : padAction = #NEON_NAV_PAGEDOWN : EndIf
    trigPrev = trig
    padPrev = pad\Buttons
    If padAction <> #NEON_NAV_NONE Or go >= 0 : nav = #True : EndIf
  EndIf

  ; the mouse: moving it hands the frame back to the pointer
  mx = WindowMouseX(Util_MainWindowID) : my = WindowMouseY(Util_MainWindowID)
  If (mx <> lastMX Or my <> lastMY) And lastMX >= 0 And padAction = #NEON_NAV_NONE : nav = #False : EndIf
  lastMX = mx : lastMY = my

  inp\Nav = nav
  If nav
    inp\NavAction = padAction : inp\GoScreen = go
  Else
    inp\MouseX = mx : inp\MouseY = my : inp\Down = down : inp\Wheel = wheel
    inp\Key = key : inp\KeyChar = char : inp\Ctrl = ctrl
  EndIf
  PresentFrame(@inp)

  If G\WantFaceSet >= 0
    If MakeFaces(G\WantFaceSet)
      Gallery_BuildArcade()
      Gallery_Log("faces now " + Neon_FaceUI + " / " + Neon_FaceMono)
    EndIf
    G\WantFaceSet = -1
  EndIf
  If G\Quit : Quit = #True : EndIf
  Delay(1)
Until Quit
