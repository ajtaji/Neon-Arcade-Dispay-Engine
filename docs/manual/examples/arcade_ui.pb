; arcade_ui.pb - the arcade kit (GlUI): a menu screen of gadgets driven by the mouse, the keys or a pad.
; Build:  pbcompiler arcade_ui.pb /EXE arcade_ui.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
XIncludeFile #Engine$ + "GlUI.pbi"

Enumeration Gadgets 1
  #Title : #Start : #Volume : #Music : #Level : #Dips : #Mode
EndEnumeration
Global Quit.i, *LevelMeter.NeonGadget

; Called from inside Neon_UpdateInput; the list's current element is the gadget that fired.
Procedure OnGadget(GadgetID.i, EventType.i)
  Select GadgetID
    Case #Start  : Quit = #True
    Case #Volume : *LevelMeter\Value = UI_Gadgets()\Value        ; the meter shows the slider's value
    Case #Music  : Debug "music " + Str(UI_Gadgets()\IsActive)
    Case #Dips   : Debug "switches %" + Bin(UI_Gadgets()\IsActive, #PB_Byte)
    Case #Mode   : Debug "mode " + StringField(UI_Gadgets()\Text, Int(UI_Gadgets()\Value) + 1, "|")
  EndSelect
EndProcedure

GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Arcade UI", 1280, 720, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #NEON_BASE_W : Util_BaseHeight = #NEON_BASE_H   ; the kit is laid out for 1280 x 720
InitRetroCRT(#NEON_BASE_W, #NEON_BASE_H)
GL_HandleResize(Gadget)
UI_UseCRT = #False                                                ; presented with DrawPassthrough, not the CRT

; set the font BEFORE adding: a gadget keeps the font it was added with
UI_ActiveFont = CreateGLFontPx("Segoe UI", 24, #PB_Font_Bold)
Neon_AddLabel(#Title, 80, 60, "OPTIONS")
Neon_AddButton(#Start, 80, 160, 220, 50, "START", #STYLE_MODERN, @OnGadget())
Neon_AddSlider(#Volume, 440, 180, 320, 30, 0.5, "VOLUME", @OnGadget())
Neon_AddToggle(#Music, 440, 250, 320, 40, "MUSIC", #True, @OnGadget())
*LevelMeter = Neon_AddMeter(#Level, 440, 360, 320, 30, 0.5, "LEVEL")
Neon_AddDipBank(#Dips, 820, 200, 8, %00001111, "DIP SWITCHES", @OnGadget())
Neon_AddCarousel(#Mode, 820, 360, 380, 50, "EASY|NORMAL|HARD", 1, @OnGadget())

Define Event.i, Down.b, WasDown.b, Key.i, DX.i, DY.i, Act.b, Last.q = GL_Micros(), Now.q
Define Pad.GLPadState, PadWas.u
Repeat
  Key = 0
  Repeat
    Event = WindowEvent()
    Select Event
      Case #PB_Event_CloseWindow : Quit = #True
      Case #PB_Event_SizeWindow : GL_HandleResize(Gadget)
      Case #PB_Event_Gadget
        Select EventType()
          Case #PB_EventType_LeftButtonDown : Down = #True
          Case #PB_EventType_LeftButtonUp : Down = #False
          Case #PB_EventType_KeyDown : Key = GetGadgetAttribute(Gadget, #PB_OpenGL_Key)
        EndSelect
    EndSelect
  Until Event = 0
  ; the D-pad: from the keys, or from pad 0 on the frame a button goes down
  DX = 0 : DY = 0 : Act = #False
  Select Key
    Case #PB_Shortcut_Up : DY = -1
    Case #PB_Shortcut_Down : DY = 1
    Case #PB_Shortcut_Left : DX = -1
    Case #PB_Shortcut_Right : DX = 1
    Case #PB_Shortcut_Return, #PB_Shortcut_Space : Act = #True
  EndSelect
  If GL_PadRead(0, @Pad)
    If Pad\Buttons & ~PadWas & 1 : DY = -1 : EndIf               ; D-pad up
    If Pad\Buttons & ~PadWas & 2 : DY = 1 : EndIf                ; down
    If Pad\Buttons & ~PadWas & 4 : DX = -1 : EndIf               ; left
    If Pad\Buttons & ~PadWas & 8 : DX = 1 : EndIf                ; right
    If Pad\Buttons & ~PadWas & $1000 : Act = #True : EndIf       ; A
    PadWas = Pad\Buttons
  EndIf
  ; the pointer as the window gives it (physical pixels on Windows), and the button's edges
  Neon_UpdateInput(WindowMouseX(Util_MainWindowID), WindowMouseY(Util_MainWindowID),
                   Bool(Down And Not WasDown), Bool(WasDown And Not Down), DX, DY, Act)
  WasDown = Down
  Now = GL_Micros()

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.02, 0.02, 0.05, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  Neon_DrawUI((Now - Last) / 1000000.0) : Last = Now
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
