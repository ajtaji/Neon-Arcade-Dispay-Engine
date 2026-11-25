; drawlog.pb - checking what a screen drew without comparing pixels: an invisible window for the OpenGL
; context, the draw log started, two widgets drawn, the log printed. Nothing appears on the screen.
; Build:  pbcompiler drawlog.pb /CONSOLE /EXE drawlog.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
XIncludeFile #Engine$ + "GlUI.pbi"
XIncludeFile #Engine$ + "GlUIChrome.pbi"
OpenConsole()

If OpenGLWindow("check", 64, 64, #PB_Window_Invisible) = 0 : PrintN("no OpenGL context") : End 1 : EndIf
Util_BaseWidth = 640 : Util_BaseHeight = 360 : Util_WinWidth = 640 : Util_WinHeight = 360
GL_ViewportX = 0 : GL_ViewportY = 0 : GL_ViewportW = 640 : GL_ViewportH = 360
UI_UseCRT = #False
*Neon_FontUI = CreateGLFontFixed("Consolas", 12, 0, 8)            ; a face whose advance is a round 8
*Neon_FontUI\LineHeight = 16                                       ; and its line 16: every width is exact
*Neon_FontSmall = *Neon_FontUI

Define Text.String
Text\s = "abc"
GL_DrawLogStart()
Neon_ChromeBeginFrame(-1000, -1000, #False, 0, 0, 0, 1 / 60)       ; the pointer nowhere
Neon_Button(10, 10, 100, 24, "OK")
Neon_TextInput(1, 10, 40, 200, 24, @Text)
Neon_ChromeEndFrame()
GL_DrawLogStop()

Define k.s
ForEach GL_DrawLog()
  Select GL_DrawLog()\Kind
    Case #GL_LOG_BOX : k = "box"
    Case #GL_LOG_TEXT : k = "text " + Chr(34) + GL_DrawLog()\Text + Chr(34)
    Case #GL_LOG_POLY : k = "poly"
    Case #GL_LOG_CLIP : k = "clip"
    Case #GL_LOG_NOCLIP : k = "noclip"
  EndSelect
  PrintN(k + " at " + StrF(GL_DrawLog()\X, 1) + ", " + StrF(GL_DrawLog()\Y, 1) +
         " size " + StrF(GL_DrawLog()\W, 1) +
         " x " + StrF(GL_DrawLog()\H, 1) + " clip " + Str(GL_DrawLog()\Clip))
Next
PrintN(Str(ListSize(GL_DrawLog())) + " primitives")
