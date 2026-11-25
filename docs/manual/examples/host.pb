; host.pb - the host services in a window: held keys, pads and other controllers, full screen on the
; window's monitor, the pointer hidden, a beep through the sound output.
; Build:  pbcompiler host.pb /EXE host.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"

#Rate = 48000 : #Pairs = 1024 : #Buffers = 4         ; 4 buffers of 1024 stereo pairs: about 85 ms queued

GL_HostPrepare()
GL_NoPowerThrottling()                               ; keep full speed behind other windows (Windows 11)
GL_TimerFine(#True)                                  ; Delay(1) waits about 1 ms
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Host services", 800, 450, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Define Win.i = Util_MainWindowID
GL_HostScaleRead(Gadget)
Util_BaseWidth = 800 : Util_BaseHeight = 450
InitRetroCRT(800, 450)
GL_HandleResize(Gadget)
Define *Font.GLFont = CreateGLFontPx("Segoe UI", 18)
Define HaveSound.i = GL_AudioOpen(#Rate, #Pairs, #Buffers), Phase.f, Beep.i, *B, i.i, v.w
Debug "cores " + Str(GL_PhysicalCores()) + ", sound " + GL_AudioDriver

Define Pad.GLPadState, Joy.GLJoyState, Quit.i, Event.i, Line.s, Key.i
Repeat
  Repeat
    Event = WindowEvent()
    Select Event
      Case #PB_Event_CloseWindow : Quit = #True
      Case #PB_Event_SizeWindow : GL_HandleResize(Gadget)
      Case #PB_Event_Gadget
        If EventType() = #PB_EventType_KeyDown
          Key = GL_KeyEventCode(GetGadgetAttribute(Gadget, #PB_OpenGL_Key))
          If Key = #PB_Shortcut_F11
            If GL_FullscreenIsOn() : GL_FullscreenLeave(Win) : Else : GL_FullscreenEnter(Win) : EndIf
            GL_CursorShow(Win, Gadget, Bool(Not GL_FullscreenIsOn()))
          ElseIf Key = #PB_Shortcut_B
            Beep = #Rate / 4                              ; a quarter of a second
          EndIf
        EndIf
    EndSelect
  Until Event = 0

  ; sound: fill every buffer the output has free (16-bit stereo, left then right)
  If HaveSound
    *B = GL_AudioNext()
    While *B
      For i = 0 To #Pairs - 1
        v = 0
        If Beep > 0 : v = Sin(Phase) * 6000 : Phase + 2 * #PI * 440 / #Rate : Beep - 1 : EndIf
        PokeW(*B + i * 4, v) : PokeW(*B + i * 4 + 2, v)
      Next
      GL_AudioPlay(*B)
      *B = GL_AudioNext()
    Wend
  EndIf

  GL_KeysSnapshot()                                  ; one read of the whole keyboard for this frame
  Line = "Shift " + Str(GL_KeySnap(#GL_Key_Shift)) + "  Space " + Str(GL_KeySnap(#PB_Shortcut_Space))
  If GL_PadRead(0, @Pad)
    Line + "   pad 0: buttons $" + Hex(Pad\Buttons) + " left stick " + Str(Pad\LX) + ", " + Str(Pad\LY)
    GL_PadRumble(0, Pad\RT * 257)                     ; the right trigger drives the motors
  ElseIf GL_JoyRead(0, @Joy)
    Line + "   " + Joy\Name + ": buttons $" + Hex(Joy\Buttons) + " x " + Str(Joy\Axis[0])
  EndIf

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.05, 0.06, 0.08, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  DrawGLText(*Font, 20, 20, "F11 full screen, B beeps (" + GL_AudioDriver + ")", 0.9, 0.9, 0.9, 1, #True)
  DrawGLText(*Font, 20, 50, Line, 0.5, 0.9, 0.6, 1, #True)
  Line = "Escape is " + GL_KeyName(#PB_Shortcut_Escape) + " on this keyboard"
  DrawGLText(*Font, 20, 80, Line, 0.7, 0.7, 0.7, 1, #True)
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
GL_PadRumble(0, 0)
GL_AudioClose()
GL_TimerFine(#False)
