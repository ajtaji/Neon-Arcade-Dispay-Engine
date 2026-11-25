; sprites.pb - one sprite alone, a sheet's frames, a batch of 2000 copies, particles and a render target.
; Build:  pbcompiler sprites.pb /EXE sprites.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"

#CanvasW = 640 : #CanvasH = 360
#Stars = 2000

; A sheet of four 16 x 16 frames in ONE row, drawn here in code: a dot that moves down its cell.
Procedure.i MakeSheet()
  Protected img.i = CreateImage(#PB_Any, 64, 16, 32, #PB_Image_Transparent), k.i, *s, *png
  If img = 0 : ProcedureReturn 0 : EndIf
  If StartDrawing(ImageOutput(img))
    DrawingMode(#PB_2DDrawing_AllChannels)
    For k = 0 To 3 : Circle(k * 16 + 8, 4 + k * 2, 4, RGBA(255, 200, 40, 255)) : Next
    StopDrawing()
  EndIf
  *png = EncodeImage(img, #PB_ImagePlugin_PNG)        ; LoadGLSpriteMemory takes an encoded picture
  If *png : *s = LoadGLSpriteMemory(*png) : FreeMemory(*png) : EndIf
  FreeImage(img)
  ProcedureReturn *s
EndProcedure

UsePNGImageDecoder() : UsePNGImageEncoder()
GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Sprites", 1280, 720, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)
InitSpriteBatcher()                                   ; once, before the first BeginBatch
InitParticleEngine()                                  ; once, before the first RenderParticles
GL_HandleResize(Gadget)

Define *Sheet.GLSprite = MakeSheet()
Define *Rope.GLSprite = CreateProceduralRopeSprite()
; The batcher and the particles measure against Util_WinWidth / Util_WinHeight (chapter 5), so they
; are drawn into a render target of the canvas's size, where those ARE the target's size.
Define *Sky.GLRenderTarget = GL_CreateRenderTarget(#CanvasW, #CanvasH)
If *Sheet = 0 Or *Sky = 0 : End 1 : EndIf

Dim StarX.f(#Stars - 1) : Dim StarY.f(#Stars - 1)
Define i.i, Quit.i, Event.i, T.f, Last.q = GL_Micros(), Now.q, Dt.f, Frame.i
For i = 0 To #Stars - 1 : StarX(i) = Random(#CanvasW) : StarY(i) = Random(#CanvasH) : Next

Repeat
  Repeat
    Event = WindowEvent()
    If Event = #PB_Event_CloseWindow : Quit = #True : EndIf
    If Event = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until Event = 0
  Now = GL_Micros() : Dt = (Now - Last) / 1000000.0 : Last = Now : T + Dt
  Frame = Int(T * 8) % 4                              ; 8 frames a second
  GL_CameraX = Sin(T * 0.3) * 40                       ; the camera drifts; what applies it follows

  ; 1. the stars and the sparks, into the render target
  GL_BeginRenderTarget(*Sky)
  glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
  BeginBatch(*Sheet)                                  ; 2000 copies of one picture: one draw call
  For i = 0 To #Stars - 1
    AddBatchedSprite(StarX(i), StarY(i), 4, 1, 0, 0.6, 0.7, 1.0, 0.8)
  Next
  EndBatch()
  ClearParticles()                                    ; particles are given afresh every frame
  For i = 0 To 199
    AddParticle(320 + Cos(i + T) * i, 300 + Sin(i * 1.7 + T) * 30, 6, 0, 1.0, 0.4 + i / 400.0, 0.1, 0.9)
  Next
  RenderParticles()
  GL_EndRenderTarget(*Sky)

  ; 2. the canvas
  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.02, 0.02, 0.06, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  DrawGLSprite(@*Sky\Sprite, 0, 0, 0.0, 1.0, 1, 1, 1, 1, #True, -1, -1, -1, -1, #True)   ; the target, as a sprite
  ; one frame of the sheet: SrcX, SrcY, SrcW, SrcH pick a 16 x 16 cell; Scale 4 draws it 64 x 64
  DrawGLSprite(*Sheet, 100, 140, 0.0, 4.0, 1, 1, 1, 1, #True, Frame * 16, 0, 16, 16)
  DrawGLSprite(*Rope, 400, 120, T, 1.0, 1, 1, 1, 1, #True)               ; turning about its centre

  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
GL_FreeRenderTarget(*Sky)
