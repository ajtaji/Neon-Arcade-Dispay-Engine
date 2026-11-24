; Layers and tile collision without a window: draw order, the parallax
; arithmetic, what a sprite layer writes into the batch, and the box, circle
; and line queries against a slow reference that visits every cell of the map
; by other methods (sampling for boxes, inverse-orientation point tests, the
; engine's CheckCollisionLineLine for lines).
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlMath.pbi"
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
Procedure.f Rnd01()
  ProcedureReturn Random(1000000) / 1000000.0
EndProcedure
Procedure.f BatchF(q.i, k.i, field.i)
  ProcedureReturn PeekF(*GL_BatchBuffer + q * 192 + k * 32 + field * 4)
EndProcedure

Util_WinWidth = 320 : Util_WinHeight = 240 : Util_BaseWidth = 320 : Util_BaseHeight = 240
*GL_BatchBuffer = AllocateMemory(GL_MaxBatch * 192)
Define *Sheet.GLSprite = AllocateStructure(GLSprite)
*Sheet\Width = 128 : *Sheet\Height = 64 : *Sheet\TextureID = 3
Define *Set.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16)
Global *Map.GLTileMap = GL_TileMapCreate(24, 18, *Set)

; ------------------------------------------------------------------ draw order
Define *Stack.GLLayers = GL_LayersCreate()
Define *A.GLLayer = GL_LayerAddTiles(*Stack, *Map, 5)
Define *B.GLLayer = GL_LayerAddSprites(*Stack, 1)
Define *C.GLLayer = GL_LayerAddTiles(*Stack, *Map, 5)
Define *D.GLLayer = GL_LayerAddSprites(*Stack, -2)
Define *E.GLLayer = GL_LayerAddTiles(*Stack, *Map, 1)
Dim Ord.i(0)
Check(Bool(GL_LayersSorted(*Stack, Ord()) = 5 And Ord(0) = *D And Ord(1) = *B And Ord(2) = *E And Ord(3) = *A And Ord(4) = *C), "back to front: by Order, ties in the order added")
GL_LayerSetOrder(*Stack, *A, 5)
Check(Bool(GL_LayersSorted(*Stack, Ord()) = 5 And Ord(3) = *C And Ord(4) = *A), "re-ordering to the same Order puts the layer in front of its equals")
GL_LayerSetOrder(*Stack, *C, -9)
GL_LayersSorted(*Stack, Ord())
Check(Bool(Ord(0) = *C And Ord(1) = *D), "a lower Order goes to the back")
GL_LayerRemove(*Stack, *B)
Check(Bool(GL_LayersSorted(*Stack, Ord()) = 4 And Ord(2) = *E), "removed")
Check(Bool(*A\ParallaxX = 1 And *A\Opacity = 1 And *A\TintG = 1 And *A\Visible And *A\Fixed = 0), "a new layer follows the world at full opacity")

; ------------------------------------------------------------------- parallax
Define i.i, ox.f, oy.f, px.f, py.f, sx.f, sy.f, want.f, cam0.f, s0.f, s1.f
For i = 1 To 300
  GL_CameraX = Rnd01() * 2000 - 500 : GL_CameraY = Rnd01() * 900 - 200 : GL_CameraZoom = 0.5 + Rnd01() * 2.5
  *A\X = Rnd01() * 100 - 50 : *A\Y = Rnd01() * 100 - 50
  *A\ScrollX = Rnd01() * 300 : *A\ScrollY = Rnd01() * 300
  *A\ParallaxX = Rnd01() * 1.5 : *A\ParallaxY = Rnd01() * 1.5
  px = Rnd01() * 500 : py = Rnd01() * 500                      ; a point of the layer's content
  GL_LayerOrigin(*A, @ox, @oy)
  sx = 160 + (ox + px - GL_CameraX - 160) * GL_CameraZoom     ; as DrawGLSprite places it
  want = 160 + (*A\X - *A\ScrollX + px - *A\ParallaxX * GL_CameraX - 160) * GL_CameraZoom
  Check(Bool(Abs(sx - want) < 0.01 * (1 + Abs(want) / 1000)), "parallax " + Str(i) + ": screen x " + StrF(sx) + " want " + StrF(want))
  ; move the camera: the content moves ParallaxX times as far on the screen
  s0 = sx
  GL_CameraX + 37.5
  GL_LayerOrigin(*A, @ox, @oy)
  s1 = 160 + (ox + px - GL_CameraX - 160) * GL_CameraZoom
  Check(Bool(Abs((s0 - s1) - 37.5 * *A\ParallaxX * GL_CameraZoom) < 0.01), "parallax " + Str(i) + ": the layer moves " + StrF(*A\ParallaxX, 3) + " times the camera")
