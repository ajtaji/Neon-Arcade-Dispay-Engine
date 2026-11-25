; first_program.pb - the smallest complete program: a window, a 320 x 240 canvas, a box and a sprite.
; Build:  pbcompiler first_program.pb /EXE first_program.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"        ; the folder that holds GlTypes.pbi
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"

#CanvasW = 320 : #CanvasH = 240
UsePNGImageDecoder()

GL_HostPrepare()                                       ; before any window
Define Gadget.i = OpenGLWindow("First program", 960, 720,
                               #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget)
If Gadget = 0 : MessageRequester("First program", "No OpenGL window could be opened.") : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH  ; the authored canvas
InitRetroCRT(#CanvasW, #CanvasH)                       ; the canvas framebuffer and the two presentation shaders
GL_HandleResize(Gadget)                                ; the letterbox for the window's size now

; A picture from a file; when the file is not there, the engine's built-in procedural sprite.
Define *Hero.GLSprite = LoadGLSprite("hero.png")
If *Hero = 0 : *Hero = CreateProceduralRopeSprite() : EndIf

Define Quit.i, Event.i, Angle.f, Last.q = GL_Micros(), Now.q, Dt.f
Repeat
  Repeat                                               ; every pending window event, then one frame
    Event = WindowEvent()
    Select Event
      Case #PB_Event_CloseWindow : Quit = #True
      Case #PB_Event_SizeWindow  : GL_HandleResize(Gadget)
      Case #PB_Event_Menu        : If EventMenu() = 1001 : Quit = #True : EndIf   ; Escape
    EndSelect
  Until Event = 0
  Now = GL_Micros() : Dt = (Now - Last) / 1000000.0 : Last = Now
  Angle + Dt                                           ; one radian a second

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)         ; draw into the canvas
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.05, 0.05, 0.12, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  DrawGLBox(16, 16, 288, 8, 0.2, 0.8, 1.0, 1.0, #True, #True)
  DrawGLSprite(*Hero, 144, 88, Angle, 1.0, 1, 1, 1, 1, #True)

  glBindFramebuffer(#GL_FRAMEBUFFER, 0)                ; then show the canvas in the window
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
