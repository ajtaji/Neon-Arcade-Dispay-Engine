; chrome.pb - the application kit (GlUIChrome) on a 1:1 canvas: a menu bar, panels, buttons, a text field,
; a tab strip and a list, driven by the mouse and keys, or by a pad through Neon_ChromeBeginNav.
; Build:  pbcompiler chrome.pb /EXE chrome.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
XIncludeFile #Engine$ + "GlUI.pbi"
XIncludeFile #Engine$ + "GlUIChrome.pbi"

#ID_Find = 1 : #ID_Tabs = 2 : #ID_Files = 3

Global Win.i, Gadget.i

; A 1:1 application canvas: one canvas unit is one physical pixel, so a bigger window shows more.
; The three size globals are set here in their three units (chapter 3), and the kit's scale is the
; display's: physical over logical. Returns #True when the scale changed (the fonts are made again).
Procedure.b SizeCanvas()
  Protected pw.i, ph.i, old.f = Neon_UIScale
  Util_WinWidth = WindowWidth(Win, #PB_Window_InnerCoordinate)     ; logical
  Util_WinHeight = WindowHeight(Win, #PB_Window_InnerCoordinate)
  ResizeGadget(Gadget, 0, 0, Util_WinWidth, Util_WinHeight)
  GL_ClientPixels(Win, @pw, @ph)                                    ; physical
  Util_BaseWidth = pw : Util_BaseHeight = ph
  GL_ViewportX = 0 : GL_ViewportY = 0 : GL_ViewportW = pw : GL_ViewportH = ph
  If Util_WinWidth > 0 : Neon_UIScale = pw / Util_WinWidth : EndIf
  ProcedureReturn Bool(Abs(Neon_UIScale - old) > 0.001)
EndProcedure

GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Gadget = OpenGLWindow("Chrome", 900, 560, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Win = Util_MainWindowID
GL_HostScaleRead(Gadget)                           ; Linux: the window's scale into Linux_DPIScale
UI_UseCRT = #False
SizeCanvas()
If Not Neon_UseFaceSet(#NEON_FACES_OPEN, #Engine$ + "assets/fonts/") : Debug Neon_FaceError() : EndIf
If Not Neon_ChromeFonts(Neon_UIScale) : MessageRequester("Chrome", Neon_FaceError()) : End 1 : EndIf

Define Find.String, Caret.i, Tab.i, Closed.i, ListTop.i, Picked.i = -1, Clicks.i, ShowGrid.b = #True
Define Tabs.s = "main.pb|level.ntm|" + Neon_TabEscape("a|b.txt")
Define Event.i, Down.b, Wheel.i, Key.i, Char.i, Ctrl.b, NavAction.i, UsePad.b
Define Pad.GLPadState, PadWas.u, Quit.i, Last.q = GL_Micros(), Now.q, Dt.f, k.i
Repeat
  Wheel = 0 : Key = 0 : Char = 0 : Ctrl = #False
  Repeat
    Event = WindowEvent()
    Select Event
      Case #PB_Event_CloseWindow : Quit = #True
      Case #PB_Event_SizeWindow : If SizeCanvas() : Neon_ChromeFonts(Neon_UIScale) : EndIf
      Case #PB_Event_Menu : If EventMenu() = 1001 : Key = #PB_Shortcut_Escape : EndIf
      Case #PB_Event_Gadget
        UsePad = #False
        Select EventType()
          Case #PB_EventType_LeftButtonDown : Down = #True
          Case #PB_EventType_LeftButtonUp : Down = #False
          Case #PB_EventType_MouseWheel : Wheel + GetGadgetAttribute(Gadget, #PB_OpenGL_WheelDelta)
          Case #PB_EventType_KeyDown
            Key = GetGadgetAttribute(Gadget, #PB_OpenGL_Key)
            Ctrl = Bool(GetGadgetAttribute(Gadget, #PB_OpenGL_Modifiers) & #PB_OpenGL_Control)
          Case #PB_EventType_Input : Char = GetGadgetAttribute(Gadget, #PB_OpenGL_Input)
        EndSelect
    EndSelect
  Until Event = 0
  Now = GL_Micros() : Dt = (Now - Last) / 1000000.0 : Last = Now

  ; a pad's button that went down this frame becomes one navigation action
  NavAction = #NEON_NAV_NONE
  If GL_PadRead(0, @Pad)
    k = Pad\Buttons & ~PadWas : PadWas = Pad\Buttons
    If k & 1 : NavAction = #NEON_NAV_PREV : ElseIf k & 2 : NavAction = #NEON_NAV_NEXT
    ElseIf k & 4 : NavAction = #NEON_NAV_LEFT : ElseIf k & 8 : NavAction = #NEON_NAV_RIGHT
    ElseIf k & $1000 : NavAction = #NEON_NAV_ACTIVATE : ElseIf k & $2000 : NavAction = #NEON_NAV_BACK : EndIf
    If NavAction <> #NEON_NAV_NONE : UsePad = #True : EndIf
  EndIf

  ; the frame: the input snapshot first, then the widgets, the menus last (they draw on top)
  If UsePad
    Neon_ChromeBeginNav(NavAction, Dt)
  Else
    Neon_ChromeBeginFrame(WindowMouseX(Win), WindowMouseY(Win), Down, Wheel, Key, Char, Dt)
    Neon_KeyCtrl = Ctrl                                ; Ctrl+A / C / X / V in the text field
  EndIf
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glDisable_(#GL_SCISSOR_TEST)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  glClearColor_(Neon_C_BgR, Neon_C_BgG, Neon_C_BgB, 1) : glClear_(#GL_COLOR_BUFFER_BIT)

  Define top.f = Neon_S(28)
  Neon_Panel(Neon_S(10), top + Neon_S(10), Neon_S(420), Neon_S(200), "Search",
             Neon_C_AccR, Neon_C_AccG, Neon_C_AccB)
  If Neon_TextInput(#ID_Find, Neon_S(24), top + Neon_S(50), Neon_S(392), Neon_S(28), @Find,
                    "Type and press Return", @Caret)
    Debug "find " + Find\s
  EndIf
  If Neon_Button(Neon_S(24), top + Neon_S(92), Neon_S(120), Neon_S(28), "Clear", #False, Bool(Find\s <> ""))
    Find\s = "" : Caret = 0
  EndIf
  If Neon_Button(Neon_S(156), top + Neon_S(92), Neon_S(120), Neon_S(28), "Count " + Str(Clicks), #True)
    Clicks + 1
  EndIf

  Tab = Neon_TabStrip(#ID_Tabs, Neon_S(440), top + Neon_S(10), Neon_S(440), Neon_S(30), Tabs, Tab, #True, @Closed)
  If Closed >= 0 : Debug "close tab " + Str(Closed) : EndIf
  Neon_ListBegin(#ID_Files, Neon_S(440), top + Neon_S(44), Neon_S(440), Neon_S(300), Neon_S(22), @ListTop)
  If Neon_ListItem("Sources", 0, #False, #True) : EndIf
  For k = 1 To 40
    If Neon_ListItem("file" + Str(k) + ".pb", 1, Bool(Picked = k), #False, Str(k * 37) + " lines")
      Picked = k
    EndIf
  Next
  Neon_ListEnd()

  Neon_MenuBarBegin(0, 0, Util_BaseWidth, top)
  If Neon_MenuBegin("File")
    If Neon_MenuItem("Quit", "Alt+F4") : Quit = #True : EndIf
  EndIf
  Neon_MenuEnd()
  If Neon_MenuBegin("View")
    If Neon_MenuItem("Grid", "", #True, ShowGrid) : ShowGrid ! 1 : EndIf
  EndIf
  Neon_MenuEnd()
  Neon_MenuBarEnd()
  Neon_ChromeEndFrame()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
