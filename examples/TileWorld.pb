; ============================================================================
; TileWorld.pb - a parallax tile world with palette animation
; ============================================================================
; Three tile layers at different parallax (a starry sky, far hills, the
; ground), a sprite layer with two heroes that share one picture and differ
; only by palette, and a status strip fixed to the screen. Every picture is
; colour-indexed and made here in code. The water's eight blues and the
; stars cycle by the clock; D fades the world to dusk and back; coins are
; animated tiles. Arrow keys scroll; the hero stands on the ground by the
; tile collision queries. Esc or closing the window quits.
;
; Build (Windows, from this folder):
;   pbcompiler TileWorld.pb /EXE TileWorld.exe /THREAD /DPIAWARE
; ============================================================================
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlMath.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlFile.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlSpriteFunctions.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlTiles.pbi"         ; brings GlPalette.pbi
XIncludeFile #PB_Compiler_FilePath + "../GlLayers.pbi"

#CanvasW = 320 : #CanvasH = 240

; --- the world palette: 0 clear, 1-7 sky, 16-23 water, 32-39 greens, 48-55 rock,
;     64-71 hills, 80-87 stars, 96-103 gold
Global *World.GLPalette = GL_PaletteCreate()
Define i.i
GL_PaletteSet(*World, 0, RGBA(0, 0, 0, 0))
For i = 0 To 6 : GL_PaletteSet(*World, 1 + i, RGBA(6 + i * 4, 8 + i * 6, 30 + i * 12, 255)) : Next
For i = 0 To 7 : GL_PaletteSet(*World, 16 + i, RGBA(20 + i * 8, 60 + i * 18, 160 + i * 12, 255)) : Next
For i = 0 To 7 : GL_PaletteSet(*World, 32 + i, RGBA(30 + i * 10, 110 + i * 16, 40 + i * 6, 255)) : Next
For i = 0 To 7 : GL_PaletteSet(*World, 48 + i, RGBA(70 + i * 16, 64 + i * 15, 60 + i * 14, 255)) : Next
For i = 0 To 7 : GL_PaletteSet(*World, 64 + i, RGBA(60 + i * 8, 40 + i * 6, 90 + i * 10, 255)) : Next
For i = 0 To 7 : GL_PaletteSet(*World, 80 + i, RGBA(60 + i * 27, 60 + i * 27, 80 + i * 24, 255)) : Next
For i = 0 To 7 : GL_PaletteSet(*World, 96 + i, RGBA(200 + i * 7, 150 + i * 13, 20 + i * 8, 255)) : Next

; --- the sheet: 8 x 4 tiles of 16 x 16
#T_Sky = 0 : #T_HillTop = 1 : #T_Hill = 2 : #T_Grass = 3 : #T_Dirt = 4 : #T_Rock = 5
#T_Water = 6 : #T_Ledge = 7 : #T_CoinA = 8 : #T_CoinB = 9 : #T_Slope = 10
Global *Sheet.GLIndexedImage = GL_IndexedCreate(128, 64)
Procedure Px(Tile.i, x.i, y.i, Index.i)
  GL_IndexedSet(*Sheet, (Tile % 8) * 16 + x, (Tile / 8) * 16 + y, Index)
