# GlUtilities.pbi: text and fonts

## Structures and constants

### Structure GLFont

A font and its glyph cache. Fields a program reads:

- `LineHeight` - the line height in pixels (the height of "A"); 0 when the face could not be loaded. A check program may set it (chapter 18).
- `BaseSize` - the size in points it was made at; `FontName`, `Style` - as given.
- `FixedAdvance` - above 0 when every glyph advances by this much; `MeasuredAdvance` - the width of "0", unrounded.
- `SnapToPixel`, `ShowControls` - the switches below.
- `PageCount`, `PageBudget`, `Misses`, `Evictions` - the cache's pages in use and allowed, characters drawn into pages, pages reused.
- `TextureID` - page 0's texture, which holds ASCII.

The rest (`PBFont`, `Ascent`, `Pages`, `Tofu`, `TofuReady`, `Block`) is the cache itself.

### Structure GLFontPage

One atlas page of a font's cache: its texture, its generation (raised each time the page is reused), the shelf the next glyph goes on, how many glyphs are on it, when it was last drawn from, and whether it is page 0 (`Pinned`, never reused).

### Structure GLGlyph

One character of a font's cache: where it is on its page (`u1`, `v1`, `u2`, `v2`), its size and advance in pixels, its page and that page's generation when it was put there, and its `State`: `#GLF_EMPTY` (0, never asked for), `#GLF_RESIDENT` (1, on a page), `#GLF_BLANK` (2, a character that draws nothing) or `#GLF_TOFU` (3, missing from the face: drawn as a box).

Internal: `GLFontRegEntry`

## Making fonts

### CreateGLFont

Makes a font of the face `FontName` at `Size` points in `Style` (`#PB_Font_Bold`, `#PB_Font_Italic` ...): loads the face, makes page 0 and draws the ASCII characters 32 to 126 into it. Returns the font, or 0 if memory could not be had. A face the system cannot load still gives a font, which draws nothing and has a `LineHeight` of 0.

### CreateGLFontFixed

As `CreateGLFont`, with every character advancing by the same whole number of pixels: the width of "0" (averaged over ten, rounded) or `AdvanceOverride` when above 0 (at least 1). Turns pixel snapping on.

### GLFontPointsForPixelHeight

Returns the point size at which the face's line height is `WantPixels` pixels, within one: starts at three quarters of `WantPixels` (at least 5 points) and corrects from the measured height, at most six times. Loads and frees the face to measure; makes no texture.

### CreateGLFontPx

A font whose line height is `WantPixels` pixels: `CreateGLFont` at `GLFontPointsForPixelHeight`.

### CreateGLFontFixedPx

As `CreateGLFontPx`, with a fixed advance (`CreateGLFontFixed`).

### GLFontFor

Returns the font for (`FontName`, `PixelHeight`, `Style`, `FixedAdvance`), making it the first time it is asked for (with `CreateGLFontPx` or `CreateGLFontFixedPx`) and returning the same font afterwards; the face name is compared without regard to case. Each call marks the font as wanted. Returns 0 if it could not be made.

### GLFontsPurgeUnused

Frees every font made by `GLFontFor` that has not been asked for since the last purge, and returns how many it freed.

### GLFontsRegistered

Returns how many fonts `GLFontFor` holds.

### FreeGLFont

Frees a font: its pages, its cache and its face.

## Settings and questions

### GLFontFixedAdvance

The font's fixed advance in pixels, or 0 for a proportional font (or no font).

### GLFontMeasuredAdvance

The width of "0" in the face, unrounded, measured over ten of them.

### GLFontLineHeight

The font's line height in pixels; 0 for no font or a face that did not load.

### GLFontSetFixedAdvance

Gives a font a fixed advance of `Advance` pixels, or makes it proportional again with 0. The ASCII characters change at once; others as they are next drawn into a page.

### GLFontSetSnapToPixel

`On` rounds every glyph's position to a whole pixel before drawing it (sharp text on a 1:1 canvas). Off by default for `CreateGLFont`, on for the fixed forms.

### GLFontSetShowControls

`On` draws control characters (below 32, and 127) as boxes instead of leaving them out. Off by default.

### GLFontSetPageBudget

How many atlas pages the font may have before it reuses them: `Pages` is kept between 2 and 8.

### GLFontPageCount

The atlas pages the font has now.

### GLFontMisses

How many characters have been drawn into the font's pages since it was made.

### GLFontEvictions

How many times one of the font's pages has been emptied for reuse.

### GLFontGlyphState

What became of one character (`cp`, a code point): it is looked up, and drawn into a page if it never was, then its state is returned: `#GLF_RESIDENT`, `#GLF_BLANK`, `#GLF_TOFU`, or `#GLF_EMPTY` for no font.

## Drawing and measuring

### DrawGLText

Draws one line of text with its top-left corner at `ScreenX`, `ScreenY`.

- `*f` - the font; 0 draws nothing.
- `Text` - the text; "" draws nothing. Characters above U+FFFF as surrogate pairs; controls skipped unless shown; tab and line breaks take no room.
- `R`, `G`, `B`, `A` - the colour.
- `Scaled` - `#True`: canvas units. `IgnoreCamera` - **default `#True`**: the camera is not applied.

One draw call for each run of characters on the same page, at most 256 characters a call. Counted in `GL_StatTextCalls`, `GL_StatTextDraws`, `GL_StatGlyphs`, `GL_StatDrawCalls`, `GL_StatBufferUploads`; logged by the draw log.

### GetGLTextWidth

The width `DrawGLText` covers for `Text` in pixels, from the same advances; 0 for no font or "". With a fixed advance it is the number of characters (controls left out) times the advance.

### GLTextXForColumn

Where column `Col` (counted in characters from 0) starts in `Text`, in pixels from the text's left. 0 for column 0 or less.

### GLTextColumnForX

The column of `Text` nearest to `X` pixels from its left: a position in the first half of a character gives its own column, in the second half the next. 0 for `X` 0 or less; at most the text's length.
