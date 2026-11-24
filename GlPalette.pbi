; ============================================================================
; GlPalette.pbi - Colour-Indexed Images and Palettes
; ============================================================================
; Included by GlTiles.pbi, at its end: XIncludeFile "GlTiles.pbi" brings it.
; Nothing above this file was changed.
;
; --- THE MODEL: INDICES + PALETTE + OPERATIONS ---
; An INDEXED IMAGE is a picture of colour numbers, one byte a pixel (0..255),
; row 0 at the top. It carries up to #GL_PALETTE_SLOTS palettes in slots; a
; draw names a slot, or hands its own palette (a palette swap), and a layer
; can replace a slot's palette for everything it draws.
;
; A PALETTE is up to 256 colours (RGBA(), so $AABBGGRR in a .l). It keeps two
; copies: Base, the colours as set, and Shown, what is drawn. The operations
; work on Shown, in the order called; GL_PaletteReset puts Base back. A frame
; that animates a palette does: Reset, Cycle, Fade.
;
;   GL_PaletteCycle(*Pal, First, Count, Steps)       rotate a range
;   GL_PaletteCycleTime(*Pal, First, Count, StepMs)  ... one step every StepMs, by the clock
;   GL_PaletteFade(*Pal, Colour, Amount)             toward a colour (alpha kept)
;   GL_PaletteFadeTo(*Pal, *Other, Amount)           toward another palette (all four channels)
;
; A fade mixes every channel as  (a * (256 - k) + b * k + 128) >> 8  with
; k = Amount * 256 rounded: whole numbers, the same on every back end, the
; console's engine included (its fade amount is this k).
;
; --- WHO DRAWS IT: THE BACK END ---
; Nothing above assumes a shader. The OpenGL back end below does the look-up
; in the fragment shader: the indices are an R8 texture, every palette in use
; is one row of a 256 x 256 RGBA texture, and each vertex carries the row of
; its palette, so sprites and tiles with different palettes still go in ONE
; draw call. A palette changed by an operation is marked and its row is
; re-sent (1 KB) at its next draw; the indices are never re-sent for that.
;
; A back end with hardware palettes carries out the same six things, the
; procedures below: GLPal_BackIndexUpload (send an image's indices, again only
; after GL_IndexedSet), GLPal_BackIndexFree, GLPal_BackPaletteCommit (give a
; palette a hardware slot and write Shown there when it is marked),
; GLPal_BackPaletteFree, GLPal_Quad (a quad of an image with a slot, flips,
; tint) and GLPal_Flush (end the batch). The operations stay on the CPU, on 256 colours,
; whatever the back end.
;
; WHICH OPENGL: the look-up needs GLSL 1.30 and R8 textures (OpenGL 3.0). The
; engine itself does not run below that - LoadModernGL ends the program
; without shaders, vertex arrays, framebuffers and instancing - so there is no
; OpenGL level the engine supports where the shader path is missing, and no
; fallback branch is compiled in. GL_IndexedBake is the CPU re-colour into an
; ordinary sprite: Width x Height look-ups and a texture upload EVERY time the
; palette changes. It is for code that needs a GLSprite (pixel collision,
; DrawGLSprite), and is the path a back end with neither shaders nor palettes
; would take.
;
; --- THE INDEXED IMAGE FILE (.nti) ---
; Big-endian chunks as the map file. Colours are written R, G, B, A - the
; console engine's $RRGGBBAA. See GL_IndexedSave.
; ============================================================================

#GL_PALETTE_SIZE  = 256
#GL_PALETTE_SLOTS = 8

