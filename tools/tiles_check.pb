; Tile sets and tile maps without a window: the cut of a sheet, cells, which
; cells a camera position submits (against a brute-force pass over every cell),
; the quads written into the sprite batch (positions and the eight
; orientations), animated tiles by the clock, and the map file round trip.
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlFile.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlSpriteFunctions.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlTiles.pbi"
OpenConsole()

Global Checks.i
Procedure Check(ok.i, message.s)
  Checks + 1
  If Not ok : PrintN("FAIL " + message) : End 1 : EndIf
EndProcedure

; ---------------------------------------------------------------- the reference
; Screen position of a world point, written out the way DrawGLSprite does it.
Procedure.f RefScreenX(wx.f, TW.f)
  ProcedureReturn TW / 2.0 + ((wx - GL_CameraX - TW / 2.0) * GL_CameraZoom)
EndProcedure
Procedure.f RefScreenY(wy.f, TH.f)
  ProcedureReturn TH / 2.0 + ((wy - GL_CameraY - TH / 2.0) * GL_CameraZoom)
EndProcedure

; Brute force: every cell whose screen rectangle overlaps the canvas.
Procedure.i RefVisible(*Map.GLTileMap, MapX.f, MapY.f, TW.f, TH.f, *R.GLTileRange)
  Protected cx.i, cy.i, n.i, x0.f, x1.f, y0.f, y1.f
  *R\Col0 = 1 << 30 : *R\Row0 = 1 << 30 : *R\Col1 = -1 : *R\Row1 = -1
  For cy = 0 To *Map\Height - 1
    For cx = 0 To *Map\Width - 1
      x0 = RefScreenX(MapX + cx * *Map\TileW, TW) : x1 = RefScreenX(MapX + (cx + 1) * *Map\TileW, TW)
      y0 = RefScreenY(MapY + cy * *Map\TileH, TH) : y1 = RefScreenY(MapY + (cy + 1) * *Map\TileH, TH)
      If x1 > 0 And x0 < TW And y1 > 0 And y0 < TH
        n + 1
        If cx < *R\Col0 : *R\Col0 = cx : EndIf
        If cx > *R\Col1 : *R\Col1 = cx : EndIf
        If cy < *R\Row0 : *R\Row0 = cy : EndIf
        If cy > *R\Row1 : *R\Row1 = cy : EndIf
      EndIf
    Next
  Next
  ProcedureReturn n
EndProcedure

Procedure.f Rnd01()
  ProcedureReturn Random(1000000) / 1000000.0
EndProcedure

; Read back vertex k (0..5) of quad q from the batch.
Procedure.f BatchF(q.i, k.i, field.i)
  ProcedureReturn PeekF(*GL_BatchBuffer + q * 192 + k * 32 + field * 4)
EndProcedure

