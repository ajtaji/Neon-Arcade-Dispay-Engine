; text.pb - fonts by pixel height, a fixed-advance font, measuring, Unicode, and the open typefaces.
; Build:  pbcompiler text.pb /EXE text.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
XIncludeFile #Engine$ + "GlUI.pbi"
XIncludeFile #Engine$ + "GlUIChrome.pbi"            ; for Neon_SetFaces / Neon_UseFaceSet

#CanvasW = 960 : #CanvasH = 540

GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Text", 960, 540, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)
GL_HandleResize(Gadget)

; The open typefaces from the engine's assets/fonts folder: registered for this process, then named.
If Not Neon_UseFaceSet(#NEON_FACES_OPEN, #Engine$ + "assets/fonts/")
  Debug Neon_FaceError()                             ; the reason; the faces stay Segoe UI and Consolas
EndIf
Define *Title.GLFont = CreateGLFontPx(Neon_FaceUI, 32)          ; 32 canvas pixels, at any desktop scale
Define *Body.GLFont = CreateGLFontPx(Neon_FaceUI, 18)
Define *Code.GLFont = CreateGLFontFixedPx(Neon_FaceMono, 16)    ; every glyph the same whole width
If *Title = 0 Or GLFontLineHeight(*Body) = 0 : End 1 : EndIf     ; a face that did not load draws nothing

Define Line.s = "Unicode: caf" + Chr($E9) + ", " + Chr($3B1) + Chr($3B2) + Chr($3B3) +
                ", arrows " + Chr($2190) + Chr($2192)
Define Quit.i, Event.i, W.f, Col.i
Repeat
  Repeat
    Event = WindowEvent()
    If Event = #PB_Event_CloseWindow : Quit = #True : EndIf
    If Event = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until Event = 0
  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.06, 0.07, 0.09, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)

  DrawGLText(*Title, 40, 30, "Neon Arcade", 0.35, 0.75, 0.82, 1.0, #True)
  W = GetGLTextWidth(*Title, "Neon Arcade")                      ; the width DrawGLText just covered
  DrawGLBox(40, 30 + GLFontLineHeight(*Title), W, 2, 0.35, 0.75, 0.82, 1.0, #True, #True)
  DrawGLText(*Body, 40, 100, Line, 0.9, 0.9, 0.9, 1.0, #True)
  DrawGLText(*Body, 40, 130, "A glyph the face lacks is drawn as a box: " + Chr($E000), 0.9, 0.6, 0.3, 1.0, #True)
  DrawGLText(*Code, 40, 180, "column 0123456789", 0.4, 0.9, 0.5, 1.0, #True)
  Col = GLTextColumnForX(*Code, "column 0123456789", 7.4 * GLFontFixedAdvance(*Code))   ; the column under x
  DrawGLText(*Code, 40, 204, "x at column 7.4 is column " + Str(Col), 0.6, 0.6, 0.6, 1.0, #True)

  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
FreeGLFont(*Title) : FreeGLFont(*Body) : FreeGLFont(*Code)
