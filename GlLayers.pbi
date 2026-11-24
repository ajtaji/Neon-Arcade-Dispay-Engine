; ============================================================================
; GlLayers.pbi - Layers (tile maps and sprite lists), Parallax, Tile Collision
; ============================================================================
; Include after GlTiles.pbi. Nothing above this file was changed.
;
; --- THE MODEL ---
; A GLLayers holds layers. A layer is a tile map or a list of sprites, with
; its own place, scroll, parallax, opacity, tint, visibility and draw order.
; GL_LayersDraw draws them back to front: the lowest Order first, and layers
; of equal Order in the order they were added.
;
; The fields of a GLLayer ARE the interface - set them directly:
;   X, Y                  where the layer's top-left sits (world, or canvas if Fixed)
;   ScrollX, ScrollY      scrolls the content as a camera would: +X moves the view right
;   ParallaxX, ParallaxY  how fast the layer follows the camera: 1 = with the world,
;                         0.5 = half as fast (far away), 0 = not at all (a backdrop)
;   Opacity               0..1, multiplies every tile's and sprite's alpha
;   TintR, TintG, TintB   multiply every colour
;   Visible               #False skips the layer
;   Order                 draw order, low first (change it with GL_LayerSetOrder)
;   Fixed                 #True: fixed to the screen, in canvas pixels, the camera
;                         ignored (a UI layer)
;
; PARALLAX, THE ARITHMETIC: the layer's content point P is drawn at the world
; position  X - ScrollX + P + GL_CameraX * (1 - ParallaxX)  (and the same in Y),
; so on screen it moves ParallaxX times as fast as the camera. GL_LayerOrigin
; gives that position for P = 0. The camera's zoom applies to every layer
; that is not Fixed.
;
; DRAW CALLS: a tile layer is one call per screenful (GL_TileMapDraw). A
; sprite layer batches consecutive sprites on the same sheet into one call;
; a change of sheet starts a new one. Sprites wholly off the canvas are not
; submitted.
;
; --- COLLISION AGAINST A TILE LAYER ---
; Each tile of a set has a collision byte (GL_TileSetCollision): 0,
; #GL_TILE_SOLID, #GL_TILE_ONEWAY or #GL_TILE_SLOPE. The queries, in the
; shape of GlMath.pbi's helpers, report every non-empty cell a box, circle or
; line touches, and return #True when the shape is inside the solid part of a
; SOLID or SLOPE tile:
;   CheckCollisionTileBox(*Map, MapX, MapY, X, Y, W, H, List Hits.GLTileHit())
;   CheckCollisionTileCircle(*Map, MapX, MapY, CX, CY, Radius, List Hits.GLTileHit())
;   CheckCollisionTileLine(*Map, MapX, MapY, X1, Y1, X2, Y2, List Hits.GLTileHit())
; and CheckCollisionLayerBox / Circle / Line take a tile layer and use its
; origin. Touching an edge is not overlapping. A slope tile is solid below its
; diagonal; its cell's flips and rotations turn the triangle with the picture.
; A one-way tile never "blocks" on its own: its hit carries NormalX, NormalY,
; the side it stops things from ((0, -1), the top, unless the cell is turned),
; and the program decides from the direction of travel.
; ============================================================================

#GL_LAYER_TILES   = 1
#GL_LAYER_SPRITES = 2

Structure GLLayerSprite
  *Sprite.GLSprite
  X.f : Y.f                       ; top-left, in the layer
  W.f : H.f                       ; drawn size; 0 = the picture rectangle's size
  Angle.f                         ; radians, about the centre
  SrcX.f : SrcY.f                 ; picture rectangle, image rows counted from the top
  SrcW.f : SrcH.f                 ; 0 = the whole picture
  Orient.i                        ; #GL_TILE_FLIPX / FLIPY / DIAG / ROT90 ...
  R.f : G.f : B.f : A.f
  Visible.i
EndStructure

