; tilemap.pb - a tile sheet made in code, a scrolling map drawn through the camera, an animated tile.
; Build:  pbcompiler tilemap.pb /EXE tilemap.exe /THREAD /DPIAWARE
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"
XIncludeFile #Engine$ + "GlTiles.pbi"

#CanvasW = 320 : #CanvasH = 240

; Four 16 x 16 tiles in a row: sky, grass, water A, water B.
Procedure.i MakeSheet()
  Protected img.i = CreateImage(#PB_Any, 64, 16, 32), *png, *s
  If img = 0 : ProcedureReturn 0 : EndIf
  If StartDrawing(ImageOutput(img))
    Box(0, 0, 16, 16, RGB(40, 60, 140))
    Box(16, 0, 16, 16, RGB(60, 150, 50)) : Box(16, 0, 16, 3, RGB(120, 220, 90))
    Box(32, 0, 16, 16, RGB(30, 90, 200)) : Box(48, 0, 16, 16, RGB(50, 120, 230))
    Line(32, 5, 16, 1, RGB(200, 230, 255)) : Line(48, 10, 16, 1, RGB(200, 230, 255))
    StopDrawing()
  EndIf
  *png = EncodeImage(img, #PB_ImagePlugin_PNG)
  If *png : *s = LoadGLSpriteMemory(*png) : FreeMemory(*png) : EndIf
  FreeImage(img)
  ProcedureReturn *s
EndProcedure

UsePNGImageDecoder() : UsePNGImageEncoder()
GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("Tile map", 960, 720, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)
GL_HandleResize(Gadget)

Define *Sheet.GLSprite = MakeSheet()
Define *Set.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16)
If *Set = 0 : MessageRequester("Tile map", GL_TileError()) : End 1 : EndIf
GL_TileSetAnimAdd(*Set, 2, 2, 250) : GL_TileSetAnimAdd(*Set, 2, 3, 250)   ; water: tiles 2 and 3, 250 ms each

Define *Map.GLTileMap = GL_TileMapCreate(200, 15, *Set)                   ; 3200 x 240 world pixels
Define x.i
GL_TileMapFill(*Map, 0, 0, 200, 15, 0)                                     ; sky everywhere
For x = 0 To 199
  If x % 20 >= 14
    GL_TileMapFill(*Map, x, 12, 1, 3, 2)                                   ; a pool every 20 cells
  Else
    GL_TileMapFill(*Map, x, 11 + (x / 7) % 2, 1, 4, 1)                     ; grass, up and down a step
  EndIf
Next

Define Quit.i, Event.i, Calls.i, Last.q = GL_Micros(), Now.q
Repeat
  Repeat
    Event = WindowEvent()
    If Event = #PB_Event_CloseWindow : Quit = #True : EndIf
    If Event = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until Event = 0
  Now = GL_Micros()
  GL_CameraX + (Now - Last) / 1000000.0 * 80 : Last = Now                   ; scroll 80 world pixels a second
  If GL_CameraX > 200 * 16 - #CanvasW : GL_CameraX = 0 : EndIf

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  Calls = GL_TileMapDraw(*Map, 0, 0, 1, 1, 1, 1, #True)                    ; only the cells in view: one call
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
GL_TileMapFree(*Map) : GL_TileSetFree(*Set)
