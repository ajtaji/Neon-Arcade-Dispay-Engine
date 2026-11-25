; tilemap_file.pb - a tile set and a map with no window: cells, flips, animation, collision bytes,
; the map file written and read back. Prints what it finds.
; Build:  pbcompiler tilemap_file.pb /CONSOLE /EXE tilemap_file.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"
XIncludeFile #Engine$ + "GlTiles.pbi"
OpenConsole()

; A tile set only needs the sheet's size to be cut, so a GLSprite with no texture serves here.
Define Sheet.GLSprite
Sheet\Width = 128 : Sheet\Height = 64
Define *Set.GLTileSet = GL_TileSetCreate(@Sheet, 16, 16)            ; 8 x 4 = 32 tiles, numbered 0 .. 31
PrintN("tiles in the set: " + Str(*Set\Count) + " (" + Str(*Set\Columns) + " columns)")
Define sx.i, sy.i
GL_TileSetSource(*Set, 9, @sx, @sy)
PrintN("tile 9 is cut from the sheet at " + Str(sx) + ", " + Str(sy))

; water: tile 6 shows tiles 6, 7, 6, 7 ... for 150 ms each
GL_TileSetAnimAdd(*Set, 6, 6, 150) : GL_TileSetAnimAdd(*Set, 6, 7, 150)
PrintN("tile 6 at 0, 149, 150, 300 ms: " + Str(GL_TileSetAnimFrame(*Set, 6, 0)) + " " +
       Str(GL_TileSetAnimFrame(*Set, 6, 149)) +
       " " + Str(GL_TileSetAnimFrame(*Set, 6, 150)) + " " + Str(GL_TileSetAnimFrame(*Set, 6, 300)))
GL_TileSetCollision(*Set, 3, #GL_TILE_SOLID)
GL_TileSetCollision(*Set, 10, #GL_TILE_SLOPE)

Define *Map.GLTileMap = GL_TileMapCreate(20, 10, *Set)               ; every cell empty
GL_TileMapFill(*Map, 0, 8, 20, 2, 3)                                  ; the floor
GL_TileMapSet(*Map, 5, 7, 10)                                         ; a slope up to the right
GL_TileMapSet(*Map, 6, 7, 10, #GL_TILE_FLIPX)                         ; and its mirror
GL_TileMapSet(*Map, 9, 7, 6, #GL_TILE_ROT90)
PrintN("cell 6,7: tile " + Str(GL_TileMapGet(*Map, 6, 7)) + ", flags $" + Hex(GL_TileMapFlags(*Map, 6, 7)) +
       ", raw cell $" + Hex(GL_TileMapCell(*Map, 6, 7)))
PrintN("cell 0,0: tile " + Str(GL_TileMapGet(*Map, 0, 0)) + " (#GL_TILE_EMPTY is " + Str(#GL_TILE_EMPTY) + ")")
PrintN("outside the map: tile " + Str(GL_TileMapGet(*Map, 99, 99)))

; the file: written to Path.new, then put in place of Path
Define Path.s = GetTemporaryDirectory() + "neon_manual_example.ntm"
If Not GL_TileMapSave(*Map, Path) : PrintN("save failed: " + GL_TileError()) : End 1 : EndIf
PrintN("saved " + Str(FileSize(Path)) + " bytes, tile layers in the file: " + Str(GL_TileMapFileLayers(Path)))

Define Other.GLSprite
Other\Width = 128 : Other\Height = 64
Define *Set2.GLTileSet = GL_TileSetCreate(@Other, 16, 16)
Define *Back.GLTileMap = GL_TileMapLoad(Path, *Set2)
If *Back = 0 : PrintN("load failed: " + GL_TileError()) : End 1 : EndIf
GL_TileSetLoad(*Set2, Path)                                           ; animations and collision bytes
PrintN("read back: " + Str(*Back\Width) + " x " + Str(*Back\Height) +
       ", cell 6,7 $" + Hex(GL_TileMapCell(*Back, 6, 7)) +
       ", tile 3 collides " + Str(GL_TileSetCollisionGet(*Set2, 3)) +
       ", tile 6 frames " + Str(*Set2\Anim(6)\Count))

; a refusal: the reason is a sentence
If GL_TileMapCreate(0, 10, *Set) = 0 : PrintN("refused: " + GL_TileError()) : EndIf

DeleteFile(Path)
GL_TileMapFree(*Back) : GL_TileMapFree(*Map) : GL_TileSetFree(*Set2) : GL_TileSetFree(*Set)
