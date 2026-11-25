; tile_collision.pb - a box, a circle and a line against a tile map, and a layer's origin. No window.
; Build:  pbcompiler tile_collision.pb /CONSOLE /EXE tile_collision.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlMath.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"
XIncludeFile #Engine$ + "GlTiles.pbi"
XIncludeFile #Engine$ + "GlLayers.pbi"
OpenConsole()

#Ground = 0 : #Ledge = 1 : #Slope = 2
Define Sheet.GLSprite : Sheet\Width = 48 : Sheet\Height = 16           ; three 16 x 16 tiles
Define *Set.GLTileSet = GL_TileSetCreate(@Sheet, 16, 16)
GL_TileSetCollision(*Set, #Ground, #GL_TILE_SOLID)
GL_TileSetCollision(*Set, #Ledge, #GL_TILE_ONEWAY)
GL_TileSetCollision(*Set, #Slope, #GL_TILE_SLOPE)

Define *Map.GLTileMap = GL_TileMapCreate(10, 6, *Set)                   ; 160 x 96 world pixels
GL_TileMapFill(*Map, 0, 5, 10, 1, #Ground)                              ; row 5: y 80 .. 96
GL_TileMapFill(*Map, 3, 2, 3, 1, #Ledge)                                ; a ledge at y 32
GL_TileMapSet(*Map, 8, 4, #Slope)                           ; solid below the line (128,80)-(144,64)

NewList Hits.GLTileHit()
Procedure Report(What.s, Blocked.i, List H.GLTileHit())
  Protected s.s
  PrintN(What + ": blocked " + Str(Blocked) + ", " + Str(ListSize(H())) + " cells")
  ForEach H()
    s = "    cell " + Str(H()\Col) + "," + Str(H()\Row) + " tile " + Str(H()\Tile) + " kind " + Str(H()\Kind) +
        " blocks " + Str(H()\Blocks) + " t " + StrF(H()\T, 3)
    If H()\Kind & #GL_TILE_ONEWAY : s + " normal " + StrF(H()\NormalX, 0) + "," + StrF(H()\NormalY, 0) : EndIf
    PrintN(s)
  Next
EndProcedure

; a 10 x 16 box standing exactly on the floor (bottom edge at y 80) touches it and does not overlap it
Report("box on the floor", CheckCollisionTileBox(*Map, 0, 0, 20, 64, 10, 16, Hits()), Hits())
Report("box 1 pixel into the floor", CheckCollisionTileBox(*Map, 0, 0, 20, 65, 10, 16, Hits()), Hits())
Report("box in the ledge", CheckCollisionTileBox(*Map, 0, 0, 52, 30, 10, 16, Hits()), Hits())
Report("circle over the slope's empty half", CheckCollisionTileCircle(*Map, 0, 0, 131, 67, 2, Hits()), Hits())
Report("circle in the slope's solid half", CheckCollisionTileCircle(*Map, 0, 0, 141, 77, 2, Hits()), Hits())
Report("line down through the ledge to the floor",
       CheckCollisionTileLine(*Map, 0, 0, 56, 0, 56, 95, Hits()), Hits())

; the same map as a layer that has scrolled: the queries use where the layer is drawn now
Define *Stack.GLLayers = GL_LayersCreate()
Define *Layer.GLLayer = GL_LayerAddTiles(*Stack, *Map, 0)
Define ox.f, oy.f
*Layer\X = 100 : *Layer\ParallaxX = 0.5 : GL_CameraX = 40
GL_LayerOrigin(*Layer, @ox, @oy)
PrintN("layer origin with X 100, parallax 0.5, camera 40: " + StrF(ox, 1) + ", " + StrF(oy, 1))
Report("box on the scrolled layer", CheckCollisionLayerBox(*Layer, 140, 65, 10, 16, Hits()), Hits())
GL_LayersFree(*Stack) : GL_TileMapFree(*Map) : GL_TileSetFree(*Set)
