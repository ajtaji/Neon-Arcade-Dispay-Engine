# Text and fonts

## Fonts and the glyph cache

A **font** (`GLFont`) is a typeface the system can load, at one size and style, with a cache of its glyphs in OpenGL textures. `CreateGLFont(FontName, Size, Style)` makes one: `FontName` is the face's family name (`"Segoe UI"`, `"Lato"`), `Size` its size in points, `Style` PureBasic's font flags (`#PB_Font_Bold`, `#PB_Font_Italic`, ...).

The glyphs live in **atlas pages**, textures of 1024 by 1024 pixels:

- Page 0 is filled when the font is made, with the printable ASCII characters 32 to 126, and is never emptied.
- Any other character is drawn into a page the first time it is asked for. Pages are added as they fill, up to a budget (8 by default, `GLFontSetPageBudget`, at least 2); when every page is full, the least recently used page other than page 0 is emptied and reused. A glyph whose page was reused is drawn again the next time it is asked for.
- The whole Unicode range is covered; a character above U+FFFF arrives in a string as a surrogate pair and is decoded as one character.
- A character the face cannot draw is shown as a **hollow box** (the "tofu" glyph), so a missing glyph is always visible. A character that is meant to be blank - the space, the no-break space, the U+2000 to U+200F family, U+202F, U+205F, U+2060, U+3000, U+FEFF, U+1680, U+180E - advances and draws nothing.
- Control characters (below 32, and 127) take no room and draw nothing, unless `GLFontSetShowControls(*Font, #True)` asks for them to be shown as boxes. Tab, carriage return and line feed are not laid out: a program splits text into lines itself.

`GLFontGlyphState(*Font, Codepoint)` says what happened to one character: `#GLF_RESIDENT` (in a page), `#GLF_BLANK`, `#GLF_TOFU`, or `#GLF_EMPTY` (never asked for). `GLFontPageCount`, `GLFontMisses` and `GLFontEvictions` count pages, characters drawn into pages, and pages reused.

## Drawing and measuring

`DrawGLText(*Font, X, Y, Text, R, G, B, A, Scaled, IgnoreCamera)` draws one line of text with its top-left corner at `X, Y`. **It ignores the camera by default** (`IgnoreCamera = #True`). It draws one call for each run of characters that share a page, at most 256 characters a call; a text of any length is drawn whole.

`GetGLTextWidth(*Font, Text)` is the width that same call covers, from the same advances, so a measurement and the picture always agree. `GLFontLineHeight(*Font)` is the font's line height: the height of a capital A as the system draws it. A glyph advances by its own width plus 5 percent of the font's size in points; this is the rule every layout in the engine is measured by.

## Fonts sized in pixels

In a DPI-aware program the system scales a font's point size by the desktop's factor, while the canvas is a fixed number of pixels. **Ask for fonts by their height in pixels**:

- `CreateGLFontPx(FontName, Pixels, Style)` makes a font whose line height is `Pixels`, within one pixel, on any desktop. It finds the point size with `GLFontPointsForPixelHeight`: it starts at three quarters of the pixel height, measures the height the system really draws, and corrects, at most six times.
- `CreateGLFontFixedPx(FontName, Pixels, Style, Advance)` does the same with a fixed advance (below).
- `GLFontFor(FontName, Pixels, Style, Fixed)` returns the same font for the same request, making it only the first time, and `GLFontsPurgeUnused()` frees every font made this way that has not been asked for since the last purge. A program that rebuilds its fonts when the display's scale changes asks `GLFontFor` for every font it wants, then purges: the fonts it no longer wants are freed without it keeping a list. `GLFontsRegistered()` counts them.

## Fixed advance, for code and columns

`CreateGLFontFixed(FontName, Size, Style, Advance)` makes a font in which every character advances by exactly the same number of pixels: by default the width of "0" measured over ten of them and rounded to a whole pixel, or `Advance` when it is above 0. It also turns on **pixel snapping** (`GLFontSetSnapToPixel`), which rounds each glyph's position to a whole pixel so the text is not blurred by sampling between pixels. Then:

- `GLFontFixedAdvance(*Font)` is that advance (0 for a proportional font); `GLFontMeasuredAdvance(*Font)` is the unrounded width of "0".
- `GLTextXForColumn(*Font, Text, Column)` is where column `Column` starts, and `GLTextColumnForX(*Font, Text, X)` the column nearest to `X`: the arithmetic `DrawGLText` uses, so a pointer and a caret agree. Columns count characters (a character above U+FFFF is one column). Both work on proportional fonts too, by adding up the advances.
- `GLFontSetFixedAdvance(*Font, Advance)` changes an existing font to a fixed advance (0 makes it proportional again); it changes the advance of ASCII at once and of other characters as they are next drawn.

## The typefaces in the repository

The engine's `assets/fonts` folder holds two typefaces, both under the SIL Open Font License, Version 1.1, which allows them to be used, embedded and redistributed with software as long as the licence goes with them:

| File | Family | Licence file |
|---|---|---|
| `Lato-Regular.ttf` | Lato (proportional) | `Lato-OFL.txt` |
| `JetBrainsMono-Regular.ttf` | JetBrains Mono (monospaced) | `JetBrainsMono-OFL.txt` |

`assets/fonts/FONTS.txt` lists them. A program that ships them ships the licence files beside them. To use them, a font file is first registered for the process, then named by its family. The application kit does both: `Neon_UseFaceSet(#NEON_FACES_OPEN, FontDir)` registers the two files from `FontDir` and selects "Lato" and "JetBrains Mono"; `Neon_SetFaces(UIFace, MonoFace, UIFile, MonoFile)` does the same for any two files. A file that cannot be registered is refused (`#False`, the reason in `Neon_FaceError()`), and the selection stays as it was. `Neon_FaceUI` and `Neon_FaceMono` are then the family names to give `CreateGLFontPx`. Only the regular weight of each face is in the repository: bold and italic fonts made from them are the system's own emboldened and slanted forms. The default selection is `#NEON_FACES_WINDOWS`, "Segoe UI" and "Consolas", the faces Windows has.

## A worked example

@include examples/text.pb

## Freeing fonts

`FreeGLFont(*Font)` frees a font's pages, its cache and its system font. Free a font only when nothing will draw with it again: the arcade kit's gadgets keep the font they were made with (chapter 11), and the application kit draws through its five font globals (chapter 12).
