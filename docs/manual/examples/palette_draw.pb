; palette_draw.pb - one indexed picture drawn with three palettes, a palette cycled by the clock, a fade.
; Build:  pbcompiler palette_draw.pb /EXE palette_draw.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"
XIncludeFile #Engine$ + "GlTiles.pbi"

#CanvasW = 320 : #CanvasH = 180

GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Palettes", 960, 540, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)
GL_HandleResize(Gadget)
If Not GL_PaletteInit() : MessageRequester("Palettes", GL_PaletteError()) : End 1 : EndIf

; a 32 x 32 picture of rings, colour numbers 1 .. 8 (0, the corners, transparent)
Define *Rings.GLIndexedImage = GL_IndexedCreate(32, 32), x.i, y.i, d.f
For y = 0 To 31 : For x = 0 To 31
  d = Sqr((x - 15.5) * (x - 15.5) + (y - 15.5) * (y - 15.5))
  If d < 16 : GL_IndexedSet(*Rings, x, y, 1 + Int(d / 2)) : EndIf
Next : Next
Define *Warm.GLPalette = GL_PaletteCreate(9), *Cold.GLPalette = GL_PaletteCreate(9)
Define *Grey.GLPalette = GL_PaletteCreate(9)
GL_PaletteSet(*Warm, 0, RGBA(0, 0, 0, 0)) : GL_PaletteSet(*Cold, 0, RGBA(0, 0, 0, 0))
GL_PaletteSet(*Grey, 0, RGBA(0, 0, 0, 0))
For x = 1 To 8
  GL_PaletteSet(*Warm, x, RGBA(255, 30 * x, 0, 255))
  GL_PaletteSet(*Cold, x, RGBA(0, 30 * x, 255, 255))
  GL_PaletteSet(*Grey, x, RGBA(30 * x, 30 * x, 30 * x, 255))
Next
GL_IndexedPalette(*Rings, 0, *Warm)                     ; the picture's own palette, in slot 0

Define Quit.i, Event.i, Ms.q, Dusk.f
Repeat
  Repeat
    Event = WindowEvent()
    If Event = #PB_Event_CloseWindow : Quit = #True : EndIf
    If Event = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until Event = 0
  Ms = GL_Micros() / 1000
  Dusk = (Sin(Ms / 1000.0) + 1) / 2 * 0.6
  ; each frame: back to the colours as set, then the operations, in order
  GL_PaletteReset(*Warm) : GL_PaletteCycleTime(*Warm, 1, 8, 90, Ms)
  GL_PaletteReset(*Cold) : GL_PaletteFade(*Cold, RGBA(0, 0, 0, 255), Dusk)

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.05, 0.05, 0.08, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  GL_IndexedDraw(*Rings, 40, 60, 0, 0, 0.0, 2.0, 1, 1, 1, 1, #True)          ; slot 0: the cycling warm rings
  GL_IndexedDraw(*Rings, 130, 60, *Cold, 0, 0.0, 2.0, 1, 1, 1, 1, #True)     ; the same picture, another palette
  GL_IndexedDraw(*Rings, 220, 60, *Grey, 0, Ms / 500.0, 2.0, 1, 1, 1, 1, #True)
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
GL_IndexedFree(*Rings)
GL_PaletteFree(*Warm) : GL_PaletteFree(*Cold) : GL_PaletteFree(*Grey)
GL_PaletteShutdown()