EndProcedure
Define x.i, y.i, d.f
RandomSeed(3)
For y = 0 To 15 : For x = 0 To 15
  Px(#T_Sky, x, y, 1 + y / 3)
  If Random(40) = 0 : Px(#T_Sky, x, y, 80 + Random(7)) : EndIf
  If y >= 8 - Int(Sin(x / 15.0 * #PI) * 6) : Px(#T_HillTop, x, y, 64 + (x + y) % 8) : EndIf
  Px(#T_Hill, x, y, 64 + (x * 3 + y) % 8)
  Px(#T_Grass, x, y, 32 + (x + y * 2) % 8)
  If y > 5 : Px(#T_Grass, x, y, 48 + (x * 5 + y * 3) % 4) : EndIf
  Px(#T_Dirt, x, y, 48 + (x * 7 + y * 5) % 5)
  Px(#T_Rock, x, y, 50 + Bool(x < 2 Or y < 2) * 4 + (x + y) % 2)
  Px(#T_Water, x, y, 16 + (x + y * 2) % 8)                     ; diagonal bands: the cycle makes waves
  If y < 4 : Px(#T_Ledge, x, y, 52 + x % 3) : EndIf
  d = Sqr((x - 7.5) * (x - 7.5) + (y - 7.5) * (y - 7.5))
  If d < 6 : Px(#T_CoinA, x, y, 96 + Int(d)) : EndIf
  If Abs(x - 7.5) < 2.5 And d < 6 : Px(#T_CoinB, x, y, 101) : EndIf
  If x + y >= 15 : Px(#T_Slope, x, y, 32 + (x + y) % 8) : EndIf
Next : Next
GL_IndexedPalette(*Sheet, 0, *World)

; --- the hero: one 16 x 24 picture, two palettes
Global *HeroImg.GLIndexedImage = GL_IndexedCreate(16, 24)
Global *Red.GLPalette = GL_PaletteCreate(8), *Blue.GLPalette = GL_PaletteCreate(8)
For y = 0 To 23 : For x = 0 To 15
  If y < 8 And Abs(x - 7.5) < 4 : GL_IndexedSet(*HeroImg, x, y, 1) : EndIf                  ; head
  If y >= 8 And y < 18 And Abs(x - 7.5) < 5 : GL_IndexedSet(*HeroImg, x, y, 2) : EndIf     ; body
  If y >= 18 And (x < 6 Or x > 9) And x > 2 And x < 13 : GL_IndexedSet(*HeroImg, x, y, 3) : EndIf
  If y = 3 And (x = 6 Or x = 9) : GL_IndexedSet(*HeroImg, x, y, 4) : EndIf               ; eyes
Next : Next
GL_PaletteSet(*Red, 0, RGBA(0, 0, 0, 0)) : GL_PaletteSet(*Red, 1, RGBA(250, 210, 170, 255))
GL_PaletteSet(*Red, 2, RGBA(210, 40, 50, 255)) : GL_PaletteSet(*Red, 3, RGBA(60, 40, 30, 255)) : GL_PaletteSet(*Red, 4, RGBA(0, 0, 0, 255))
GL_PaletteCopy(*Blue, *Red) : GL_PaletteSet(*Blue, 2, RGBA(40, 90, 230, 255))
GL_IndexedPalette(*HeroImg, 0, *Red)

; --- the tile set and the maps
Global *Set.GLTileSet = GL_TileSetCreateIndexed(*Sheet, 16, 16)
GL_TileSetAnimAdd(*Set, #T_CoinA, #T_CoinA, 300) : GL_TileSetAnimAdd(*Set, #T_CoinA, #T_CoinB, 300)
GL_TileSetCollision(*Set, #T_Grass, #GL_TILE_SOLID) : GL_TileSetCollision(*Set, #T_Dirt, #GL_TILE_SOLID)
GL_TileSetCollision(*Set, #T_Rock, #GL_TILE_SOLID) : GL_TileSetCollision(*Set, #T_Ledge, #GL_TILE_ONEWAY)
GL_TileSetCollision(*Set, #T_Slope, #GL_TILE_SLOPE)

#WorldW = 160                                     ; cells: 2560 pixels, eight screens
Global *SkyMap.GLTileMap = GL_TileMapCreate(40, 16, *Set)
Global *HillMap.GLTileMap = GL_TileMapCreate(90, 16, *Set)
Global *GroundMap.GLTileMap = GL_TileMapCreate(#WorldW, 15, *Set)
Global *StatusMap.GLTileMap = GL_TileMapCreate(6, 1, *Set)
GL_TileMapFill(*SkyMap, 0, 0, 40, 16, #T_Sky)
For x = 0 To 89
  y = 9 + Int(Sin(x / 7.0) * 2)
  GL_TileMapSet(*HillMap, x, y, #T_HillTop)
  GL_TileMapFill(*HillMap, x, y + 1, 1, 16, #T_Hill)
Next
Define ground.i = 12
For x = 0 To #WorldW - 1
  If x % 23 = 10 And x > 20                       ; a pool of water
    GL_TileMapFill(*GroundMap, x, ground, 4, 3, #T_Water)
    x + 3 : Continue
  EndIf
  GL_TileMapSet(*GroundMap, x, ground, #T_Grass)
  GL_TileMapFill(*GroundMap, x, ground + 1, 1, 2, #T_Dirt)
  If x % 17 = 5 : GL_TileMapSet(*GroundMap, x, ground - 1, #T_Rock, (Random(1) * #GL_TILE_DIAG) | (Random(1) * #GL_TILE_FLIPX) | (Random(1) * #GL_TILE_FLIPY)) : EndIf
  If x % 19 = 8 : GL_TileMapFill(*GroundMap, x, ground - 4, 3, 1, #T_Ledge) : GL_TileMapSet(*GroundMap, x + 1, ground - 5, #T_CoinA) : EndIf
  If x % 29 = 14 : GL_TileMapSet(*GroundMap, x, ground - 1, #T_Slope) : GL_TileMapSet(*GroundMap, x + 1, ground - 1, #T_Slope, #GL_TILE_FLIPX) : x + 1 : EndIf
Next
For x = 0 To 5 : GL_TileMapSet(*StatusMap, x, 0, #T_CoinA) : Next

; --- the layers
Global *Stack.GLLayers = GL_LayersCreate()
Global *Sky.GLLayer = GL_LayerAddTiles(*Stack, *SkyMap, 0)
Global *Hills.GLLayer = GL_LayerAddTiles(*Stack, *HillMap, 1)
Global *Ground.GLLayer = GL_LayerAddTiles(*Stack, *GroundMap, 2)
Global *Actors.GLLayer = GL_LayerAddSprites(*Stack, 3)
Global *Status.GLLayer = GL_LayerAddTiles(*Stack, *StatusMap, 9)
*Sky\ParallaxX = 0.1 : *Sky\ParallaxY = 0.0
*Hills\ParallaxX = 0.45 : *Hills\ParallaxY = 0.2 : *Hills\Y = -16
*Status\Fixed = #True : *Status\X = 4 : *Status\Y = 4 : *Status\Opacity = 0.8
Global *Hero.GLLayerSprite = GL_LayerImageAdd(*Actors, *HeroImg, 40, 0)
Global *Twin.GLLayerSprite = GL_LayerImageAdd(*Actors, *HeroImg, 70, 0, *Blue)      ; the palette swap

; --- the window: a 320 x 240 canvas, letterboxed
GL_HostPrepare()
Define Gadget.i = OpenGLWindow("Neon tile world", 960, 720, #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MaximizeGadget)
If Not Gadget : MessageRequester("Neon tile world", "No OpenGL window.") : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)
InitSpriteBatcher()
GL_HandleResize(Gadget)
If Not GL_PaletteInit() : MessageRequester("Neon tile world", GL_PaletteError()) : End 1 : EndIf

NewList Hits.GLTileHit()
Define quit.i, ev.i, now.q, last.q = GL_Micros(), dt.f, dusk.i, duskAmount.f, heroY.f = 0, heroVY.f, twinY.f, twinVY.f
Define camX.f = 0, speed.f = 60, ms.q, k.i

Procedure.f Fall(X.f, Y.f, *VY.Float, dt.f)
  ; gravity, then stand on the surface of whatever solid or slope tile the feet are in
  ; (the ground layer's origin is 0,0), and on one-way ledges only when coming down onto them
  Protected NewList H.GLTileHit(), top.f, lx.f, oldBottom.f = Y + 24
  *VY\f + 600 * dt : If *VY\f > 400 : *VY\f = 400 : EndIf
  Y + *VY\f * dt
  If CheckCollisionLayerBox(*Ground, X + 3, Y, 10, 24, H())
    ForEach H()
      If Not H()\Blocks : Continue : EndIf
      top = H()\Row * 16
      If H()\Kind & #GL_TILE_SLOPE                 ; the diagonal under the feet' middle
        lx = X + 8 - H()\Col * 16
        If lx < 0 : lx = 0 : ElseIf lx > 16 : lx = 16 : EndIf
        If H()\Flags & #GL_TILE_FLIPX : top + lx : Else : top + 16 - lx : EndIf
      EndIf
      If Y + 24 > top : Y = top - 24 : *VY\f = 0 : EndIf
    Next
  EndIf
  ForEach H()
    If H()\Kind & #GL_TILE_ONEWAY And *VY\f >= 0 And oldBottom <= H()\Row * 16 + 0.01
      Y = H()\Row * 16 - 24 : *VY\f = 0
    EndIf
  Next
  If Y > 15 * 16 : Y = 0 : *VY\f = 0 : EndIf     ; fell in the water: drop in again
  ProcedureReturn Y
EndProcedure

Repeat
  Repeat
    ev = WindowEvent()
    Select ev
      Case #PB_Event_CloseWindow : quit = #True
      Case #PB_Event_SizeWindow : GL_HandleResize(Gadget)
      Case #PB_Event_Menu : If EventMenu() = 1001 : quit = #True : EndIf
      Case #PB_Event_Gadget
        If EventType() = #PB_EventType_KeyDown And GetGadgetAttribute(Gadget, #PB_OpenGL_Key) = #PB_Shortcut_D : dusk ! 1 : EndIf
    EndSelect
  Until ev = 0
  now = GL_Micros() : dt = (now - last) / 1000000.0 : last = now
  If dt > 0.1 : dt = 0.1 : EndIf
  ms = now / 1000

  ; scroll
  If GL_KeyHeld(#PB_Shortcut_Right) : camX + speed * 3 * dt : ElseIf GL_KeyHeld(#PB_Shortcut_Left) : camX - speed * 3 * dt : Else : camX + speed * dt : EndIf
  If camX < 0 : camX = 0 : EndIf
  If camX > #WorldW * 16 - #CanvasW : camX = 0 : EndIf
  GL_CameraX = camX : GL_CameraY = 0 : GL_CameraZoom = 1.0
  *Hero\X = camX + 100 : *Twin\X = camX + 140
  heroY = Fall(*Hero\X, heroY, @heroVY, dt) : *Hero\Y = heroY
  twinY = Fall(*Twin\X, twinY, @twinVY, dt) : *Twin\Y = twinY

  ; the palettes for this frame: back to the colours as set, then animate
  If dusk : duskAmount + dt * 0.5 : Else : duskAmount - dt * 0.5 : EndIf
  If duskAmount < 0 : duskAmount = 0 : ElseIf duskAmount > 0.65 : duskAmount = 0.65 : EndIf
  GL_PaletteReset(*World)
  GL_PaletteCycleTime(*World, 16, 8, 110, ms)                 ; water
  GL_PaletteCycleTime(*World, 80, 8, 260, ms)                 ; stars
  GL_PaletteFade(*World, RGBA(10, 10, 60, 255), duskAmount)   ; dusk
  GL_PaletteReset(*Red) : GL_PaletteFade(*Red, RGBA(10, 10, 60, 255), duskAmount)
  GL_PaletteReset(*Blue) : GL_PaletteFade(*Blue, RGBA(10, 10, 60, 255), duskAmount)

  ; the frame
  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.02, 0.02, 0.08, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  GL_LayersDraw(*Stack, #True, ms)
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until quit

GL_IndexedFree(*Sheet) : GL_IndexedFree(*HeroImg)
GL_PaletteShutdown()
