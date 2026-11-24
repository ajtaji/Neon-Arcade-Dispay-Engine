; ============================================================================
; GlTiles.pbi - Tile Sets, Tile Maps, Animated Tiles and the Map File
; ============================================================================
; Include after GlSpriteFunctions.pbi. Nothing above this file was changed; a
; program that does not call these is exactly as before.
;
; --- THE MODEL ---
; A TILE SET is a sprite sheet cut into equal tiles: tile size, the spacing
; between tiles and the margin round the sheet, numbered left to right, top to
; bottom from 0. A set holds at most #GL_TILE_MAX tiles.
;
; A TILE MAP is a grid of 16-bit cells. One cell:
;
;   bits  0-9   tile number + 1 (0 = empty cell, 1..1023 = tiles 0..1022)
;   bit   10    #GL_TILE_FLIPX   mirror left-right
;   bit   11    #GL_TILE_FLIPY   mirror top-bottom
;   bit   12    #GL_TILE_DIAG    swap x and y (with the flips: the rotations)
;   bits 13-15  palette slot 0-7 (indexed tile sets, GlPalette.pbi)
;
; The orientation is applied to the picture as DIAG first, then FLIPX, then
; FLIPY - the order Tiled uses, so #GL_TILE_ROT90 = DIAG | FLIPX turns the
; tile a quarter clockwise. The program never handles the +1: GL_TileMapSet and
; GL_TileMapGet speak tile numbers, and #GL_TILE_EMPTY (-1) for an empty cell.
;
; --- DRAWING ---
; GL_TileMapDraw draws through the 2D camera (GL_CameraX/Y/Zoom) exactly as
; DrawGLSprite places a sprite, with the same Scaled and IgnoreCamera switches.
; Only the cells that the camera can see are submitted, into the engine's
; sprite batcher (InitSpriteBatcher; started on first use if the program has
; not), so a whole screen of one tile set is ONE glDrawArrays: a 320x240
; canvas of 16x16 tiles is at most 21 x 16 = 336 quads, and the batch holds
; GL_MaxBatch (10000) before it must draw and start again. Draw maps outside a
; program's own BeginBatch / EndBatch: they share the batcher's buffer.
; Each draw adds one to GL_StatDrawCalls per glDrawArrays it issues.
;
; --- ANIMATED TILES ---
; GL_TileSetAnimAdd gives a tile a list of frames (another tile, for so many
; milliseconds). Every cell holding that tile shows the frame for the time,
; with the cell's own orientation. The time is GL_Micros() / 1000 unless the
; program passes its own (a paused game passes a paused clock).
;
; --- THE MAP FILE (.ntm) ---
; Big-endian, so that the console engine can use the cells where they lie.
; Documented in the README and at GL_TileMapSave. Saved through GL_FileStore.
;
; --- ERRORS ---
; A procedure that cannot do what was asked returns 0 / #False and leaves the
; reason in GL_TileError().
; ============================================================================

#GL_TILE_EMPTY    = -1
#GL_TILE_MAX      = 1023          ; tiles 0..1022 fit the 10-bit cell field
#GL_TILE_NUMBER   = $03FF
#GL_TILE_FLIPX    = $0400
#GL_TILE_FLIPY    = $0800
#GL_TILE_DIAG     = $1000
#GL_TILE_ROT90    = #GL_TILE_DIAG | #GL_TILE_FLIPX
#GL_TILE_ROT180   = #GL_TILE_FLIPX | #GL_TILE_FLIPY
#GL_TILE_ROT270   = #GL_TILE_DIAG | #GL_TILE_FLIPY
#GL_TILE_ORIENT   = $1C00
#GL_TILE_PALSHIFT = 13
#GL_TILE_PALETTE  = $E000