Structure GLPalette
  Count.i                         ; entries in use (saved; the operations reach all 256)
  Base.l[#GL_PALETTE_SIZE]        ; as set
  Shown.l[#GL_PALETTE_SIZE]       ; as drawn
  Changed.i                       ; Shown changed since the back end last took it
  Row.i                           ; back end: the palette's row / slot, -1 when it has none
EndStructure

Structure GLIndexedImage
  Width.i : Height.i
  *Index                          ; Width x Height bytes, row 0 at the top
  Palette.i[#GL_PALETTE_SLOTS]    ; GLPalette addresses
  OwnsPalettes.i                  ; made by GL_IndexedLoad: freed with the image
  Changed.i                       ; indices changed since the back end last took them
  TextureID.l                     ; back end: the indices on the GPU
EndStructure

Global GLPal_Error.s

Procedure.s GL_PaletteError()
  ProcedureReturn GLPal_Error
EndProcedure

Procedure.i GLPal_Fail(Message.s)
  GLPal_Error = Message
  ProcedureReturn 0
EndProcedure

Declare GLPal_BackPaletteFree(*Pal.GLPalette)
Declare GLPal_BackIndexFree(*Img.GLIndexedImage)

; ============================================================================
; PALETTES
; ============================================================================

; A palette of Count entries, every one transparent black until set.
Procedure.i GL_PaletteCreate(Count.i = 256)
  Protected *Pal.GLPalette
  If Count < 1 Or Count > #GL_PALETTE_SIZE : ProcedureReturn GLPal_Fail("GL_PaletteCreate: 1 to 256 entries.") : EndIf
  *Pal = AllocateStructure(GLPalette)
  *Pal\Count = Count : *Pal\Row = -1 : *Pal\Changed = #True
  ProcedureReturn *Pal
EndProcedure

Procedure GL_PaletteFree(*Pal.GLPalette)
  If Not *Pal : ProcedureReturn : EndIf
  GLPal_BackPaletteFree(*Pal)
  FreeStructure(*Pal)
EndProcedure

; Set entry Index to Colour (RGBA()), both as set and as shown.
Procedure.i GL_PaletteSet(*Pal.GLPalette, Index.i, Colour.l)
  If Not *Pal Or Index < 0 Or Index >= #GL_PALETTE_SIZE : ProcedureReturn #False : EndIf
  *Pal\Base[Index] = Colour : *Pal\Shown[Index] = Colour : *Pal\Changed = #True
  If Index >= *Pal\Count : *Pal\Count = Index + 1 : EndIf
  ProcedureReturn #True
EndProcedure

Procedure.l GL_PaletteGet(*Pal.GLPalette, Index.i)
  If Not *Pal Or Index < 0 Or Index >= #GL_PALETTE_SIZE : ProcedureReturn 0 : EndIf
  ProcedureReturn *Pal\Base[Index]
EndProcedure

; The colour drawn for Index now.
Procedure.l GL_PaletteShown(*Pal.GLPalette, Index.i)
  If Not *Pal Or Index < 0 Or Index >= #GL_PALETTE_SIZE : ProcedureReturn 0 : EndIf
  ProcedureReturn *Pal\Shown[Index]
EndProcedure

; Shown = Base.
Procedure GL_PaletteReset(*Pal.GLPalette)
  If Not *Pal : ProcedureReturn : EndIf
  CopyMemory(@*Pal\Base[0], @*Pal\Shown[0], #GL_PALETTE_SIZE * 4)
  *Pal\Changed = #True
EndProcedure

; *Dest takes *Src's entries, as set and as shown.
Procedure GL_PaletteCopy(*Dest.GLPalette, *Src.GLPalette)
  If Not *Dest Or Not *Src : ProcedureReturn : EndIf
  CopyMemory(@*Src\Base[0], @*Dest\Base[0], #GL_PALETTE_SIZE * 4)
  CopyMemory(@*Src\Shown[0], @*Dest\Shown[0], #GL_PALETTE_SIZE * 4)
  *Dest\Count = *Src\Count : *Dest\Changed = #True
EndProcedure

Procedure.i GLPal_Range(*First.Integer, *Count.Integer)
  If *Count\i < 0 : *Count\i = #GL_PALETTE_SIZE - *First\i : EndIf
  If *First\i < 0 Or *Count\i < 1 Or *First\i + *Count\i > #GL_PALETTE_SIZE : ProcedureReturn #False : EndIf
  ProcedureReturn #True
EndProcedure

; Rotate the shown colours First .. First + Count - 1 by Steps: each colour
; moves Steps entries up the range (down for a negative Steps), the last
; wrapping to the first.
Procedure.i GL_PaletteCycle(*Pal.GLPalette, First.i, Count.i, Steps.i)
  Protected i.i, k.i
  Protected Dim Old.l(#GL_PALETTE_SIZE - 1)
  If Not *Pal Or Not GLPal_Range(@First, @Count) : ProcedureReturn #False : EndIf
  k = Steps % Count : If k < 0 : k + Count : EndIf
  If k = 0 : ProcedureReturn #True : EndIf
  For i = 0 To Count - 1 : Old(i) = *Pal\Shown[First + i] : Next
  For i = 0 To Count - 1 : *Pal\Shown[First + (i + k) % Count] = Old(i) : Next
  *Pal\Changed = #True
  ProcedureReturn #True
EndProcedure

; Cycle by the clock: one step every StepMs (TimeMs < 0 reads GL_Micros()).
; Call it after GL_PaletteReset: the rotation is worked out from the time, so
; frames that come late do not drift.
Procedure.i GL_PaletteCycleTime(*Pal.GLPalette, First.i, Count.i, StepMs.i, TimeMs.q = -1)
  If StepMs < 1 Or Count = 0 : ProcedureReturn #False : EndIf
  If TimeMs < 0 : TimeMs = GL_Micros() / 1000 : EndIf
  If Count < 0 : Count = #GL_PALETTE_SIZE - First : EndIf
  ProcedureReturn GL_PaletteCycle(*Pal, First, Count, (TimeMs / StepMs) % Count)
EndProcedure

Procedure.i GLPal_Amount(Amount.f)
  Protected k.i = Round(Amount * 256.0, #PB_Round_Nearest)
  If k < 0 : k = 0 : ElseIf k > 256 : k = 256 : EndIf
  ProcedureReturn k
EndProcedure

Macro GLPal_Mix(A, B, K)
  (((A) * (256 - (K)) + (B) * (K) + 128) >> 8)
EndMacro

; Mix the shown colours First .. First + Count - 1 toward Colour by Amount
; (0 = unchanged, 1 = all Colour). Red, green and blue only: a transparent
; entry stays transparent. Count -1 = to the end.
Procedure.i GL_PaletteFade(*Pal.GLPalette, Colour.l, Amount.f, First.i = 0, Count.i = -1)
  Protected k.i = GLPal_Amount(Amount), i.i, c.l, r.i = Red(Colour), g.i = Green(Colour), b.i = Blue(Colour)
  If Not *Pal Or Not GLPal_Range(@First, @Count) : ProcedureReturn #False : EndIf
  For i = First To First + Count - 1
    c = *Pal\Shown[i]
    *Pal\Shown[i] = RGBA(GLPal_Mix(Red(c), r, k), GLPal_Mix(Green(c), g, k), GLPal_Mix(Blue(c), b, k), Alpha(c))
  Next
  *Pal\Changed = #True
  ProcedureReturn #True
EndProcedure

; Mix the shown colours toward *Other's shown colours by Amount, all four channels.
Procedure.i GL_PaletteFadeTo(*Pal.GLPalette, *Other.GLPalette, Amount.f, First.i = 0, Count.i = -1)
  Protected k.i = GLPal_Amount(Amount), i.i, c.l, o.l
  If Not *Pal Or Not *Other Or Not GLPal_Range(@First, @Count) : ProcedureReturn #False : EndIf
  For i = First To First + Count - 1
    c = *Pal\Shown[i] : o = *Other\Shown[i]
    *Pal\Shown[i] = RGBA(GLPal_Mix(Red(c), Red(o), k), GLPal_Mix(Green(c), Green(o), k), GLPal_Mix(Blue(c), Blue(o), k), GLPal_Mix(Alpha(c), Alpha(o), k))
  Next
  *Pal\Changed = #True
  ProcedureReturn #True
EndProcedure

; ============================================================================
; INDEXED IMAGES
; ============================================================================

; A Width x Height image; *Indices (Width x Height bytes, row 0 at the top) is
; copied when given, else every pixel is 0.
Procedure.i GL_IndexedCreate(Width.i, Height.i, *Indices = 0)
  Protected *Img.GLIndexedImage
  If Width < 1 Or Height < 1 Or Width > 16384 Or Height > 16384 : ProcedureReturn GLPal_Fail("GL_IndexedCreate: 1 to 16384 pixels each way.") : EndIf
  *Img = AllocateStructure(GLIndexedImage)
  *Img\Index = AllocateMemory(Width * Height)
  If Not *Img\Index : FreeStructure(*Img) : ProcedureReturn GLPal_Fail("GL_IndexedCreate: out of memory.") : EndIf
  If *Indices : CopyMemory(*Indices, *Img\Index, Width * Height) : EndIf
  *Img\Width = Width : *Img\Height = Height : *Img\Changed = #True
  ProcedureReturn *Img
EndProcedure

; Free the image (and its palettes if GL_IndexedLoad made them).
Procedure GL_IndexedFree(*Img.GLIndexedImage)
  Protected i.i
  If Not *Img : ProcedureReturn : EndIf
  GLPal_BackIndexFree(*Img)
  If *Img\OwnsPalettes
    For i = 0 To #GL_PALETTE_SLOTS - 1
      If *Img\Palette[i] : GL_PaletteFree(*Img\Palette[i]) : EndIf
    Next
  EndIf
  FreeMemory(*Img\Index)
  FreeStructure(*Img)
EndProcedure

Procedure.i GL_IndexedGet(*Img.GLIndexedImage, X.i, Y.i)
  If Not *Img Or X < 0 Or Y < 0 Or X >= *Img\Width Or Y >= *Img\Height : ProcedureReturn -1 : EndIf
  ProcedureReturn PeekA(*Img\Index + Y * *Img\Width + X)
EndProcedure

; Change a pixel; the back end takes the indices again at the next draw.
Procedure.i GL_IndexedSet(*Img.GLIndexedImage, X.i, Y.i, Index.i)
  If Not *Img Or X < 0 Or Y < 0 Or X >= *Img\Width Or Y >= *Img\Height Or Index < 0 Or Index > 255 : ProcedureReturn #False : EndIf
  PokeA(*Img\Index + Y * *Img\Width + X, Index)
  *Img\Changed = #True
  ProcedureReturn #True
EndProcedure

; Put *Pal in Slot (0 .. 7). The image does not own it.
Procedure.i GL_IndexedPalette(*Img.GLIndexedImage, Slot.i, *Pal.GLPalette)
  If Not *Img Or Slot < 0 Or Slot >= #GL_PALETTE_SLOTS : ProcedureReturn #False : EndIf
  *Img\Palette[Slot] = *Pal
  ProcedureReturn #True
EndProcedure

Procedure.i GL_IndexedPaletteOf(*Img.GLIndexedImage, Slot.i)
  If Not *Img Or Slot < 0 Or Slot >= #GL_PALETTE_SLOTS : ProcedureReturn 0 : EndIf
  ProcedureReturn *Img\Palette[Slot]
EndProcedure

; An indexed image from a PureBasic image: each colour is looked up in *Pal
; (exactly, alpha included) and added at the end when new. Fails, changing
; nothing, if the picture has more colours than the palette has room for.
Procedure.i GL_IndexedFromImage(Img.i, *Pal.GLPalette)
  Protected w.i, h.i, x.i, y.i, c.l, i.i, n.i, *Buf, added.i, *Img.GLIndexedImage
  Protected NewMap Seen.i()
  Protected Dim Add.l(255)
  If Not IsImage(Img) Or Not *Pal : ProcedureReturn GLPal_Fail("GL_IndexedFromImage: no image or no palette.") : EndIf
  w = ImageWidth(Img) : h = ImageHeight(Img)
  n = *Pal\Count
  For i = 0 To n - 1
    If Not FindMapElement(Seen(), Hex(*Pal\Base[i] & $FFFFFFFF)) : Seen(Hex(*Pal\Base[i] & $FFFFFFFF)) = i : EndIf
  Next
  *Buf = AllocateMemory(w * h)
  If Not *Buf : ProcedureReturn GLPal_Fail("GL_IndexedFromImage: out of memory.") : EndIf
  StartDrawing(ImageOutput(Img))
  DrawingMode(#PB_2DDrawing_AllChannels)
  For y = 0 To h - 1
    For x = 0 To w - 1
      c = Point(x, y)
      If ImageDepth(Img) < 32 : c = RGBA(Red(c), Green(c), Blue(c), 255) : EndIf
      If Not FindMapElement(Seen(), Hex(c & $FFFFFFFF))
        If n + added >= #GL_PALETTE_SIZE
          StopDrawing() : FreeMemory(*Buf)
          ProcedureReturn GLPal_Fail("GL_IndexedFromImage: more than " + Str(#GL_PALETTE_SIZE) + " colours.")
        EndIf
        Seen(Hex(c & $FFFFFFFF)) = n + added : Add(added) = c : added + 1
      EndIf
      PokeA(*Buf + y * w + x, Seen())
    Next
  Next
  StopDrawing()
  For i = 0 To added - 1 : GL_PaletteSet(*Pal, n + i, Add(i)) : Next
  *Img = GL_IndexedCreate(w, h, *Buf)
  FreeMemory(*Buf)
  If *Img : *Img\Palette[0] = *Pal : EndIf
  ProcedureReturn *Img
EndProcedure

; The image through *Pal's shown colours (0 = slot 0's) into *Dest:
; Width x Height RGBA() longs, row 0 at the top. The CPU reference.
Procedure.i GL_IndexedResolve(*Img.GLIndexedImage, *Pal.GLPalette, *Dest)
  Protected i.i, n.i
  If Not *Img Or Not *Dest : ProcedureReturn #False : EndIf
  If Not *Pal : *Pal = *Img\Palette[0] : EndIf
  If Not *Pal : ProcedureReturn GLPal_Fail("GL_IndexedResolve: no palette.") : EndIf
  n = *Img\Width * *Img\Height
  For i = 0 To n - 1
    PokeL(*Dest + i * 4, *Pal\Shown[PeekA(*Img\Index + i)])
  Next
  ProcedureReturn #True
EndProcedure

; ============================================================================
; THE INDEXED IMAGE FILE (.nti)
; ============================================================================
; Big-endian. Header "NTIX", version (2, = 1), number of chunks (2); chunks
; as the map file (id, length, payload, padded to 4).
;   "IDX8"  width (2), height (2), then width x height bytes, row 0 first
;   "IDX4"  width (2), height (2), then two pixels a byte, the first in the
;           high half, each row starting on a byte (the console's CI4)
;   "PAL "  slot (1), 0 (1), count (2), then count colours R, G, B, A
; A palette file is the same with no image chunk.


; Write a chunk header at *P and return where its payload starts.
Procedure.i GLPal_Chunk(*P, Id.s, Length.i)
  PokeS(*P, Id, 4, #PB_Ascii | #PB_String_NoZero) : GLTile_Put32(*P + 4, Length)
  ProcedureReturn *P + 8
EndProcedure

; Write through GL_FileStore (the map file's way: "Path.new", then in place of Path).
Procedure.i GLPal_Store(Path.s, *Bytes, Size.i)
  If Not GLTile_StoreFile(Path, *Bytes, Size) : ProcedureReturn GLPal_Fail(GL_TileError()) : EndIf
  ProcedureReturn #True
EndProcedure

; Save *Img (or, with *Img = 0, only the palettes in Pals) to Path. Packed
; writes four bits a pixel, refused if an index is above 15.
Procedure.i GLPal_SaveFile(*Img.GLIndexedImage, Array Pals.i(1), Path.s, Packed.i)
  Protected total.i = 8, chunks.i, i.i, k.i, x.i, y.i, rowBytes.i, payload.i, *Buf, *P, *Pal.GLPalette, ok.i
  If *Img
    If Packed
      For i = 0 To *Img\Width * *Img\Height - 1
        If PeekA(*Img\Index + i) > 15 : ProcedureReturn GLPal_Fail("GL_IndexedSave: an index above 15 does not fit four bits.") : EndIf
      Next
      rowBytes = (*Img\Width + 1) / 2
    Else
      rowBytes = *Img\Width
    EndIf
    payload = 4 + rowBytes * *Img\Height
    total + 8 + ((payload + 3) & ~3) : chunks + 1
  EndIf
  For k = 0 To #GL_PALETTE_SLOTS - 1
    *Pal = Pals(k)
    If *Pal : total + 8 + ((4 + *Pal\Count * 4 + 3) & ~3) : chunks + 1 : EndIf
  Next
  *Buf = AllocateMemory(total)
  If Not *Buf : ProcedureReturn GLPal_Fail("GL_IndexedSave: out of memory.") : EndIf
  PokeS(*Buf, "NTIX", 4, #PB_Ascii | #PB_String_NoZero) : GLTile_Put16(*Buf + 4, 1) : GLTile_Put16(*Buf + 6, chunks)
  *P = *Buf + 8
  If *Img
    If Packed : *P = GLPal_Chunk(*P, "IDX4", payload) : Else : *P = GLPal_Chunk(*P, "IDX8", payload) : EndIf
    GLTile_Put16(*P, *Img\Width) : GLTile_Put16(*P + 2, *Img\Height)
    For y = 0 To *Img\Height - 1
      If Packed
        For x = 0 To *Img\Width - 1
          k = PeekA(*Img\Index + y * *Img\Width + x)
          If x & 1 : k = PeekA(*P + 4 + y * rowBytes + x / 2) | k : Else : k << 4 : EndIf
          PokeA(*P + 4 + y * rowBytes + x / 2, k)
        Next
      Else
        CopyMemory(*Img\Index + y * *Img\Width, *P + 4 + y * rowBytes, rowBytes)
      EndIf
    Next
    *P + ((payload + 3) & ~3)
  EndIf
  For k = 0 To #GL_PALETTE_SLOTS - 1
    *Pal = Pals(k)
    If *Pal
      *P = GLPal_Chunk(*P, "PAL ", 4 + *Pal\Count * 4)
      PokeA(*P, k) : PokeA(*P + 1, 0) : GLTile_Put16(*P + 2, *Pal\Count)
      For i = 0 To *Pal\Count - 1
        PokeL(*P + 4 + i * 4, *Pal\Base[i])           ; RGBA() in memory is R, G, B, A
      Next
      *P + ((4 + *Pal\Count * 4 + 3) & ~3)
    EndIf
  Next
  ok = GLPal_Store(Path, *Buf, total)
  FreeMemory(*Buf)
  ProcedureReturn ok
EndProcedure

; Save the image with the palettes in its slots. Packed: four bits a pixel.
Procedure.i GL_IndexedSave(*Img.GLIndexedImage, Path.s, Packed.i = #False)
  Protected k.i
  Protected Dim Pals.i(#GL_PALETTE_SLOTS - 1)
  If Not *Img : ProcedureReturn GLPal_Fail("GL_IndexedSave: no image.") : EndIf
  For k = 0 To #GL_PALETTE_SLOTS - 1 : Pals(k) = *Img\Palette[k] : Next
  ProcedureReturn GLPal_SaveFile(*Img, Pals(), Path, Packed)
EndProcedure

; Save one palette (as slot 0) on its own.
Procedure.i GL_PaletteSave(*Pal.GLPalette, Path.s)
  Protected Dim Pals.i(#GL_PALETTE_SLOTS - 1)
  If Not *Pal : ProcedureReturn GLPal_Fail("GL_PaletteSave: no palette.") : EndIf
  Pals(0) = *Pal
  ProcedureReturn GLPal_SaveFile(0, Pals(), Path, #False)
EndProcedure

; The file in memory, checked, or 0.
Procedure.i GLPal_ReadFile(Path.s, *Size.Integer)
  Protected f.i, n.i, *Buf
  f = ReadFile(#PB_Any, Path)
  If Not f : ProcedureReturn GLPal_Fail("Cannot open " + Path) : EndIf
  n = Lof(f)
  If n < 8 Or n > $7FFFFFFF : CloseFile(f) : ProcedureReturn GLPal_Fail(Path + " is not an indexed image file.") : EndIf
  *Buf = AllocateMemory(n, #PB_Memory_NoClear)
  If Not *Buf Or ReadData(f, *Buf, n) <> n
    CloseFile(f) : If *Buf : FreeMemory(*Buf) : EndIf
    ProcedureReturn GLPal_Fail("Cannot read " + Path)
  EndIf
  CloseFile(f)
  If PeekS(*Buf, 4, #PB_Ascii) <> "NTIX" Or GLTile_Get16(*Buf + 4) <> 1
    FreeMemory(*Buf) : ProcedureReturn GLPal_Fail(Path + " is not a version 1 indexed image file.")
  EndIf
  *Size\i = n
  ProcedureReturn *Buf
EndProcedure

; Walk the chunks: fills Img with the image (0 if none) and Pals() with new
; palettes. False (and nothing kept) if the file is damaged.
Procedure.i GLPal_ParseFile(*Buf, Size.i, Path.s, *ImgOut.Integer, Array Pals.i(1))
  Protected at.i = 8, count.i = GLTile_Get16(*Buf + 6), c.i, len.i, id.s, w.i, h.i, x.i, y.i, k.i, rowBytes.i
  Protected *Img.GLIndexedImage, *Pal.GLPalette, slot.i, n.i, i.i, ok.i = #True
  For c = 1 To count
    If at + 8 > Size : ok = #False : Break : EndIf
    id = PeekS(*Buf + at, 4, #PB_Ascii) : len = GLTile_Get32(*Buf + at + 4)
    If at + 8 + len > Size : ok = #False : Break : EndIf
    Select id
      Case "IDX8", "IDX4"
        If *Img Or len < 4 : ok = #False : Break : EndIf
        w = GLTile_Get16(*Buf + at + 8) : h = GLTile_Get16(*Buf + at + 10)
        If id = "IDX4" : rowBytes = (w + 1) / 2 : Else : rowBytes = w : EndIf
        If len <> 4 + rowBytes * h : ok = #False : Break : EndIf
        *Img = GL_IndexedCreate(w, h)
        If Not *Img : ok = #False : Break : EndIf
        For y = 0 To h - 1
          For x = 0 To w - 1
            If id = "IDX4"
              k = PeekA(*Buf + at + 12 + y * rowBytes + x / 2)
              If x & 1 : k & 15 : Else : k >> 4 : EndIf
            Else
              k = PeekA(*Buf + at + 12 + y * rowBytes + x)
            EndIf
            PokeA(*Img\Index + y * w + x, k)
          Next
        Next
      Case "PAL "
        If len < 4 : ok = #False : Break : EndIf
        slot = PeekA(*Buf + at + 8) : n = GLTile_Get16(*Buf + at + 10)
        If slot >= #GL_PALETTE_SLOTS Or n < 1 Or n > #GL_PALETTE_SIZE Or len <> 4 + n * 4 Or Pals(slot) : ok = #False : Break : EndIf
        *Pal = GL_PaletteCreate(n)
        For i = 0 To n - 1 : GL_PaletteSet(*Pal, i, PeekL(*Buf + at + 12 + i * 4)) : Next
        *Pal\Count = n
        Pals(slot) = *Pal
    EndSelect
    at + 8 + ((len + 3) & ~3)
  Next
  If Not ok
    If *Img : GL_IndexedFree(*Img) : *Img = 0 : EndIf
    For k = 0 To #GL_PALETTE_SLOTS - 1
      If Pals(k) : GL_PaletteFree(Pals(k)) : Pals(k) = 0 : EndIf
    Next
    GLPal_Fail(Path + " is damaged.")
  EndIf
  *ImgOut\i = *Img
  ProcedureReturn ok
EndProcedure

; Load an indexed image with its palettes (which it then owns).
Procedure.i GL_IndexedLoad(Path.s)
  Protected Size.i, *Buf = GLPal_ReadFile(Path, @Size), *Img.GLIndexedImage, k.i, ok.i
  Protected Dim Pals.i(#GL_PALETTE_SLOTS - 1)
  If Not *Buf : ProcedureReturn 0 : EndIf
  ok = GLPal_ParseFile(*Buf, Size, Path, @*Img, Pals())
  FreeMemory(*Buf)
  If ok And Not *Img
    For k = 0 To #GL_PALETTE_SLOTS - 1
      If Pals(k) : GL_PaletteFree(Pals(k)) : EndIf
    Next
    ProcedureReturn GLPal_Fail(Path + " holds no image.")
  EndIf
  If Not ok : ProcedureReturn 0 : EndIf
  For k = 0 To #GL_PALETTE_SLOTS - 1 : *Img\Palette[k] = Pals(k) : Next
  *Img\OwnsPalettes = #True
  ProcedureReturn *Img
EndProcedure

; Load the palette in Slot of a file (an image file or a palette file). The
; caller owns it.
Procedure.i GL_PaletteLoad(Path.s, Slot.i = 0)
  Protected Size.i, *Buf = GLPal_ReadFile(Path, @Size), *Img.GLIndexedImage, k.i, *Keep
  Protected Dim Pals.i(#GL_PALETTE_SLOTS - 1)
  If Not *Buf : ProcedureReturn 0 : EndIf
  If Not GLPal_ParseFile(*Buf, Size, Path, @*Img, Pals()) : FreeMemory(*Buf) : ProcedureReturn 0 : EndIf
  FreeMemory(*Buf)
  If *Img : GL_IndexedFree(*Img) : EndIf
  For k = 0 To #GL_PALETTE_SLOTS - 1
    If k = Slot : *Keep = Pals(k) : ElseIf Pals(k) : GL_PaletteFree(Pals(k)) : EndIf
  Next
  If Not *Keep : ProcedureReturn GLPal_Fail(Path + " has no palette in slot " + Str(Slot) + ".") : EndIf
  ProcedureReturn *Keep
EndProcedure

; ============================================================================
; THE OPENGL BACK END
; ============================================================================
; One program, one 256 x 256 palette texture (row = palette), and a batch of
; quads whose vertices are: position (2), texture point (2), colour (4), the
; palette's row (1). Started on first use; GL_PaletteShutdown before the
; context goes away. Like the sprite batcher, it belongs to one context.

Global GLPal_Program.l, GLPal_VAO.l, GLPal_VBO.l, GLPal_PaletteTex.l
Global GLPal_LocIndex.l, GLPal_LocPalette.l
Global *GLPal_Buffer, GLPal_Count.i, GLPal_Texture.l, GLPal_Flushes.i
Global Dim GLPal_RowOwner.i(255)              ; the palette in each row
#GLPal_Stride = 36                            ; bytes a vertex
#GLPal_QuadBytes = 6 * #GLPal_Stride

; The shaders, also for a check program to compile and report on its own.
Procedure.s GLPal_VertexSource()
  ProcedureReturn "#version 140" + #LF$ + "#extension GL_ARB_explicit_attrib_location : enable" + #LF$ +
                  "layout (location = 0) in vec2 pos;" + #LF$ + "layout (location = 1) in vec2 uv;" + #LF$ +
                  "layout (location = 2) in vec4 col;" + #LF$ + "layout (location = 3) in float row;" + #LF$ +
                  "out vec2 TexCoords; out vec4 VertexColor; flat out int PaletteRow;" + #LF$ +
                  "void main() { gl_Position = vec4(pos, 0.0, 1.0); TexCoords = uv; VertexColor = col; PaletteRow = int(row + 0.5); }"
EndProcedure
Procedure.s GLPal_FragmentSource()
  ProcedureReturn "#version 140" + #LF$ + "in vec2 TexCoords; in vec4 VertexColor; flat in int PaletteRow;" + #LF$ +
                  "out vec4 color; uniform sampler2D indexTex; uniform sampler2D paletteTex;" + #LF$ +
                  "void main() { int i = int(texture(indexTex, TexCoords).r * 255.0 + 0.5);" + #LF$ +
                  " color = texelFetch(paletteTex, ivec2(i, PaletteRow), 0) * VertexColor; }"
EndProcedure

Procedure.i GL_PaletteInit()
  Protected major.l, *Name
  If GLPal_Program : ProcedureReturn #True : EndIf
  If Not glCreateShader Or Not glGenVertexArrays : ProcedureReturn GLPal_Fail("GL_PaletteInit: open an OpenGL window first.") : EndIf
  glGetIntegerv_(#GL_MAJOR_VERSION, @major)
  If major < 3 : ProcedureReturn GLPal_Fail("GL_PaletteInit: the palette look-up needs OpenGL 3.0.") : EndIf
  GLPal_Program = Util_CompileProgram(GLPal_VertexSource(), GLPal_FragmentSource())
  *Name = UTF8("indexTex") : GLPal_LocIndex = glGetUniformLocation(GLPal_Program, *Name) : FreeMemory(*Name)
  *Name = UTF8("paletteTex") : GLPal_LocPalette = glGetUniformLocation(GLPal_Program, *Name) : FreeMemory(*Name)
  glGenTextures_(1, @GLPal_PaletteTex)
  glBindTexture_(#GL_TEXTURE_2D, GLPal_PaletteTex)
  glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_RGBA, 256, 256, 0, #GL_RGBA, #GL_UNSIGNED_BYTE, #Null)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MIN_FILTER, #GL_NEAREST)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MAG_FILTER, #GL_NEAREST)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_S, #GL_CLAMP_TO_EDGE)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_T, #GL_CLAMP_TO_EDGE)
  *GLPal_Buffer = AllocateMemory(GL_MaxBatch * #GLPal_QuadBytes)
  glGenVertexArrays(1, @GLPal_VAO) : glGenBuffers(1, @GLPal_VBO)
  glBindVertexArray(GLPal_VAO) : glBindBuffer(#GL_ARRAY_BUFFER, GLPal_VBO)
  glBufferData(#GL_ARRAY_BUFFER, GL_MaxBatch * #GLPal_QuadBytes, #Null, #GL_DYNAMIC_DRAW)
  glVertexAttribPointer(0, 2, #GL_FLOAT, #GL_FALSE, #GLPal_Stride, 0)  : glEnableVertexAttribArray(0)
  glVertexAttribPointer(1, 2, #GL_FLOAT, #GL_FALSE, #GLPal_Stride, 8)  : glEnableVertexAttribArray(1)
  glVertexAttribPointer(2, 4, #GL_FLOAT, #GL_FALSE, #GLPal_Stride, 16) : glEnableVertexAttribArray(2)
  glVertexAttribPointer(3, 1, #GL_FLOAT, #GL_FALSE, #GLPal_Stride, 32) : glEnableVertexAttribArray(3)
  glBindVertexArray(0)
  ProcedureReturn #True
EndProcedure

; Back end 1: the image's indices on the GPU (again when they changed).
Procedure.i GLPal_BackIndexUpload(*Img.GLIndexedImage)
  Protected *Rows, y.i, src.i
  If *Img\TextureID And Not *Img\Changed : ProcedureReturn *Img\TextureID : EndIf
  If Not *Img\TextureID
    glGenTextures_(1, @*Img\TextureID)
    glBindTexture_(#GL_TEXTURE_2D, *Img\TextureID)
    glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MIN_FILTER, #GL_NEAREST)
    glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MAG_FILTER, #GL_NEAREST)
    glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_S, #GL_CLAMP_TO_EDGE)
    glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_T, #GL_CLAMP_TO_EDGE)
  Else
    glBindTexture_(#GL_TEXTURE_2D, *Img\TextureID)
  EndIf
  ; the same row order as a sprite's texture, so one texture-point rule serves both
  *Rows = AllocateMemory(*Img\Width * *Img\Height, #PB_Memory_NoClear)
  For y = 0 To *Img\Height - 1
    src = y
    CompilerIf #GL_SpriteRowsBottomUp
      src = *Img\Height - 1 - y
    CompilerEndIf
    CopyMemory(*Img\Index + src * *Img\Width, *Rows + y * *Img\Width, *Img\Width)
  Next
  glPixelStorei_(#GL_UNPACK_ALIGNMENT, 1)
  glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_R8, *Img\Width, *Img\Height, 0, #GL_RED, #GL_UNSIGNED_BYTE, *Rows)
  glPixelStorei_(#GL_UNPACK_ALIGNMENT, 4)
  FreeMemory(*Rows)
  *Img\Changed = #False
  ProcedureReturn *Img\TextureID
EndProcedure

; Back end 2: free the image's indices on the GPU.
Procedure GLPal_BackIndexFree(*Img.GLIndexedImage)
  If *Img\TextureID : glDeleteTextures_(1, @*Img\TextureID) : *Img\TextureID = 0 : EndIf
EndProcedure

; Back end 3: the palette's row, its shown colours written there when they
; changed. -1 when all 256 rows are taken.
Procedure.i GLPal_BackPaletteCommit(*Pal.GLPalette)
  Protected r.i
  If *Pal\Row < 0
    For r = 0 To 255
      If GLPal_RowOwner(r) = 0 : Break : EndIf
    Next
    If r > 255 : GLPal_Fail("More than 256 palettes in use at once.") : ProcedureReturn -1 : EndIf
    GLPal_RowOwner(r) = *Pal : *Pal\Row = r : *Pal\Changed = #True
  EndIf
  If *Pal\Changed
    glBindTexture_(#GL_TEXTURE_2D, GLPal_PaletteTex)
    glTexSubImage2D_(#GL_TEXTURE_2D, 0, 0, *Pal\Row, 256, 1, #GL_RGBA, #GL_UNSIGNED_BYTE, @*Pal\Shown[0])
    *Pal\Changed = #False
  EndIf
  ProcedureReturn *Pal\Row
EndProcedure

; Back end 4: give the palette's row back.
Procedure GLPal_BackPaletteFree(*Pal.GLPalette)
  If *Pal\Row >= 0 And *Pal\Row < 256 And GLPal_RowOwner(*Pal\Row) = *Pal : GLPal_RowOwner(*Pal\Row) = 0 : EndIf
  *Pal\Row = -1
EndProcedure

; Back end 5: draw the batch.
Procedure GLPal_Flush()
  If GLPal_Count = 0 : ProcedureReturn : EndIf
  glUseProgram(GLPal_Program)
  glActiveTexture(#GL_TEXTURE1) : glBindTexture_(#GL_TEXTURE_2D, GLPal_PaletteTex)
  glActiveTexture(#GL_TEXTURE0) : glBindTexture_(#GL_TEXTURE_2D, GLPal_Texture)
  glUniform1i(GLPal_LocIndex, 0) : glUniform1i(GLPal_LocPalette, 1)
  glBindVertexArray(GLPal_VAO) : glBindBuffer(#GL_ARRAY_BUFFER, GLPal_VBO)
  CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
    glBufferData(#GL_ARRAY_BUFFER, GL_MaxBatch * #GLPal_QuadBytes, #Null, #GL_DYNAMIC_DRAW)
  CompilerEndIf
  glBufferSubData(#GL_ARRAY_BUFFER, 0, GLPal_Count * #GLPal_QuadBytes, *GLPal_Buffer)
  glDrawArrays_(#GL_TRIANGLES, 0, GLPal_Count * 6)
  glBindVertexArray(0)
  GL_StatDrawCalls + 1 : GL_StatBufferUploads + 1 : GLPal_Flushes + 1
  GLPal_Count = 0
EndProcedure

; Start drawing *Img: a new batch if its indices are another texture.
Procedure.i GLPal_Begin(*Img.GLIndexedImage)
  Protected tex.l
  If Not GL_PaletteInit() : ProcedureReturn #False : EndIf
  tex = GLPal_BackIndexUpload(*Img)
  If tex <> GLPal_Texture : GLPal_Flush() : GLPal_Texture = tex : EndIf
  ProcedureReturn #True
EndProcedure

; The palette a draw uses: *Explicit, else the override for Slot, else the
; image's Slot, else the image's slot 0. 0 when there is none.
Procedure.i GLPal_Choose(*Img.GLIndexedImage, Slot.i, *Overrides, *Explicit.GLPalette)
  Protected *P
  If *Explicit : ProcedureReturn *Explicit : EndIf
  If Slot < 0 Or Slot >= #GL_PALETTE_SLOTS : Slot = 0 : EndIf
  If *Overrides : *P = PeekI(*Overrides + Slot * SizeOf(Integer)) : If *P : ProcedureReturn *P : EndIf : EndIf
  If *Img\Palette[Slot] : ProcedureReturn *Img\Palette[Slot] : EndIf
  ProcedureReturn *Img\Palette[0]
EndProcedure

Macro GLPal_Vertex(Ptr, NX, NY, U, V, R, G, B, A, Row)
  Ptr\f = NX : Ptr + 4 : Ptr\f = NY : Ptr + 4 : Ptr\f = U : Ptr + 4 : Ptr\f = V : Ptr + 4
  Ptr\f = R : Ptr + 4 : Ptr\f = G : Ptr + 4 : Ptr\f = B : Ptr + 4 : Ptr\f = A : Ptr + 4 : Ptr\f = Row : Ptr + 4
EndMacro

; One quad into the palette batch: corners TL, TR, BL, BR already in device
; coordinates (NX(), NY()) and their texture points.
Procedure GLPal_Quad(*NX.Float, *NY.Float, *U.Float, *V.Float, R.f, G.f, B.f, A.f, Row.i)
  Protected *P.Float, rf.f = Row
  If GLPal_Count >= GL_MaxBatch : GLPal_Flush() : EndIf
  *P = *GLPal_Buffer + GLPal_Count * #GLPal_QuadBytes
  GLPal_Vertex(*P, PeekF(*NX), PeekF(*NY), PeekF(*U), PeekF(*V), R, G, B, A, rf)
  GLPal_Vertex(*P, PeekF(*NX + 8), PeekF(*NY + 8), PeekF(*U + 8), PeekF(*V + 8), R, G, B, A, rf)
  GLPal_Vertex(*P, PeekF(*NX + 4), PeekF(*NY + 4), PeekF(*U + 4), PeekF(*V + 4), R, G, B, A, rf)
  GLPal_Vertex(*P, PeekF(*NX + 8), PeekF(*NY + 8), PeekF(*U + 8), PeekF(*V + 8), R, G, B, A, rf)
  GLPal_Vertex(*P, PeekF(*NX + 12), PeekF(*NY + 12), PeekF(*U + 12), PeekF(*V + 12), R, G, B, A, rf)
  GLPal_Vertex(*P, PeekF(*NX + 4), PeekF(*NY + 4), PeekF(*U + 4), PeekF(*V + 4), R, G, B, A, rf)
  GLPal_Count + 1
EndProcedure

; Free the back end's GPU objects; every palette loses its row (it gets one
; again at its next draw, after a new GL_PaletteInit). Free indexed images'
; textures (GL_IndexedFree) before the context goes, as with sprites.
Procedure GL_PaletteShutdown()
  Protected r.i, *Pal.GLPalette, delProgram.glDeleteProgram, delVAO.glDeleteVertexArrays, delBuffer.glDeleteBuffers
  If Not GLPal_Program : ProcedureReturn : EndIf
  For r = 0 To 255
    *Pal = GLPal_RowOwner(r)
    If *Pal : *Pal\Row = -1 : *Pal\Changed = #True : GLPal_RowOwner(r) = 0 : EndIf
  Next
  delProgram = GetGLProc("glDeleteProgram") : delVAO = GetGLProc("glDeleteVertexArrays") : delBuffer = GetGLProc("glDeleteBuffers")
  If delProgram : delProgram(GLPal_Program) : EndIf
  If delVAO : delVAO(1, @GLPal_VAO) : EndIf
  If delBuffer : delBuffer(1, @GLPal_VBO) : EndIf
  glDeleteTextures_(1, @GLPal_PaletteTex)
  FreeMemory(*GLPal_Buffer) : *GLPal_Buffer = 0
  GLPal_Program = 0 : GLPal_VAO = 0 : GLPal_VBO = 0 : GLPal_PaletteTex = 0 : GLPal_Texture = 0 : GLPal_Count = 0
EndProcedure

; ============================================================================
; DRAWING AN INDEXED IMAGE
; ============================================================================

Structure GLPalCorners
  NX.f[4] : NY.f[4] : U.f[4] : V.f[4]          ; TL, TR, BL, BR
EndStructure

; Draw *Img as DrawGLSprite draws a sprite: top-left at X, Y, turned about its
; centre, scaled, tinted, a part of it (SrcX.. in pixels, rows from the top;
; SrcW -1 = all), through the camera unless IgnoreCamera. *Pal swaps the
; palette; 0 uses slot Slot. Orient flips / turns the picture as a tile.
; Returns the glDrawArrays issued.
Procedure.i GL_IndexedDraw(*Img.GLIndexedImage, X.f, Y.f, *Pal.GLPalette = 0, Slot.i = 0, AngleRadians.f = 0.0, Scale.f = 1.0, R.f = 1.0, G.f = 1.0, B.f = 1.0, A.f = 1.0, Scaled.b = #False, SrcX.f = 0, SrcY.f = 0, SrcW.f = -1, SrcH.f = -1, IgnoreCamera.b = #False, Orient.i = 0)
  Protected Xf.GLTileXform, Q.GLPalCorners, row.i, w.f, h.f, cx.f, cy.f, c.f, s.f, i.i, lx.f, ly.f
  Protected u0.f, vt.f, u1.f, vb.f, ss.f, tt.f, right.i, bottom.i
  If Not *Img : ProcedureReturn 0 : EndIf
  *Pal = GLPal_Choose(*Img, Slot, 0, *Pal)
  If Not *Pal : ProcedureReturn GLPal_Fail("GL_IndexedDraw: the image has no palette.") : EndIf
  If Not GLPal_Begin(*Img) : ProcedureReturn 0 : EndIf
  row = GLPal_BackPaletteCommit(*Pal)
  If row < 0 : ProcedureReturn 0 : EndIf
  If SrcW <= 0 Or SrcH <= 0 : SrcX = 0 : SrcY = 0 : SrcW = *Img\Width : SrcH = *Img\Height : EndIf
  GLTile_SourceUV(*Img\Width, *Img\Height, SrcX, SrcY, SrcW, SrcH, @u0, @vt, @u1, @vb)
  GLTile_MakeXform(@Xf, Scaled, IgnoreCamera)
  w = SrcW * Scale : h = SrcH * Scale
  cx = X + w / 2.0 : cy = Y + h / 2.0 : c = Cos(AngleRadians) : s = Sin(AngleRadians)
  For i = 0 To 3
    right = i & 1 : bottom = i >> 1
    lx = -w / 2.0 : If right : lx = w / 2.0 : EndIf
    ly = -h / 2.0 : If bottom : ly = h / 2.0 : EndIf
    Q\NX[i] = (cx + lx * c - ly * s) * Xf\KX + Xf\CX
    Q\NY[i] = (cy + lx * s + ly * c) * Xf\KY + Xf\CY
    GLTile_SourceCorner(Orient, right, bottom, ss, tt)
    Q\U[i] = u0 + (u1 - u0) * ss : Q\V[i] = vt + (vb - vt) * tt
  Next
  GLPal_Flushes = 0
  GLPal_Quad(@Q\NX[0], @Q\NY[0], @Q\U[0], @Q\V[0], R, G, B, A, row)
  GLPal_Flush()
  ProcedureReturn GLPal_Flushes
EndProcedure

; ============================================================================
; THE CPU RE-COLOUR: AN ORDINARY SPRITE
; ============================================================================

; The image through *Pal (0 = slot 0) into a new GLSprite, with its alpha
; mask, as LoadGLSprite makes one. Width x Height look-ups and an upload.
Procedure.i GL_IndexedToSprite(*Img.GLIndexedImage, *Pal.GLPalette = 0)
  Protected *Sprite.GLSprite, *Px, *Rows, y.i, src.i, i.i
  If Not *Img : ProcedureReturn 0 : EndIf
  *Px = AllocateMemory(*Img\Width * *Img\Height * 4)
  If Not *Px : ProcedureReturn GLPal_Fail("GL_IndexedToSprite: out of memory.") : EndIf
  If Not GL_IndexedResolve(*Img, *Pal, *Px) : FreeMemory(*Px) : ProcedureReturn 0 : EndIf
  *Sprite = AllocateMemory(SizeOf(GLSprite))
  *Sprite\Width = *Img\Width : *Sprite\Height = *Img\Height
  *Sprite\AlphaMask = AllocateMemory(*Img\Width * *Img\Height)
  For i = 0 To *Img\Width * *Img\Height - 1
    If Alpha(PeekL(*Px + i * 4)) > 0 : PokeB(*Sprite\AlphaMask + i, 1) : EndIf
  Next
  *Rows = AllocateMemory(*Img\Width * *Img\Height * 4, #PB_Memory_NoClear)
  For y = 0 To *Img\Height - 1
    src = y
    CompilerIf #GL_SpriteRowsBottomUp
      src = *Img\Height - 1 - y
    CompilerEndIf
    CopyMemory(*Px + src * *Img\Width * 4, *Rows + y * *Img\Width * 4, *Img\Width * 4)
  Next
  glGenTextures_(1, @*Sprite\TextureID) : glBindTexture_(#GL_TEXTURE_2D, *Sprite\TextureID)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MIN_FILTER, #GL_NEAREST)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MAG_FILTER, #GL_NEAREST)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_S, #GL_CLAMP_TO_EDGE)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_T, #GL_CLAMP_TO_EDGE)
  glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_RGBA, *Img\Width, *Img\Height, 0, #GL_RGBA, #GL_UNSIGNED_BYTE, *Rows)
  FreeMemory(*Rows) : FreeMemory(*Px)
  ProcedureReturn *Sprite
EndProcedure

; Re-colour *Sprite (made by GL_IndexedToSprite from the same image) through
; *Pal again: after a palette operation, for code that needs a GLSprite.
Procedure.i GL_IndexedBake(*Img.GLIndexedImage, *Pal.GLPalette, *Sprite.GLSprite)
  Protected *Px, *Rows, y.i, src.i
  If Not *Img Or Not *Sprite Or *Sprite\Width <> *Img\Width Or *Sprite\Height <> *Img\Height : ProcedureReturn #False : EndIf
  *Px = AllocateMemory(*Img\Width * *Img\Height * 4)
  If Not GL_IndexedResolve(*Img, *Pal, *Px) : FreeMemory(*Px) : ProcedureReturn #False : EndIf
  *Rows = AllocateMemory(*Img\Width * *Img\Height * 4, #PB_Memory_NoClear)
  For y = 0 To *Img\Height - 1
    src = y
    CompilerIf #GL_SpriteRowsBottomUp
      src = *Img\Height - 1 - y
    CompilerEndIf
    CopyMemory(*Px + src * *Img\Width * 4, *Rows + y * *Img\Width * 4, *Img\Width * 4)
  Next
  glBindTexture_(#GL_TEXTURE_2D, *Sprite\TextureID)
  glTexSubImage2D_(#GL_TEXTURE_2D, 0, 0, 0, *Img\Width, *Img\Height, #GL_RGBA, #GL_UNSIGNED_BYTE, *Rows)
  FreeMemory(*Rows) : FreeMemory(*Px)
  ProcedureReturn #True
EndProcedure

; ============================================================================
; INDEXED TILE SETS (the tile map side is GlTiles.pbi)
; ============================================================================

; Cut an indexed image into tiles, as GL_TileSetCreate cuts a sprite. Each
; tile is drawn with palette slot GL_TileSetPaletteSlot (0 unless set), so one
; image can show several palettes at once; a layer can replace any slot.
Procedure.i GL_TileSetCreateIndexed(*Img.GLIndexedImage, TileW.i, TileH.i, Spacing.i = 0, Margin.i = 0)
  Protected *Set.GLTileSet
  If Not *Img : ProcedureReturn GLTile_Fail("GL_TileSetCreateIndexed: no image.") : EndIf
  *Set = GLTile_NewSet(*Img\Width, *Img\Height, TileW, TileH, Spacing, Margin)
  If *Set : *Set\Indexed = *Img : EndIf
  ProcedureReturn *Set
EndProcedure

; The palette row a slot of an indexed set draws with now (-1: none).
Procedure.i GLTile_SlotRow(*Set.GLTileSet, Slot.i, *Palettes)
  Protected *Pal.GLPalette = GLPal_Choose(*Set\Indexed, Slot, *Palettes, 0)
  If Not *Pal : GLTile_Fail("An indexed tile set has no palette for slot " + Str(Slot) + ".") : ProcedureReturn -1 : EndIf
  ProcedureReturn GLPal_BackPaletteCommit(*Pal)
EndProcedure

; GLTile_Quad's twin for the palette batch.
Procedure GLTile_QuadPal(*X.GLTileXform, X0.f, Y0.f, X1.f, Y1.f, U0.f, VTop.f, U1.f, VBottom.f, Orient.i, R.f, G.f, B.f, A.f, Row.i)
  Protected Q.GLPalCorners, i.i, s.f, t.f, right.i, bottom.i
  For i = 0 To 3
    right = i & 1 : bottom = i >> 1
    If right : Q\NX[i] = X1 * *X\KX + *X\CX : Else : Q\NX[i] = X0 * *X\KX + *X\CX : EndIf
    If bottom : Q\NY[i] = Y1 * *X\KY + *X\CY : Else : Q\NY[i] = Y0 * *X\KY + *X\CY : EndIf
    GLTile_SourceCorner(Orient, right, bottom, s, t)
    Q\U[i] = U0 + (U1 - U0) * s : Q\V[i] = VTop + (VBottom - VTop) * t
  Next
  GLPal_Quad(@Q\NX[0], @Q\NY[0], @Q\U[0], @Q\V[0], R, G, B, A, Row)
EndProcedure

Procedure.i GLTile_BeginIndexed(*Set.GLTileSet)
  If Not GLPal_Begin(*Set\Indexed) : GLTile_Fail(GL_PaletteError()) : ProcedureReturn #False : EndIf
  GLPal_Flushes = 0
  ProcedureReturn #True
EndProcedure

Procedure.i GLTile_EndIndexed()
  GLPal_Flush()
  ProcedureReturn GLPal_Flushes
EndProcedure