Next
*A\Fixed = #True : *A\X = 10 : *A\ScrollX = 4 : *A\ParallaxX = 0.25 : GL_CameraX = 999
GL_LayerOrigin(*A, @ox, @oy)
Check(Bool(ox = 6), "a fixed (UI) layer is in canvas pixels and ignores the camera")
*A\Fixed = #False : *A\ParallaxX = 0 : *A\ScrollX = 0 : *A\X = 0
GL_LayerOrigin(*A, @ox, @oy)
Check(Bool(ox = 999), "parallax 0: a backdrop that never moves on the screen")

; ------------------------------------------- a sprite layer into the batch
Define *S.GLLayer = GL_LayerAddSprites(*Stack, 3), *e1.GLLayerSprite, *e2.GLLayerSprite, *e3.GLLayerSprite, n.i
*S\TintR = 0.5 : *S\Opacity = 0.25
GL_CameraX = 0 : GL_CameraY = 0 : GL_CameraZoom = 1
*e1 = GL_LayerSpriteAdd(*S, *Sheet, 20, 30)
*e2 = GL_LayerSpriteAdd(*S, *Sheet, 5000, 30)                 ; off the canvas
*e3 = GL_LayerSpriteAdd(*S, *Sheet, 100, 100)
*e3\SrcX = 16 : *e3\SrcY = 32 : *e3\SrcW = 16 : *e3\SrcH = 16 : *e3\W = 32 : *e3\H = 32 : *e3\Angle = #PI / 2 : *e3\Orient = #GL_TILE_FLIPX
*e3\G = 0.5
GL_BatchCount = 0 : GL_CurrentBatchTexture = 3
n = GLLayer_SubmitSprites(*S, 0, 0, #False)
Check(Bool(n = 2 And GL_BatchCount = 2), "two sprites submitted, the one off the canvas not")
Check(Bool(Abs((BatchF(0, 0, 0) + 1) * 160 - 20) < 0.001 And Abs((1 - BatchF(0, 0, 1)) * 120 - 30) < 0.001), "first sprite's top-left at 20,30")
Check(Bool(Abs((BatchF(0, 4, 0) + 1) * 160 - 148) < 0.001 And Abs((1 - BatchF(0, 4, 1)) * 120 - 94) < 0.001), "its bottom-right at 148,94: the whole 128x64 picture")
Check(Bool(BatchF(0, 0, 4) = 0.5 And BatchF(0, 0, 5) = 1 And BatchF(0, 0, 7) = 0.25), "layer tint and opacity multiply the sprite's colour")
Check(Bool(BatchF(1, 0, 5) = 0.5 * 1 And BatchF(1, 0, 4) = 0.5), "and the sprite's own")
; the turned one: 32x32 at 100,100, centre 116,116; a quarter turn takes the top-left corner to the top-right
Define u0.f, vt.f, u1.f, vb.f
GLTile_SourceUV(128, 64, 16, 32, 16, 16, @u0, @vt, @u1, @vb)
Check(Bool(Abs((BatchF(1, 0, 0) + 1) * 160 - 132) < 0.001 And Abs((1 - BatchF(1, 0, 1)) * 120 - 100) < 0.001), "a quarter turn puts the TL vertex at the top-right of the box")
Check(Bool(Abs(BatchF(1, 0, 2) - u1) < 0.00001 And Abs(BatchF(1, 0, 3) - vt) < 0.00001), "FLIPX: the TL vertex shows the picture's top-right")

; ------------------------------------------------------- collision: the map
Define x.i, y.i, k.i
GL_TileSetCollision(*Set, 1, #GL_TILE_SOLID)
GL_TileSetCollision(*Set, 2, #GL_TILE_ONEWAY)
GL_TileSetCollision(*Set, 3, #GL_TILE_SLOPE)
GL_TileSetCollision(*Set, 4, #GL_TILE_SLOPE)
Check(Bool(GL_TileSetCollisionGet(*Set, 3) = #GL_TILE_SLOPE And GL_TileSetCollision(*Set, 99, 1) = #False), "collision bytes")
RandomSeed(11)
For y = 0 To 17 : For x = 0 To 23
  k = Random(5)
  If k : GL_TileMapSet(*Map, x, y, k, OrientBits(Random(7))) : EndIf      ; tile 5: kind 0
Next : Next
Global MapX.f = 4.0, MapY.f = -8.0

; ---- the reference: every cell, other methods
; base coordinates of a world point in cell cx, cy: undo FLIPY, FLIPX, DIAG
Procedure RefBase(cx.i, cy.i, wx.f, wy.f, *S.Float, *T.Float)
  Protected s.f = (wx - MapX) / 16.0 - cx, t.f = (wy - MapY) / 16.0 - cy, o.i = GL_TileMapFlags(*Map, cx, cy)
  If o & #GL_TILE_FLIPY : t = 1 - t : EndIf
  If o & #GL_TILE_FLIPX : s = 1 - s : EndIf
  If o & #GL_TILE_DIAG : Swap s, t : EndIf
  *S\f = s : *T\f = t
EndProcedure
Procedure.i RefSolidPoint(cx.i, cy.i, wx.f, wy.f)      ; inside the slope triangle, strictly
  Protected s.f, t.f
  RefBase(cx, cy, wx, wy, @s, @t)
  ProcedureReturn Bool(s + t > 1.0 And s < 1.0 And t < 1.0)
EndProcedure
; the triangle's three corners: the cell corners whose base s + t >= 1
Procedure.i RefTriangle(cx.i, cy.i, Array TX.f(1), Array TY.f(1))
  Protected k.i, n.i, wx.f, wy.f, s.f, t.f, col.i, row.i
  For k = 0 To 3
    col = cx + (k & 1) : row = cy + (k >> 1)
    wx = MapX + col * 16 : wy = MapY + row * 16
    RefBase(cx, cy, wx, wy, @s, @t)
    If s + t >= 0.999 : TX(n) = wx : TY(n) = wy : n + 1 : EndIf
  Next
  ProcedureReturn n
EndProcedure

Structure RefHit : Col.i : Row.i : Blocks.i : T.f : EndStructure
Global NewList Ref.RefHit()

Procedure RefBox(bx.f, by.f, bw.f, bh.f)
  Protected cx.i, cy.i, x0.f, y0.f, ax.f, ay.f, zx.f, zy.f, sx.f, sy.f, kind.i, blocks.i
  ClearList(Ref())
  For cy = 0 To *Map\Height - 1 : For cx = 0 To *Map\Width - 1
    If GL_TileMapGet(*Map, cx, cy) < 0 : Continue : EndIf
    x0 = MapX + cx * 16 : y0 = MapY + cy * 16
    ax = bx : If x0 > ax : ax = x0 : EndIf
    ay = by : If y0 > ay : ay = y0 : EndIf
    zx = bx + bw : If x0 + 16 < zx : zx = x0 + 16 : EndIf
    zy = by + bh : If y0 + 16 < zy : zy = y0 + 16 : EndIf
    If zx <= ax Or zy <= ay : Continue : EndIf                ; no area in common
    kind = GL_TileSetCollisionGet(*Map\Set, GL_TileMapGet(*Map, cx, cy))
    blocks = #False
    If kind & #GL_TILE_SLOPE
      sy = ay + 1.0 / 16
      While sy < zy And Not blocks
        sx = ax + 1.0 / 16
        While sx < zx
          If RefSolidPoint(cx, cy, sx, sy) : blocks = #True : Break : EndIf
          sx + 1.0 / 8
        Wend
        sy + 1.0 / 8
      Wend
    ElseIf kind & #GL_TILE_SOLID
      blocks = #True
    EndIf
    AddElement(Ref()) : Ref()\Col = cx : Ref()\Row = cy : Ref()\Blocks = blocks
  Next : Next
EndProcedure

Procedure.f RefSeg2(px.f, py.f, ax.f, ay.f, bx.f, by.f)
  Protected dx.f = bx - ax, dy.f = by - ay, t.f = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
  If t < 0 : t = 0 : EndIf
  If t > 1 : t = 1 : EndIf
  ProcedureReturn (ax + t * dx - px) * (ax + t * dx - px) + (ay + t * dy - py) * (ay + t * dy - py)
EndProcedure

Procedure RefCircle(ccx.f, ccy.f, r.f)
  Protected cx.i, cy.i, x0.f, y0.f, dx.f, dy.f, kind.i, blocks.i, n.i, k.i, best.f, d.f
  Dim TX.f(3) : Dim TY.f(3)
  ClearList(Ref())
  For cy = 0 To *Map\Height - 1 : For cx = 0 To *Map\Width - 1
    If GL_TileMapGet(*Map, cx, cy) < 0 : Continue : EndIf
    x0 = MapX + cx * 16 : y0 = MapY + cy * 16
    dx = 0 : If ccx < x0 : dx = x0 - ccx : ElseIf ccx > x0 + 16 : dx = ccx - x0 - 16 : EndIf
    dy = 0 : If ccy < y0 : dy = y0 - ccy : ElseIf ccy > y0 + 16 : dy = ccy - y0 - 16 : EndIf
    If dx * dx + dy * dy >= r * r : Continue : EndIf
    kind = GL_TileSetCollisionGet(*Map\Set, GL_TileMapGet(*Map, cx, cy))
    blocks = #False
    If kind & #GL_TILE_SLOPE
      If ccx > x0 And ccx < x0 + 16 And ccy > y0 And ccy < y0 + 16 And RefSolidPoint(cx, cy, ccx, ccy)
        blocks = #True
      Else
        n = RefTriangle(cx, cy, TX(), TY())
        best = Infinity()
        For k = 0 To 2
          d = RefSeg2(ccx, ccy, TX(k), TY(k), TX((k + 1) % 3), TY((k + 1) % 3))
          If d < best : best = d : EndIf
        Next
        blocks = Bool(n = 3 And best < r * r)
      EndIf
    ElseIf kind & #GL_TILE_SOLID
      blocks = #True
    EndIf
    AddElement(Ref()) : Ref()\Col = cx : Ref()\Row = cy : Ref()\Blocks = blocks
  Next : Next
EndProcedure

; a segment against a convex outline by edge crossings and an inside start
Procedure.i RefSegPoly(x1.f, y1.f, x2.f, y2.f, n.i, Array PX.f(1), Array PY.f(1), *Enter.Float, Inside.i)
  Protected k.i, hx.f, hy.f, best.f = Infinity(), hit.i, t.f
  If Inside : *Enter\f = 0 : ProcedureReturn #True : EndIf
  For k = 0 To n - 1
    If CheckCollisionLineLine(x1, y1, x2, y2, PX(k), PY(k), PX((k + 1) % n), PY((k + 1) % n), @hx, @hy)
      If Abs(x2 - x1) > Abs(y2 - y1) : t = (hx - x1) / (x2 - x1) : Else : t = (hy - y1) / (y2 - y1) : EndIf
      If t < best : best = t : EndIf
      hit = #True
    EndIf
  Next
  *Enter\f = best
  ProcedureReturn hit
EndProcedure

Procedure RefLine(x1.f, y1.f, x2.f, y2.f)
  Protected cx.i, cy.i, x0.f, y0.f, kind.i, blocks.i, n.i, tc.f, ts.f, inSq.i
  Dim PX.f(3) : Dim PY.f(3) : Dim TX.f(3) : Dim TY.f(3)
  ClearList(Ref())
  For cy = 0 To *Map\Height - 1 : For cx = 0 To *Map\Width - 1
    If GL_TileMapGet(*Map, cx, cy) < 0 : Continue : EndIf
    x0 = MapX + cx * 16 : y0 = MapY + cy * 16
    PX(0) = x0 : PY(0) = y0 : PX(1) = x0 + 16 : PY(1) = y0 : PX(2) = x0 + 16 : PY(2) = y0 + 16 : PX(3) = x0 : PY(3) = y0 + 16
    inSq = Bool(x1 > x0 And x1 < x0 + 16 And y1 > y0 And y1 < y0 + 16)
    If Not RefSegPoly(x1, y1, x2, y2, 4, PX(), PY(), @tc, inSq) : Continue : EndIf
    kind = GL_TileSetCollisionGet(*Map\Set, GL_TileMapGet(*Map, cx, cy))
    blocks = #False : ts = tc
    If kind & #GL_TILE_SLOPE
      n = RefTriangle(cx, cy, TX(), TY())
      blocks = RefSegPoly(x1, y1, x2, y2, 3, TX(), TY(), @ts, Bool(inSq And RefSolidPoint(cx, cy, x1, y1)))
      If Not blocks : ts = tc : EndIf
    ElseIf kind & #GL_TILE_SOLID
      blocks = #True
    EndIf
    AddElement(Ref()) : Ref()\Col = cx : Ref()\Row = cy : Ref()\Blocks = blocks : Ref()\T = ts
  Next : Next
EndProcedure

NewList Hits.GLTileHit()
Procedure.s HitKey(col.i, row.i, blocks.i)
  ProcedureReturn RSet(Str(col), 3, "0") + "," + RSet(Str(row), 3, "0") + ":" + Str(blocks)
EndProcedure
Procedure.i SameAsRef(List H.GLTileHit(), WithT.i, Name.s)
  Protected NewMap Want.f(), n.i, bad.s, key.s
  ForEach Ref() : Want(HitKey(Ref()\Col, Ref()\Row, Ref()\Blocks)) = Ref()\T : Next
  If ListSize(H()) <> MapSize(Want()) : bad = "count " + Str(ListSize(H())) + " want " + Str(MapSize(Want())) : EndIf
  ForEach H()
    key = HitKey(H()\Col, H()\Row, H()\Blocks)
    If Not FindMapElement(Want(), key) : bad + " extra " + key : Break : EndIf
    If WithT And Abs(Want() - H()\T) > 0.0005 : bad + " T at " + key + " " + StrF(H()\T, 5) + " want " + StrF(Want(), 5) : Break : EndIf
  Next
  If bad <> "" : PrintN("FAIL " + Name + ": " + bad) : End 1 : EndIf
  Checks + 1
EndProcedure

Define bx.f, by.f, bw.f, bh.f, got.i, wantAny.i, r.f, x2.f, y2.f, lastT.f, sorted.i, blockers.i
For i = 1 To 600
  bx = Random(1600) / 4.0 - 20 : by = Random(1200) / 4.0 - 30        ; quarter pixels: edges meet exactly
  bw = Random(160) / 4.0 + 0.25 : bh = Random(160) / 4.0 + 0.25
  got = CheckCollisionTileBox(*Map, MapX, MapY, bx, by, bw, bh, Hits())
  RefBox(bx, by, bw, bh)
  SameAsRef(Hits(), #False, "box " + Str(i) + " at " + StrF(bx, 2) + "," + StrF(by, 2) + " " + StrF(bw, 2) + "x" + StrF(bh, 2))
  wantAny = #False : ForEach Ref() : If Ref()\Blocks : wantAny = #True : EndIf : Next
  Check(Bool(got = wantAny), "box " + Str(i) + ": the answer is whether any hit blocks")
  If got : blockers + 1 : EndIf
Next
Check(Bool(blockers > 50 And blockers < 590), "boxes both blocked and free (" + Str(blockers) + " of 600 blocked)")
For i = 1 To 600
  bx = Rnd01() * 420 - 20 : by = Rnd01() * 320 - 30 : r = Rnd01() * 25 + 0.3
  got = CheckCollisionTileCircle(*Map, MapX, MapY, bx, by, r, Hits())
  RefCircle(bx, by, r)
  SameAsRef(Hits(), #False, "circle " + Str(i))
  wantAny = #False : ForEach Ref() : If Ref()\Blocks : wantAny = #True : EndIf : Next
  Check(Bool(got = wantAny), "circle " + Str(i) + ": the answer")
Next
For i = 1 To 600
  bx = Rnd01() * 420 - 20 : by = Rnd01() * 320 - 30
  x2 = bx + Rnd01() * 160 - 80 : y2 = by + Rnd01() * 160 - 80
  got = CheckCollisionTileLine(*Map, MapX, MapY, bx, by, x2, y2, Hits())
  RefLine(bx, by, x2, y2)
  SameAsRef(Hits(), #True, "line " + Str(i))
  sorted = #True : lastT = -1
  ForEach Hits() : If Hits()\T < lastT : sorted = #False : EndIf : lastT = Hits()\T : Next
  Check(sorted, "line " + Str(i) + ": hits nearest first")
  wantAny = #False : ForEach Ref() : If Ref()\Blocks : wantAny = #True : EndIf : Next
  Check(Bool(got = wantAny), "line " + Str(i) + ": the answer")
Next

; one-way tiles: never "block", carry the side they stop things from
Define *Plat.GLTileMap = GL_TileMapCreate(8, 1, *Set), o.i, nx.f, ny.f, s.f, t.f, ms.f, mt.f
For o = 0 To 7 : GL_TileMapSet(*Plat, o, 0, 2, OrientBits(o)) : Next
Check(Bool(CheckCollisionTileBox(*Plat, 0, 0, 0, 0, 128, 16, Hits()) = #False And ListSize(Hits()) = 8), "one-way tiles are reported, not blocking")
ForEach Hits()
  o = OrientNumber(Hits()\Flags)
  ; reference: the picture's top edge middle and its centre, turned with the cell
  s = 0.5 : t = 0.0 : ms = 0.5 : mt = 0.5
  If o & 4 : Swap s, t : Swap ms, mt : EndIf
  If o & 1 : s = 1 - s : ms = 1 - ms : EndIf
  If o & 2 : t = 1 - t : mt = 1 - mt : EndIf
  nx = (s - ms) * 2 : ny = (t - mt) * 2
  Check(Bool(Hits()\Kind = #GL_TILE_ONEWAY And Hits()\NormalX = nx And Hits()\NormalY = ny), "one-way orientation " + Str(o) + ": stops from " + StrF(nx, 0) + "," + StrF(ny, 0))
Next
Check(Bool(CheckCollisionTileBox(*Plat, 0, 0, 0, -10, 16, 10, Hits()) = #False And ListSize(Hits()) = 0), "standing exactly on top touches nothing")

; the layer wrappers use the layer's origin
*A\Fixed = #False : *A\X = 40 : *A\Y = 8 : *A\ScrollX = 0 : *A\ScrollY = 0 : *A\ParallaxX = 1 : *A\ParallaxY = 1 : *A\Map = *Map
got = CheckCollisionLayerBox(*A, 100, 60, 20, 20, Hits())
Check(Bool(got = CheckCollisionTileBox(*Map, 40, 8, 100, 60, 20, 20, Hits())), "layer box = map box at the layer's origin")
Check(Bool(CheckCollisionLayerBox(*S, 0, 0, 10, 10, Hits()) = #False), "a sprite layer has no tiles to hit")

; ------------------------------------------- the collision table in the file
Define path.s = ProgramParameter(0), *Set2.GLTileSet = GL_TileSetCreate(*Sheet, 16, 16)
If path = "" : path = GetTemporaryDirectory() + "layers_check.ntm" : EndIf
DeleteFile(path)
Check(GL_TileMapSave(*Map, path), "save with the collision table")
Check(Bool(GL_TileSetLoad(*Set2, path)), "load the set's table")
Check(Bool(CompareMemory(@*Set2\Collide(0), @*Set\Collide(0), *Set\Count)), "collision bytes round trip")
DeleteFile(path)

GL_LayersFree(*Stack)
PrintN("PASS layers: " + Str(Checks) + " checks - draw order, parallax at 300 cameras, sprite layer quads, 600 boxes / circles / lines against an every-cell reference, one-way sides, the collision table")