; The palette-slot bits of a cell, for GL_TileMapSet's Flags.
Macro GL_TilePalette(Slot)
  (((Slot) & 7) << #GL_TILE_PALSHIFT)
EndMacro

Structure GLTileFrame
  Tile.l
  Ms.l
EndStructure

Structure GLTileAnim
  Count.i
  TotalMs.q
  *Frames                     ; Count x GLTileFrame
EndStructure

Structure GLTileSet
  *Sprite.GLSprite            ; the sheet (not owned: the program frees it)
  ImageW.i : ImageH.i
  TileW.i : TileH.i
  Spacing.i : Margin.i
  Columns.i : Rows.i : Count.i
  Animated.i                  ; how many tiles have frames
  Array Anim.GLTileAnim(0)    ; one per tile
EndStructure

Structure GLTileMap
  Width.i : Height.i          ; in cells
  TileW.i : TileH.i           ; in world pixels
  *Cells                      ; Width x Height unsigned words, row 0 first
  *Set.GLTileSet
EndStructure

; The cells a draw submits: columns Col0..Col1, rows Row0..Row1 (inclusive).
Structure GLTileRange
  Col0.i : Row0.i
  Col1.i : Row1.i
EndStructure

; World position -> normalised device coordinates for one draw.
Structure GLTileXform
  KX.f : CX.f
  KY.f : CY.f
EndStructure

Global GLTile_Error.s
Global GLTile_Flushes.i

Procedure.s GL_TileError()
  ProcedureReturn GLTile_Error
EndProcedure

Procedure.i GLTile_Fail(Message.s)
  GLTile_Error = Message
  ProcedureReturn 0
EndProcedure

; ============================================================================
; TILE SETS
; ============================================================================

; Cut *Sprite into TileW x TileH tiles. Spacing is the gap between tiles,
; Margin the border round the sheet, both in pixels. Returns the set or 0.
Procedure.i GL_TileSetCreate(*Sprite.GLSprite, TileW.i, TileH.i, Spacing.i = 0, Margin.i = 0)
  Protected *Set.GLTileSet, Columns.i, Rows.i
  If Not *Sprite : ProcedureReturn GLTile_Fail("GL_TileSetCreate: no sprite.") : EndIf
  If TileW < 1 Or TileH < 1 Or Spacing < 0 Or Margin < 0
    ProcedureReturn GLTile_Fail("GL_TileSetCreate: tile size must be at least 1, spacing and margin not negative.")
  EndIf
  Columns = (*Sprite\Width - 2 * Margin + Spacing) / (TileW + Spacing)
  Rows = (*Sprite\Height - 2 * Margin + Spacing) / (TileH + Spacing)
  If Columns < 1 Or Rows < 1 : ProcedureReturn GLTile_Fail("GL_TileSetCreate: the sheet holds no whole tile.") : EndIf
  If Columns * Rows > #GL_TILE_MAX
    ProcedureReturn GLTile_Fail("GL_TileSetCreate: " + Str(Columns * Rows) + " tiles; a set holds at most " + Str(#GL_TILE_MAX) + ".")
  EndIf
  *Set = AllocateStructure(GLTileSet)
  *Set\Sprite = *Sprite
  *Set\ImageW = *Sprite\Width : *Set\ImageH = *Sprite\Height
  *Set\TileW = TileW : *Set\TileH = TileH
  *Set\Spacing = Spacing : *Set\Margin = Margin
  *Set\Columns = Columns : *Set\Rows = Rows : *Set\Count = Columns * Rows
  ReDim *Set\Anim(*Set\Count - 1)
  ProcedureReturn *Set
EndProcedure

Procedure GL_TileSetAnimClear(*Set.GLTileSet, Tile.i)
  If Not *Set Or Tile < 0 Or Tile >= *Set\Count : ProcedureReturn : EndIf
  If *Set\Anim(Tile)\Frames
    FreeMemory(*Set\Anim(Tile)\Frames)
    *Set\Animated - 1
  EndIf
  *Set\Anim(Tile)\Frames = 0 : *Set\Anim(Tile)\Count = 0 : *Set\Anim(Tile)\TotalMs = 0
EndProcedure

; Free the set (not its sprite).
Procedure GL_TileSetFree(*Set.GLTileSet)
  Protected i.i
  If Not *Set : ProcedureReturn : EndIf
  For i = 0 To *Set\Count - 1 : GL_TileSetAnimClear(*Set, i) : Next
  FreeStructure(*Set)
EndProcedure

; The top-left pixel of Tile in the sheet (image rows counted from the top).
Procedure.i GL_TileSetSource(*Set.GLTileSet, Tile.i, *X.Integer, *Y.Integer)
  If Not *Set Or Tile < 0 Or Tile >= *Set\Count : ProcedureReturn #False : EndIf
  If *X : *X\i = *Set\Margin + (Tile % *Set\Columns) * (*Set\TileW + *Set\Spacing) : EndIf
  If *Y : *Y\i = *Set\Margin + (Tile / *Set\Columns) * (*Set\TileH + *Set\Spacing) : EndIf
  ProcedureReturn #True
EndProcedure

; Append one frame to Tile's animation: show FrameTile for Ms milliseconds.
; The first frame added is shown first; the list repeats.
Procedure.i GL_TileSetAnimAdd(*Set.GLTileSet, Tile.i, FrameTile.i, Ms.i)
  Protected *A.GLTileAnim, *F.GLTileFrame, *Grown
  If Not *Set Or Tile < 0 Or Tile >= *Set\Count Or FrameTile < 0 Or FrameTile >= *Set\Count
    ProcedureReturn GLTile_Fail("GL_TileSetAnimAdd: tile out of range.")
  EndIf
  If Ms < 1 Or Ms > 65535 : ProcedureReturn GLTile_Fail("GL_TileSetAnimAdd: a frame lasts 1 to 65535 ms.") : EndIf
  *A = @*Set\Anim(Tile)
  If *A\Count >= 65535 : ProcedureReturn GLTile_Fail("GL_TileSetAnimAdd: too many frames.") : EndIf
  If *A\Frames
    *Grown = ReAllocateMemory(*A\Frames, (*A\Count + 1) * SizeOf(GLTileFrame), #PB_Memory_NoClear)
  Else
    *Grown = AllocateMemory(SizeOf(GLTileFrame), #PB_Memory_NoClear)
    If *Grown : *Set\Animated + 1 : EndIf
  EndIf
  If Not *Grown : ProcedureReturn GLTile_Fail("GL_TileSetAnimAdd: out of memory.") : EndIf
  *A\Frames = *Grown
  *F = *A\Frames + *A\Count * SizeOf(GLTileFrame)
  *F\Tile = FrameTile : *F\Ms = Ms
  *A\Count + 1 : *A\TotalMs + Ms
  ProcedureReturn #True
EndProcedure

; The tile shown for Tile at TimeMs (Tile itself when it has no frames).
Procedure.i GL_TileSetAnimFrame(*Set.GLTileSet, Tile.i, TimeMs.q)
  Protected *A.GLTileAnim, *F.GLTileFrame, t.q, i.i
  If Not *Set Or Tile < 0 Or Tile >= *Set\Count : ProcedureReturn Tile : EndIf
  *A = @*Set\Anim(Tile)
  If *A\Count = 0 : ProcedureReturn Tile : EndIf
  t = TimeMs % *A\TotalMs
  If t < 0 : t + *A\TotalMs : EndIf
  *F = *A\Frames
  For i = 0 To *A\Count - 1
    If t < *F\Ms : ProcedureReturn *F\Tile : EndIf
    t - *F\Ms
    *F + SizeOf(GLTileFrame)
  Next
  ProcedureReturn Tile
EndProcedure

; ============================================================================
; TILE MAPS
; ============================================================================

; An empty Width x Height map whose cells are the size of *Set's tiles.
Procedure.i GL_TileMapCreate(Width.i, Height.i, *Set.GLTileSet)
  Protected *Map.GLTileMap
  If Not *Set : ProcedureReturn GLTile_Fail("GL_TileMapCreate: no tile set.") : EndIf
  If Width < 1 Or Height < 1 Or Width > 65535 Or Height > 65535
    ProcedureReturn GLTile_Fail("GL_TileMapCreate: a map is 1 to 65535 cells each way.")
  EndIf
  *Map = AllocateStructure(GLTileMap)
  *Map\Cells = AllocateMemory(Width * Height * 2)
  If Not *Map\Cells : FreeStructure(*Map) : ProcedureReturn GLTile_Fail("GL_TileMapCreate: out of memory.") : EndIf
  *Map\Width = Width : *Map\Height = Height
  *Map\TileW = *Set\TileW : *Map\TileH = *Set\TileH
  *Map\Set = *Set
  ProcedureReturn *Map
EndProcedure

Procedure GL_TileMapFree(*Map.GLTileMap)
  If Not *Map : ProcedureReturn : EndIf
  If *Map\Cells : FreeMemory(*Map\Cells) : EndIf
  FreeStructure(*Map)
EndProcedure

; The raw 16-bit cell (0 outside the map).
Procedure.i GL_TileMapCell(*Map.GLTileMap, X.i, Y.i)
  If Not *Map Or X < 0 Or Y < 0 Or X >= *Map\Width Or Y >= *Map\Height : ProcedureReturn 0 : EndIf
  ProcedureReturn PeekU(*Map\Cells + (Y * *Map\Width + X) * 2)
EndProcedure

Procedure.i GL_TileMapSetCell(*Map.GLTileMap, X.i, Y.i, Cell.i)
  If Not *Map Or X < 0 Or Y < 0 Or X >= *Map\Width Or Y >= *Map\Height : ProcedureReturn #False : EndIf
  PokeU(*Map\Cells + (Y * *Map\Width + X) * 2, Cell & $FFFF)
  ProcedureReturn #True
EndProcedure

; Put Tile (or #GL_TILE_EMPTY) at X, Y. Flags: #GL_TILE_FLIPX / FLIPY / DIAG /
; ROT90 / ROT180 / ROT270, | GL_TilePalette(slot). Takes effect on the next draw.
Procedure.i GL_TileMapSet(*Map.GLTileMap, X.i, Y.i, Tile.i, Flags.i = 0)
  If Tile = #GL_TILE_EMPTY : ProcedureReturn GL_TileMapSetCell(*Map, X, Y, 0) : EndIf
  If Tile < 0 Or Tile >= #GL_TILE_MAX : ProcedureReturn #False : EndIf
  ProcedureReturn GL_TileMapSetCell(*Map, X, Y, (Tile + 1) | (Flags & (#GL_TILE_ORIENT | #GL_TILE_PALETTE)))
EndProcedure

; The tile at X, Y, or #GL_TILE_EMPTY (also outside the map).
Procedure.i GL_TileMapGet(*Map.GLTileMap, X.i, Y.i)
  ProcedureReturn (GL_TileMapCell(*Map, X, Y) & #GL_TILE_NUMBER) - 1
EndProcedure

; The orientation and palette bits at X, Y.
Procedure.i GL_TileMapFlags(*Map.GLTileMap, X.i, Y.i)
  ProcedureReturn GL_TileMapCell(*Map, X, Y) & (#GL_TILE_ORIENT | #GL_TILE_PALETTE)
EndProcedure

; Fill a W x H block (clipped to the map).
Procedure GL_TileMapFill(*Map.GLTileMap, X.i, Y.i, W.i, H.i, Tile.i, Flags.i = 0)
  Protected cx.i, cy.i
  If Not *Map : ProcedureReturn : EndIf
  For cy = Y To Y + H - 1
    For cx = X To X + W - 1
      GL_TileMapSet(*Map, cx, cy, Tile, Flags)
    Next
  Next
EndProcedure

; ============================================================================
; WHAT THE CAMERA SEES
; ============================================================================

Procedure GLTile_Canvas(Scaled.b, *W.Float, *H.Float)
  *W\f = Util_WinWidth : *H\f = Util_WinHeight
  If Scaled : *W\f = Util_BaseWidth : *H\f = Util_BaseHeight : EndIf
EndProcedure

; The same placement as DrawGLSprite: screen = C + (world - camera - C) * zoom.
Procedure GLTile_MakeXform(*X.GLTileXform, Scaled.b, IgnoreCamera.b)
  Protected TW.f, TH.f, Z.f = GL_CameraZoom, CamX.f = GL_CameraX, CamY.f = GL_CameraY
  GLTile_Canvas(Scaled, @TW, @TH)
  If IgnoreCamera : Z = 1.0 : CamX = 0.0 : CamY = 0.0 : EndIf
  *X\KX = 2.0 * Z / TW
  *X\CX = 2.0 * ((TW / 2.0) * (1.0 - Z) - CamX * Z) / TW - 1.0
  *X\KY = -2.0 * Z / TH
  *X\CY = 1.0 - 2.0 * ((TH / 2.0) * (1.0 - Z) - CamY * Z) / TH
EndProcedure

; The world rectangle on the canvas: X0..X1, Y0..Y1. False when zoom <= 0.
Procedure.i GLTile_VisibleWorld(Scaled.b, IgnoreCamera.b, *X0.Float, *Y0.Float, *X1.Float, *Y1.Float)
  Protected TW.f, TH.f, Z.f = GL_CameraZoom
  GLTile_Canvas(Scaled, @TW, @TH)
  If IgnoreCamera
    *X0\f = 0.0 : *Y0\f = 0.0 : *X1\f = TW : *Y1\f = TH
    ProcedureReturn #True
  EndIf
  If Z <= 0.0 : ProcedureReturn #False : EndIf
  *X0\f = GL_CameraX + (TW / 2.0) * (1.0 - 1.0 / Z) : *X1\f = GL_CameraX + (TW / 2.0) * (1.0 + 1.0 / Z)
  *Y0\f = GL_CameraY + (TH / 2.0) * (1.0 - 1.0 / Z) : *Y1\f = GL_CameraY + (TH / 2.0) * (1.0 + 1.0 / Z)
  ProcedureReturn #True
EndProcedure

; Which cells of *Map, placed with its top-left at MapX, MapY, are on the
; canvas. Returns how many (0 = none; then Col1 < Col0 or Row1 < Row0).
Procedure.i GL_TileMapRange(*Map.GLTileMap, MapX.f, MapY.f, *R.GLTileRange, Scaled.b = #False, IgnoreCamera.b = #False)
  Protected X0.f, Y0.f, X1.f, Y1.f
  If Not *R : ProcedureReturn 0 : EndIf
  *R\Col0 = 0 : *R\Row0 = 0 : *R\Col1 = -1 : *R\Row1 = -1
  If Not *Map : ProcedureReturn 0 : EndIf
  If Not GLTile_VisibleWorld(Scaled, IgnoreCamera, @X0, @Y0, @X1, @Y1) : ProcedureReturn 0 : EndIf
  *R\Col0 = Round((X0 - MapX) / *Map\TileW, #PB_Round_Down)
  *R\Col1 = Round((X1 - MapX) / *Map\TileW, #PB_Round_Up) - 1
  *R\Row0 = Round((Y0 - MapY) / *Map\TileH, #PB_Round_Down)
  *R\Row1 = Round((Y1 - MapY) / *Map\TileH, #PB_Round_Up) - 1
  If *R\Col0 < 0 : *R\Col0 = 0 : EndIf
  If *R\Row0 < 0 : *R\Row0 = 0 : EndIf
  If *R\Col1 > *Map\Width - 1 : *R\Col1 = *Map\Width - 1 : EndIf
  If *R\Row1 > *Map\Height - 1 : *R\Row1 = *Map\Height - 1 : EndIf
  If *R\Col1 < *R\Col0 Or *R\Row1 < *R\Row0 : ProcedureReturn 0 : EndIf
  ProcedureReturn (*R\Col1 - *R\Col0 + 1) * (*R\Row1 - *R\Row0 + 1)
EndProcedure

; ============================================================================
; THE QUAD WRITER - into the engine's sprite batch (GlSpriteFunctions.pbi)
; ============================================================================

; Draw what is in the batch and start it again. Counted in GL_StatDrawCalls.
Procedure GLTile_Flush()
  If GL_BatchCount = 0 : ProcedureReturn : EndIf
  EndBatch()
  GL_StatDrawCalls + 1 : GL_StatBufferUploads + 1
  GLTile_Flushes + 1
  GL_BatchCount = 0
EndProcedure

; Where the picture's corner (S, T) (0..1, T down) lands for an orientation:
; undo FLIPY, then FLIPX, then DIAG.
Macro GLTile_SourceCorner(Orient, Sx, Ty, OutS, OutT)
  OutS = Sx : OutT = Ty
  If Orient & #GL_TILE_FLIPY : OutT = 1.0 - OutT : EndIf
  If Orient & #GL_TILE_FLIPX : OutS = 1.0 - OutS : EndIf
  If Orient & #GL_TILE_DIAG : Swap OutS, OutT : EndIf
EndMacro

Macro GLTile_Vertex(Ptr, NX, NY, U, V, R, G, B, A)
  Ptr\f = NX : Ptr + 4 : Ptr\f = NY : Ptr + 4 : Ptr\f = U : Ptr + 4 : Ptr\f = V : Ptr + 4
  Ptr\f = R : Ptr + 4 : Ptr\f = G : Ptr + 4 : Ptr\f = B : Ptr + 4 : Ptr\f = A : Ptr + 4
EndMacro

; One axis-aligned quad, world X0,Y0 - X1,Y1, showing the picture rectangle
; U0..U1 across and VTop..VBottom down, turned by Orient.
Procedure GLTile_Quad(*X.GLTileXform, X0.f, Y0.f, X1.f, Y1.f, U0.f, VTop.f, U1.f, VBottom.f, Orient.i, R.f, G.f, B.f, A.f)
  Protected *P.Float, s.f, t.f
  Protected uTL.f, vTL.f, uTR.f, vTR.f, uBL.f, vBL.f, uBR.f, vBR.f
  Protected nx0.f = X0 * *X\KX + *X\CX, nx1.f = X1 * *X\KX + *X\CX
  Protected ny0.f = Y0 * *X\KY + *X\CY, ny1.f = Y1 * *X\KY + *X\CY
  If GL_BatchCount >= GL_MaxBatch : GLTile_Flush() : EndIf
  GLTile_SourceCorner(Orient, 0.0, 0.0, s, t) : uTL = U0 + (U1 - U0) * s : vTL = VTop + (VBottom - VTop) * t
  GLTile_SourceCorner(Orient, 1.0, 0.0, s, t) : uTR = U0 + (U1 - U0) * s : vTR = VTop + (VBottom - VTop) * t
  GLTile_SourceCorner(Orient, 0.0, 1.0, s, t) : uBL = U0 + (U1 - U0) * s : vBL = VTop + (VBottom - VTop) * t
  GLTile_SourceCorner(Orient, 1.0, 1.0, s, t) : uBR = U0 + (U1 - U0) * s : vBR = VTop + (VBottom - VTop) * t
  *P = *GL_BatchBuffer + GL_BatchCount * 192
  GLTile_Vertex(*P, nx0, ny0, uTL, vTL, R, G, B, A)
  GLTile_Vertex(*P, nx0, ny1, uBL, vBL, R, G, B, A)
  GLTile_Vertex(*P, nx1, ny0, uTR, vTR, R, G, B, A)
  GLTile_Vertex(*P, nx0, ny1, uBL, vBL, R, G, B, A)
  GLTile_Vertex(*P, nx1, ny1, uBR, vBR, R, G, B, A)
  GLTile_Vertex(*P, nx1, ny0, uTR, vTR, R, G, B, A)
  GL_BatchCount + 1
EndProcedure

; The texture coordinates of a picture rectangle given in image pixels with
; rows counted from the top, on either OS (see #GL_SpriteRowsBottomUp).
Procedure GLTile_SourceUV(ImageW.i, ImageH.i, SX.f, SY.f, SW.f, SH.f, *U0.Float, *VTop.Float, *U1.Float, *VBottom.Float)
  *U0\f = SX / ImageW : *U1\f = (SX + SW) / ImageW
  CompilerIf #GL_SpriteRowsBottomUp
    *VTop\f = (ImageH - SY) / ImageH : *VBottom\f = (ImageH - SY - SH) / ImageH
  CompilerElse
    *VTop\f = SY / ImageH : *VBottom\f = (SY + SH) / ImageH
  CompilerEndIf
EndProcedure

Procedure.q GLTile_Now()
  ProcedureReturn GL_Micros() / 1000
EndProcedure

; Add the visible cells of *Map (top-left at MapX, MapY) to the CURRENT batch,
; whose texture must be the map's tile sheet. Returns the quads added. Several
; maps on one sheet can share one batch this way; GL_TileMapDraw is the usual
; call. TimeMs < 0 reads the clock.
Procedure.i GL_TileMapSubmit(*Map.GLTileMap, MapX.f, MapY.f, R.f = 1.0, G.f = 1.0, B.f = 1.0, A.f = 1.0, Scaled.b = #False, IgnoreCamera.b = #False, TimeMs.q = -1)
  Protected Rg.GLTileRange, Xf.GLTileXform, *Set.GLTileSet, cx.i, cy.i, cell.i, tile.i, n.i
  Protected sx.i, sy.i, x0.f, y0.f, x1.f, y1.f, u0.f, vt.f, u1.f, vb.f, *Row
  If Not *Map Or Not *Map\Set : ProcedureReturn 0 : EndIf
  *Set = *Map\Set
  If GL_TileMapRange(*Map, MapX, MapY, @Rg, Scaled, IgnoreCamera) = 0 : ProcedureReturn 0 : EndIf
  If *Set\Animated And TimeMs < 0 : TimeMs = GLTile_Now() : EndIf
  GLTile_MakeXform(@Xf, Scaled, IgnoreCamera)
  For cy = Rg\Row0 To Rg\Row1
    y0 = MapY + cy * *Map\TileH : y1 = MapY + (cy + 1) * *Map\TileH
    *Row = *Map\Cells + (cy * *Map\Width) * 2
    For cx = Rg\Col0 To Rg\Col1
      cell = PeekU(*Row + cx * 2)
      tile = (cell & #GL_TILE_NUMBER) - 1
      If tile < 0 Or tile >= *Set\Count : Continue : EndIf
      If *Set\Animated : tile = GL_TileSetAnimFrame(*Set, tile, TimeMs) : EndIf
      sx = *Set\Margin + (tile % *Set\Columns) * (*Set\TileW + *Set\Spacing)
      sy = *Set\Margin + (tile / *Set\Columns) * (*Set\TileH + *Set\Spacing)
      GLTile_SourceUV(*Set\ImageW, *Set\ImageH, sx, sy, *Set\TileW, *Set\TileH, @u0, @vt, @u1, @vb)
      x0 = MapX + cx * *Map\TileW : x1 = MapX + (cx + 1) * *Map\TileW
      GLTile_Quad(@Xf, x0, y0, x1, y1, u0, vt, u1, vb, cell & #GL_TILE_ORIENT, R, G, B, A)
      n + 1
    Next
  Next
  ProcedureReturn n
EndProcedure

; Draw the visible part of *Map with its top-left at MapX, MapY (world, or
; canvas when IgnoreCamera). R, G, B, A tint every tile. Returns the number
; of glDrawArrays issued (1 for any screenful that fits the batch).
Procedure.i GL_TileMapDraw(*Map.GLTileMap, MapX.f = 0.0, MapY.f = 0.0, R.f = 1.0, G.f = 1.0, B.f = 1.0, A.f = 1.0, Scaled.b = #False, IgnoreCamera.b = #False, TimeMs.q = -1)
  If Not *Map Or Not *Map\Set Or Not *Map\Set\Sprite : ProcedureReturn 0 : EndIf
  If Not GL_BatchShader : InitSpriteBatcher() : EndIf
  GLTile_Flushes = 0
  GL_CurrentBatchTexture = *Map\Set\Sprite\TextureID : GL_BatchCount = 0
  GL_TileMapSubmit(*Map, MapX, MapY, R, G, B, A, Scaled, IgnoreCamera, TimeMs)
  GLTile_Flush()
  ProcedureReturn GLTile_Flushes
EndProcedure

; ============================================================================
; THE MAP FILE
; ============================================================================
; All numbers big-endian. A file is a header and chunks:
;
;   0   4  "NTMP"
;   4   2  version (1)
;   6   2  number of chunks
;   then each chunk: 4-byte id, 4-byte payload length, the payload, and zero
;   bytes to the next multiple of 4. A reader skips ids it does not know.
;
;   "MAP "  width (2), height (2), tile width (2), tile height (2), then
;           width x height cells (2 each) as above, row 0 first. One chunk per
;           tile layer, back to front.
;   "ANIM"  entries (2); each: tile (2), frames (2), frames x (tile (2), ms (2))
;   "TFLG"  count (2), then count collision bytes, one per tile (GlLayers.pbi)

Procedure GLTile_Put16(*P, Value.i)
  PokeA(*P, (Value >> 8) & $FF) : PokeA(*P + 1, Value & $FF)
EndProcedure

Procedure GLTile_Put32(*P, Value.i)
  PokeA(*P, (Value >> 24) & $FF) : PokeA(*P + 1, (Value >> 16) & $FF)
  PokeA(*P + 2, (Value >> 8) & $FF) : PokeA(*P + 3, Value & $FF)
EndProcedure

Procedure.i GLTile_Get16(*P)
  ProcedureReturn (PeekA(*P) << 8) | PeekA(*P + 1)
EndProcedure

Procedure.i GLTile_Get32(*P)
  ProcedureReturn (PeekA(*P) << 24) | (PeekA(*P + 1) << 16) | (PeekA(*P + 2) << 8) | PeekA(*P + 3)
EndProcedure

; Write Size bytes to Path through GL_FileStore: into a new "Path.new",
; then put it in place of Path. The old file is not touched until the new
; one is complete on disk.
Procedure.i GLTile_StoreFile(Path.s, *Bytes, Size.i)
  Protected Temp.s = Path + ".new"
  If FileSize(Temp) >= 0 And Not DeleteFile(Temp) : ProcedureReturn GLTile_Fail("Cannot remove the old " + Temp) : EndIf
  If Not GL_FileStore(Temp, *Bytes, Size, #True) : ProcedureReturn GLTile_Fail("Cannot write " + Temp) : EndIf
  If FileSize(Path) >= 0 And Not DeleteFile(Path)
    DeleteFile(Temp)
    ProcedureReturn GLTile_Fail("Cannot replace " + Path)
  EndIf
  If Not RenameFile(Temp, Path) : ProcedureReturn GLTile_Fail("Cannot rename " + Temp + " to " + Path) : EndIf
  ProcedureReturn #True
EndProcedure

; The whole file in memory (caller frees), or 0.
Procedure.i GLTile_ReadFile(Path.s, *Size.Integer)
  Protected f.i, *Buf, n.i
  f = ReadFile(#PB_Any, Path)
  If Not f : ProcedureReturn GLTile_Fail("Cannot open " + Path) : EndIf
  n = Lof(f)
  If n < 8 Or n > $7FFFFFFF : CloseFile(f) : ProcedureReturn GLTile_Fail(Path + " is not a tile map file.") : EndIf
  *Buf = AllocateMemory(n, #PB_Memory_NoClear)
  If Not *Buf : CloseFile(f) : ProcedureReturn GLTile_Fail("Out of memory reading " + Path) : EndIf
  If ReadData(f, *Buf, n) <> n : CloseFile(f) : FreeMemory(*Buf) : ProcedureReturn GLTile_Fail("Cannot read " + Path) : EndIf
  CloseFile(f)
  If PeekA(*Buf) <> 'N' Or PeekA(*Buf + 1) <> 'T' Or PeekA(*Buf + 2) <> 'M' Or PeekA(*Buf + 3) <> 'P' Or GLTile_Get16(*Buf + 4) <> 1
    FreeMemory(*Buf) : ProcedureReturn GLTile_Fail(Path + " is not a version 1 tile map file.")
  EndIf
  *Size\i = n
  ProcedureReturn *Buf
EndProcedure

; Find chunk Id number Index (0 = first) in a file image. Returns the payload
; offset and puts its length in *Length, or -1.
Procedure.i GLTile_FindChunk(*Buf, Size.i, Id.s, Index.i, *Length.Integer)
  Protected at.i = 8, count.i = GLTile_Get16(*Buf + 6), i.i, len.i, seen.i
  For i = 1 To count
    If at + 8 > Size : ProcedureReturn -1 : EndIf
    len = GLTile_Get32(*Buf + at + 4)
    If len < 0 Or at + 8 + len > Size : ProcedureReturn -1 : EndIf
    If PeekS(*Buf + at, 4, #PB_Ascii) = Id
      If seen = Index : *Length\i = len : ProcedureReturn at + 8 : EndIf
      seen + 1
    EndIf
    at + 8 + ((len + 3) & ~3)
  Next
  ProcedureReturn -1
EndProcedure

; How many tile layers ("MAP " chunks) the file holds, or -1.
Procedure.i GL_TileMapFileLayers(Path.s)
  Protected Size.i, *Buf = GLTile_ReadFile(Path, @Size), n.i, len.i
  If Not *Buf : ProcedureReturn -1 : EndIf
  While GLTile_FindChunk(*Buf, Size, "MAP ", n, @len) >= 0 : n + 1 : Wend
  FreeMemory(*Buf)
  ProcedureReturn n
EndProcedure

; Bytes of the "ANIM" payload for *Set, 0 when nothing is animated.
Procedure.i GLTile_AnimBytes(*Set.GLTileSet)
  Protected i.i, n.i
  If Not *Set Or *Set\Animated = 0 : ProcedureReturn 0 : EndIf
  n = 2
  For i = 0 To *Set\Count - 1
    If *Set\Anim(i)\Count : n + 4 + 4 * *Set\Anim(i)\Count : EndIf
  Next
  ProcedureReturn n
EndProcedure

; Extra chunks a tile set contributes to a saved map (GlLayers.pbi adds the
; collision table through this hook). Returns total bytes, writes at *Out
; when *Out is not 0 and counts the chunks in *Chunks.
Prototype.i GLTile_SetChunksProto(*Set.GLTileSet, *Out, *Chunks.Integer)
Global GLTile_ExtraChunks.GLTile_SetChunksProto

Procedure.i GLTile_SetChunks(*Set.GLTileSet, *Out, *Chunks.Integer)
  Protected bytes.i = GLTile_AnimBytes(*Set), i.i, k.i, *F.GLTileFrame, *P, total.i
  If bytes
    total + 8 + ((bytes + 3) & ~3) : *Chunks\i + 1
    If *Out
      PokeS(*Out, "ANIM", 4, #PB_Ascii | #PB_String_NoZero) : GLTile_Put32(*Out + 4, bytes)
      *P = *Out + 8
      GLTile_Put16(*P, *Set\Animated) : *P + 2
      For i = 0 To *Set\Count - 1
        If *Set\Anim(i)\Count
          GLTile_Put16(*P, i) : GLTile_Put16(*P + 2, *Set\Anim(i)\Count) : *P + 4
          *F = *Set\Anim(i)\Frames
          For k = 1 To *Set\Anim(i)\Count
            GLTile_Put16(*P, *F\Tile) : GLTile_Put16(*P + 2, *F\Ms) : *P + 4
            *F + SizeOf(GLTileFrame)
          Next
        EndIf
      Next
      *Out + 8 + ((bytes + 3) & ~3)
    EndIf
  EndIf
  If GLTile_ExtraChunks : total + GLTile_ExtraChunks(*Set, *Out, *Chunks) : EndIf
  ProcedureReturn total
EndProcedure

; Save *Map to Path; with SaveSet the tile set's animations (and collision
; table, when GlLayers.pbi is included) go in the same file.
Procedure.i GL_TileMapSave(*Map.GLTileMap, Path.s, SaveSet.i = #True)
  Protected mapBytes.i, total.i, chunks.i, *Buf, *P, i.i, ok.i, setBytes.i
  If Not *Map : ProcedureReturn GLTile_Fail("GL_TileMapSave: no map.") : EndIf
  mapBytes = 8 + *Map\Width * *Map\Height * 2
  If SaveSet And *Map\Set : setBytes = GLTile_SetChunks(*Map\Set, 0, @chunks) : EndIf
  chunks + 1
  total = 8 + 8 + ((mapBytes + 3) & ~3) + setBytes
  *Buf = AllocateMemory(total)
  If Not *Buf : ProcedureReturn GLTile_Fail("GL_TileMapSave: out of memory.") : EndIf
  PokeS(*Buf, "NTMP", 4, #PB_Ascii | #PB_String_NoZero) : GLTile_Put16(*Buf + 4, 1) : GLTile_Put16(*Buf + 6, chunks)
  *P = *Buf + 8
  PokeS(*P, "MAP ", 4, #PB_Ascii | #PB_String_NoZero) : GLTile_Put32(*P + 4, mapBytes)
  GLTile_Put16(*P + 8, *Map\Width) : GLTile_Put16(*P + 10, *Map\Height)
  GLTile_Put16(*P + 12, *Map\TileW) : GLTile_Put16(*P + 14, *Map\TileH)
  For i = 0 To *Map\Width * *Map\Height - 1
    GLTile_Put16(*P + 16 + i * 2, PeekU(*Map\Cells + i * 2))
  Next
  *P + 8 + ((mapBytes + 3) & ~3)
  chunks = 0
  If SaveSet And *Map\Set : GLTile_SetChunks(*Map\Set, *P, @chunks) : EndIf
  ok = GLTile_StoreFile(Path, *Buf, total)
  FreeMemory(*Buf)
  ProcedureReturn ok
EndProcedure

; Load tile layer Index (0 = the first "MAP " chunk) of Path, drawn with
; *Set, whose tile size must match the file's. Returns the map or 0.
Procedure.i GL_TileMapLoad(Path.s, *Set.GLTileSet, Index.i = 0)
  Protected Size.i, *Buf, at.i, len.i, w.i, h.i, *Map.GLTileMap, i.i
  If Not *Set : ProcedureReturn GLTile_Fail("GL_TileMapLoad: no tile set.") : EndIf
  *Buf = GLTile_ReadFile(Path, @Size)
  If Not *Buf : ProcedureReturn 0 : EndIf
  at = GLTile_FindChunk(*Buf, Size, "MAP ", Index, @len)
  If at < 0 Or len < 8 : FreeMemory(*Buf) : ProcedureReturn GLTile_Fail(Path + " has no tile layer " + Str(Index) + ".") : EndIf
  w = GLTile_Get16(*Buf + at) : h = GLTile_Get16(*Buf + at + 2)
  If len <> 8 + w * h * 2 : FreeMemory(*Buf) : ProcedureReturn GLTile_Fail(Path + ": tile layer " + Str(Index) + " has the wrong length.") : EndIf
  If GLTile_Get16(*Buf + at + 4) <> *Set\TileW Or GLTile_Get16(*Buf + at + 6) <> *Set\TileH
    FreeMemory(*Buf) : ProcedureReturn GLTile_Fail(Path + ": the tile size is not the tile set's.")
  EndIf
  *Map = GL_TileMapCreate(w, h, *Set)
  If Not *Map : FreeMemory(*Buf) : ProcedureReturn 0 : EndIf
  For i = 0 To w * h - 1
    PokeU(*Map\Cells + i * 2, GLTile_Get16(*Buf + at + 8 + i * 2))
  Next
  FreeMemory(*Buf)
  ProcedureReturn *Map
EndProcedure

; Hook for further tile-set chunks on load (GlLayers.pbi: the collision table).
Prototype.i GLTile_LoadChunksProto(*Set.GLTileSet, *Buf, Size.i)
Global GLTile_LoadExtra.GLTile_LoadChunksProto

; Replace *Set's animations (and collision table) with those saved in Path.
Procedure.i GL_TileSetLoad(*Set.GLTileSet, Path.s)
  Protected Size.i, *Buf, at.i, len.i, entries.i, e.i, tile.i, frames.i, k.i, *P, *End, ok.i = #True
  If Not *Set : ProcedureReturn GLTile_Fail("GL_TileSetLoad: no tile set.") : EndIf
  *Buf = GLTile_ReadFile(Path, @Size)
  If Not *Buf : ProcedureReturn #False : EndIf
  For k = 0 To *Set\Count - 1 : GL_TileSetAnimClear(*Set, k) : Next
  at = GLTile_FindChunk(*Buf, Size, "ANIM", 0, @len)
  If at >= 0 And len >= 2
    *P = *Buf + at : *End = *P + len
    entries = GLTile_Get16(*P) : *P + 2
    For e = 1 To entries
      If *P + 4 > *End : ok = #False : Break : EndIf
      tile = GLTile_Get16(*P) : frames = GLTile_Get16(*P + 2) : *P + 4
      If *P + frames * 4 > *End : ok = #False : Break : EndIf
      For k = 1 To frames
        If Not GL_TileSetAnimAdd(*Set, tile, GLTile_Get16(*P), GLTile_Get16(*P + 2)) : ok = #False : EndIf
        *P + 4
      Next
    Next
    If Not ok : GLTile_Fail(Path + ": the animation table does not fit this tile set.") : EndIf
  EndIf
  If ok And GLTile_LoadExtra : ok = GLTile_LoadExtra(*Set, *Buf, Size) : EndIf
  FreeMemory(*Buf)
  ProcedureReturn ok
EndProcedure
