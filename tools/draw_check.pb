; Drawing read back from an INVISIBLE window (#PB_Window_Invisible; nothing is
; shown on the screen): tile maps drawn through the camera into a render
; target, every pixel compared with a CPU reference that walks from the pixel
; back to the sheet; layers with parallax, opacity, a turned sprite and a
; screen-fixed layer; draw calls counted.
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlFile.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlSpriteFunctions.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlTiles.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlLayers.pbi"
OpenConsole()

Global Checks.i
Procedure Check(ok.i, message.s)
  Checks + 1
  If Not ok : PrintN("FAIL " + message) : End 1 : EndIf
EndProcedure

#W = 160 : #H = 120
Global *Pixels = AllocateMemory(#W * #H * 4)

; Read the target back; Pixel(x, y) with y counted from the TOP of the picture.
Procedure ReadBack()
  glPixelStorei_(#GL_PACK_ALIGNMENT, 1)
  glReadPixels_(0, 0, #W, #H, #GL_RGBA, #GL_UNSIGNED_BYTE, *Pixels)
EndProcedure
Procedure.l Pixel(x.i, y.i)
  ProcedureReturn PeekL(*Pixels + ((#H - 1 - y) * #W + x) * 4)
EndProcedure

; The sheet: 4 x 2 tiles of 16 x 16; every pixel a different colour.
Procedure.l SheetColour(ix.i, iy.i)
  ProcedureReturn RGBA(ix * 4, iy * 8, 200, 255)
EndProcedure

Define Gadget.i = OpenGLWindow("neon draw check", 64, 64, #PB_Window_Invisible)
Check(Bool(Gadget), "an OpenGL context in an invisible window")
PrintN("GL " + PeekS(glGetString_(#GL_VERSION), -1, #PB_UTF8))
InitSpriteBatcher()
glDisable_(#GL_SCISSOR_TEST)

Define img.i = CreateImage(#PB_Any, 64, 32, 32), x.i, y.i
StartDrawing(ImageOutput(img))
DrawingMode(#PB_2DDrawing_AllChannels)
For y = 0 To 31 : For x = 0 To 63 : Plot(x, y, SheetColour(x, y)) : Next : Next
StopDrawing()
Define *Sheet.GLSprite = Internal_ProcessGLSprite(img)
Define *Set.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16)
Check(Bool(*Set And *Set\Count = 8), "sheet cut into 8 tiles")
GL_TileSetAnimAdd(*Set, 7, 2, 100) : GL_TileSetAnimAdd(*Set, 7, 5, 100)

Define *Map.GLTileMap = GL_TileMapCreate(30, 20, *Set)
RandomSeed(7)
For y = 0 To 19 : For x = 0 To 29
  If Random(9) > 0 : GL_TileMapSet(*Map, x, y, Random(7), Random(7) << 10) : EndIf
Next : Next

Define *Target.GLRenderTarget = GL_CreateRenderTarget(#W, #H, #False)
Check(Bool(*Target), "a render target")

; CPU reference: the colour of the map placed at MapX, MapY at world point wx, wy.
Procedure.l RefWorld(*Map.GLTileMap, MapX.f, MapY.f, wx.f, wy.f, Ms.q)
  Protected cx.i = Round((wx - MapX) / 16.0, #PB_Round_Down), cy.i = Round((wy - MapY) / 16.0, #PB_Round_Down)
  Protected s.f, t.f, tile.i, flags.i, sx.i, sy.i
  If cx < 0 Or cy < 0 Or cx >= *Map\Width Or cy >= *Map\Height : ProcedureReturn 0 : EndIf
  tile = GL_TileMapGet(*Map, cx, cy) : flags = GL_TileMapFlags(*Map, cx, cy)
  If tile < 0 : ProcedureReturn 0 : EndIf
  tile = GL_TileSetAnimFrame(*Map\Set, tile, Ms)
  s = (wx - MapX) / 16.0 - cx : t = (wy - MapY) / 16.0 - cy
  If flags & #GL_TILE_FLIPY : t = 1.0 - t : EndIf
  If flags & #GL_TILE_FLIPX : s = 1.0 - s : EndIf
  If flags & #GL_TILE_DIAG : Swap s, t : EndIf
  GL_TileSetSource(*Map\Set, tile, @sx, @sy)
  ProcedureReturn SheetColour(sx + Int(s * 16.0), sy + Int(t * 16.0))
EndProcedure

; The world point under the centre of canvas pixel px, py, through the camera.
Procedure.f WorldX(px.i)
  ProcedureReturn (px + 0.5 - #W / 2.0) / GL_CameraZoom + GL_CameraX + #W / 2.0
EndProcedure
Procedure.f WorldY(py.i)
  ProcedureReturn (py + 0.5 - #H / 2.0) / GL_CameraZoom + GL_CameraY + #H / 2.0
EndProcedure

; CPU reference for one pixel of the map placed at MapX, MapY at time Ms.
Procedure.l RefPixel(*Map.GLTileMap, MapX.f, MapY.f, px.i, py.i, Ms.q)
  ProcedureReturn RefWorld(*Map, MapX, MapY, WorldX(px), WorldY(py), Ms)
EndProcedure

Procedure.i CheckMapPixels(*Map.GLTileMap, MapX.f, MapY.f, T.q, Name.s)
  Protected x.i, y.i, bad.i, first.s
  For y = 0 To #H - 1 : For x = 0 To #W - 1
    If Pixel(x, y) <> RefPixel(*Map, MapX, MapY, x, y, T)
      If bad = 0 : first = " first at " + Str(x) + "," + Str(y) + " got $" + Hex(Pixel(x, y) & $FFFFFFFF) + " want $" + Hex(RefPixel(*Map, MapX, MapY, x, y, T) & $FFFFFFFF) : EndIf
      bad + 1
    EndIf
  Next : Next
  Check(Bool(bad = 0), Name + ": " + Str(bad) + " pixels differ from the CPU reference" + first)
  ProcedureReturn bad
EndProcedure

Structure CamCase : X.f : Y.f : Z.f : T.q : EndStructure
Dim Cases.CamCase(5)
Cases(0)\X = 0 : Cases(0)\Y = 0 : Cases(0)\Z = 1 : Cases(0)\T = 0
Cases(1)\X = 37 : Cases(1)\Y = 21 : Cases(1)\Z = 1 : Cases(1)\T = 150
Cases(2)\X = -13 : Cases(2)\Y = -9 : Cases(2)\Z = 2 : Cases(2)\T = 50
Cases(3)\X = 100.3 : Cases(3)\Y = 50.6 : Cases(3)\Z = 1 : Cases(3)\T = 0
Cases(4)\X = 55 : Cases(4)\Y = 33 : Cases(4)\Z = 3 : Cases(4)\T = 199
Cases(5)\X = 300 : Cases(5)\Y = 200 : Cases(5)\Z = 1 : Cases(5)\T = 0
Define i.i, draws.i, before.q
For i = 0 To 5
  GL_BeginRenderTarget(*Target)
  glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
  GL_CameraX = Cases(i)\X : GL_CameraY = Cases(i)\Y : GL_CameraZoom = Cases(i)\Z
  before = GL_StatDrawCalls
  draws = GL_TileMapDraw(*Map, 8, 4, 1, 1, 1, 1, #True, #False, Cases(i)\T)
  ReadBack()
  GL_EndRenderTarget(*Target)
  Check(Bool(draws = 1 And GL_StatDrawCalls - before = 1), "camera case " + Str(i) + ": one draw call (" + Str(draws) + ")")
  CheckMapPixels(*Map, 8, 4, Cases(i)\T, "camera case " + Str(i))
Next

; tint and opacity: half-transparent red tint over a cleared (0,0,0,0) target
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
GL_CameraX = 0 : GL_CameraY = 0 : GL_CameraZoom = 1
GL_TileMapFill(*Map, 0, 0, 30, 20, 0)
GL_TileMapDraw(*Map, 0, 0, 1.0, 0.0, 0.0, 1.0, #True, #False, 0)
ReadBack()
GL_EndRenderTarget(*Target)
Check(Bool(Red(Pixel(5, 3)) = 5 * 4 And Green(Pixel(5, 3)) = 0 And Blue(Pixel(5, 3)) = 0), "tint multiplies the tile colour")

; a zoomed-out view of a big map: more than one batch of 10000 quads
Define *Huge.GLTileMap = GL_TileMapCreate(400, 300, *Set), Rg.GLTileRange, visible.i
GL_TileMapFill(*Huge, 0, 0, 400, 300, 1)
GL_CameraX = 2000 : GL_CameraY = 1500 : GL_CameraZoom = 0.04
GL_BeginRenderTarget(*Target)
visible = GL_TileMapRange(*Huge, 0, 0, @Rg, #True)
before = GL_StatDrawCalls
draws = GL_TileMapDraw(*Huge, 0, 0, 1, 1, 1, 1, #True, #False, 0)
GL_EndRenderTarget(*Target)
Check(Bool(visible > 10000 And draws = (visible + 9999) / 10000 And GL_StatDrawCalls - before = draws), Str(visible) + " visible tiles drawn in " + Str(draws) + " calls of up to 10000")

; ------------------------------------------------------------------ layers
; back: the map with parallax 0.5 / 0.25 and a scroll; middle: a sprite layer,
; half transparent, one sprite flipped top to bottom; front: a 3-tile map
; fixed to the screen. Camera at 30, 12, zoom 1.
GL_TileMapFill(*Map, 0, 0, 30, 20, #GL_TILE_EMPTY)
RandomSeed(9)
For y = 0 To 19 : For x = 0 To 29
  If Random(9) > 0 : GL_TileMapSet(*Map, x, y, Random(6), Random(7) << 10) : EndIf
Next : Next
Define *Ui.GLTileMap = GL_TileMapCreate(3, 1, *Set)
GL_TileMapSet(*Ui, 0, 0, 1) : GL_TileMapSet(*Ui, 1, 0, 2, #GL_TILE_ROT90) : GL_TileMapSet(*Ui, 2, 0, 3)
Define *Stack.GLLayers = GL_LayersCreate()
Define *Ui_L.GLLayer = GL_LayerAddTiles(*Stack, *Ui, 9)
Define *Back.GLLayer = GL_LayerAddTiles(*Stack, *Map, -1)
Define *Mid.GLLayer = GL_LayerAddSprites(*Stack, 4)
*Back\ParallaxX = 0.5 : *Back\ParallaxY = 0.25 : *Back\ScrollX = 3
*Mid\Opacity = 0.5
Define *Spr.GLLayerSprite = GL_LayerSpriteAdd(*Mid, *Sheet, 40, 20)
*Spr\Orient = #GL_TILE_FLIPY
*Ui_L\Fixed = #True : *Ui_L\X = 2 : *Ui_L\Y = 2
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
GL_CameraX = 30 : GL_CameraY = 12 : GL_CameraZoom = 1
before = GL_StatDrawCalls
draws = GL_LayersDraw(*Stack, #True, 0)
ReadBack()
GL_EndRenderTarget(*Target)
Check(Bool(draws = 3 And GL_StatDrawCalls - before = 3), "three layers, three draw calls (" + Str(draws) + ")")
Define bad.i, first.s, bx.f, by.f, wr.f, wg.f, wb.f, c.l, wx.f, wy.f, s.f, t.f
For y = 0 To #H - 1 : For x = 0 To #W - 1
  ; back layer: origin = X - ScrollX + camera * (1 - parallax) = -3 + 15, 0 + 9
  c = RefWorld(*Map, -3 + 30 * 0.5, 12 * 0.75, WorldX(x), WorldY(y), 0)
  wr = Red(c) : wg = Green(c) : wb = Blue(c)
  ; middle: the whole 64 x 32 sheet at 40, 20, flipped top to bottom, half opacity
  wx = WorldX(x) : wy = WorldY(y)
  If wx >= 40 And wx < 104 And wy >= 20 And wy < 52
    s = (wx - 40) / 64.0 : t = 1.0 - (wy - 20) / 32.0
    c = SheetColour(Int(s * 64), Int(t * 32))
    wr = Red(c) * 0.5 + wr * 0.5 : wg = Green(c) * 0.5 + wg * 0.5 : wb = Blue(c) * 0.5 + wb * 0.5
  EndIf
  ; front: canvas pixels 2..50 x 2..18, the camera ignored
  c = RefWorld(*Ui, 2, 2, x + 0.5, y + 0.5, 0)
  If Alpha(c) : wr = Red(c) : wg = Green(c) : wb = Blue(c) : EndIf
  c = Pixel(x, y)
  If Abs(Red(c) - wr) > 1 Or Abs(Green(c) - wg) > 1 Or Abs(Blue(c) - wb) > 1
    If bad = 0 : first = " first at " + Str(x) + "," + Str(y) + " got " + Str(Red(c)) + "," + Str(Green(c)) + "," + Str(Blue(c)) + " want " + StrF(wr, 1) + "," + StrF(wg, 1) + "," + StrF(wb, 1) : EndIf
    bad + 1
  EndIf
Next : Next
Check(Bool(bad = 0), "layers: " + Str(bad) + " pixels differ from the CPU reference by more than 1" + first)
*Mid\Visible = #False
GL_BeginRenderTarget(*Target)
draws = GL_LayersDraw(*Stack, #True, 0)
GL_EndRenderTarget(*Target)
Check(Bool(draws = 2), "a hidden layer is not drawn")
GL_LayersFree(*Stack)

; NOTE (not a pass/fail): which image rows DrawGLSprite shows for SrcY = 0.
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
DrawGLSprite(*Sheet, 0, 0, 0.0, 1.0, 1, 1, 1, 1, #True, 0, 0, 16, 16, #True)
ReadBack()
GL_EndRenderTarget(*Target)
PrintN("note: DrawGLSprite(SrcY = 0, SrcH = 16) shows image row " + Str(Green(Pixel(0, 0)) / 8) + " at its top (row 0 is the top of the image)")

GL_FreeRenderTarget(*Target)
PrintN("PASS draw: " + Str(Checks) + " checks - tile maps at 6 camera positions pixel for pixel against the CPU reference, tint, batches of 10000, three layers")
