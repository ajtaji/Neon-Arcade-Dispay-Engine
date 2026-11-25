; palette_ops.pb - a palette's operations on the CPU, an indexed image, and the .nti file. No window.
; Build:  pbcompiler palette_ops.pb /CONSOLE /EXE palette_ops.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlSpriteFunctions.pbi"
XIncludeFile #Engine$ + "GlTiles.pbi"                   ; brings GlPalette.pbi
OpenConsole()

Procedure.s Colour(c.l)
  ProcedureReturn "(" + Str(Red(c)) + "," + Str(Green(c)) + "," + Str(Blue(c)) + "," + Str(Alpha(c)) + ")"
EndProcedure

Define *Pal.GLPalette = GL_PaletteCreate(8), i.i, s.s
GL_PaletteSet(*Pal, 0, RGBA(0, 0, 0, 0))                ; entry 0: transparent
For i = 1 To 7 : GL_PaletteSet(*Pal, i, RGBA(i * 30, 0, 0, 255)) : Next

; cycle entries 1..4 one step: each colour moves one place up, the last wraps to the first
GL_PaletteCycle(*Pal, 1, 4, 1)
For i = 1 To 4 : s + Colour(GL_PaletteShown(*Pal, i)) + " " : Next
PrintN("shown 1..4 after one step: " + s)
PrintN("set 1 is still " + Colour(GL_PaletteGet(*Pal, 1)))

; by the clock: one step every 100 ms, worked out from the time (so a late frame does not drift)
GL_PaletteReset(*Pal)
GL_PaletteCycleTime(*Pal, 1, 4, 100, 250)              ; 250 ms = 2 steps
PrintN("at 250 ms, shown 1 = " + Colour(GL_PaletteShown(*Pal, 1)) +
       " (set 3 was " + Colour(GL_PaletteGet(*Pal, 3)) + ")")

; a fade: each channel (a * (256 - k) + b * k + 128) >> 8 with k = Amount * 256 rounded; alpha kept
GL_PaletteReset(*Pal)
GL_PaletteFade(*Pal, RGBA(0, 0, 255, 255), 0.25)
PrintN("entry 4 faded a quarter toward blue: " + Colour(GL_PaletteShown(*Pal, 4)))
PrintN("entry 0 keeps alpha 0: " + Colour(GL_PaletteShown(*Pal, 0)))

; an indexed image: one byte a pixel, drawn through a palette in one of eight slots
Define *Img.GLIndexedImage = GL_IndexedCreate(4, 2)
GL_IndexedSet(*Img, 0, 0, 1) : GL_IndexedSet(*Img, 3, 1, 7)
GL_IndexedPalette(*Img, 0, *Pal)
Dim Px.l(7)
GL_PaletteReset(*Pal)
GL_IndexedResolve(*Img, 0, @Px(0))                      ; the CPU look-up: what the shader draws
PrintN("pixel 0,0 = " + Colour(Px(0)) + ", pixel 3,1 = " + Colour(Px(7)) + ", pixel 1,0 = " + Colour(Px(1)))

; the file: the image and the palettes in its slots, written through the durable file store
Define Path.s = GetTemporaryDirectory() + "neon_manual_example.nti"
If Not GL_IndexedSave(*Img, Path, #True) : PrintN("save: " + GL_PaletteError()) : End 1 : EndIf
Define *Back.GLIndexedImage = GL_IndexedLoad(Path)       ; it owns the palettes it reads
PrintN("file " + Str(FileSize(Path)) + " bytes; read back " + Str(*Back\Width) + " x " + Str(*Back\Height) +
       ", pixel 3,1 = " + Str(GL_IndexedGet(*Back, 3, 1)) + ", its palette's entry 7 = " +
       Colour(GL_PaletteGet(GL_IndexedPaletteOf(*Back, 0), 7)))
If GL_IndexedSet(*Img, 0, 0, 16) And Not GL_IndexedSave(*Img, Path, #True)
  PrintN("refused: " + GL_PaletteError())
EndIf
DeleteFile(Path)
GL_IndexedFree(*Back) : GL_IndexedFree(*Img) : GL_PaletteFree(*Pal)
