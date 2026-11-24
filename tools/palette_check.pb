; Palettes and indexed images without a window: the operations (swap, cycle,
; cycle by the clock, fade to a colour, fade to a palette, their composition)
; on the colour values against references written here, the CPU look-up,
; making an indexed image from a picture, the .nti file (8 and 4 bits a pixel)
; and the palette slots of an indexed tile set in the map file.
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
Procedure.l RndColour()
  ProcedureReturn RGBA(Random(255), Random(255), Random(255), Random(255))
EndProcedure
; the fade reference, in doubles: a + (b - a) * k / 256, rounded half up
Procedure.i RefMix(a.i, b.i, Amount.f)
  Protected k.d = Round(Amount * 256.0, #PB_Round_Nearest)
  If k < 0 : k = 0 : EndIf
  If k > 256 : k = 256 : EndIf
  ProcedureReturn Int((a * (256.0 - k) + b * k) / 256.0 + 0.5)
EndProcedure

Define *P.GLPalette, *Q.GLPalette, i.i, j.i, k.i, first.i, count.i, steps.i, ok.i, c.l, o.l, amt.f
Dim Old.l(255)
Check(Bool(GL_PaletteCreate(0) = 0 And GL_PaletteCreate(257) = 0 And GL_PaletteError() <> ""), "palette size 1 to 256")
*P = GL_PaletteCreate(16)
Check(Bool(*P And *P\Count = 16 And *P\Row = -1), "a 16-colour palette, no back-end row yet")
Check(Bool(GL_PaletteSet(*P, 3, RGBA(1, 2, 3, 4)) And GL_PaletteGet(*P, 3) = RGBA(1, 2, 3, 4) And GL_PaletteShown(*P, 3) = RGBA(1, 2, 3, 4)), "set, get, shown")
Check(Bool(GL_PaletteSet(*P, 40, RGBA(9, 9, 9, 9)) And *P\Count = 41), "setting past the count grows it")
Check(Bool(GL_PaletteSet(*P, 256, 0) = #False And GL_PaletteSet(*P, -1, 0) = #False), "outside 0..255 refused")
GL_PaletteFree(*P)

; ---------------------------------------------------------------- cycling
*P = GL_PaletteCreate(256)
For i = 0 To 255 : GL_PaletteSet(*P, i, RndColour()) : Next
For i = 1 To 500
  first = Random(200) : count = Random(255 - first) + 1 : steps = Random(1000) - 500
  For j = 0 To 255 : Old(j) = GL_PaletteShown(*P, j) : Next
  *P\Changed = #False
  Check(GL_PaletteCycle(*P, first, count, steps), "cycle " + Str(i))
  ok = #True
  For j = 0 To 255
    If j >= first And j < first + count
      k = ((j - first - steps) % count + count) % count      ; the colour that moved here
      If GL_PaletteShown(*P, j) <> Old(first + k) : ok = #False : EndIf
    ElseIf GL_PaletteShown(*P, j) <> Old(j)
      ok = #False
    EndIf
  Next
  Check(ok, "cycle " + Str(i) + ": range " + Str(first) + "+" + Str(count) + " by " + Str(steps) + " against the reference, the rest untouched")
  Check(Bool(*P\Changed Or steps % count = 0), "cycle " + Str(i) + ": marks the palette for the back end")
Next
Check(Bool(GL_PaletteCycle(*P, 250, 10, 1) = #False And GL_PaletteCycle(*P, -1, 3, 1) = #False And GL_PaletteCycle(*P, 0, 0, 1) = #False), "a range outside 0..255 refused")
For j = 0 To 255 : Old(j) = GL_PaletteShown(*P, j) : Next
GL_PaletteCycle(*P, 5, 7, 3) : GL_PaletteCycle(*P, 5, 7, -3)
ok = #True : For j = 0 To 255 : If GL_PaletteShown(*P, j) <> Old(j) : ok = #False : EndIf : Next
Check(ok, "3 steps up and 3 back is where it started")
GL_PaletteReset(*P)
ok = #True : For j = 0 To 255 : If GL_PaletteShown(*P, j) <> GL_PaletteGet(*P, j) : ok = #False : EndIf : Next
Check(ok, "reset shows the colours as set")

; by the clock: one step every 100 ms over 6 entries
Define t.q
For t = 0 To 1300 Step 50
  GL_PaletteReset(*P)
  GL_PaletteCycleTime(*P, 20, 6, 100, t)
  k = (t / 100) % 6
  Check(Bool(GL_PaletteShown(*P, 20 + k) = GL_PaletteGet(*P, 20)), "at " + Str(t) + " ms entry 20's colour has moved " + Str(k) + " places")
Next

; ---------------------------------------------------------------- fading
Define r.i, g.i, b.i
For i = 1 To 2000
  GL_PaletteReset(*P)
  c = RndColour() : amt = Random(1100) / 1000.0 - 0.05
  first = Random(255) : count = Random(255 - first) + 1
  For j = 0 To 255 : Old(j) = GL_PaletteShown(*P, j) : Next
  GL_PaletteFade(*P, c, amt, first, count)
  ok = #True
  For j = 0 To 255
    o = GL_PaletteShown(*P, j)
    If j >= first And j < first + count
      If Red(o) <> RefMix(Red(Old(j)), Red(c), amt) Or Green(o) <> RefMix(Green(Old(j)), Green(c), amt) Or Blue(o) <> RefMix(Blue(Old(j)), Blue(c), amt) Or Alpha(o) <> Alpha(Old(j))
        ok = #False
      EndIf
    ElseIf o <> Old(j)
      ok = #False
    EndIf
  Next
  Check(ok, "fade " + Str(i) + " toward $" + Hex(c & $FFFFFFFF) + " by " + StrF(amt, 3) + ": every channel against the reference, alpha kept")
Next
GL_PaletteReset(*P) : GL_PaletteFade(*P, RGBA(10, 20, 30, 0), 1.0)
Check(Bool(Red(GL_PaletteShown(*P, 9)) = 10 And Blue(GL_PaletteShown(*P, 200)) = 30 And Alpha(GL_PaletteShown(*P, 9)) = Alpha(GL_PaletteGet(*P, 9))), "fade by 1 is the colour, alpha kept")
GL_PaletteReset(*P) : GL_PaletteFade(*P, RGBA(10, 20, 30, 0), 0.0)
ok = #True : For j = 0 To 255 : If GL_PaletteShown(*P, j) <> GL_PaletteGet(*P, j) : ok = #False : EndIf : Next
Check(ok, "fade by 0 changes nothing")
*Q = GL_PaletteCreate(256)
For i = 0 To 255 : GL_PaletteSet(*Q, i, RndColour()) : Next
For i = 1 To 300
  GL_PaletteReset(*P) : amt = Random(1000) / 1000.0
  GL_PaletteFadeTo(*P, *Q, amt)
  ok = #True
  For j = 0 To 255
    o = GL_PaletteShown(*P, j) : c = GL_PaletteShown(*Q, j) : k = GL_PaletteGet(*P, j)
    If Red(o) <> RefMix(Red(k), Red(c), amt) Or Green(o) <> RefMix(Green(k), Green(c), amt) Or Blue(o) <> RefMix(Blue(k), Blue(c), amt) Or Alpha(o) <> RefMix(Alpha(k), Alpha(c), amt)
      ok = #False
    EndIf
  Next
  Check(ok, "fade to another palette " + Str(i) + " by " + StrF(amt, 3) + ": all four channels")
Next
; a frame's sequence: reset, cycle by the clock, fade - against the reference steps
GL_PaletteReset(*P)
GL_PaletteCycleTime(*P, 100, 16, 80, 1000)          ; 12 steps, 12 mod 16
GL_PaletteFade(*P, RGBA(0, 0, 0, 255), 0.25)
ok = #True
For j = 0 To 255
  k = GL_PaletteGet(*P, j)
  If j >= 100 And j < 116 : k = GL_PaletteGet(*P, 100 + ((j - 100 - 12) % 16 + 16) % 16) : EndIf
  o = GL_PaletteShown(*P, j)
  If Red(o) <> RefMix(Red(k), 0, 0.25) Or Green(o) <> RefMix(Green(k), 0, 0.25) Or Blue(o) <> RefMix(Blue(k), 0, 0.25) Or Alpha(o) <> Alpha(k) : ok = #False : EndIf
Next
Check(ok, "reset, cycle by the clock, fade: composed in that order")
GL_PaletteCopy(*Q, *P)
Check(Bool(GL_PaletteShown(*Q, 105) = GL_PaletteShown(*P, 105) And GL_PaletteGet(*Q, 105) = GL_PaletteGet(*P, 105)), "copy takes both copies")

; ------------------------------------------------------------ indexed images
Define *Img.GLIndexedImage, x.i, y.i, *Px, w.i = 13, h.i = 7
*Img = GL_IndexedCreate(w, h)
Check(Bool(*Img And GL_IndexedGet(*Img, 12, 6) = 0 And GL_IndexedGet(*Img, 13, 0) = -1), "a 13 x 7 image of zeros")
For y = 0 To h - 1 : For x = 0 To w - 1 : GL_IndexedSet(*Img, x, y, (x * 31 + y * 7) & 255) : Next : Next
Check(Bool(GL_IndexedGet(*Img, 5, 3) = (5 * 31 + 3 * 7) & 255 And GL_IndexedSet(*Img, 0, 0, 256) = #False), "pixels set and read; index 256 refused")
*Px = AllocateMemory(w * h * 4)
Check(Bool(GL_IndexedResolve(*Img, 0, *Px) = #False), "no palette, no look-up")
GL_IndexedPalette(*Img, 0, *P)
GL_PaletteReset(*P) : GL_PaletteCycle(*P, 0, 256, 1)
Check(GL_IndexedResolve(*Img, 0, *Px), "look-up through slot 0")
ok = #True
For y = 0 To h - 1 : For x = 0 To w - 1
  If PeekL(*Px + (y * w + x) * 4) <> GL_PaletteGet(*P, (((x * 31 + y * 7) & 255) + 255) % 256) : ok = #False : EndIf
Next : Next
Check(ok, "every pixel is the SHOWN colour of its index (cycled by one)")
GL_IndexedResolve(*Img, *Q, *Px)
Check(Bool(PeekL(*Px + 4 * 4) = GL_PaletteShown(*Q, GL_IndexedGet(*Img, 4, 0))), "a swapped palette")
; the palette a draw uses
Define *R.GLPalette = GL_PaletteCreate(), *S.GLPalette = GL_PaletteCreate()
Dim Over.i(7)
GL_IndexedPalette(*Img, 2, *R)
Check(Bool(GLPal_Choose(*Img, 2, 0, 0) = *R And GLPal_Choose(*Img, 5, 0, 0) = *P), "slot 2 has its palette; an empty slot falls back to slot 0")
Over(2) = *S
Check(Bool(GLPal_Choose(*Img, 2, @Over(0), 0) = *S And GLPal_Choose(*Img, 1, @Over(0), 0) = *P), "a layer's replacement wins for its slot only")
Check(Bool(GLPal_Choose(*Img, 2, @Over(0), *Q) = *Q), "a sprite's own palette wins over all")

; from a picture
Define img.i = CreateImage(#PB_Any, 8, 4, 32), *From.GLIndexedImage, *FP.GLPalette = GL_PaletteCreate(1)
StartDrawing(ImageOutput(img)) : DrawingMode(#PB_2DDrawing_AllChannels)
For y = 0 To 3 : For x = 0 To 7 : Plot(x, y, RGBA((x % 5) * 50, 0, y & 1, 255)) : Next : Next
StopDrawing()
GL_PaletteSet(*FP, 0, RGBA(0, 0, 0, 0))             ; a transparent entry 0 kept first
*From = GL_IndexedFromImage(img, *FP)
Check(Bool(*From And *FP\Count = 11), "8 x 4 picture of 10 colours: palette of 1 + 10 (" + Str(*FP\Count) + ")")
ok = #True
StartDrawing(ImageOutput(img)) : DrawingMode(#PB_2DDrawing_AllChannels)
For y = 0 To 3 : For x = 0 To 7
  If (GL_PaletteGet(*FP, GL_IndexedGet(*From, x, y)) & $FFFFFFFF) <> (Point(x, y) & $FFFFFFFF) : ok = #False : EndIf
Next : Next
StopDrawing()
Check(ok, "every pixel's index gives back its colour")
Define big.i = CreateImage(#PB_Any, 20, 15, 32), *Before = GL_PaletteCreate(1)
StartDrawing(ImageOutput(big)) : DrawingMode(#PB_2DDrawing_AllChannels)
For y = 0 To 14 : For x = 0 To 19 : Plot(x, y, RGBA(x, y, 7, 255)) : Next : Next
StopDrawing()
Check(Bool(GL_IndexedFromImage(big, *Before) = 0 And GL_PaletteGet(*Before, 1) = 0), "300 colours refused, the palette untouched: " + GL_PaletteError())

; ------------------------------------------------------------ the .nti file
Define path.s = ProgramParameter(0), *Back.GLIndexedImage, *raw, size.i, f.i
If path = "" : path = GetTemporaryDirectory() + "palette_check" : EndIf
GL_IndexedPalette(*Img, 3, *Q) : GL_IndexedPalette(*Img, 2, 0)
GL_PaletteSet(*P, 7, RGBA($12, $34, $56, $78))
DeleteFile(path + ".nti")
Check(GL_IndexedSave(*Img, path + ".nti"), "save an 8-bit image with palettes in slots 0 and 3")
size = FileSize(path + ".nti")
Check(Bool(size = 8 + (8 + ((4 + 13 * 7 + 3) & ~3)) + 2 * (8 + 4 + 256 * 4)), "its size (" + Str(size) + ")")
f = ReadFile(#PB_Any, path + ".nti") : *raw = AllocateMemory(size) : ReadData(f, *raw, size) : CloseFile(f)
Check(Bool(PeekS(*raw, 4, #PB_Ascii) = "NTIX" And PeekA(*raw + 7) = 3 And PeekS(*raw + 8, 4, #PB_Ascii) = "IDX8"), "NTIX, three chunks, IDX8 first")
i = 8 + 8 + ((4 + 13 * 7 + 3) & ~3)          ; the first PAL chunk
Check(Bool(PeekS(*raw + i, 4, #PB_Ascii) = "PAL " And PeekA(*raw + i + 8) = 0 And PeekA(*raw + i + 11) = 0 And PeekA(*raw + i + 10) = 1), "PAL chunk: slot 0, 256 colours")
Check(Bool(PeekA(*raw + i + 12 + 7 * 4) = $12 And PeekA(*raw + i + 13 + 7 * 4) = $34 And PeekA(*raw + i + 14 + 7 * 4) = $56 And PeekA(*raw + i + 15 + 7 * 4) = $78), "colours written R, G, B, A ($RRGGBBAA)")
*Back = GL_IndexedLoad(path + ".nti")
Check(Bool(*Back And *Back\Width = 13 And *Back\Height = 7 And CompareMemory(*Back\Index, *Img\Index, 13 * 7)), "indices round trip")
Check(Bool(*Back\Palette[0] And *Back\Palette[3] And *Back\Palette[1] = 0 And *Back\OwnsPalettes), "palettes come back in their slots")
Define *BP.GLPalette = *Back\Palette[3]
Check(Bool(CompareMemory(@*BP\Base[0], @*Q\Base[0], 1024)), "slot 3's colours round trip (as set)")
GL_IndexedFree(*Back)
; four bits a pixel
Define *Small.GLIndexedImage = GL_IndexedCreate(5, 3)
For y = 0 To 2 : For x = 0 To 4 : GL_IndexedSet(*Small, x, y, (x + y * 5) % 16) : Next : Next
GL_IndexedPalette(*Small, 0, *P)
Check(GL_IndexedSave(*Small, path + "4.nti", #True), "save packed")
f = ReadFile(#PB_Any, path + "4.nti") : FreeMemory(*raw) : size = Lof(f) : *raw = AllocateMemory(size) : ReadData(f, *raw, size) : CloseFile(f)
Check(Bool(PeekS(*raw + 8, 4, #PB_Ascii) = "IDX4" And PeekA(*raw + 15) = 4 + 3 * 3 And PeekA(*raw + 20) = $01 And PeekA(*raw + 21) = $23 And PeekA(*raw + 22) = $40), "IDX4: high half first, each row starts on a byte")
*Back = GL_IndexedLoad(path + "4.nti")
Check(Bool(*Back And CompareMemory(*Back\Index, *Small\Index, 15)), "packed indices round trip")
GL_IndexedFree(*Back)
GL_IndexedSet(*Small, 0, 0, 16)
Check(Bool(GL_IndexedSave(*Small, path + "4.nti", #True) = #False), "an index above 15 cannot be packed: " + GL_PaletteError())
; a palette on its own
Check(GL_PaletteSave(*Q, path + ".ntp"), "save a palette file")
Define *L.GLPalette = GL_PaletteLoad(path + ".ntp")
Check(Bool(*L And CompareMemory(@*L\Base[0], @*Q\Base[0], 1024) And GL_IndexedLoad(path + ".ntp") = 0), "load it; it holds no image")
GL_PaletteFree(*L)
*L = GL_PaletteLoad(path + ".nti", 3)
Check(Bool(*L And CompareMemory(@*L\Base[0], @*Q\Base[0], 1024)), "a palette taken from an image file's slot 3")
GL_PaletteFree(*L)
; damage
f = CreateFile(#PB_Any, path + ".nti") : WriteData(f, *raw, 30) : CloseFile(f)
Check(Bool(GL_IndexedLoad(path + ".nti") = 0), "a cut-off file refused: " + GL_PaletteError())
DeleteFile(path + ".nti") : DeleteFile(path + "4.nti") : DeleteFile(path + ".ntp")

; ------------------------------------------------- indexed tile sets in the map file
Define *Sheet.GLIndexedImage = GL_IndexedCreate(64, 32), *Set.GLTileSet, *Map.GLTileMap, *Set2.GLTileSet
*Set = GL_TileSetCreateIndexed(*Sheet, 16, 16)
Check(Bool(*Set And *Set\Count = 8 And *Set\Indexed = *Sheet And *Set\Sprite = 0), "an indexed tile set: 8 tiles")
Check(Bool(GL_TileSetPaletteSlot(*Set, 5, 3) And GL_TileSetPaletteSlotGet(*Set, 5) = 3 And GL_TileSetPaletteSlot(*Set, 5, 8) = #False), "per-tile palette slots 0..7")
GL_TileSetPaletteSlot(*Set, 7, 1)
*Map = GL_TileMapCreate(4, 4, *Set) : GL_TileMapSet(*Map, 1, 1, 5)
Check(GL_TileMapSave(*Map, path + ".ntm"), "save a map of an indexed set")
*Set2 = GL_TileSetCreateIndexed(*Sheet, 16, 16)
Check(Bool(GL_TileSetLoad(*Set2, path + ".ntm") And GL_TileSetPaletteSlotGet(*Set2, 5) = 3 And GL_TileSetPaletteSlotGet(*Set2, 7) = 1 And GL_TileSetPaletteSlotGet(*Set2, 0) = 0), "palette slots round trip (TPAL)")
DeleteFile(path + ".ntm")

PrintN("PASS palette: " + Str(Checks) + " checks - 500 cycles, the clock, 2000 fades and 300 palette fades against references, their order, slots and swaps, the look-up, pictures, .nti 8 and 4 bit, palette slots in the map file")