Structure GLLayer
  Kind.i
  *Map.GLTileMap
  List Sprites.GLLayerSprite()
  X.f : Y.f
  ScrollX.f : ScrollY.f
  ParallaxX.f : ParallaxY.f
  Opacity.f
  TintR.f : TintG.f : TintB.f
  Visible.i
  Order.i
  Fixed.i
  Seq.i                           ; when it was added (ties in Order)
EndStructure

Structure GLLayers
  List Layers.GLLayer()
  NextSeq.i
EndStructure

; One cell a collision query touched.
Structure GLTileHit
  Col.i : Row.i
  Tile.i                          ; the tile in the cell
  Flags.i                         ; the cell's orientation bits
  Kind.i                          ; the tile's collision byte
  Blocks.i                        ; inside the solid part of a SOLID or SLOPE tile
  T.f                             ; lines: 0..1 where the line enters (the solid part if Blocks)
  NormalX.f : NormalY.f           ; ONEWAY: the side it stops things from
EndStructure

Procedure.i GL_LayersCreate()
  ProcedureReturn AllocateStructure(GLLayers)
EndProcedure

; Free the layer set. Maps and sprites belong to the program and are not freed.
Procedure GL_LayersFree(*Stack.GLLayers)
  If *Stack : FreeStructure(*Stack) : EndIf
EndProcedure

Procedure.i GLLayer_New(*Stack.GLLayers, Kind.i, Order.i)
  Protected *L.GLLayer
  If Not *Stack : ProcedureReturn 0 : EndIf
  LastElement(*Stack\Layers())
  *L = AddElement(*Stack\Layers())
  *L\Kind = Kind : *L\Order = Order : *L\Seq = *Stack\NextSeq : *Stack\NextSeq + 1
  *L\ParallaxX = 1.0 : *L\ParallaxY = 1.0 : *L\Opacity = 1.0
  *L\TintR = 1.0 : *L\TintG = 1.0 : *L\TintB = 1.0 : *L\Visible = #True
  ProcedureReturn *L
EndProcedure

