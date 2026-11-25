; collision.pb - the GlMath tests: boxes, circles, lines, a Bezier point, polygons by SAT, a hull and
; pixel masks. No window: the sprites here are made by hand with an alpha mask and no texture.
; Build:  pbcompiler collision.pb /CONSOLE /EXE collision.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
OpenConsole()

PrintN("boxes 0,0 10x10 and 10,0 10x10 (touching): " + Str(CheckCollisionAABB(0, 0, 10, 10, 10, 0, 10, 10)))
PrintN("boxes 0,0 10x10 and 9.5,0 10x10:           " + Str(CheckCollisionAABB(0, 0, 10, 10, 9.5, 0, 10, 10)))
PrintN("circles r5 at 0,0 and r5 at 10,0 (touching): " + Str(CheckCollisionCircle(0, 0, 5, 10, 0, 5)))

Define hx.f, hy.f
If CheckCollisionLineLine(0, 0, 10, 10, 0, 10, 10, 0, @hx, @hy)
  PrintN("the two diagonals cross at " + StrF(hx, 2) + ", " + StrF(hy, 2))
EndIf
PrintN("segments that only meet at an end: " + Str(CheckCollisionLineLine(0, 0, 10, 0, 10, 0, 10, 10)))
PrintN("segment 0,0 - 10,0 against a circle r1 at 5,1: " + Str(CheckCollisionLineCircle(0, 0, 10, 0, 5, 1, 1)))

Define bx.f, by.f
Math_CalculateBezierCubic(0.5, 0, 0, 0, 100, 100, 100, 100, 0, @bx, @by)
PrintN("Bezier (0,0)(0,100)(100,100)(100,0) at t 0.5: " + StrF(bx, 2) + ", " + StrF(by, 2))

; two squares as polygons (vertices around their centre), tested at offsets
Procedure.i Square(Half.f)
  Protected *P.GLPolygon = AllocateMemory(SizeOf(GLPolygon)), *V.GLPoint
  *P\VertexCount = 4
  *P\Vertices = AllocateMemory(4 * SizeOf(GLPoint))
  *V = *P\Vertices
  *V\x = -Half : *V\y = -Half : *V + SizeOf(GLPoint)
  *V\x = Half : *V\y = -Half : *V + SizeOf(GLPoint)
  *V\x = Half : *V\y = Half : *V + SizeOf(GLPoint)
  *V\x = -Half : *V\y = Half
  ProcedureReturn *P
EndProcedure
Define *A.GLPolygon = Square(5), *B.GLPolygon = Square(5)
PrintN("SAT squares 10 wide, centres 9 apart:  " + Str(CheckCollisionSAT(*A, 0, 0, *B, 9, 0)))
PrintN("SAT squares 10 wide, centres 11 apart: " + Str(CheckCollisionSAT(*A, 0, 0, *B, 11, 0)))

; a sprite with only an alpha mask: 8 x 8, a solid 4 x 4 block in the middle (1 = solid)
Procedure.i MaskSprite()
  Protected *S.GLSprite = AllocateMemory(SizeOf(GLSprite)), x.i, y.i
  *S\Width = 8 : *S\Height = 8 : *S\AlphaMask = AllocateMemory(64)
  For y = 2 To 5 : For x = 2 To 5 : PokeB(*S\AlphaMask + y * 8 + x, 1) : Next : Next
  ProcedureReturn *S
EndProcedure
Define *S1.GLSprite = MaskSprite(), *S2.GLSprite = MaskSprite()
PrintN("masks at 0,0 and 3,0 (the blocks overlap):  " +
       Str(CheckCollisionPixelPerfect(*S1, 0, 0, 0, 1, *S2, 3, 0, 0, 1)))
PrintN("masks at 0,0 and 5,0 (only empty pixels):   " +
       Str(CheckCollisionPixelPerfect(*S1, 0, 0, 0, 1, *S2, 5, 0, 0, 1)))

Define *Hull.GLPolygon = GenerateSpriteHull(*S1), i.i, *V.GLPoint, s.s
*V = *Hull\Vertices
For i = 1 To *Hull\VertexCount
  s + " (" + StrF(*V\x, 1) + "," + StrF(*V\y, 1) + ")" : *V + SizeOf(GLPoint)
Next
PrintN("hull of the solid block, about the sprite's centre:")
PrintN("   " + s)
FreeMemory(*Hull\Vertices) : FreeMemory(*Hull)