; ------------------------------------------------------------------- the sheet
Define *Sheet.GLSprite = AllocateStructure(GLSprite)
*Sheet\Width = 100 : *Sheet\Height = 70 : *Sheet\TextureID = 7
Check(Bool(GL_TileSetCreate(0, 16, 16) = 0 And GL_TileError() <> ""), "no sprite refused")
Check(Bool(GL_TileSetCreate(*Sheet, 0, 16) = 0), "zero tile width refused")
Define *Set.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16, 2, 1)
Check(Bool(*Set And *Set\Columns = 5 And *Set\Rows = 3 And *Set\Count = 15), "16x16 tiles, spacing 2, margin 1 on 100x70: 5 x 3")
Define sx.i, sy.i
Check(Bool(GL_TileSetSource(*Set, 7, @sx, @sy) And sx = 37 And sy = 19), "tile 7 starts at 37,19")
Check(Bool(GL_TileSetSource(*Set, 15, @sx, @sy) = #False), "tile past the end refused")
Define *Big.GLSprite = AllocateStructure(GLSprite)
*Big\Width = 1024 : *Big\Height = 1024
Check(Bool(GL_TileSetCreate(*Big, 8, 8) = 0), "a sheet of 16384 tiles is refused, not cut short")

; ------------------------------------------------------------------- the cells
Define *Map.GLTileMap = GL_TileMapCreate(40, 30, *Set)
Check(Bool(*Map And GL_TileMapGet(*Map, 0, 0) = #GL_TILE_EMPTY), "a new map is empty")
Check(Bool(GL_TileMapSet(*Map, 3, 4, 14, #GL_TILE_ROT90 | GL_TilePalette(5))), "set a tile")
Check(Bool(GL_TileMapGet(*Map, 3, 4) = 14 And GL_TileMapFlags(*Map, 3, 4) = #GL_TILE_ROT90 | GL_TilePalette(5)), "get it back with its flags")
Check(Bool(GL_TileMapCell(*Map, 3, 4) = (15 | $1400 | $A000)), "cell layout: number+1, DIAG|FLIPX, palette 5")
Check(Bool(GL_TileMapSet(*Map, 40, 0, 1) = #False And GL_TileMapSet(*Map, -1, 0, 1) = #False), "outside the map refused")
Check(Bool(GL_TileMapSet(*Map, 0, 0, #GL_TILE_MAX) = #False), "tile number past the field refused")
GL_TileMapSet(*Map, 3, 4, #GL_TILE_EMPTY)
Check(Bool(GL_TileMapCell(*Map, 3, 4) = 0), "empty clears the cell")
Define x.i, y.i
For y = 0 To 29 : For x = 0 To 39
  If (x * 7 + y * 3) % 5 <> 0 : GL_TileMapSet(*Map, x, y, (x + y * 3) % 15, ((x + y) % 8) << 10) : EndIf
Next : Next

; ------------------------------------------------- which cells a camera submits
Util_WinWidth = 320 : Util_WinHeight = 240 : Util_BaseWidth = 320 : Util_BaseHeight = 240
*GL_BatchBuffer = AllocateMemory(GL_MaxBatch * 192)
Define Rg.GLTileRange, Ref.GLTileRange, n.i, nRef.i, i.i, MapX.f, MapY.f, filled.i, q.i
For i = 1 To 400
  GL_CameraX = Rnd01() * 900.0 - 200.0 : GL_CameraY = Rnd01() * 700.0 - 150.0
  GL_CameraZoom = 0.35 + Rnd01() * 3.0
  If i % 7 = 0 : GL_CameraZoom = 1.0 : GL_CameraX = Int(GL_CameraX) : GL_CameraY = Int(GL_CameraY) : EndIf
  MapX = Rnd01() * 80.0 - 40.0 : MapY = Rnd01() * 80.0 - 40.0
  n = GL_TileMapRange(*Map, MapX, MapY, @Rg)
  nRef = RefVisible(*Map, MapX, MapY, 320, 240, @Ref)
  If nRef = 0
    Check(Bool(n = 0), "camera " + Str(i) + ": nothing visible")
  Else
    Check(Bool(n = nRef And Rg\Col0 = Ref\Col0 And Rg\Col1 = Ref\Col1 And Rg\Row0 = Ref\Row0 And Rg\Row1 = Ref\Row1),
          "camera " + Str(i) + ": cells " + Str(Rg\Col0) + "-" + Str(Rg\Col1) + " x " + Str(Rg\Row0) + "-" + Str(Rg\Row1) +
          " against the brute force " + Str(Ref\Col0) + "-" + Str(Ref\Col1) + " x " + Str(Ref\Row0) + "-" + Str(Ref\Row1))
  EndIf
  ; the quads written are exactly the non-empty visible cells
  filled = 0
  If n
    For y = Rg\Row0 To Rg\Row1 : For x = Rg\Col0 To Rg\Col1
      If GL_TileMapGet(*Map, x, y) <> #GL_TILE_EMPTY : filled + 1 : EndIf
    Next : Next
  EndIf
  GL_BatchCount = 0
  q = GL_TileMapSubmit(*Map, MapX, MapY)
  Check(Bool(q = filled And GL_BatchCount = filled), "camera " + Str(i) + ": " + Str(q) + " quads for " + Str(filled) + " filled visible cells")
Next

; A full 320x240 screen of 16x16 tiles: at most 21 x 16 cells, in one batch.
Define *Full.GLTileMap = GL_TileMapCreate(500, 400, *Set), worst.i
GL_TileMapFill(*Full, 0, 0, 500, 400, 3)
GL_CameraZoom = 1.0
For i = 1 To 200
  GL_CameraX = Rnd01() * 7000.0 : GL_CameraY = Rnd01() * 5000.0
  GL_BatchCount = 0
  q = GL_TileMapSubmit(*Full, 0, 0)
  If q > worst : worst = q : EndIf
Next
Check(Bool(worst = 21 * 16), "a scrolling full screen submits at most 21 x 16 = 336 tiles (saw " + Str(worst) + ")")
GL_CameraX = 160 : GL_CameraY = 96 : GL_BatchCount = 0
Check(Bool(GL_TileMapSubmit(*Full, 0, 0) = 20 * 15), "tile-aligned camera: exactly 20 x 15")

; ------------------------------------------------- one quad: place and picture
; A single tile at cell 2,1 of a map placed at 10,20; camera moved and zoomed.
Define *One.GLTileMap = GL_TileMapCreate(4, 4, *Set), o.i, k.i, ex.f, ey.f, nx.f, ny.f
Define u0.f, vt.f, u1.f, vb.f, s.f, t.f, us.f, vs.f, cs.i, ct.i, ok.i, worstErr.f
GL_CameraX = -60.5 : GL_CameraY = -30.25 : GL_CameraZoom = 1.75
GLTile_SourceUV(100, 70, 37, 19, 16, 16, @u0, @vt, @u1, @vb)
For o = 0 To 7
  GL_TileMapFill(*One, 0, 0, 4, 4, #GL_TILE_EMPTY)
  GL_TileMapSet(*One, 2, 1, 7, o << 10)
  GL_BatchCount = 0
  Check(Bool(GL_TileMapSubmit(*One, 10, 20) = 1), "orientation " + Str(o) + ": one quad")
  ; forward reference: the picture's corner (cs, ct) goes through DIAG, then
  ; FLIPX, then FLIPY to a screen corner; the vertex there must show it.
  For cs = 0 To 1 : For ct = 0 To 1
    s = cs : t = ct
    If o & 4 : Swap s, t : EndIf
    If o & 1 : s = 1.0 - s : EndIf
    If o & 2 : t = 1.0 - t : EndIf
    ex = RefScreenX(10 + 2 * 16 + s * 16, 320) : ey = RefScreenY(20 + 1 * 16 + t * 16, 240)
    us = u0 + (u1 - u0) * cs : vs = vt + (vb - vt) * ct
    ok = #False
    For k = 0 To 5
      nx = (BatchF(0, k, 0) + 1.0) * 160.0 : ny = (1.0 - BatchF(0, k, 1)) * 120.0
      If Abs(nx - ex) < 0.01 And Abs(ny - ey) < 0.01
        If Abs(BatchF(0, k, 2) - us) < 0.00001 And Abs(BatchF(0, k, 3) - vs) < 0.00001 : ok = #True : EndIf
      EndIf
    Next
    Check(ok, "orientation " + Str(o) + ": picture corner " + Str(cs) + "," + Str(ct) + " at its screen corner with the right texture point")
  Next : Next
Next
; the named rotations: where the picture's top-left corner goes
Procedure.i CornerOfTopLeft(Orient.i)    ; 0 TL 1 TR 2 BL 3 BR on screen
  Protected s.f = 0, t.f = 0
  If Orient & #GL_TILE_DIAG : Swap s, t : EndIf
  If Orient & #GL_TILE_FLIPX : s = 1 - s : EndIf
  If Orient & #GL_TILE_FLIPY : t = 1 - t : EndIf
  ProcedureReturn Int(s) + 2 * Int(t)
EndProcedure
Check(Bool(CornerOfTopLeft(#GL_TILE_ROT90) = 1 And CornerOfTopLeft(#GL_TILE_ROT180) = 3 And CornerOfTopLeft(#GL_TILE_ROT270) = 2), "ROT90 / 180 / 270 carry the top-left corner clockwise")
; colour reaches every vertex
GL_TileMapSet(*One, 2, 1, 7)
GL_BatchCount = 0 : GL_TileMapSubmit(*One, 10, 20, 0.25, 0.5, 0.75, 0.5)
Check(Bool(BatchF(0, 3, 4) = 0.25 And BatchF(0, 3, 5) = 0.5 And BatchF(0, 3, 6) = 0.75 And BatchF(0, 3, 7) = 0.5), "tint and opacity on every vertex")
; neighbours share their edge exactly: no crack between tiles
GL_TileMapSet(*One, 3, 1, 7)
GL_BatchCount = 0 : GL_TileMapSubmit(*One, 10.3, 20.7)
Check(Bool(BatchF(0, 4, 0) = BatchF(1, 0, 0)), "the right edge of one tile is the left edge of the next, bit for bit")
; IgnoreCamera: canvas coordinates, untouched by the camera
GL_TileMapFill(*One, 0, 0, 4, 4, #GL_TILE_EMPTY) : GL_TileMapSet(*One, 0, 0, 1)
GL_BatchCount = 0 : GL_TileMapSubmit(*One, 32, 48, 1, 1, 1, 1, #False, #True)
Check(Bool(Abs((BatchF(0, 0, 0) + 1.0) * 160.0 - 32) < 0.001 And Abs((1.0 - BatchF(0, 0, 1)) * 120.0 - 48) < 0.001), "a screen-fixed map ignores the camera")

; ------------------------------------------------------------ animated tiles
Check(Bool(GL_TileSetAnimAdd(*Set, 4, 5, 100) And GL_TileSetAnimAdd(*Set, 4, 6, 50) And GL_TileSetAnimAdd(*Set, 4, 4, 250)), "three frames")
Check(Bool(GL_TileSetAnimAdd(*Set, 4, 99, 10) = #False And GL_TileSetAnimAdd(*Set, 4, 5, 0) = #False), "bad frames refused")
Check(Bool(GL_TileSetAnimFrame(*Set, 4, 0) = 5 And GL_TileSetAnimFrame(*Set, 4, 99) = 5 And GL_TileSetAnimFrame(*Set, 4, 100) = 6), "frame by the clock")
Check(Bool(GL_TileSetAnimFrame(*Set, 4, 149) = 6 And GL_TileSetAnimFrame(*Set, 4, 150) = 4 And GL_TileSetAnimFrame(*Set, 4, 399) = 4 And GL_TileSetAnimFrame(*Set, 4, 400) = 5), "and round again")
Check(Bool(GL_TileSetAnimFrame(*Set, 4, -1) = 4 And GL_TileSetAnimFrame(*Set, 3, 120) = 3), "before zero, and an unanimated tile")
GL_TileMapFill(*One, 0, 0, 4, 4, #GL_TILE_EMPTY) : GL_TileMapSet(*One, 0, 0, 4, #GL_TILE_FLIPX)
GL_CameraX = 0 : GL_CameraY = 0 : GL_CameraZoom = 1
GLTile_SourceUV(100, 70, 1 + 1 * 18, 1 + 1 * 18, 16, 16, @u0, @vt, @u1, @vb)    ; tile 6: column 1, row 1
GL_BatchCount = 0 : GL_TileMapSubmit(*One, 0, 0, 1, 1, 1, 1, #False, #False, 1200 + 120)
Check(Bool(Abs(BatchF(0, 0, 2) - u1) < 0.00001 And Abs(BatchF(0, 0, 3) - vt) < 0.00001), "the cell shows frame tile 6, still mirrored, at 1320 ms")

; ------------------------------------------------------------ the map file
Define path.s = ProgramParameter(0), *Back.GLTileMap, same.i, f.i, *raw, size.i
If path = "" : path = GetTemporaryDirectory() + "tiles_check.ntm" : EndIf
DeleteFile(path)
Check(GL_TileMapSave(*Map, path), "save the 40 x 30 map with the set's animation")
size = FileSize(path)
Check(Bool(size = 8 + (8 + 8 + 40 * 30 * 2) + (8 + 20)), "file size is header + MAP + ANIM padded to 4 (" + Str(size) + ")")
f = ReadFile(#PB_Any, path) : *raw = AllocateMemory(size) : ReadData(f, *raw, size) : CloseFile(f)
Check(Bool(PeekS(*raw, 4, #PB_Ascii) = "NTMP" And PeekA(*raw + 5) = 1 And PeekA(*raw + 7) = 2 And PeekS(*raw + 8, 4, #PB_Ascii) = "MAP "), "header, version 1, two chunks, MAP first")
Check(Bool(PeekA(*raw + 16) = 0 And PeekA(*raw + 17) = 40 And PeekA(*raw + 19) = 30 And PeekA(*raw + 21) = 16 And PeekA(*raw + 23) = 16), "big-endian sizes")
x = GL_TileMapCell(*Map, 1, 0)
Check(Bool(PeekA(*raw + 24 + 2) = (x >> 8) And PeekA(*raw + 24 + 3) = (x & 255)), "cells big-endian, row 0 first")
*Back = GL_TileMapLoad(path, *Set)
Check(Bool(*Back And *Back\Width = 40 And *Back\Height = 30), "load it back")
same = Bool(*Back And CompareMemory(*Back\Cells, *Map\Cells, 40 * 30 * 2))
Check(same, "every cell the same after the round trip")
Check(Bool(GL_TileMapFileLayers(path) = 1), "one tile layer in the file")
Define *Set2.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16, 2, 1)
Check(Bool(GL_TileSetLoad(*Set2, path) And *Set2\Animated = 1 And GL_TileSetAnimFrame(*Set2, 4, 120) = 6 And GL_TileSetAnimFrame(*Set2, 4, 200) = 4), "animations round trip")
Define *Set8.GLTileSet = GL_TileSetCreate(*Sheet, 8, 8)
Check(Bool(GL_TileMapLoad(path, *Set8) = 0 And FindString(GL_TileError(), "tile size")), "another tile size refused: " + GL_TileError())
Check(Bool(GL_TileMapLoad(path, *Set, 1) = 0), "no second layer")
; save the small map over the big file: the file layer's exact-size rule is met by replacing the file
Check(GL_TileMapSave(*One, path, #False), "save a different size over it")
Check(Bool(FileSize(path) = 8 + 8 + 8 + 16 * 2 And FileSize(path + ".new") = -1), "replaced, no stray .new")
GL_TileMapFree(*Back) : *Back = GL_TileMapLoad(path, *Set)
Check(Bool(*Back And CompareMemory(*Back\Cells, *One\Cells, 32)), "the small map loads")
; a damaged file
f = CreateFile(#PB_Any, path) : WriteData(f, *raw, 40) : CloseFile(f)
Check(Bool(GL_TileMapLoad(path, *Set) = 0), "a cut-off file refused: " + GL_TileError())
PokeA(*raw + 5, 2) : f = CreateFile(#PB_Any, path) : WriteData(f, *raw, size) : CloseFile(f)
Check(Bool(GL_TileMapLoad(path, *Set) = 0), "version 2 refused")
DeleteFile(path)

GL_TileSetAnimClear(*Set, 4)
Check(Bool(*Set\Animated = 0 And GL_TileSetAnimFrame(*Set, 4, 120) = 4), "animation cleared")
GL_TileMapFree(*Map) : GL_TileMapFree(*Full) : GL_TileMapFree(*One) : GL_TileMapFree(*Back)
GL_TileSetFree(*Set) : GL_TileSetFree(*Set2) : GL_TileSetFree(*Set8)
PrintN("PASS tiles: " + Str(Checks) + " checks - sheet cut, cells, 400 camera positions against every cell, 336-tile screen in one batch, 8 orientations, animation by the clock, map file round trip")
