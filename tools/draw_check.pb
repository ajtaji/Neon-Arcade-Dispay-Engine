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

; Orientation number 0-7 (bit 0 FLIPX, bit 1 FLIPY, bit 2 DIAG) as cell bits.
Procedure.i OrientBits(o.i)
  Protected f.i
  If o & 1 : f | #GL_TILE_FLIPX : EndIf
  If o & 2 : f | #GL_TILE_FLIPY : EndIf
  If o & 4 : f | #GL_TILE_DIAG : EndIf
  ProcedureReturn f
EndProcedure
Procedure.i OrientNumber(f.i)
  ProcedureReturn Bool(f & #GL_TILE_FLIPX) | (Bool(f & #GL_TILE_FLIPY) << 1) | (Bool(f & #GL_TILE_DIAG) << 2)
EndProcedure

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
  If Random(9) > 0 : GL_TileMapSet(*Map, x, y, Random(7), OrientBits(Random(7))) : EndIf
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
  If Random(9) > 0 : GL_TileMapSet(*Map, x, y, Random(6), OrientBits(Random(7))) : EndIf
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

; ---------------------------------------------------------------- palettes
; First compile and link the palette shaders here, reporting to the console,
; so that a driver's refusal is a FAIL line and never the engine's message box.
Procedure.l TryShader(Type.l, Src.s)
  Protected *s = UTF8(Src), sh.l = glCreateShader(Type), ok.l, n.l, *log
  Dim *Text(0) : *Text(0) = *s
  glShaderSource(sh, 1, @*Text(), #Null) : glCompileShader(sh)
  glGetShaderiv(sh, #GL_COMPILE_STATUS, @ok)
  If Not ok
    glGetShaderiv(sh, #GL_INFO_LOG_LENGTH, @n) : *log = AllocateMemory(n + 1)
    glGetShaderInfoLog(sh, n, #Null, *log) : PrintN("shader log: " + PeekS(*log, -1, #PB_UTF8)) : FreeMemory(*log)
    sh = 0
  EndIf
  FreeMemory(*s)
  ProcedureReturn sh
EndProcedure
Define vs.l = TryShader(#GL_VERTEX_SHADER, GLPal_VertexSource()), fs.l = TryShader(#GL_FRAGMENT_SHADER, GLPal_FragmentSource()), prog.l, linked.l
Check(Bool(vs And fs), "the palette shaders compile on this driver")
prog = glCreateProgram() : glAttachShader(prog, vs) : glAttachShader(prog, fs) : glLinkProgram(prog)
glGetProgramiv(prog, #GL_LINK_STATUS, @linked)
Check(Bool(linked), "and link")
Check(GL_PaletteInit(), "palette back end: " + GL_PaletteError())

; the indexed sheet: 64 x 32, index (x * 3 + y * 5) & 255; index 0 is transparent in P0
Define *ISheet.GLIndexedImage = GL_IndexedCreate(64, 32), *P0.GLPalette = GL_PaletteCreate(), *P1.GLPalette = GL_PaletteCreate(), *P2.GLPalette = GL_PaletteCreate()
For y = 0 To 31 : For x = 0 To 63 : GL_IndexedSet(*ISheet, x, y, (x * 3 + y * 5) & 255) : Next : Next
For i = 0 To 255
  GL_PaletteSet(*P0, i, RGBA(i, 255 - i, (i * 7) & 255, 255))
  GL_PaletteSet(*P1, i, RGBA((i * 13) & 255, i, 100, 255))
  GL_PaletteSet(*P2, i, RGBA(255 - i, (i * 3) & 255, 50, 255))
Next
GL_PaletteSet(*P0, 0, RGBA(0, 0, 0, 0))
GL_IndexedPalette(*ISheet, 0, *P0) : GL_IndexedPalette(*ISheet, 1, *P1)
Define *ISet.GLTileSet = GL_TileSetCreateIndexed(*ISheet, 16, 16)
For i = 4 To 7 : GL_TileSetPaletteSlot(*ISet, i, 1) : Next    ; the bottom row of tiles uses slot 1
Define *IMap.GLTileMap = GL_TileMapCreate(30, 20, *ISet)
RandomSeed(5)
For y = 0 To 19 : For x = 0 To 29
  If Random(9) > 0 : GL_TileMapSet(*IMap, x, y, Random(7), OrientBits(Random(7))) : EndIf
Next : Next

; CPU reference: the shown colour of an image pixel through a palette (0 when transparent)
Procedure.l RefIndexed(*Img.GLIndexedImage, *Pal.GLPalette, ix.i, iy.i)
  Protected c.l = GL_PaletteShown(*Pal, GL_IndexedGet(*Img, ix, iy))
  If Alpha(c) = 0 : ProcedureReturn 0 : EndIf
  ProcedureReturn c
EndProcedure
Procedure.l RefWorldIdx(*Map.GLTileMap, MapX.f, MapY.f, wx.f, wy.f, *Swap0.GLPalette)
  Protected cx.i = Round((wx - MapX) / 16.0, #PB_Round_Down), cy.i = Round((wy - MapY) / 16.0, #PB_Round_Down)
  Protected s.f, t.f, tile.i, flags.i, sx.i, sy.i, *Pal.GLPalette, *Img.GLIndexedImage = *Map\Set\Indexed
  If cx < 0 Or cy < 0 Or cx >= *Map\Width Or cy >= *Map\Height : ProcedureReturn 0 : EndIf
  tile = GL_TileMapGet(*Map, cx, cy) : flags = GL_TileMapFlags(*Map, cx, cy)
  If tile < 0 : ProcedureReturn 0 : EndIf
  s = (wx - MapX) / 16.0 - cx : t = (wy - MapY) / 16.0 - cy
  If flags & #GL_TILE_FLIPY : t = 1.0 - t : EndIf
  If flags & #GL_TILE_FLIPX : s = 1.0 - s : EndIf
  If flags & #GL_TILE_DIAG : Swap s, t : EndIf
  GL_TileSetSource(*Map\Set, tile, @sx, @sy)
  *Pal = GL_IndexedPaletteOf(*Img, GL_TileSetPaletteSlotGet(*Map\Set, tile))
  If GL_TileSetPaletteSlotGet(*Map\Set, tile) = 0 And *Swap0 : *Pal = *Swap0 : EndIf
  ProcedureReturn RefIndexed(*Img, *Pal, sx + Int(s * 16.0), sy + Int(t * 16.0))
EndProcedure
Procedure.i CheckIndexedMap(*Map.GLTileMap, MapX.f, MapY.f, *Swap0.GLPalette, Name.s)
  Protected x.i, y.i, bad.i, first.s, want.l
  For y = 0 To #H - 1 : For x = 0 To #W - 1
    want = RefWorldIdx(*Map, MapX, MapY, WorldX(x), WorldY(y), *Swap0)
    If Pixel(x, y) <> want
      If bad = 0 : first = " first at " + Str(x) + "," + Str(y) + " got $" + Hex(Pixel(x, y) & $FFFFFFFF) + " want $" + Hex(want & $FFFFFFFF) : EndIf
      bad + 1
    EndIf
  Next : Next
  Check(Bool(bad = 0), Name + ": " + Str(bad) + " pixels differ" + first)
EndProcedure

GL_CameraX = 37 : GL_CameraY = 21 : GL_CameraZoom = 1
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
before = GL_StatDrawCalls
draws = GL_TileMapDraw(*IMap, 8, 4, 1, 1, 1, 1, #True, #False, 0)
ReadBack()
GL_EndRenderTarget(*Target)
Check(Bool(draws = 1 And GL_StatDrawCalls - before = 1), "an indexed map with two palettes at once: one draw call (" + Str(draws) + ")")
CheckIndexedMap(*IMap, 8, 4, 0, "indexed tile map, palettes by tile, index 0 transparent")

; the clock cycles P0 (entries 1..254), P1 is faded half way to red: redraw, the indices are not sent again
GL_PaletteReset(*P0) : GL_PaletteCycleTime(*P0, 1, 254, 50, 175)
GL_PaletteReset(*P1) : GL_PaletteFade(*P1, RGBA(255, 0, 0, 255), 0.5)
Check(Bool(*ISheet\Changed = #False And *P0\Changed And *P1\Changed), "a palette change marks the palettes, not the image")
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
draws = GL_TileMapDraw(*IMap, 8, 4, 1, 1, 1, 1, #True, #False, 0)
ReadBack()
GL_EndRenderTarget(*Target)
CheckIndexedMap(*IMap, 8, 4, 0, "after a cycle and a fade")

; a layer swaps slot 0 for P2
Define *PStack.GLLayers = GL_LayersCreate(), *PL.GLLayer = GL_LayerAddTiles(*PStack, *IMap, 0)
*PL\X = 8 : *PL\Y = 4
GL_LayerPalette(*PL, 0, *P2)
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
draws = GL_LayersDraw(*PStack, #True, 0)
ReadBack()
GL_EndRenderTarget(*Target)
Check(Bool(draws = 1), "the swapped layer: one call")
CheckIndexedMap(*IMap, 8, 4, *P2, "a layer's palette swap for slot 0")
GL_LayersFree(*PStack)

; two indexed sprites of one image, each with its own palette, in one sprite layer: one call
Define *SStack.GLLayers = GL_LayersCreate(), *SL.GLLayer = GL_LayerAddSprites(*SStack, 0), *sa.GLLayerSprite, *sb.GLLayerSprite
*sa = GL_LayerImageAdd(*SL, *ISheet, 0, 0, *P1)
*sb = GL_LayerImageAdd(*SL, *ISheet, 70, 40, *P2) : *sb\Orient = #GL_TILE_FLIPX
GL_CameraX = 0 : GL_CameraY = 0
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
before = GL_StatDrawCalls
draws = GL_LayersDraw(*SStack, #True, 0)
ReadBack()
GL_EndRenderTarget(*Target)
Check(Bool(draws = 1 And GL_StatDrawCalls - before = 1), "two sprites, two palettes, one image: one draw call (" + Str(draws) + ")")
Define want.l
bad = 0 : first = ""
For y = 0 To #H - 1 : For x = 0 To #W - 1
  want = 0
  If x < 64 And y < 32 : want = RefIndexed(*ISheet, *P1, x, y) : EndIf
  If x >= 70 And x < 134 And y >= 40 And y < 72 : want = RefIndexed(*ISheet, *P2, 63 - (x - 70), y - 40) : EndIf
  If Pixel(x, y) <> want
    If bad = 0 : first = " first at " + Str(x) + "," + Str(y) : EndIf
    bad + 1
  EndIf
Next : Next
Check(Bool(bad = 0), "per-sprite palette swap, one flipped: " + Str(bad) + " pixels differ" + first)
GL_LayersFree(*SStack)

; one GL_IndexedDraw of a part of the image with slot 1, and a pixel changed afterwards
GL_IndexedSet(*ISheet, 20, 5, 77)
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
draws = GL_IndexedDraw(*ISheet, 10, 10, 0, 1, 0.0, 1.0, 1, 1, 1, 1, #True, 16, 0, 32, 16)
ReadBack()
GL_EndRenderTarget(*Target)
bad = 0
For y = 0 To #H - 1 : For x = 0 To #W - 1
  want = 0
  If x >= 10 And x < 42 And y >= 10 And y < 26 : want = RefIndexed(*ISheet, *P1, 16 + x - 10, y - 10) : EndIf
  If Pixel(x, y) <> want : bad + 1 : EndIf
Next : Next
Check(Bool(draws = 1 And bad = 0 And Pixel(14, 15) = RefIndexed(*ISheet, *P1, 20, 5)), "GL_IndexedDraw of a part, through slot 1, with a pixel changed since the last draw: " + Str(bad) + " differ")

; the CPU re-colour into an ordinary sprite, and baking it again after a fade
Define *Baked.GLSprite = GL_IndexedToSprite(*ISheet, *P2)
Check(Bool(*Baked And *Baked\Width = 64 And PeekB(*Baked\AlphaMask) = 1), "baked into a 64 x 32 sprite with its mask")
GL_PaletteReset(*P2) : GL_PaletteFade(*P2, RGBA(0, 0, 255, 255), 0.75)
Check(GL_IndexedBake(*ISheet, *P2, *Baked), "baked again after a fade")
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
DrawGLSprite(*Baked, 20, 30, 0.0, 1.0, 1, 1, 1, 1, #True, -1, -1, -1, -1, #True)
ReadBack()
GL_EndRenderTarget(*Target)
bad = 0
For y = 0 To #H - 1 : For x = 0 To #W - 1
  want = 0
  If x >= 20 And x < 84 And y >= 30 And y < 62 : want = RefIndexed(*ISheet, *P2, x - 20, y - 30) : EndIf
  If Pixel(x, y) <> want : bad + 1 : EndIf
Next : Next
Check(Bool(bad = 0), "the baked sprite drawn by DrawGLSprite matches the look-up: " + Str(bad) + " differ")
GL_IndexedFree(*ISheet)
GL_PaletteShutdown()
Check(Bool(*P0\Row = -1 And *P1\Row = -1 And *P0\Changed), "shutdown takes every palette's row back")

; NOTE (not a pass/fail): which image rows DrawGLSprite shows for SrcY = 0.
GL_BeginRenderTarget(*Target)
glClearColor_(0, 0, 0, 0) : glClear_(#GL_COLOR_BUFFER_BIT)
DrawGLSprite(*Sheet, 0, 0, 0.0, 1.0, 1, 1, 1, 1, #True, 0, 0, 16, 16, #True)
ReadBack()
GL_EndRenderTarget(*Target)
PrintN("note: DrawGLSprite(SrcY = 0, SrcH = 16) shows image row " + Str(Green(Pixel(0, 0)) / 8) + " at its top (row 0 is the top of the image)")

GL_FreeRenderTarget(*Target)
PrintN("PASS draw: " + Str(Checks) + " checks - tile maps at 6 camera positions pixel for pixel against the CPU reference, tint, batches of 10000, three layers, indexed maps, cycles, fades, swaps, the CPU re-colour")
