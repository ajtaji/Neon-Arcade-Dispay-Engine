; layers.pb - a far layer, a near layer and a sprite layer at three parallax speeds, a fixed status
; layer, and a hero that walks on the near layer by the collision queries.
; Build:  pbcompiler layers.pb /EXE layers.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"
XIncludeFile #Engine$ + "GlTiles.pbi"
XIncludeFile #Engine$ + "GlLayers.pbi"

#CanvasW = 320 : #CanvasH = 240
#Hill = 0 : #Ground = 1 : #Coin = 2

Procedure.i SheetFromImage(img.i)                   ; a PureBasic image -> a GLSprite
  Protected *png = EncodeImage(img, #PB_ImagePlugin_PNG), *s
  If *png : *s = LoadGLSpriteMemory(*png) : FreeMemory(*png) : EndIf
  FreeImage(img)
  ProcedureReturn *s
EndProcedure

UsePNGImageDecoder() : UsePNGImageEncoder()
GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Layers", 960, 720, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)
InitSpriteBatcher()
GL_HandleResize(Gadget)

Define img.i = CreateImage(#PB_Any, 48, 16, 32, #PB_Image_Transparent)
If StartDrawing(ImageOutput(img))
  DrawingMode(#PB_2DDrawing_AllChannels)
  Box(0, 0, 16, 16, RGBA(70, 60, 110, 255)) : Box(16, 0, 16, 16, RGBA(110, 80, 50, 255))
  Box(16, 0, 16, 4, RGBA(80, 180, 70, 255)) : Circle(40, 8, 5, RGBA(240, 200, 40, 255))
  StopDrawing()
EndIf
Define *Sheet.GLSprite = SheetFromImage(img)
img = CreateImage(#PB_Any, 12, 20, 32)
If StartDrawing(ImageOutput(img)) : Box(0, 0, 12, 20, RGB(220, 60, 60)) : StopDrawing() : EndIf
Define *HeroPic.GLSprite = SheetFromImage(img)

Define *Set.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16)
GL_TileSetCollision(*Set, #Ground, #GL_TILE_SOLID)
Define *Far.GLTileMap = GL_TileMapCreate(60, 15, *Set)
Define *Near.GLTileMap = GL_TileMapCreate(200, 15, *Set)
Define *Status.GLTileMap = GL_TileMapCreate(5, 1, *Set)
Define x.i
For x = 0 To 59 : GL_TileMapFill(*Far, x, 8 + (x / 3) % 3, 1, 7, #Hill) : Next
For x = 0 To 199 : GL_TileMapFill(*Near, x, 12 - Bool(x % 16 > 11), 1, 4, #Ground) : Next
GL_TileMapFill(*Status, 0, 0, 5, 1, #Coin)

Define *World.GLLayers = GL_LayersCreate()
Define *FarL.GLLayer = GL_LayerAddTiles(*World, *Far, 0)
Define *NearL.GLLayer = GL_LayerAddTiles(*World, *Near, 1)
Define *Actors.GLLayer = GL_LayerAddSprites(*World, 2)
Define *StatusL.GLLayer = GL_LayerAddTiles(*World, *Status, 9)
*FarL\ParallaxX = 0.3 : *FarL\TintR = 0.7 : *FarL\TintG = 0.7          ; far away: slower and darker
*StatusL\Fixed = #True : *StatusL\X = 4 : *StatusL\Y = 4 : *StatusL\Opacity = 0.8
Define *Hero.GLLayerSprite = GL_LayerSpriteAdd(*Actors, *HeroPic, 40, 0)

NewList Hits.GLTileHit()
Define Quit.i, Event.i, Last.q = GL_Micros(), Now.q, Dt.f, VY.f
Repeat
  Repeat
    Event = WindowEvent()
    If Event = #PB_Event_CloseWindow : Quit = #True : EndIf
    If Event = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until Event = 0
  Now = GL_Micros() : Dt = (Now - Last) / 1000000.0 : Last = Now
  If Dt > 0.1 : Dt = 0.1 : EndIf
  If GL_KeyHeld(#PB_Shortcut_Right) : *Hero\X + 90 * Dt : EndIf
  If GL_KeyHeld(#PB_Shortcut_Left) : *Hero\X - 90 * Dt : EndIf
  VY + 500 * Dt : *Hero\Y + VY * Dt                                       ; gravity
  ; the near layer's origin is 0,0 and its parallax 1, so the hero's layer coordinates are world coordinates
  If CheckCollisionLayerBox(*NearL, *Hero\X, *Hero\Y, 12, 20, Hits())
    ForEach Hits()
      If Hits()\Blocks And *Hero\Y + 20 > Hits()\Row * 16 : *Hero\Y = Hits()\Row * 16 - 20 : VY = 0 : EndIf
    Next
  EndIf
  GL_CameraX = *Hero\X - #CanvasW / 3

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.1, 0.12, 0.25, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  GL_LayersDraw(*World, #True)                                            ; back to front
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
GL_LayersFree(*World)