; A tile layer showing *Map (the map stays the program's).
Procedure.i GL_LayerAddTiles(*Stack.GLLayers, *Map.GLTileMap, Order.i = 0)
  Protected *L.GLLayer
  If Not *Map : ProcedureReturn GLTile_Fail("GL_LayerAddTiles: no map.") : EndIf
  *L = GLLayer_New(*Stack, #GL_LAYER_TILES, Order)
  If *L : *L\Map = *Map : EndIf
  ProcedureReturn *L
EndProcedure

; An empty sprite layer.
Procedure.i GL_LayerAddSprites(*Stack.GLLayers, Order.i = 0)
  ProcedureReturn GLLayer_New(*Stack, #GL_LAYER_SPRITES, Order)
EndProcedure

Procedure GL_LayerRemove(*Stack.GLLayers, *Layer.GLLayer)
  If Not *Stack Or Not *Layer : ProcedureReturn : EndIf
  ForEach *Stack\Layers()
    If @*Stack\Layers() = *Layer : DeleteElement(*Stack\Layers()) : Break : EndIf
  Next
EndProcedure

; Change a layer's draw order; it goes behind any layer already at that Order
; that was added later, and in front of the earlier ones - as if added now.
Procedure GL_LayerSetOrder(*Stack.GLLayers, *Layer.GLLayer, Order.i)
  If Not *Stack Or Not *Layer : ProcedureReturn : EndIf
  *Layer\Order = Order : *Layer\Seq = *Stack\NextSeq : *Stack\NextSeq + 1
EndProcedure

; Add a sprite to a sprite layer at X, Y (its top-left, in the layer). The
; returned entry's fields can be changed at any time; it shows on the next draw.
Procedure.i GL_LayerSpriteAdd(*Layer.GLLayer, *Sprite.GLSprite, X.f, Y.f)
  Protected *E.GLLayerSprite
  If Not *Layer Or *Layer\Kind <> #GL_LAYER_SPRITES Or Not *Sprite : ProcedureReturn 0 : EndIf
  LastElement(*Layer\Sprites())
  *E = AddElement(*Layer\Sprites())
  *E\Sprite = *Sprite : *E\X = X : *E\Y = Y
  *E\R = 1.0 : *E\G = 1.0 : *E\B = 1.0 : *E\A = 1.0 : *E\Visible = #True
  ProcedureReturn *E
EndProcedure

Procedure GL_LayerSpriteRemove(*Layer.GLLayer, *Entry.GLLayerSprite)
  If Not *Layer Or Not *Entry : ProcedureReturn : EndIf
  ForEach *Layer\Sprites()
    If @*Layer\Sprites() = *Entry : DeleteElement(*Layer\Sprites()) : Break : EndIf
  Next
EndProcedure

Procedure GL_LayerSpritesClear(*Layer.GLLayer)
  If *Layer : ClearList(*Layer\Sprites()) : EndIf
EndProcedure

; Where the layer's content point 0,0 is drawn now: world coordinates (handed
; to the camera), or canvas coordinates for a Fixed layer.
Procedure GL_LayerOrigin(*Layer.GLLayer, *X.Float, *Y.Float)
  If Not *Layer : ProcedureReturn : EndIf
  If *Layer\Fixed
    *X\f = *Layer\X - *Layer\ScrollX
    *Y\f = *Layer\Y - *Layer\ScrollY
  Else
    *X\f = *Layer\X - *Layer\ScrollX + GL_CameraX * (1.0 - *Layer\ParallaxX)
    *Y\f = *Layer\Y - *Layer\ScrollY + GL_CameraY * (1.0 - *Layer\ParallaxY)
  EndIf
EndProcedure

; The layers in drawing order (back first) as GLLayer addresses in Out().
; Returns how many.
Procedure.i GL_LayersSorted(*Stack.GLLayers, Array Out.i(1))
  Protected n.i, i.i, j.i, *A.GLLayer, *B.GLLayer, keep.i
  If Not *Stack : ProcedureReturn 0 : EndIf
  n = ListSize(*Stack\Layers())
  If ArraySize(Out()) < n : ReDim Out(n) : EndIf
  ForEach *Stack\Layers() : Out(i) = @*Stack\Layers() : i + 1 : Next
  For i = 1 To n - 1                     ; insertion sort: few layers, stable
    keep = Out(i) : *A = keep : j = i - 1
    While j >= 0
      *B = Out(j)
      If *B\Order < *A\Order Or (*B\Order = *A\Order And *B\Seq < *A\Seq) : Break : EndIf
      Out(j + 1) = Out(j) : j - 1
    Wend
    Out(j + 1) = keep
  Next
  ProcedureReturn n
EndProcedure

Structure GLLayerQuad
  NX.f[4] : NY.f[4] : U.f[4] : V.f[4]       ; corners TL, TR, BL, BR
EndStructure

; One quad turned by Angle about its centre CX, CY (world), into the batch.
Procedure GLLayer_QuadTurned(*X.GLTileXform, CX.f, CY.f, HW.f, HH.f, CosA.f, SinA.f, U0.f, VTop.f, U1.f, VBottom.f, Orient.i, R.f, G.f, B.f, A.f)
  Protected *P.Float, s.f, t.f, i.i, right.i, bottom.i, lx.f, ly.f, Q.GLLayerQuad
  If GL_BatchCount >= GL_MaxBatch : GLTile_Flush() : EndIf
  For i = 0 To 3
    right = i & 1 : bottom = i >> 1
    lx = -HW : If right : lx = HW : EndIf
    ly = -HH : If bottom : ly = HH : EndIf
    Q\NX[i] = (CX + lx * CosA - ly * SinA) * *X\KX + *X\CX
    Q\NY[i] = (CY + lx * SinA + ly * CosA) * *X\KY + *X\CY
    GLTile_SourceCorner(Orient, right, bottom, s, t)
    Q\U[i] = U0 + (U1 - U0) * s : Q\V[i] = VTop + (VBottom - VTop) * t
  Next
  *P = *GL_BatchBuffer + GL_BatchCount * 192
  GLTile_Vertex(*P, Q\NX[0], Q\NY[0], Q\U[0], Q\V[0], R, G, B, A)
  GLTile_Vertex(*P, Q\NX[2], Q\NY[2], Q\U[2], Q\V[2], R, G, B, A)
  GLTile_Vertex(*P, Q\NX[1], Q\NY[1], Q\U[1], Q\V[1], R, G, B, A)
  GLTile_Vertex(*P, Q\NX[2], Q\NY[2], Q\U[2], Q\V[2], R, G, B, A)
  GLTile_Vertex(*P, Q\NX[3], Q\NY[3], Q\U[3], Q\V[3], R, G, B, A)
  GLTile_Vertex(*P, Q\NX[1], Q\NY[1], Q\U[1], Q\V[1], R, G, B, A)
  GL_BatchCount + 1
EndProcedure

; Add a sprite layer's visible sprites, starting a new batch at each change of
; sheet. Returns the sprites submitted. Leaves the last batch open.
Procedure.i GLLayer_SubmitSprites(*L.GLLayer, OX.f, OY.f, Scaled.b)
  Protected Xf.GLTileXform, *E.GLLayerSprite, n.i, w.f, h.f, sw.f, sh.f, cx.f, cy.f, rad.f
  Protected u0.f, vt.f, u1.f, vb.f, X0.f, Y0.f, X1.f, Y1.f
  Protected TR.f = *L\TintR, TG.f = *L\TintG, TB.f = *L\TintB, TA.f = *L\Opacity
  GLTile_MakeXform(@Xf, Scaled, *L\Fixed)
  If Not GLTile_VisibleWorld(Scaled, *L\Fixed, @X0, @Y0, @X1, @Y1) : ProcedureReturn 0 : EndIf
  ForEach *L\Sprites()
    *E = @*L\Sprites()
    If Not *E\Visible Or Not *E\Sprite : Continue : EndIf
    sw = *E\SrcW : sh = *E\SrcH
    If sw <= 0 Or sh <= 0 : sw = *E\Sprite\Width : sh = *E\Sprite\Height : EndIf
    w = *E\W : h = *E\H
    If w <= 0 Or h <= 0 : w = sw : h = sh : EndIf
    cx = OX + *E\X + w / 2.0 : cy = OY + *E\Y + h / 2.0
    rad = Sqr(w * w + h * h) / 2.0
    If cx + rad <= X0 Or cx - rad >= X1 Or cy + rad <= Y0 Or cy - rad >= Y1 : Continue : EndIf
    If *E\Sprite\TextureID <> GL_CurrentBatchTexture
      GLTile_Flush()
      GL_CurrentBatchTexture = *E\Sprite\TextureID
    EndIf
    If *E\SrcW > 0 And *E\SrcH > 0
      GLTile_SourceUV(*E\Sprite\Width, *E\Sprite\Height, *E\SrcX, *E\SrcY, sw, sh, @u0, @vt, @u1, @vb)
    Else
      GLTile_SourceUV(*E\Sprite\Width, *E\Sprite\Height, 0, 0, sw, sh, @u0, @vt, @u1, @vb)
    EndIf
    GLLayer_QuadTurned(@Xf, cx, cy, w / 2.0, h / 2.0, Cos(*E\Angle), Sin(*E\Angle), u0, vt, u1, vb, *E\Orient,
                       *E\R * TR, *E\G * TG, *E\B * TB, *E\A * TA)
    n + 1
  Next
  ProcedureReturn n
EndProcedure

; Draw one layer. Returns the glDrawArrays issued.
Procedure.i GL_LayerDraw(*Layer.GLLayer, Scaled.b = #False, TimeMs.q = -1)
  Protected OX.f, OY.f
  If Not *Layer Or Not *Layer\Visible Or *Layer\Opacity <= 0.0 : ProcedureReturn 0 : EndIf
  GL_LayerOrigin(*Layer, @OX, @OY)
  If *Layer\Kind = #GL_LAYER_TILES
    ProcedureReturn GL_TileMapDraw(*Layer\Map, OX, OY, *Layer\TintR, *Layer\TintG, *Layer\TintB, *Layer\Opacity, Scaled, *Layer\Fixed, TimeMs)
  EndIf
  If Not GL_BatchShader : InitSpriteBatcher() : EndIf
  GLTile_Flushes = 0 : GL_BatchCount = 0 : GL_CurrentBatchTexture = 0
  GLLayer_SubmitSprites(*Layer, OX, OY, Scaled)
  GLTile_Flush()
  ProcedureReturn GLTile_Flushes
EndProcedure

; Draw every visible layer, back to front. Returns the glDrawArrays issued.
Procedure.i GL_LayersDraw(*Stack.GLLayers, Scaled.b = #False, TimeMs.q = -1)
  Protected Dim Order.i(0), n.i, i.i, calls.i
  If Not *Stack : ProcedureReturn 0 : EndIf
  If TimeMs < 0 : TimeMs = GLTile_Now() : EndIf       ; one time for every layer of the frame
  n = GL_LayersSorted(*Stack, Order())
  For i = 0 To n - 1
    calls + GL_LayerDraw(Order(i), Scaled, TimeMs)
  Next
  ProcedureReturn calls
EndProcedure

; ============================================================================
; COLLISION AGAINST A TILE LAYER
; ============================================================================

Structure GLTilePoly
  N.i
  X.f[4] : Y.f[4]
EndStructure

; A point of the unit cell (S, T; T down) after the cell's orientation, in
; the order the picture is turned: DIAG, then FLIPX, then FLIPY.
Macro GLTile_TurnPoint(Orient, S, T)
  If Orient & #GL_TILE_DIAG : Swap S, T : EndIf
  If Orient & #GL_TILE_FLIPX : S = 1.0 - S : EndIf
  If Orient & #GL_TILE_FLIPY : T = 1.0 - T : EndIf
EndMacro

; The cell's square, or with Slope its solid triangle, in world coordinates.
Procedure GLTile_CellPoly(*P.GLTilePoly, X0.f, Y0.f, W.f, H.f, Orient.i, Slope.i)
  Protected i.i, s.f, t.f
  If Slope
    *P\N = 3
    *P\X[0] = 0 : *P\Y[0] = 1 : *P\X[1] = 1 : *P\Y[1] = 1 : *P\X[2] = 1 : *P\Y[2] = 0
    For i = 0 To 2
      s = *P\X[i] : t = *P\Y[i]
      GLTile_TurnPoint(Orient, s, t)
      *P\X[i] = X0 + s * W : *P\Y[i] = Y0 + t * H
    Next
  Else
    *P\N = 4
    *P\X[0] = X0 : *P\Y[0] = Y0 : *P\X[1] = X0 + W : *P\Y[1] = Y0
    *P\X[2] = X0 + W : *P\Y[2] = Y0 + H : *P\X[3] = X0 : *P\Y[3] = Y0 + H
  EndIf
EndProcedure

; The outward normal of edge i (unnormalised).
Procedure GLTile_EdgeNormal(*P.GLTilePoly, i.i, *NX.Float, *NY.Float)
  Protected j.i = (i + 1) % *P\N, cx.f, cy.f, k.i, nx.f, ny.f
  For k = 0 To *P\N - 1 : cx + *P\X[k] : cy + *P\Y[k] : Next
  cx / *P\N : cy / *P\N
  nx = *P\Y[j] - *P\Y[i] : ny = -(*P\X[j] - *P\X[i])
  If nx * (cx - *P\X[i]) + ny * (cy - *P\Y[i]) > 0 : nx = -nx : ny = -ny : EndIf
  *NX\f = nx : *NY\f = ny
EndProcedure

; Box X0,Y0 - X1,Y1 against a convex polygon by separating axes. Touching is not overlapping.
Procedure.i GLTile_BoxPoly(X0.f, Y0.f, X1.f, Y1.f, *P.GLTilePoly)
  Protected i.i, k.i, nx.f, ny.f, a0.f, a1.f, b0.f, b1.f, d.f, Box.GLTilePoly
  GLTile_CellPoly(@Box, X0, Y0, X1 - X0, Y1 - Y0, 0, #False)
  For i = -2 To *P\N - 1
    If i = -2 : nx = 1 : ny = 0 : ElseIf i = -1 : nx = 0 : ny = 1 : Else : GLTile_EdgeNormal(*P, i, @nx, @ny) : EndIf
    a0 = Infinity() : a1 = -Infinity() : b0 = Infinity() : b1 = -Infinity()
    For k = 0 To 3
      d = Box\X[k] * nx + Box\Y[k] * ny
      If d < a0 : a0 = d : EndIf
      If d > a1 : a1 = d : EndIf
    Next
    For k = 0 To *P\N - 1
      d = *P\X[k] * nx + *P\Y[k] * ny
      If d < b0 : b0 = d : EndIf
      If d > b1 : b1 = d : EndIf
    Next
    If a1 <= b0 Or b1 <= a0 : ProcedureReturn #False : EndIf
  Next
  ProcedureReturn #True
EndProcedure

; The squared distance from a point to segment A-B.
Procedure.f GLTile_PointSegment2(PX.f, PY.f, AX.f, AY.f, BX.f, BY.f)
  Protected dx.f = BX - AX, dy.f = BY - AY, l2.f = dx * dx + dy * dy, t.f, ex.f, ey.f
  If l2 > 0 : t = ((PX - AX) * dx + (PY - AY) * dy) / l2 : EndIf
  If t < 0 : t = 0 : ElseIf t > 1 : t = 1 : EndIf
  ex = AX + t * dx - PX : ey = AY + t * dy - PY
  ProcedureReturn ex * ex + ey * ey
EndProcedure

; Circle against a convex polygon: the centre inside, or an edge nearer than the radius.
Procedure.i GLTile_CirclePoly(CX.f, CY.f, Radius.f, *P.GLTilePoly)
  Protected i.i, j.i, nx.f, ny.f, inside.i = #True
  For i = 0 To *P\N - 1
    GLTile_EdgeNormal(*P, i, @nx, @ny)
    If nx * (CX - *P\X[i]) + ny * (CY - *P\Y[i]) >= 0 : inside = #False : Break : EndIf
  Next
  If inside : ProcedureReturn #True : EndIf
  For i = 0 To *P\N - 1
    j = (i + 1) % *P\N
    If GLTile_PointSegment2(CX, CY, *P\X[i], *P\Y[i], *P\X[j], *P\Y[j]) < Radius * Radius : ProcedureReturn #True : EndIf
  Next
  ProcedureReturn #False
EndProcedure

; Segment against a convex polygon by clipping (Cyrus-Beck). *T gets where it enters.
Procedure.i GLTile_LinePoly(X1.f, Y1.f, X2.f, Y2.f, *P.GLTilePoly, *T.Float)
  Protected i.i, nx.f, ny.f, num.f, den.f, t0.f = 0.0, t1.f = 1.0, t.f
  For i = 0 To *P\N - 1
    GLTile_EdgeNormal(*P, i, @nx, @ny)
    num = nx * (X1 - *P\X[i]) + ny * (Y1 - *P\Y[i])      ; < 0 inside
    den = nx * (X2 - X1) + ny * (Y2 - Y1)
    If den = 0
      If num >= 0 : ProcedureReturn #False : EndIf
    Else
      t = -num / den
      If den < 0
        If t > t0 : t0 = t : EndIf
      Else
        If t < t1 : t1 = t : EndIf
      EndIf
    EndIf
  Next
  If X1 = X2 And Y1 = Y2                                ; a point: inside every edge
    If *T : *T\f = 0.0 : EndIf
    ProcedureReturn #True
  EndIf
  If t0 >= t1 : ProcedureReturn #False : EndIf
  If *T : *T\f = t0 : EndIf
  ProcedureReturn #True
EndProcedure

; The cells a bounding box can touch, clipped to the map. False if none.
Procedure.i GLTile_Candidates(*Map.GLTileMap, MapX.f, MapY.f, X0.f, Y0.f, X1.f, Y1.f, *R.GLTileRange)
  *R\Col0 = Round((X0 - MapX) / *Map\TileW, #PB_Round_Down) : *R\Col1 = Round((X1 - MapX) / *Map\TileW, #PB_Round_Down)
  *R\Row0 = Round((Y0 - MapY) / *Map\TileH, #PB_Round_Down) : *R\Row1 = Round((Y1 - MapY) / *Map\TileH, #PB_Round_Down)
  If *R\Col0 < 0 : *R\Col0 = 0 : EndIf
  If *R\Row0 < 0 : *R\Row0 = 0 : EndIf
  If *R\Col1 >= *Map\Width : *R\Col1 = *Map\Width - 1 : EndIf
  If *R\Row1 >= *Map\Height : *R\Row1 = *Map\Height - 1 : EndIf
  ProcedureReturn Bool(*R\Col0 <= *R\Col1 And *R\Row0 <= *R\Row1)
EndProcedure

#GLTile_ShapeBox = 0 : #GLTile_ShapeCircle = 1 : #GLTile_ShapeLine = 2

; The one walk the three queries share.
Procedure.i GLTile_Query(*Map.GLTileMap, MapX.f, MapY.f, Shape.i, A.f, B.f, C.f, D.f, List Hits.GLTileHit())
  Protected Rg.GLTileRange, Sq.GLTilePoly, Tri.GLTilePoly, cx.i, cy.i, cell.i, tile.i, kind.i, orient.i
  Protected x0.f, y0.f, touch.i, blocks.i, tCell.f, tSolid.f, any.i, nx.f, ny.f, *H.GLTileHit
  Protected bx0.f, by0.f, bx1.f, by1.f
  ClearList(Hits())
  If Not *Map Or Not *Map\Set : ProcedureReturn #False : EndIf
  Select Shape
    Case #GLTile_ShapeBox    : bx0 = A : by0 = B : bx1 = A + C : by1 = B + D
    Case #GLTile_ShapeCircle : bx0 = A - C : by0 = B - C : bx1 = A + C : by1 = B + C
    Case #GLTile_ShapeLine
      bx0 = A : bx1 = C : by0 = B : by1 = D
      If bx1 < bx0 : Swap bx0, bx1 : EndIf
      If by1 < by0 : Swap by0, by1 : EndIf
  EndSelect
  If Not GLTile_Candidates(*Map, MapX, MapY, bx0, by0, bx1, by1, @Rg) : ProcedureReturn #False : EndIf
  For cy = Rg\Row0 To Rg\Row1
    For cx = Rg\Col0 To Rg\Col1
      cell = PeekU(*Map\Cells + (cy * *Map\Width + cx) * 2)
      tile = (cell & #GL_TILE_NUMBER) - 1
      If tile < 0 : Continue : EndIf
      orient = cell & #GL_TILE_ORIENT
      kind = 0
      If tile < *Map\Set\Count : kind = *Map\Set\Collide(tile) : EndIf
      x0 = MapX + cx * *Map\TileW : y0 = MapY + cy * *Map\TileH
      GLTile_CellPoly(@Sq, x0, y0, *Map\TileW, *Map\TileH, 0, #False)
      Select Shape
        Case #GLTile_ShapeBox    : touch = GLTile_BoxPoly(A, B, A + C, B + D, @Sq)
        Case #GLTile_ShapeCircle : touch = GLTile_CirclePoly(A, B, C, @Sq)
        Case #GLTile_ShapeLine   : touch = GLTile_LinePoly(A, B, C, D, @Sq, @tCell)
      EndSelect
      If Not touch : Continue : EndIf
      blocks = #False : tSolid = tCell
      If kind & #GL_TILE_SLOPE
        GLTile_CellPoly(@Tri, x0, y0, *Map\TileW, *Map\TileH, orient, #True)
        Select Shape
          Case #GLTile_ShapeBox    : blocks = GLTile_BoxPoly(A, B, A + C, B + D, @Tri)
          Case #GLTile_ShapeCircle : blocks = GLTile_CirclePoly(A, B, C, @Tri)
          Case #GLTile_ShapeLine   : blocks = GLTile_LinePoly(A, B, C, D, @Tri, @tSolid)
        EndSelect
      ElseIf kind & #GL_TILE_SOLID
        blocks = #True
      EndIf
      *H = AddElement(Hits())
      *H\Col = cx : *H\Row = cy : *H\Tile = tile : *H\Flags = cell & #GL_TILE_ORIENT
      *H\Kind = kind : *H\Blocks = blocks
      If Shape = #GLTile_ShapeLine : *H\T = tCell : If blocks : *H\T = tSolid : EndIf : EndIf
      If kind & #GL_TILE_ONEWAY
        nx = 0 : ny = -1
        If orient & #GL_TILE_DIAG : Swap nx, ny : EndIf
        If orient & #GL_TILE_FLIPX : nx = -nx : EndIf
        If orient & #GL_TILE_FLIPY : ny = -ny : EndIf
        *H\NormalX = nx : *H\NormalY = ny
      EndIf
      If blocks : any = #True : EndIf
    Next
  Next
  If Shape = #GLTile_ShapeLine : SortStructuredList(Hits(), #PB_Sort_Ascending, OffsetOf(GLTileHit\T), #PB_Float) : EndIf
  ProcedureReturn any
EndProcedure

; Every non-empty cell the box X, Y, W, H overlaps; #True if it is inside a solid part.
Procedure.b CheckCollisionTileBox(*Map.GLTileMap, MapX.f, MapY.f, X.f, Y.f, W.f, H.f, List Hits.GLTileHit())
  ProcedureReturn GLTile_Query(*Map, MapX, MapY, #GLTile_ShapeBox, X, Y, W, H, Hits())
EndProcedure

; Every non-empty cell the circle overlaps; #True if it is inside a solid part.
Procedure.b CheckCollisionTileCircle(*Map.GLTileMap, MapX.f, MapY.f, CX.f, CY.f, Radius.f, List Hits.GLTileHit())
  ProcedureReturn GLTile_Query(*Map, MapX, MapY, #GLTile_ShapeCircle, CX, CY, Radius, 0, Hits())
EndProcedure

; Every non-empty cell the segment crosses, nearest first (by T); #True if
; it passes through a solid part - the first such hit is where it is stopped.
Procedure.b CheckCollisionTileLine(*Map.GLTileMap, MapX.f, MapY.f, X1.f, Y1.f, X2.f, Y2.f, List Hits.GLTileHit())
  ProcedureReturn GLTile_Query(*Map, MapX, MapY, #GLTile_ShapeLine, X1, Y1, X2, Y2, Hits())
EndProcedure

; The same against a tile layer, where the layer is drawn now.
Procedure.b CheckCollisionLayerBox(*Layer.GLLayer, X.f, Y.f, W.f, H.f, List Hits.GLTileHit())
  Protected OX.f, OY.f
  ClearList(Hits())
  If Not *Layer Or *Layer\Kind <> #GL_LAYER_TILES : ProcedureReturn #False : EndIf
  GL_LayerOrigin(*Layer, @OX, @OY)
  ProcedureReturn CheckCollisionTileBox(*Layer\Map, OX, OY, X, Y, W, H, Hits())
EndProcedure

Procedure.b CheckCollisionLayerCircle(*Layer.GLLayer, CX.f, CY.f, Radius.f, List Hits.GLTileHit())
  Protected OX.f, OY.f
  ClearList(Hits())
  If Not *Layer Or *Layer\Kind <> #GL_LAYER_TILES : ProcedureReturn #False : EndIf
  GL_LayerOrigin(*Layer, @OX, @OY)
  ProcedureReturn CheckCollisionTileCircle(*Layer\Map, OX, OY, CX, CY, Radius, Hits())
EndProcedure

Procedure.b CheckCollisionLayerLine(*Layer.GLLayer, X1.f, Y1.f, X2.f, Y2.f, List Hits.GLTileHit())
  Protected OX.f, OY.f
  ClearList(Hits())
  If Not *Layer Or *Layer\Kind <> #GL_LAYER_TILES : ProcedureReturn #False : EndIf
  GL_LayerOrigin(*Layer, @OX, @OY)
  ProcedureReturn CheckCollisionTileLine(*Layer\Map, OX, OY, X1, Y1, X2, Y2, Hits())
EndProcedure
