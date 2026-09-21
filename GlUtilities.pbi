; ============================================================================
; DOT GOBBLER DELUXE ENGINE - CORE UTILITIES (V3)
; ============================================================================
; 
; --- ENGINE PHILOSOPHY & PIPELINE ---
; This framework decouples the "Game Resolution" from the "Window Resolution".
; 
; 1. VIRTUAL CANVAS (The FBO):
;    All game logic and drawing functions operate on a fixed internal resolution 
;    (Util_BaseWidth x Util_BaseHeight). The engine draws everything to an 
;    invisible texture in RAM (the FBO) first.
;
; 2. THE CAMERA:
;    The engine features a built-in 2D Camera (GL_CameraX, GL_CameraY, GL_CameraZoom).
;    Game world entities are automatically shifted by the camera. UI elements 
;    (Text, HUD) should use 'IgnoreCamera = #True' so they stick to the screen.
;
; 3. THE FINAL STAMP (Letterboxing & CRT):
;    Once the FBO is completely drawn, the engine slaps that texture onto the 
;    physical window. GL_HandleResize() automatically calculates the black 
;    letterbox bars to preserve the aspect ratio, no matter how the user 
;    stretches or maximizes the window.
;
; --- STANDARD MAIN LOOP PIPELINE ---
;   glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
;   glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
;   ... DrawGame() ...
;   glBindFramebuffer(#GL_FRAMEBUFFER, 0)
;   glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
;   DrawRetroCRT() OR DrawPassthrough()
;
; ============================================================================
; HiDPI: THE FIVE THINGS, AND WHAT GOES WRONG IF YOU MISS ONE
; ============================================================================
; Written down here because it has now been solved twice from scratch -
; once in DotGobblerDeluxe.pb and again in ArduinoBasic/AvrEmuDebugger.pb -
; and every failure mode looks like a LAYOUT bug rather than a scaling one,
; so the search starts in the wrong place.
;
; 1. BUILD WITH /DPIAWARE  (IDE: "DPI aware"; CLI: pbcompiler ... /DPIAWARE)
;    Without it Windows scales the whole window by the desktop factor. A
;    1600x950 layout becomes 2000x1187 at 125%, overflows the monitor, and
;    the right-hand edge is silently cut off. Do NOT reach for
;    SetProcessDPIAware() from user32 instead: it is a Windows-only API
;    call in a codebase that also builds for Linux, and the flag already
;    does the job on both.
;
; 2. LINUX: SHIELD AND SCALE, BEFORE ANY INCLUDE
;      CompilerIf #PB_Compiler_OS = #PB_OS_Linux
;        SetEnvironmentVariable("GDK_BACKEND", "x11")
;        ImportC "" : gtk_widget_get_scale_factor(*widget) : EndImport
;      CompilerEndIf
;    then after the window exists:
;      Linux_DPIScale = gtk_widget_get_scale_factor(GadgetID(GLGadget))
;    GL_HandleResize() and MapPhysicalToVirtual() both read Linux_DPIScale;
;    leave it at its default and the viewport and the mouse disagree with
;    each other on any scaled desktop.
;
; 3. NEVER OPEN A WINDOW BIGGER THAN THE DESKTOP
;      ExamineDesktops() : TrueW = DesktopWidth(0) : TrueH = DesktopHeight(0)
;    and clamp the requested size to it, preserving aspect. A window larger
;    than the screen cannot be dragged back into view.
;
; 4. SET Util_BaseWidth/Height TO THE AUTHORED RESOLUTION
;    OpenGLWindow() sets them to the size it CREATED, which is only the
;    authored size by luck. Set them explicitly to the resolution the
;    layout was designed at, then call GL_HandleResize() once at startup
;    and again on #PB_Event_SizeWindow. That is what makes the letterbox
;    maths correct at every window size.
;
; 5. FONTS ARE SIZED IN CANVAS PIXELS, NOT POINTS
;    The one that bites hardest. In a DPI-aware app PureBasic scales font
;    point sizes by the desktop factor, but CreateGLFont() bakes its atlas
;    for a canvas that is a FIXED number of texels. Ask for 14 on a 200%
;    display and you get ~28 texels - every column then overlaps the one
;    beside it, and it reads as a layout mistake. Divide the request by the
;    same factor to cancel it:
;
;      Procedure.i VFontSize(CanvasPixels.i)
;        Protected sc.f = 1.0
;        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
;          sc = DesktopResolutionX()
;        CompilerElse
;          sc = Linux_DPIScale
;        CompilerEndIf
;        If sc <= 0.0 : sc = 1.0 : EndIf
;        ProcedureReturn Round(CanvasPixels / sc, #PB_Round_Nearest)
;      EndProcedure
;
; AND FOR INPUT: put every mouse coordinate through MapPhysicalToVirtual()
; (GlUI.pbi) before hit-testing it. It undoes the letterbox offset, the
; scale, and - when UI_UseCRT is set - the barrel warp, so the click lands
; where the user seems to be pointing rather than where the pixel is.
; ============================================================================

XIncludeFile "opengl_constants.pbi"
XIncludeFile "opengl_extensions.pbi" 
XIncludeFile "opengl_prototypes.pbi" 
XIncludeFile "opengl_features.pbi"

Declare GL_HandleResize(GadgetID.i)

; ============================================================================
; THE GLYPH CACHE
; ============================================================================
; WHAT THIS REPLACED, AND WHY IT HAD TO GO.
;
; CreateGLFont used to bake exactly glyphs 32..126 into one fixed 1024x1024
; atlas, and DrawGLText carried
;
;     If Ascii >= 32 And Ascii <= 126
;
; with no Else. Anything outside that range - a smart quote pasted from a
; web page, an accented name, a degree sign, a box-drawing character, any
; CJK at all - was DROPPED. No error, no box, no gap: the character simply
; was not there, and the text either side closed up over the hole.
;
; GetGLTextWidth had the same range test, so a measured width agreed with a
; wrong picture and every alignment computed from it was confidently wrong.
; That is a SILENT WRONG ANSWER, which is the one failure class this project
; refuses outright. A read-only view of ASCII source survives it. An editor
; cannot.
;
; ----------------------------------------------------------------------------
; HOW IT WORKS NOW
; ----------------------------------------------------------------------------
; Glyphs are rasterised ON FIRST USE and kept in atlas PAGES.
;
;   * Lookup is a two-level table over the whole Unicode range: block =
;     cp >> 8 picks a 256-entry array, cp & 255 indexes it. Two loads and an
;     index - no map, no hashing, no search. The blocks are allocated only
;     when something in them is actually asked for, so a session that only
;     ever draws ASCII allocates exactly one block.
;
;   * PAGE 0 IS PINNED and carries the eager ASCII bake, exactly as before.
;     The common case is therefore resident before the first frame and can
;     never be evicted by a flood of rare glyphs. That is the whole reason
;     the fast path is not slower than it was.
;
;   * Pages beyond the first are allocated on demand up to a budget and then
;     recycled LRU. Eviction is BY PAGE, not by glyph: a shelf-packed atlas
;     cannot free an interior rectangle without fragmenting, and the honest
;     answer to "this page is full" is to clear the whole thing. Every glyph
;     records the page GENERATION it was minted under, so the glyphs that
;     lived on a recycled page are invalidated by a single counter bump
;     rather than by walking the table. A stale UV can therefore never be
;     drawn - the generation check fails first and the glyph is re-rasterised.
;
;   * A glyph the font cannot draw gets TOFU: a hollow box, visible, in the
;     text, where the character is. The test is not a guess about coverage,
;     it is direct - rasterise it and look at the bitmap. If nothing was
;     drawn, and the codepoint is not one that is LEGITIMATELY blank (space,
;     NBSP, the U+2000 space family, ZWSP...), it is a missing glyph and it
;     gets a box. Invisible is precisely the failure being removed here, so
;     "draw nothing" is never an outcome.
;
; ----------------------------------------------------------------------------
; ONE COORDINATE CONVENTION, NOT TWO
; ----------------------------------------------------------------------------
; The old bake uploaded a whole PureBasic image with glTexImage2D and then
; carried a CompilerIf that flipped V on Windows and not on Linux, because
; the Windows drawing buffer is bottom-up. Every glyph now goes through one
; packer that copies rows through DrawingBufferPitch() - which is negative on
; a bottom-up buffer, and walking it is the only thing that makes the row
; order a known quantity rather than a platform accident. The atlas is
; top-down on both systems and there is no V flip anywhere. One convention
; is one thing to get wrong instead of two.
; ============================================================================

#GLF_PAGE_W    = 1024
#GLF_PAGE_H    = 1024
#GLF_MAX_PAGES = 8              ; 8 MB of atlas at worst, and only if used
#GLF_PAD       = 2              ; texels between glyphs, as before
#GLF_BLOCKS    = 4352           ; 0x110000 / 256 - the whole Unicode range

; Glyph states. #GLF_BLANK exists so a space is not mistaken for a missing
; glyph: both rasterise to nothing, and only one of them is a fault.
#GLF_EMPTY    = 0               ; never asked for
#GLF_RESIDENT = 1               ; in the atlas, UVs good for this generation
#GLF_BLANK    = 2               ; legitimately empty - advance, draw nothing
#GLF_TOFU     = 3               ; could not be rasterised - draws the box

Structure GLGlyph
  u1.f : v1.f
  u2.f : v2.f
  Width.f
  Height.f
  Advance.f
  Page.l            ; which atlas page u1..v2 refer to
  Gen.l             ; the generation of that page when these UVs were minted
  State.l           ; #GLF_EMPTY / #GLF_RESIDENT / #GLF_BLANK / #GLF_TOFU
  Spare.l
EndStructure

Structure GLFontPage
  TextureID.l
  Gen.l             ; bumped on every recycle; invalidates every glyph on it
  ShelfX.l
  ShelfY.l
  ShelfH.l
  Live.l            ; glyphs currently packed here (diagnostics only)
  LastUse.q         ; LRU stamp, touched when the page is bound for a draw
  Pinned.b          ; page 0: holds the ASCII bake, never recycled
EndStructure

Structure GLFont
  ; TextureID STAYS THE FIRST FIELD and still means "the texture the ASCII
  ; lives on". Anything that reached in and read it before still reads the
  ; same thing.
  TextureID.l
  BaseSize.i
  LineHeight.f

  ; --- everything below is new; no existing caller reads any of it --------
  FontName.s
  Style.i
  PBFont.i          ; kept LOADED now: the rasteriser needs it after startup
  Ascent.f

  FixedAdvance.f    ; > 0.0 = every glyph advances by exactly this many px
  MeasuredAdvance.f ; what the face actually measures, unrounded, always set
  SnapToPixel.b     ; round each glyph's x to a whole pixel before drawing
  ShowControls.b    ; draw C0/C1 controls as tofu instead of skipping them

  PageBudget.i
  PageCount.i
  Pages.GLFontPage[#GLF_MAX_PAGES]

  Tofu.GLGlyph
  TofuReady.b

  Misses.i          ; glyphs rasterised since creation
  Evictions.i       ; pages recycled since creation

  Block.i[#GLF_BLOCKS]
EndStructure

; --- Global State ---
Global Util_WinWidth.f, Util_WinHeight.f
Global Util_BaseWidth.f, Util_BaseHeight.f 

Global Util_TextShader.l, Util_TextVAO.l, Util_TextVBO.l
Global Util_TextLoc_Tex.l, Util_TextLoc_Color.l

; ----------------------------------------------------------------------------
; INSTRUMENTATION. Three integer increments per draw call, always on.
;
; It is here because the question "how many draw calls is this screen?" was
; asked and could not be answered - the only way to find out was to guess
; from the source. A counter that is always compiled in is the difference
; between a measurement and an estimate, and it costs less than the call it
; is counting. Read them with GL_StatsReset() / GL_StatsDrawCalls().
; ----------------------------------------------------------------------------
Global GL_StatDrawCalls.q       ; EVERY glDrawArrays this engine issues
Global GL_StatTextDraws.q       ; ...of which are text batches
Global GL_StatTextCalls.q       ; DrawGLText calls made by the host
Global GL_StatGlyphs.q          ; glyph quads emitted
Global GL_StatBufferUploads.q   ; glBufferSubData calls

; The LRU clock. Bumped when a page is bound for drawing, not per glyph.
Global GLF_Clock.q

; The one staging buffer DrawGLText builds its quads in. See the note there.
Global GLF_QuadBuf.i

Global Util_ShapeShader.l, Util_ShapeVAO.l, Util_ShapeVBO.l
Global Util_ShapeLoc_Color.l

; --- FBO & CRT State ---
Prototype.i glGenFramebuffers_Type(n.l, *framebuffers)
Prototype.i glBindFramebuffer_Type(target.l, framebuffer.l)
Prototype.i glFramebufferTexture2D_Type(target.l, attachment.l, textarget.l, texture.l, level.l)
Prototype.i glCheckFramebufferStatus_Type(target.l)

Global glGenFramebuffers.glGenFramebuffers_Type
Global glBindFramebuffer.glBindFramebuffer_Type
Global glFramebufferTexture2D.glFramebufferTexture2D_Type
Global glCheckFramebufferStatus.glCheckFramebufferStatus_Type

Global Util_FBO.l, Util_FBOTex.l
Global Util_PostShader.l, Util_PostVAO.l, Util_PostVBO.l
Global Util_PostLoc_Tex.l, Util_PostLoc_Time.l
Global Util_PassShader.l

;2D Camera State
Global GL_CameraX.f = 0.0
Global GL_CameraY.f = 0.0
Global GL_CameraZoom.f = 1.0

; Window State Variables for Fullscreen Toggle
Global Util_OrigX.i, Util_OrigY.i, Util_OrigW.i, Util_OrigH.i
Global Util_OrigStyle.i
Global Util_IsFullscreen.b = #False
Global Util_MainWindowID.i
Global Util_MainGadgetID.i
Global Linux_DPIScale.d = 1.0 
Global GL_ViewportX.i = 0 
Global GL_ViewportY.i = 0
Global GL_ViewportW.i = 0
Global GL_ViewportH.i = 0

; ============================================================================
; TWO KINDS OF PROGRAM SHARE THIS ENGINE, AND THEY WANT OPPOSITE THINGS
; ============================================================================
; A GAME is authored at a fixed resolution and letterboxed: making the window
; bigger makes everything BIGGER, aspect is preserved, black bars appear.
;
; AN APPLICATION is not authored at a resolution at all. Making its window
; bigger must show MORE, not larger - and its text must be RE-RASTERISED at
; the new size rather than magnified, because a scaled glyph is a soft glyph
; and an editor full of soft glyphs is unusable. Ron, on the wave-1 IDE:
; "they are resizing the entire fbo like its a game, the ide is text and
; buttons. should act like an os."
;
; So the mode is EXPLICIT, and it defaults to the one that already shipped.
; Nothing that does not ask for #GL_VIEWPORT_NATIVE can be affected by it.
;
;   #GL_VIEWPORT_LETTERBOX (default) - unchanged. Util_BaseWidth/Height are
;       the authored canvas; GL_Viewport* is the aspect-correct rectangle the
;       canvas is stamped into.
;   #GL_VIEWPORT_NATIVE - canvas units ARE physical pixels. Util_BaseWidth/
;       Height follow the client area, the viewport is the whole client area
;       with no bars, and MapPhysicalToVirtual's scale falls out as 1.0
;       because it already derives the scale from these same globals.
;   #GL_VIEWPORT_STRETCH - a fixed authored application canvas fills the whole
;       client area. X and Y may scale independently. This is for dense fixed
;       dashboards such as the emulator, where hiding a control or reserving
;       dead bands is worse than a small aspect adjustment. Mouse mapping uses
;       those same independent scales, so hit testing remains exact.
;
; In NATIVE mode the HOST owns font sizing: nothing scales for it any more, so
; it must ask for a font in PIXELS (CreateGLFontPx) and re-ask when the DPI or
; the user's size preference changes. GLFontFor()/GLFontsPurgeUnused() below
; exist so that doing so does not leak an atlas per DPI change.
; ============================================================================
#GL_VIEWPORT_LETTERBOX = 0
#GL_VIEWPORT_NATIVE    = 1
#GL_VIEWPORT_STRETCH   = 2
Global GL_ViewportMode.i = #GL_VIEWPORT_LETTERBOX

; ============================================================================
; MULTIPLE OPENGL WINDOWS
; ============================================================================
; OpenGLWindow originally exposed one process-wide set of window, viewport and
; GPU-object globals. That is convenient for a one-window game, but it means a
; second OpenGLGadget replaces the shader/VAO/FBO names belonging to the first
; context. GLWindowContext keeps that legacy API intact while making ownership
; explicit: a host captures after constructing a window, then activates that
; context before handling its input, resize or draw work.
Structure GLWindowContext
  WindowID.i : GadgetID.i
  WinWidth.f : WinHeight.f : BaseWidth.f : BaseHeight.f
  TextShader.l : TextVAO.l : TextVBO.l : TextLocTex.l : TextLocColor.l
  ShapeShader.l : ShapeVAO.l : ShapeVBO.l : ShapeLocColor.l
  FBO.l : FBOTex.l : PostShader.l : PostVAO.l : PostVBO.l
  PostLocTex.l : PostLocTime.l : PassShader.l
  CameraX.f : CameraY.f : CameraZoom.f
  OrigX.i : OrigY.i : OrigW.i : OrigH.i : OrigStyle.i : IsFullscreen.b
  DpiScale.d
  ViewportX.i : ViewportY.i : ViewportW.i : ViewportH.i : ViewportMode.i
  Valid.b
EndStructure

Global *GL_CurrentContext.GLWindowContext

Procedure GL_ContextCapture(*Context.GLWindowContext)
  If Not *Context : ProcedureReturn : EndIf
  *Context\WindowID = Util_MainWindowID : *Context\GadgetID = Util_MainGadgetID
  *Context\WinWidth = Util_WinWidth : *Context\WinHeight = Util_WinHeight
  *Context\BaseWidth = Util_BaseWidth : *Context\BaseHeight = Util_BaseHeight
  *Context\TextShader = Util_TextShader : *Context\TextVAO = Util_TextVAO : *Context\TextVBO = Util_TextVBO
  *Context\TextLocTex = Util_TextLoc_Tex : *Context\TextLocColor = Util_TextLoc_Color
  *Context\ShapeShader = Util_ShapeShader : *Context\ShapeVAO = Util_ShapeVAO : *Context\ShapeVBO = Util_ShapeVBO
  *Context\ShapeLocColor = Util_ShapeLoc_Color
  *Context\FBO = Util_FBO : *Context\FBOTex = Util_FBOTex
  *Context\PostShader = Util_PostShader : *Context\PostVAO = Util_PostVAO : *Context\PostVBO = Util_PostVBO
  *Context\PostLocTex = Util_PostLoc_Tex : *Context\PostLocTime = Util_PostLoc_Time : *Context\PassShader = Util_PassShader
  *Context\CameraX = GL_CameraX : *Context\CameraY = GL_CameraY : *Context\CameraZoom = GL_CameraZoom
  *Context\OrigX = Util_OrigX : *Context\OrigY = Util_OrigY : *Context\OrigW = Util_OrigW : *Context\OrigH = Util_OrigH
  *Context\OrigStyle = Util_OrigStyle : *Context\IsFullscreen = Util_IsFullscreen
  *Context\DpiScale = Linux_DPIScale
  *Context\ViewportX = GL_ViewportX : *Context\ViewportY = GL_ViewportY
  *Context\ViewportW = GL_ViewportW : *Context\ViewportH = GL_ViewportH : *Context\ViewportMode = GL_ViewportMode
  *Context\Valid = Bool(Util_MainWindowID And Util_MainGadgetID)
  *GL_CurrentContext = *Context
EndProcedure

Procedure.i GL_ContextActivate(*Context.GLWindowContext)
  If Not *Context Or Not *Context\Valid : ProcedureReturn 0 : EndIf
  If Not IsWindow(*Context\WindowID) Or Not IsGadget(*Context\GadgetID) : ProcedureReturn 0 : EndIf
  SetGadgetAttribute(*Context\GadgetID, #PB_OpenGL_SetContext, #True)
  Util_MainWindowID = *Context\WindowID : Util_MainGadgetID = *Context\GadgetID
  Util_WinWidth = *Context\WinWidth : Util_WinHeight = *Context\WinHeight
  Util_BaseWidth = *Context\BaseWidth : Util_BaseHeight = *Context\BaseHeight
  Util_TextShader = *Context\TextShader : Util_TextVAO = *Context\TextVAO : Util_TextVBO = *Context\TextVBO
  Util_TextLoc_Tex = *Context\TextLocTex : Util_TextLoc_Color = *Context\TextLocColor
  Util_ShapeShader = *Context\ShapeShader : Util_ShapeVAO = *Context\ShapeVAO : Util_ShapeVBO = *Context\ShapeVBO
  Util_ShapeLoc_Color = *Context\ShapeLocColor
  Util_FBO = *Context\FBO : Util_FBOTex = *Context\FBOTex
  Util_PostShader = *Context\PostShader : Util_PostVAO = *Context\PostVAO : Util_PostVBO = *Context\PostVBO
  Util_PostLoc_Tex = *Context\PostLocTex : Util_PostLoc_Time = *Context\PostLocTime : Util_PassShader = *Context\PassShader
  GL_CameraX = *Context\CameraX : GL_CameraY = *Context\CameraY : GL_CameraZoom = *Context\CameraZoom
  Util_OrigX = *Context\OrigX : Util_OrigY = *Context\OrigY : Util_OrigW = *Context\OrigW : Util_OrigH = *Context\OrigH
  Util_OrigStyle = *Context\OrigStyle : Util_IsFullscreen = *Context\IsFullscreen
  Linux_DPIScale = *Context\DpiScale
  GL_ViewportX = *Context\ViewportX : GL_ViewportY = *Context\ViewportY
  GL_ViewportW = *Context\ViewportW : GL_ViewportH = *Context\ViewportH : GL_ViewportMode = *Context\ViewportMode
  *GL_CurrentContext = *Context
  ProcedureReturn 1
EndProcedure

Procedure GL_ContextForget(*Context.GLWindowContext)
  If Not *Context : ProcedureReturn : EndIf
  If *GL_CurrentContext = *Context : *GL_CurrentContext = 0 : EndIf
  ClearStructure(*Context, GLWindowContext)
EndProcedure

; A cheap liveness probe for a context that MAY have been lost across a display
; power-down / GPU reset (sleep + fast boot are the classic triggers). The
; caller MUST have made the context current first - see GL_ContextActivate. It
; asks the driver for a string only a live context can answer; a dead or
; not-yet-restored context returns a null pointer, exactly as GL_GetHardwareInfo
; already relies on. This never blocks, so it is safe to call from the same
; thread that pumps window messages.
Procedure.i GL_ContextIsAlive()
  If glGetString_(#GL_VERSION) = 0 : ProcedureReturn #False : EndIf
  ProcedureReturn #True
EndProcedure

Procedure GL_SetViewportMode(Mode.i)
  GL_ViewportMode = Mode
EndProcedure

; ============================================================================
; POINTER LOADER & ERROR CHECKING
; ============================================================================

; Core Pointers
Global glGenVertexArrays.glGenVertexArrays, glBindVertexArray.glBindVertexArray
Global glGenBuffers.glGenBuffers, glBindBuffer.glBindBuffer
Global glBufferData.glBufferData, glBufferSubData.glBufferSubData
Global glCreateShader.glCreateShader, glShaderSource.glShaderSource
Global glCompileShader.glCompileShader, glGetShaderiv.glGetShaderiv, glGetShaderInfoLog.glGetShaderInfoLog
Global glCreateProgram.glCreateProgram, glAttachShader.glAttachShader, glLinkProgram.glLinkProgram
Global glGetProgramiv.glGetProgramiv, glGetProgramInfoLog.glGetProgramInfoLog, glUseProgram.glUseProgram
Global glVertexAttribPointer.glVertexAttribPointer, glEnableVertexAttribArray.glEnableVertexAttribArray
Global glDeleteShader.glDeleteShader, glGetUniformLocation.glGetUniformLocation
Global glUniform1f.glUniform1f, glUniform4f.glUniform4f, glUniform1i.glUniform1i
Global glActiveTexture.glActiveTexture

; ============================================================================
; CROSS-PLATFORM OPENGL EXTENSION LOADER
; ============================================================================

CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  ImportC "-lGL"
    ; Pass a raw memory pointer instead of a PureBasic string type
    glXGetProcAddressARB(*name) 
  EndImport
CompilerEndIf

; A unified wrapper that automatically calls the right OS API
Procedure.i GetGLProc(Name.s)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ProcedureReturn wglGetProcAddress_(Name)
    
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    ; Explicitly allocate an ASCII byte array in memory for Linux GLX
    Define *AsciiName = Ascii(Name)
    Define Result = glXGetProcAddressARB(*AsciiName)
    FreeMemory(*AsciiName) ; Clean up to prevent memory leaks
    ProcedureReturn Result
  CompilerEndIf
EndProcedure

; Windows-Only VSync Pointers
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Prototype.i wglSwapIntervalEXT(interval.i)
  Prototype.i wglGetSwapIntervalEXT()
  Global wglSwapIntervalEXT.wglSwapIntervalEXT
  Global wglGetSwapIntervalEXT.wglGetSwapIntervalEXT
CompilerEndIf

Prototype.i glDrawArraysInstanced_Type(mode.l, first.l, count.l, instancecount.l)
Prototype.i glVertexAttribDivisor_Type(index.l, divisor.l)
Prototype.i glUniform2f_Type(location.l, v0.f, v1.f)
Prototype.i glUniform3f_Type(location.l, v0.f, v1.f, v2.f)

Global glUniform2f.glUniform2f_Type
Global glUniform3f.glUniform3f_Type
Global glDrawArraysInstanced.glDrawArraysInstanced_Type
Global glVertexAttribDivisor.glVertexAttribDivisor_Type

Procedure LoadModernGL()
  glGenVertexArrays = GetGLProc("glGenVertexArrays")
  glBindVertexArray = GetGLProc("glBindVertexArray")
  glGenBuffers      = GetGLProc("glGenBuffers")
  glBindBuffer      = GetGLProc("glBindBuffer")
  glBufferData      = GetGLProc("glBufferData")
  glBufferSubData   = GetGLProc("glBufferSubData")
  glCreateShader    = GetGLProc("glCreateShader")
  glShaderSource    = GetGLProc("glShaderSource")
  glCompileShader   = GetGLProc("glCompileShader")
  glGetShaderiv     = GetGLProc("glGetShaderiv")
  glGetShaderInfoLog = GetGLProc("glGetShaderInfoLog")
  glCreateProgram   = GetGLProc("glCreateProgram")
  glAttachShader    = GetGLProc("glAttachShader")
  glLinkProgram     = GetGLProc("glLinkProgram")
  glGetProgramiv    = GetGLProc("glGetProgramiv")
  glGetProgramInfoLog = GetGLProc("glGetProgramInfoLog")
  glUseProgram      = GetGLProc("glUseProgram")
  glVertexAttribPointer = GetGLProc("glVertexAttribPointer")
  glEnableVertexAttribArray = GetGLProc("glEnableVertexAttribArray")
  glDeleteShader    = GetGLProc("glDeleteShader")
  glGetUniformLocation = GetGLProc("glGetUniformLocation")
  glUniform1f       = GetGLProc("glUniform1f")
  glUniform4f       = GetGLProc("glUniform4f")
  glUniform1i       = GetGLProc("glUniform1i")
  glActiveTexture   = GetGLProc("glActiveTexture")
  glGenFramebuffers = GetGLProc("glGenFramebuffers")
  glBindFramebuffer = GetGLProc("glBindFramebuffer")
  glFramebufferTexture2D = GetGLProc("glFramebufferTexture2D")
  glCheckFramebufferStatus = GetGLProc("glCheckFramebufferStatus")
  glDrawArraysInstanced = GetGLProc("glDrawArraysInstanced")
  glVertexAttribDivisor = GetGLProc("glVertexAttribDivisor")
  glUniform2f = GetGLProc("glUniform2f")
  glUniform3f = GetGLProc("glUniform3f")
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    wglSwapIntervalEXT = GetGLProc("wglSwapIntervalEXT")
    wglGetSwapIntervalEXT = GetGLProc("wglGetSwapIntervalEXT")
  CompilerEndIf
  
  If Not glCreateShader
    MessageRequester("Fatal Error", "Failed to load OpenGL 3.3+ pointers.")
    End
  EndIf
  
  ; ============================================================================
  ; HARDWARE CAPABILITIES CHECK
  ; ============================================================================
  Define MissingFeatures.s = ""
  
  ; Check the pointers. If they are 0 (#Null), the GPU doesn't support them!
  If Not glUseProgram          : MissingFeatures + "- GLSL Shaders" + #LF$ : EndIf
  If Not glGenVertexArrays     : MissingFeatures + "- Vertex Array Objects (VAO)" + #LF$ : EndIf
  If Not glGenFramebuffers     : MissingFeatures + "- Framebuffer Objects (FBO)" + #LF$ : EndIf
  If Not glDrawArraysInstanced : MissingFeatures + "- Hardware Instancing" + #LF$ : EndIf
  
  ; If any critical feature is missing, intercept the crash and warn the user
  If MissingFeatures <> ""
    ; Attempt to grab the hardware version string to help the user debug
    Define *VersionString = glGetString_(#GL_VERSION)
    Define Version.s = "Unknown"
    If *VersionString
      Version = PeekS(*VersionString, -1, #PB_UTF8)
    EndIf
    
    Define ErrorMsg.s = "Your graphics card or driver does not support the required OpenGL features to run this game." + #LF$ + #LF$
    ErrorMsg + "Detected OpenGL Version: " + Version + #LF$ + #LF$
    ErrorMsg + "Missing Capabilities:" + #LF$ + MissingFeatures + #LF$
    ErrorMsg + "Please try updating your graphics drivers."
    
    ; Display the clean OS error window
    MessageRequester("Dot Gobbler Deluxe - Hardware Error", ErrorMsg, #PB_MessageRequester_Error)
    
    ; Gracefully kill the application immediately to prevent the memory crash
    End 
  EndIf
EndProcedure


; --- Robust Internal Shader Compiler ---
Procedure.l Util_CompileProgram(VertSrc.s, FragSrc.s)
  ; 1. NULL POINTER CHECK
  ; Catch missing extensions instantly before they cause an IMA
  If glShaderSource = #Null
    MessageRequester("Fatal Error", "glShaderSource pointer failed to load! Your GPU may not support this.") 
    End
  EndIf

  Define Success.l, LogLen.l, *LogMap, ErrMsg.s
  
  ; ==========================================
  ; VERTEX SHADER COMPILATION
  ; ==========================================
  Define *VertStr = UTF8(VertSrc)
  Define VertShader.l = glCreateShader(#GL_VERTEX_SHADER)
  
  ; 2. ARRAY WRAPPER FIX (Vertex)
  ; Forces contiguous memory alignment for the PB C-Backend
  Dim *VertStringArray(0)
  *VertStringArray(0) = *VertStr
  glShaderSource(VertShader, 1, @*VertStringArray(), #Null)
  
  glCompileShader(VertShader)
  
  glGetShaderiv(VertShader, #GL_COMPILE_STATUS, @Success)
  If Success = 0
    glGetShaderiv(VertShader, #GL_INFO_LOG_LENGTH, @LogLen)
    *LogMap = AllocateMemory(LogLen)
    glGetShaderInfoLog(VertShader, LogLen, #Null, *LogMap)
    ErrMsg = PeekS(*LogMap, LogLen, #PB_UTF8) : FreeMemory(*LogMap)
    MessageRequester("Vertex Shader Error", ErrMsg) : End
  EndIf
  
  ; ==========================================
  ; FRAGMENT SHADER COMPILATION
  ; ==========================================
  Define *FragStr = UTF8(FragSrc)
  Define FragShader.l = glCreateShader(#GL_FRAGMENT_SHADER)
  
  ; 3. ARRAY WRAPPER FIX (Fragment)
  Dim *FragStringArray(0)
  *FragStringArray(0) = *FragStr
  glShaderSource(FragShader, 1, @*FragStringArray(), #Null)
  
  glCompileShader(FragShader)
  
  glGetShaderiv(FragShader, #GL_COMPILE_STATUS, @Success)
  If Success = 0
    glGetShaderiv(FragShader, #GL_INFO_LOG_LENGTH, @LogLen)
    *LogMap = AllocateMemory(LogLen)
    glGetShaderInfoLog(FragShader, LogLen, #Null, *LogMap)
    ErrMsg = PeekS(*LogMap, LogLen, #PB_UTF8) : FreeMemory(*LogMap)
    MessageRequester("Fragment Shader Error", ErrMsg) : End
  EndIf
  
  ; ==========================================
  ; PROGRAM LINKING
  ; ==========================================
  Define Prog.l = glCreateProgram()
  glAttachShader(Prog, VertShader)
  glAttachShader(Prog, FragShader)
  glLinkProgram(Prog)
  
  glGetProgramiv(Prog, #GL_LINK_STATUS, @Success)
  If Success = 0
    glGetProgramiv(Prog, #GL_INFO_LOG_LENGTH, @LogLen)
    *LogMap = AllocateMemory(LogLen)
    glGetProgramInfoLog(Prog, LogLen, #Null, *LogMap)
    ErrMsg = PeekS(*LogMap, LogLen, #PB_UTF8) : FreeMemory(*LogMap)
    MessageRequester("Program Link Error", ErrMsg) : End
  EndIf
  
  glDeleteShader(VertShader)
  glDeleteShader(FragShader)
  FreeMemory(*VertStr)
  FreeMemory(*FragStr)
  ProcedureReturn Prog
EndProcedure

; ============================================================================
; PUBLIC API
; ============================================================================

; ----------------------------------------------------------------------------
; OpenGLWindow()
; Description: Boots the physical OS window, initializes the OpenGL context, 
;              and compiles the core engine shaders.
; Parameters:
;   Title  - The text displayed in the OS window title bar.
;   Width  - The initial physical width of the window.
;   Height - The initial physical height of the window.
; Returns: The GadgetID of the OpenGL canvas (or 0 if failed).
; ----------------------------------------------------------------------------

Procedure OpenGLWindow(Title.s, Width.i, Height.i, Flags.i = #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  ; Preserve the window we are leaving, then start with an empty set of
  ; context-owned object names. OpenGL numeric IDs are meaningful only in the
  ; context that created them; carrying an FBO or VAO into this new gadget is
  ; not sharing it, it is naming an unrelated (or nonexistent) object.
  If *GL_CurrentContext : GL_ContextCapture(*GL_CurrentContext) : EndIf
  Util_TextShader = 0 : Util_TextVAO = 0 : Util_TextVBO = 0
  Util_TextLoc_Tex = 0 : Util_TextLoc_Color = 0
  Util_ShapeShader = 0 : Util_ShapeVAO = 0 : Util_ShapeVBO = 0 : Util_ShapeLoc_Color = 0
  Util_FBO = 0 : Util_FBOTex = 0 : Util_PostShader = 0 : Util_PostVAO = 0 : Util_PostVBO = 0
  Util_PostLoc_Tex = 0 : Util_PostLoc_Time = 0 : Util_PassShader = 0
  GL_CameraX = 0.0 : GL_CameraY = 0.0 : GL_CameraZoom = 1.0
  Util_OrigX = 0 : Util_OrigY = 0 : Util_OrigW = 0 : Util_OrigH = 0 : Util_OrigStyle = 0
  Util_IsFullscreen = #False : Linux_DPIScale = 1.0
  GL_ViewportX = 0 : GL_ViewportY = 0 : GL_ViewportW = 0 : GL_ViewportH = 0
  GL_ViewportMode = #GL_VIEWPORT_LETTERBOX
  ExamineDesktops()
  Util_WinWidth = Width : Util_WinHeight = Height
  Util_BaseWidth = Width : Util_BaseHeight = Height
  
  ; ADDED: Min and Max gadgets
  ;Define Flags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget
  
  Util_MainWindowID = OpenWindow(#PB_Any, 0, 0, Width, Height, Title, Flags) 
  If Util_MainWindowID
    Util_MainGadgetID = OpenGLGadget(#PB_Any, 0, 0, Width, Height, #PB_OpenGL_Keyboard)
    
    ;  LINUX FIX: Force GTK3 to physically realize the window in memory
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      While WindowEvent() : Wend
    CompilerEndIf
    
    SetGadgetAttribute(Util_MainGadgetID, #PB_OpenGL_SetContext, #True)
    LoadModernGL()
    
    ; Add a keyboard shortcut for the ESC key to trap it in the event loop
    AddKeyboardShortcut(Util_MainWindowID, #PB_Shortcut_Escape, 1001)
    
    ; --- Build Internal Shaders ---
    Define TextVert.s = "#version 140" + #LF$ + "#extension GL_ARB_explicit_attrib_location : enable" + #LF$ + "layout (location = 0) in vec4 vertex;" + #LF$ + "out vec2 TexCoords;" + #LF$ + "void main() { gl_Position = vec4(vertex.xy, 0.0, 1.0); TexCoords = vertex.zw; }"
    Define TextFrag.s = "#version 140" + #LF$ + "in vec2 TexCoords;" + #LF$ + "out vec4 color;" + #LF$ + "uniform sampler2D text;" + #LF$ + "uniform vec4 u_textColor;" + #LF$ + "void main() { color = texture(text, TexCoords) * u_textColor; }"
    Util_TextShader = Util_CompileProgram(TextVert, TextFrag)
    Define *TexName = UTF8("text") : Util_TextLoc_Tex = glGetUniformLocation(Util_TextShader, *TexName) : FreeMemory(*TexName)
    Define *ColName = UTF8("u_textColor") : Util_TextLoc_Color = glGetUniformLocation(Util_TextShader, *ColName) : FreeMemory(*ColName)
    
    glGenVertexArrays(1, @Util_TextVAO) : glGenBuffers(1, @Util_TextVBO)
    glBindVertexArray(Util_TextVAO) : glBindBuffer(#GL_ARRAY_BUFFER, Util_TextVBO)
    glBufferData(#GL_ARRAY_BUFFER, 24576, #Null, #GL_DYNAMIC_DRAW)
    glVertexAttribPointer(0, 4, #GL_FLOAT, #GL_FALSE, 4 * 4, #Null)
    glEnableVertexAttribArray(0)
    
    Define ShapeVert.s = "#version 140" + #LF$ + "#extension GL_ARB_explicit_attrib_location : enable" + #LF$ + "layout (location = 0) in vec2 vertex;" + #LF$ + "void main() { gl_Position = vec4(vertex.x, vertex.y, 0.0, 1.0); }"
    Define ShapeFrag.s = "#version 140" + #LF$ + "out vec4 color;" + #LF$ + "uniform vec4 u_shapecolor;" + #LF$ + "void main() { color = u_shapecolor; }"
    Util_ShapeShader = Util_CompileProgram(ShapeVert, ShapeFrag)
    Define *SColName = UTF8("u_shapecolor") : Util_ShapeLoc_Color = glGetUniformLocation(Util_ShapeShader, *SColName) : FreeMemory(*SColName)
    
    glGenVertexArrays(1, @Util_ShapeVAO) : glGenBuffers(1, @Util_ShapeVBO)
    glBindVertexArray(Util_ShapeVAO) : glBindBuffer(#GL_ARRAY_BUFFER, Util_ShapeVBO)
    glBufferData(#GL_ARRAY_BUFFER, 65536, #Null, #GL_DYNAMIC_DRAW) 
    glVertexAttribPointer(0, 2, #GL_FLOAT, #GL_FALSE, 2 * 4, #Null)
    glEnableVertexAttribArray(0)
    
    glEnable_(#GL_BLEND)
    glBlendFunc_(#GL_SRC_ALPHA, #GL_ONE_MINUS_SRC_ALPHA)
    
    ProcedureReturn Util_MainGadgetID
  EndIf
  ProcedureReturn 0
EndProcedure

; --- Window & Hardware Capabilities ---

Procedure GL_SetVSync(State.i)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If wglSwapIntervalEXT
      wglSwapIntervalEXT(State) ; 1 = VSync On, 0 = VSync Off
    EndIf
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    ; On Linux, VSync is usually enforced by the Desktop Compositor (Wayland/X11)
  CompilerEndIf
EndProcedure

Procedure.s GL_GetHardwareInfo()
  ; Safely grab the memory pointers first
  Define *Vendor = glGetString_(#GL_VENDOR)
  Define *Renderer = glGetString_(#GL_RENDERER)
  Define *Version = glGetString_(#GL_VERSION)
  
  ; LINUX FIX: Shield against Null Pointers if the context dropped
  If *Vendor = 0 Or *Renderer = 0 Or *Version = 0
    ProcedureReturn "ERROR: OpenGL Context is dead or not initialized!"
  EndIf
  
  Define Info.s = "Vendor: " + PeekS(*Vendor, -1, #PB_Ascii) + #CRLF$
  Info + "GPU: " + PeekS(*Renderer, -1, #PB_Ascii) + #CRLF$
  Info + "OpenGL: " + PeekS(*Version, -1, #PB_Ascii) + #CRLF$
  
  Define VSyncState = -1
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If wglGetSwapIntervalEXT : VSyncState = wglGetSwapIntervalEXT() : EndIf
  CompilerEndIf
  
  Info + "VSync Status: " + Str(VSyncState)
  ProcedureReturn Info
EndProcedure

Procedure GL_ToggleFullscreen()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Define WinID = WindowID(Util_MainWindowID)
    If Util_IsFullscreen
      SetWindowLongPtr_(WinID, #GWL_STYLE, Util_OrigStyle)
      ResizeWindow(Util_MainWindowID, Util_OrigX, Util_OrigY, Util_OrigW, Util_OrigH)
      Util_IsFullscreen = #False
    Else
      Util_OrigX = WindowX(Util_MainWindowID) : Util_OrigY = WindowY(Util_MainWindowID)
      Util_OrigW = WindowWidth(Util_MainWindowID) : Util_OrigH = WindowHeight(Util_MainWindowID)
      Util_OrigStyle = GetWindowLongPtr_(WinID, #GWL_STYLE)
      
      Define hDC = GetDC_(0)
      Define TrueW = GetDeviceCaps_(hDC, 118) : Define TrueH = GetDeviceCaps_(hDC, 117)
      ReleaseDC_(0, hDC)
      
      SetWindowLongPtr_(WinID, #GWL_STYLE, #WS_POPUP | #WS_VISIBLE)
      SetWindowPos_(WinID, #HWND_TOP, 0, 0, TrueW, TrueH, #SWP_FRAMECHANGED)
      Util_IsFullscreen = #True
    EndIf
    
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    ; Native Linux Fullscreen Toggle
    If Util_IsFullscreen
      SetWindowState(Util_MainWindowID, #PB_Window_Normal)
      Util_IsFullscreen = #False
    Else
      SetWindowState(Util_MainWindowID, #PB_Window_Maximize)
      Util_IsFullscreen = #True
    EndIf
  CompilerEndIf
  
; Force the letterboxing math to update to the new fullscreen/windowed dimensions
  GL_HandleResize(Util_MainGadgetID)
EndProcedure

; ============================================================================
; --- Rendering Procedures : TEXT ---
; ============================================================================

; The pixel format the OS hands back from DrawingBuffer(). Unchanged from the
; original bake - only the place it is used has moved.
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  #GLF_PIXELFORMAT = #GL_RGBA
CompilerElse
  #GLF_PIXELFORMAT = #GL_BGRA_EXT
CompilerEndIf

; ----------------------------------------------------------------------------
; Codepoints that are SUPPOSED to draw nothing.
;
; This list is the difference between a space and a hole. Every one of these
; rasterises to an empty bitmap, and so does a character the font has no
; glyph for - so without naming them, either every space becomes a tofu box
; or no missing glyph ever does. There is no third option that is honest.
; ----------------------------------------------------------------------------
Procedure.b GLF_IsBlankCodepoint(cp.i)
  Select cp
    Case $0020, $00A0, $1680, $180E, $202F, $205F, $3000, $FEFF, $2060
      ProcedureReturn #True
  EndSelect
  If cp >= $2000 And cp <= $200B : ProcedureReturn #True : EndIf   ; space family + ZWSP
  If cp >= $200C And cp <= $200F : ProcedureReturn #True : EndIf   ; ZWNJ/ZWJ/marks
  ProcedureReturn #False
EndProcedure

; ----------------------------------------------------------------------------
; The scratch surface every dynamic glyph is rasterised on. ONE of them, for
; the whole process: creating and destroying a PureBasic image per glyph was
; measured as the dominant cost of a cache miss, and a miss happens on a
; keystroke.
; ----------------------------------------------------------------------------
Global GLF_Scratch.i = 0
Global GLF_ScratchW.i = 0
Global GLF_ScratchH.i = 0

Procedure.i GLF_EnsureScratch(w.i, h.i)
  If w < 64 : w = 64 : EndIf
  If h < 64 : h = 64 : EndIf
  If GLF_Scratch And GLF_ScratchW >= w And GLF_ScratchH >= h
    ProcedureReturn GLF_Scratch
  EndIf
  If w < GLF_ScratchW : w = GLF_ScratchW : EndIf
  If h < GLF_ScratchH : h = GLF_ScratchH : EndIf
  If GLF_Scratch : FreeImage(GLF_Scratch) : GLF_Scratch = 0 : EndIf
  GLF_Scratch = CreateImage(#PB_Any, w, h, 32, #PB_Image_Transparent)
  If GLF_Scratch
    GLF_ScratchW = w : GLF_ScratchH = h
  Else
    GLF_ScratchW = 0 : GLF_ScratchH = 0
  EndIf
  ProcedureReturn GLF_Scratch
EndProcedure

; ----------------------------------------------------------------------------
; WHICH WAY UP IS THE DRAWING BUFFER? ASK IT, DO NOT ASSUME.
;
; The old code assumed, with a CompilerIf: flip V on Windows, do not on Linux.
; That is a guess about every platform nobody has run, and when it is wrong the
; symptom is upside-down text rather than a diagnostic.
;
; So this plots a pixel at the image's TOP-left and looks at where it landed.
; MEASURED ON THIS MACHINE (PureBasic 6.21, Windows x64): pitch is POSITIVE
; (+32 for an 8px-wide 32-bit image) and memory row 0 holds the image's BOTTOM
; row - the buffer is bottom-up and DrawingBuffer() points at the LAST image
; line, not the first. That is the opposite of the reading the documentation's
; wording invites, and it is why the answer is probed rather than argued.
; ----------------------------------------------------------------------------
Global GLF_BottomUp.i = -1        ; -1 = not probed yet, 0 = top-down, 1 = bottom-up

Procedure GLF_ProbeBufferOrder()
  If GLF_BottomUp >= 0 : ProcedureReturn : EndIf
  GLF_BottomUp = 0
  Protected img.i = CreateImage(#PB_Any, 4, 4, 32, #PB_Image_Transparent)
  If img = 0 : ProcedureReturn : EndIf
  If StartDrawing(ImageOutput(img))
    DrawingMode(#PB_2DDrawing_AllChannels)
    Box(0, 0, 4, 4, RGBA(0, 0, 0, 0))
    Plot(0, 0, RGBA(255, 255, 255, 255))          ; the image's TOP-left pixel
    Protected *b = DrawingBuffer()
    Protected pitch.i = DrawingBufferPitch()
    Protected *top.Long = *b
    Protected *bot.Long = *b + 3 * pitch
    If *top\l = 0 And *bot\l <> 0
      GLF_BottomUp = 1
    EndIf
    StopDrawing()
  EndIf
  FreeImage(img)
EndProcedure

; ----------------------------------------------------------------------------
; Copy a w*h rectangle out of the CURRENTLY OPEN drawing buffer into a packed,
; TOP-DOWN block, and say whether anything was actually drawn.
;
; Normalising here is what lets the atlas have ONE coordinate convention and no
; V flip anywhere - the flip used to live in the UV arithmetic, on one OS only.
;
; Returns the number of non-transparent pixels found. Zero means the font drew
; nothing at all, which - for a codepoint that is not in the blank list - is
; the definition of a missing glyph.
; ----------------------------------------------------------------------------
Procedure.i GLF_PackRect(sx.i, sy.i, w.i, h.i, *dest)
  Protected *base = DrawingBuffer()
  Protected pitch.i = DrawingBufferPitch()
  Protected ih.i = OutputHeight()
  If *base = 0 Or w <= 0 Or h <= 0 : ProcedureReturn 0 : EndIf
  Protected y.i, x.i, ink.i = 0, row.i
  Protected *src, *dst = *dest, *px.Ascii
  For y = 0 To h - 1
    If GLF_BottomUp = 1
      row = ih - 1 - (sy + y)
    Else
      row = sy + y
    EndIf
    If row < 0 Or row >= ih
      FillMemory(*dst, w * 4, 0)
      *dst + w * 4
      Continue
    EndIf
    *src = *base + row * pitch + sx * 4
    CopyMemory(*src, *dst, w * 4)
    ; The alpha byte is the 4th in both BGRA and RGBA, so this one scan is
    ; correct on both systems.
    *px = *dst + 3
    For x = 0 To w - 1
      If *px\a : ink + 1 : EndIf
      *px + 4
    Next
    *dst + w * 4
  Next
  ProcedureReturn ink
EndProcedure

; ----------------------------------------------------------------------------
; Page management.
; ----------------------------------------------------------------------------
Procedure GLF_NewPageTexture(*p.GLFontPage)
  glGenTextures_(1, @*p\TextureID)
  glBindTexture_(#GL_TEXTURE_2D, *p\TextureID)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MIN_FILTER, #GL_LINEAR)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MAG_FILTER, #GL_LINEAR)
  ; CLAMP_TO_EDGE, not the GL_REPEAT default. With LINEAR filtering a sample
  ; taken exactly on the atlas border wraps to the far side of the page and
  ; drags a sliver of an unrelated glyph into the quad. The old atlas got
  ; away with it because its 2-texel padding kept samples away from the
  ; edges; that is luck, not a guarantee, and a full page has glyphs ON the
  ; border.
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_S, #GL_CLAMP_TO_EDGE)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_T, #GL_CLAMP_TO_EDGE)
  ; ZEROED, not #Null. glTexImage2D with a null pointer allocates the page and
  ; leaves its contents UNDEFINED - whatever happened to be in that block of
  ; video memory. No glyph quad addresses those texels directly, but LINEAR
  ; filtering samples half a texel OUTSIDE the quad at its edges, so the fringe
  ; of every glyph on the outermost shelf is blended against undefined data.
  ; Measured here it was a one-LSB wobble; on a driver that does not happen to
  ; hand back zeros it is a coloured halo, and it would be blamed on the font.
  Protected *blank = AllocateMemory(#GLF_PAGE_W * #GLF_PAGE_H * 4)
  glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_RGBA, #GLF_PAGE_W, #GLF_PAGE_H, 0,
                #GLF_PIXELFORMAT, #GL_UNSIGNED_BYTE, *blank)
  If *blank : FreeMemory(*blank) : EndIf
  *p\ShelfX = 0 : *p\ShelfY = 0 : *p\ShelfH = 0 : *p\Live = 0
EndProcedure

Procedure GLF_RecyclePage(*f.GLFont, idx.i)
  Protected *p.GLFontPage = @*f\Pages[idx]
  ; The generation bump IS the invalidation. Every glyph that pointed here
  ; still carries the old number, so the next lookup that reaches one fails
  ; its generation check and re-rasterises. Nothing has to be walked, and
  ; there is no window in which a stale UV can be drawn.
  *p\Gen + 1
  *p\ShelfX = 0 : *p\ShelfY = 0 : *p\ShelfH = 0 : *p\Live = 0
  *f\Evictions + 1
  ; And WIPE it. New glyphs overwrite the old ones where they land, but the
  ; 2-texel gaps between them do not get overwritten, so the ink of an evicted
  ; glyph would sit right beside a live one and bleed into its edge under
  ; LINEAR filtering. Four megabytes per eviction is the right trade against a
  ; smear that only appears after a long session and cannot be reproduced.
  Protected *blank = AllocateMemory(#GLF_PAGE_W * #GLF_PAGE_H * 4)
  If *blank
    glBindTexture_(#GL_TEXTURE_2D, *p\TextureID)
    glPixelStorei_(#GL_UNPACK_ALIGNMENT, 1)
    glTexSubImage2D_(#GL_TEXTURE_2D, 0, 0, 0, #GLF_PAGE_W, #GLF_PAGE_H,
                     #GLF_PIXELFORMAT, #GL_UNSIGNED_BYTE, *blank)
    FreeMemory(*blank)
  EndIf
EndProcedure

; Find room for a w*h glyph. Returns the page index, or -1 if the glyph is
; larger than a whole page (which no font size this engine can load produces,
; but a caller with a 900pt font would).
Procedure.i GLF_Place(*f.GLFont, w.i, h.i, *ox.Integer, *oy.Integer)
  Protected i.i, *p.GLFontPage
  Protected need.i = w + #GLF_PAD
  If w > #GLF_PAGE_W Or h > #GLF_PAGE_H : ProcedureReturn -1 : EndIf

  For i = 0 To *f\PageCount - 1
    *p = @*f\Pages[i]
    If *p\ShelfX + need > #GLF_PAGE_W
      ; close this shelf and start the next one
      If *p\ShelfH > 0
        *p\ShelfY + *p\ShelfH + #GLF_PAD
        *p\ShelfX = 0 : *p\ShelfH = 0
      EndIf
    EndIf
    If *p\ShelfY + h <= #GLF_PAGE_H And *p\ShelfX + need <= #GLF_PAGE_W
      *ox\i = *p\ShelfX
      *oy\i = *p\ShelfY
      *p\ShelfX + need
      If h > *p\ShelfH : *p\ShelfH = h : EndIf
      *p\Live + 1
      ProcedureReturn i
    EndIf
  Next

  ; Room for a fresh page?
  If *f\PageCount < *f\PageBudget
    i = *f\PageCount
    *f\PageCount + 1
    GLF_NewPageTexture(@*f\Pages[i])
    *f\Pages[i]\LastUse = GLF_Clock
    ProcedureReturn GLF_Place(*f, w, h, *ox, *oy)
  EndIf

  ; Everything is full. Recycle the least recently used UNPINNED page.
  Protected victim.i = -1
  Protected oldest.q = -1
  For i = 0 To *f\PageCount - 1
    If *f\Pages[i]\Pinned : Continue : EndIf
    If oldest < 0 Or *f\Pages[i]\LastUse < oldest
      oldest = *f\Pages[i]\LastUse
      victim = i
    EndIf
  Next
  If victim < 0 : ProcedureReturn -1 : EndIf
  GLF_RecyclePage(*f, victim)
  ProcedureReturn GLF_Place(*f, w, h, *ox, *oy)
EndProcedure

; ----------------------------------------------------------------------------
; The tofu box, built once per font. Drawn, not faked: it goes into the atlas
; like any other glyph so the draw path has exactly one case to handle.
; ----------------------------------------------------------------------------
Procedure GLF_BuildTofu(*f.GLFont)
  If *f\TofuReady : ProcedureReturn : EndIf
  ; Mark it ready FIRST. If any step below fails, the glyph stays zero-sized
  ; and the caller falls back to an advance-only blank - but we must never
  ; retry a failing build on every single missing character.
  *f\TofuReady = #True

  Protected h.i = *f\LineHeight - 2
  If h < 6 : h = 6 : EndIf
  Protected w.i = h * 0.62
  If w < 4 : w = 4 : EndIf

  Protected img.i = GLF_EnsureScratch(w + 4, h + 4)
  If img = 0 : ProcedureReturn : EndIf
  Protected *buf = AllocateMemory(w * h * 4)
  If *buf = 0 : ProcedureReturn : EndIf

  If StartDrawing(ImageOutput(img))
    DrawingMode(#PB_2DDrawing_AllChannels)
    Box(0, 0, w, h, RGBA(0, 0, 0, 0))
    Box(0, 0, w, h, RGBA(255, 255, 255, 255))
    If w > 2 And h > 2
      Box(1, 1, w - 2, h - 2, RGBA(0, 0, 0, 0))
    EndIf
    GLF_PackRect(0, 0, w, h, *buf)
    StopDrawing()
  Else
    FreeMemory(*buf) : ProcedureReturn
  EndIf

  Protected px.i, py.i
  Protected page.i = GLF_Place(*f, w, h, @px, @py)
  If page < 0 : FreeMemory(*buf) : ProcedureReturn : EndIf

  glBindTexture_(#GL_TEXTURE_2D, *f\Pages[page]\TextureID)
  glPixelStorei_(#GL_UNPACK_ALIGNMENT, 1)
  glTexSubImage2D_(#GL_TEXTURE_2D, 0, px, py, w, h, #GLF_PIXELFORMAT, #GL_UNSIGNED_BYTE, *buf)
  FreeMemory(*buf)

  *f\Tofu\u1 = px / (#GLF_PAGE_W * 1.0)
  *f\Tofu\u2 = (px + w) / (#GLF_PAGE_W * 1.0)
  *f\Tofu\v1 = py / (#GLF_PAGE_H * 1.0)
  *f\Tofu\v2 = (py + h) / (#GLF_PAGE_H * 1.0)
  *f\Tofu\Width  = w
  *f\Tofu\Height = h
  *f\Tofu\Advance = w + #GLF_PAD
  *f\Tofu\Page = page
  *f\Tofu\Gen  = *f\Pages[page]\Gen
  *f\Tofu\State = #GLF_TOFU
EndProcedure

; ----------------------------------------------------------------------------
; Rasterise one codepoint into the atlas. This is the cache MISS path; it is
; allowed to be slow, and everything above exists so that it is rare.
; ----------------------------------------------------------------------------
Procedure GLF_Rasterise(*f.GLFont, cp.i, *g.GLGlyph)
  *f\Misses + 1

  ; Build the source string. Above the BMP that is a surrogate pair, which is
  ; also exactly what a PureBasic string holds, so the rasteriser is handed
  ; back the two units it would have had if we had never decoded them.
  Protected s.s
  If cp <= $FFFF
    s = Chr(cp)
  Else
    Protected v.i = cp - $10000
    s = Chr($D800 + (v >> 10)) + Chr($DC00 + (v & $3FF))
  EndIf

  Protected adv.f, w.i, h.i, ink.i = 0
  Protected img.i, *buf, px.i, py.i, page.i

  ; --- measure ------------------------------------------------------------
  img = GLF_EnsureScratch(64, 64)
  If img = 0 Or *f\PBFont = 0
    *g\State = #GLF_BLANK : *g\Advance = 0.0 : ProcedureReturn
  EndIf
  If StartDrawing(ImageOutput(img))
    DrawingFont(FontID(*f\PBFont))
    w = TextWidth(s)
    h = TextHeight(s)
    StopDrawing()
  EndIf

  If GLF_IsBlankCodepoint(cp)
    *g\State = #GLF_BLANK
    *g\Width = 0 : *g\Height = 0
    If *f\FixedAdvance > 0.0
      *g\Advance = *f\FixedAdvance
    Else
      *g\Advance = w + (*f\BaseSize * 0.05)
    EndIf
    ProcedureReturn
  EndIf

  If w > 0 And h > 0
    img = GLF_EnsureScratch(w + 8, h + 8)
    If img
      *buf = AllocateMemory(w * h * 4)
      If *buf And StartDrawing(ImageOutput(img))
        DrawingMode(#PB_2DDrawing_AllChannels)
        Box(0, 0, w, h, RGBA(0, 0, 0, 0))
        DrawingMode(#PB_2DDrawing_AlphaBlend | #PB_2DDrawing_Transparent)
        DrawingFont(FontID(*f\PBFont))
        DrawText(0, 0, s, RGBA(255, 255, 255, 255))
        ink = GLF_PackRect(0, 0, w, h, *buf)
        StopDrawing()
      EndIf
    EndIf
  EndIf

  If *f\FixedAdvance > 0.0
    adv = *f\FixedAdvance
  Else
    adv = w + (*f\BaseSize * 0.05)
  EndIf

  ; --- nothing was drawn: this is a MISSING GLYPH, and it gets a box -------
  ; Not a gap. Not silence. The whole reason this file was rewritten.
  If ink = 0
    If *buf : FreeMemory(*buf) : EndIf
    GLF_BuildTofu(*f)
    If *f\Tofu\State = #GLF_TOFU
      Protected gen.l = *f\Pages[*f\Tofu\Page]\Gen
      If gen <> *f\Tofu\Gen
        ; the tofu's own page was recycled - rebuild it before handing it out
        *f\TofuReady = #False
        GLF_BuildTofu(*f)
      EndIf
      CopyMemory(@*f\Tofu, *g, SizeOf(GLGlyph))
      *g\State = #GLF_TOFU
      If adv > 0.0 : *g\Advance = adv : EndIf
    Else
      *g\State = #GLF_BLANK
      *g\Advance = adv
    EndIf
    ProcedureReturn
  EndIf

  page = GLF_Place(*f, w, h, @px, @py)
  If page < 0
    FreeMemory(*buf)
    *g\State = #GLF_BLANK : *g\Advance = adv
    ProcedureReturn
  EndIf

  glBindTexture_(#GL_TEXTURE_2D, *f\Pages[page]\TextureID)
  glPixelStorei_(#GL_UNPACK_ALIGNMENT, 1)
  glTexSubImage2D_(#GL_TEXTURE_2D, 0, px, py, w, h, #GLF_PIXELFORMAT, #GL_UNSIGNED_BYTE, *buf)
  FreeMemory(*buf)

  *g\u1 = px / (#GLF_PAGE_W * 1.0)
  *g\u2 = (px + w) / (#GLF_PAGE_W * 1.0)
  *g\v1 = py / (#GLF_PAGE_H * 1.0)
  *g\v2 = (py + h) / (#GLF_PAGE_H * 1.0)
  *g\Width  = w
  *g\Height = h
  *g\Advance = adv
  *g\Page = page
  *g\Gen  = *f\Pages[page]\Gen
  *g\State = #GLF_RESIDENT
EndProcedure

; ----------------------------------------------------------------------------
; GLF_Glyph() - THE HOT PATH. Everything else in this file exists to keep it
; to two loads and an index for a glyph that is already resident.
; ----------------------------------------------------------------------------
; GLF_Slot() - the table entry for a codepoint, WITHOUT rasterising it.
; Separate from GLF_Glyph because the eager ASCII bake runs inside an open
; StartDrawing session, and a nested StartDrawing is an error - so the bake
; must be able to reach a slot without any chance of the miss path firing.
Procedure.i GLF_Slot(*f.GLFont, cp.i)
  Protected blk.i = cp >> 8
  If blk < 0 Or blk >= #GLF_BLOCKS : ProcedureReturn 0 : EndIf
  Protected *b = *f\Block[blk]
  If *b = 0
    *b = AllocateMemory(256 * SizeOf(GLGlyph))
    If *b = 0 : ProcedureReturn 0 : EndIf
    *f\Block[blk] = *b
  EndIf
  ProcedureReturn *b + (cp & 255) * SizeOf(GLGlyph)
EndProcedure

Procedure.i GLF_Glyph(*f.GLFont, cp.i)
  Protected *g.GLGlyph = GLF_Slot(*f, cp)
  If *g = 0 : ProcedureReturn 0 : EndIf
  Select *g\State
    Case #GLF_RESIDENT, #GLF_TOFU
      ; The generation check is what makes eviction safe. A page that was
      ; recycled under this glyph's feet fails here and falls through to a
      ; fresh rasterisation, so a stale UV is unreachable by construction.
      If *f\Pages[*g\Page]\Gen = *g\Gen : ProcedureReturn *g : EndIf
    Case #GLF_BLANK
      ProcedureReturn *g
  EndSelect
  GLF_Rasterise(*f, cp, *g)
  ProcedureReturn *g
EndProcedure

; ----------------------------------------------------------------------------
; CreateGLFont()
; Description: Opens an OS font and prepares its glyph cache. ASCII 32..126 is
;              baked eagerly into the pinned first atlas page, exactly as this
;              procedure has always done; everything else is rasterised the
;              first time it is asked for.
; Parameters:
;   FontName - The system name of the font (e.g., "Arial" or "Consolas").
;   Size     - The point size of the font.
; Returns: A pointer to the generated *GLFont structure.
; ----------------------------------------------------------------------------
Procedure.i CreateGLFont(FontName.s, Size.i, Style.i = 0)
  GLF_ProbeBufferOrder()
  Protected *f.GLFont = AllocateStructure(GLFont)
  If *f = 0 : ProcedureReturn 0 : EndIf
  *f\BaseSize   = Size
  *f\FontName   = FontName
  *f\Style      = Style
  *f\PageBudget = #GLF_MAX_PAGES
  ; The font handle is KEPT. It used to be freed at the end of this procedure,
  ; which was correct when nothing could ever be rasterised again and is the
  ; single thing that made an on-demand cache impossible.
  *f\PBFont = LoadFont(#PB_Any, FontName, Size, Style)

  ; --- page 0: pinned, and it carries the ASCII ---------------------------
  *f\PageCount = 1
  *f\Pages[0]\Pinned = #True
  GLF_NewPageTexture(@*f\Pages[0])
  *f\TextureID = *f\Pages[0]\TextureID

  If *f\PBFont = 0 : ProcedureReturn *f : EndIf

  ; Two passes inside ONE drawing session: measure the shelves first so the
  ; scratch image is exactly as tall as the bake needs. The old code always
  ; allocated 1024x1024 (4 MB) per font whatever the size was.
  Protected i.i, cw.i, ch.i, x.i, y.i, maxh.i, needH.i
  Protected img.i = GLF_EnsureScratch(#GLF_PAGE_W, 64)
  If img = 0 : ProcedureReturn *f : EndIf

  x = 0 : y = 0 : maxh = 0
  If StartDrawing(ImageOutput(img))
    DrawingFont(FontID(*f\PBFont))
    *f\LineHeight = TextHeight("A")
    ; The face's REAL advance, measured over ten cells so a per-call rounding
    ; error cannot masquerade as the answer. Always recorded, even for a
    ; proportional font, because it is what CreateGLFontFixed() reports.
    *f\MeasuredAdvance = TextWidth("0000000000") / 10.0
    For i = 32 To 126
      cw = TextWidth(Chr(i)) : ch = TextHeight(Chr(i))
      ; The wrap test is "x + cw", NOT "x + cw + pad", because that is what
      ; the original bake used - and the shelf a glyph lands on decides which
      ; texels sit next to it, which with LINEAR filtering decides its edge
      ; pixels to within one LSB. Matching it exactly is what makes the two
      ; emulator panels come out pixel-for-pixel identical instead of merely
      ; indistinguishable.
      If x + cw > #GLF_PAGE_W
        x = 0 : y + maxh + #GLF_PAD : maxh = 0
      EndIf
      If ch > maxh : maxh = ch : EndIf
      x + cw + #GLF_PAD
    Next
    StopDrawing()
  EndIf
  needH = y + maxh + #GLF_PAD
  If needH < 8 : needH = 8 : EndIf
  If needH > #GLF_PAGE_H : needH = #GLF_PAGE_H : EndIf

  img = GLF_EnsureScratch(#GLF_PAGE_W, needH)
  If img = 0 : ProcedureReturn *f : EndIf
  Protected *buf = AllocateMemory(#GLF_PAGE_W * needH * 4)
  If *buf = 0 : ProcedureReturn *f : EndIf

  Protected *g.GLGlyph
  x = 0 : y = 0 : maxh = 0
  If StartDrawing(ImageOutput(img))
    DrawingMode(#PB_2DDrawing_AllChannels)
    Box(0, 0, #GLF_PAGE_W, needH, RGBA(0, 0, 0, 0))
    DrawingMode(#PB_2DDrawing_AlphaBlend | #PB_2DDrawing_Transparent)
    DrawingFont(FontID(*f\PBFont))
    For i = 32 To 126
      cw = TextWidth(Chr(i)) : ch = TextHeight(Chr(i))
      ; The wrap test is "x + cw", NOT "x + cw + pad", because that is what
      ; the original bake used - and the shelf a glyph lands on decides which
      ; texels sit next to it, which with LINEAR filtering decides its edge
      ; pixels to within one LSB. Matching it exactly is what makes the two
      ; emulator panels come out pixel-for-pixel identical instead of merely
      ; indistinguishable.
      If x + cw > #GLF_PAGE_W
        x = 0 : y + maxh + #GLF_PAD : maxh = 0
      EndIf
      If ch > maxh : maxh = ch : EndIf
      If y + ch <= needH
        DrawText(x, y, Chr(i), RGBA(255, 255, 255, 255))
      EndIf
      ; GLF_Slot, not GLF_Glyph: we are inside StartDrawing and the miss path
      ; opens its own drawing session.
      *g = GLF_Slot(*f, i)
      If *g And GLF_IsBlankCodepoint(i)
        ; The space. It is inside the baked range, it rasterises to nothing,
        ; and the old code still gave it a fully transparent quad on every
        ; draw - six vertices per space, blended against the framebuffer to
        ; produce exactly no change. Marking it BLANK skips the quad. The
        ; picture cannot differ, because a transparent quad contributes
        ; nothing; the emulator panels are full of spaces and their
        ; screenshots are the check.
        *g\State   = #GLF_BLANK
        *g\Width   = 0
        *g\Height  = 0
        *g\Advance = cw + (Size * 0.05)
        *g\Page    = 0
        *g\Gen     = 0
      ElseIf *g
        *g\Width   = cw
        *g\Height  = ch
        ; Advance = width + Size*0.05, UNCHANGED. Every layout in the shipped
        ; product is measured against this number; changing it here would move
        ; every column in both emulator panels. A genuinely constant advance is
        ; opt-in, through CreateGLFontFixed / GLFontSetFixedAdvance.
        *g\Advance = cw + (Size * 0.05)
        *g\u1 = x / (#GLF_PAGE_W * 1.0)
        *g\u2 = (x + cw) / (#GLF_PAGE_W * 1.0)
        *g\v1 = y / (#GLF_PAGE_H * 1.0)
        *g\v2 = (y + ch) / (#GLF_PAGE_H * 1.0)
        *g\Page  = 0
        *g\Gen   = 0
        *g\State = #GLF_RESIDENT
      EndIf
      x + cw + #GLF_PAD
    Next
    GLF_PackRect(0, 0, #GLF_PAGE_W, needH, *buf)
    StopDrawing()
  EndIf

  ; Hand the shelves to the packer so on-demand glyphs continue where the
  ; bake stopped, on the SAME page - one texture for ASCII plus the handful
  ; of accents a real document adds, which keeps them in one draw call.
  *f\Pages[0]\ShelfX = x
  *f\Pages[0]\ShelfY = y
  *f\Pages[0]\ShelfH = maxh
  *f\Pages[0]\Live   = 95

  glBindTexture_(#GL_TEXTURE_2D, *f\Pages[0]\TextureID)
  glPixelStorei_(#GL_UNPACK_ALIGNMENT, 1)
  glTexSubImage2D_(#GL_TEXTURE_2D, 0, 0, 0, #GLF_PAGE_W, needH,
                   #GLF_PIXELFORMAT, #GL_UNSIGNED_BYTE, *buf)
  FreeMemory(*buf)
  ProcedureReturn *f
EndProcedure

; ----------------------------------------------------------------------------
; CreateGLFontFixed()
; Description: The same font, but with a genuinely CONSTANT advance, so that
;              column <-> x is a multiply instead of a prefix sum.
;
; WHY THIS EXISTS. CreateGLFont sets Advance = Width + Size*0.05 for every
; glyph, so even a monospaced face comes out with an advance that varies by a
; fraction of a pixel per character. Over an 80-column line that accumulates,
; and the caret lands between the glyph you clicked and its neighbour - a
; defect that looks perfectly fine in a screenshot and is only ever found by a
; person clicking in the wrong place all afternoon.
;
; Parameters:
;   AdvanceOverride - 0.0 (the default) measures the face itself over ten "0"
;                     cells and rounds to a whole pixel, which keeps glyph
;                     quads on pixel boundaries. Pass a number to force one.
; Returns: A *GLFont, or 0.
; ----------------------------------------------------------------------------
Procedure.i CreateGLFontFixed(FontName.s, Size.i, Style.i = 0, AdvanceOverride.f = 0.0)
  Protected *f.GLFont = CreateGLFont(FontName, Size, Style)
  If *f = 0 : ProcedureReturn 0 : EndIf
  Protected adv.f = AdvanceOverride
  If adv <= 0.0
    adv = *f\MeasuredAdvance
    ; Whole pixels on purpose. A fractional advance puts every quad on a
    ; fractional texel with LINEAR filtering, and an editor full of slightly
    ; blurred, slightly uneven glyphs is a worse trade than a sub-pixel of
    ; accumulated error - which rounding here removes entirely anyway.
    adv = Round(adv, #PB_Round_Nearest)
  EndIf
  If adv < 1.0 : adv = 1.0 : EndIf
  *f\FixedAdvance = adv
  *f\SnapToPixel  = #True

  ; Re-stamp the advance of everything already baked. Glyphs cached later
  ; pick it up in GLF_Rasterise.
  Protected i.i, *g.GLGlyph
  For i = 32 To 126
    *g = GLF_Slot(*f, i)
    If *g : *g\Advance = adv : EndIf
  Next
  ProcedureReturn *f
EndProcedure

; --- Small accessors, so the host never reaches into the structure ---------

; > 0.0 when the font advances by a constant; 0.0 when it is proportional.
Procedure.f GLFontFixedAdvance(*f.GLFont)
  If Not *f : ProcedureReturn 0.0 : EndIf
  ProcedureReturn *f\FixedAdvance
EndProcedure

; What the face itself measures per cell, unrounded. Always available, even
; on a proportional font, where it is the width of a "0".
Procedure.f GLFontMeasuredAdvance(*f.GLFont)
  If Not *f : ProcedureReturn 0.0 : EndIf
  ProcedureReturn *f\MeasuredAdvance
EndProcedure

Procedure.f GLFontLineHeight(*f.GLFont)
  If Not *f : ProcedureReturn 0.0 : EndIf
  ProcedureReturn *f\LineHeight
EndProcedure

; Make an existing font fixed (or, with 0.0, proportional again). Only affects
; glyphs cached from here on plus the ASCII re-stamped below.
Procedure GLFontSetFixedAdvance(*f.GLFont, Advance.f)
  If Not *f : ProcedureReturn : EndIf
  *f\FixedAdvance = Advance
  Protected i.i, *g.GLGlyph
  For i = 32 To 126
    *g = GLF_Slot(*f, i)
    If *g
      If Advance > 0.0
        *g\Advance = Advance
      Else
        *g\Advance = *g\Width + (*f\BaseSize * 0.05)
      EndIf
    EndIf
  Next
EndProcedure

; Round each glyph's x to a whole pixel before it is drawn. Off by default -
; it changes where existing text lands by up to half a pixel.
Procedure GLFontSetSnapToPixel(*f.GLFont, On.b)
  If *f : *f\SnapToPixel = On : EndIf
EndProcedure

; Draw C0/C1 control characters as tofu instead of skipping them. Off by
; default: the emulator's serial pane renders raw bytes from the emulated
; program, and turning every stray 0x07 into a box would change a shipped
; picture. An EDITOR should turn it on - a control character hiding in a
; source file is exactly the thing you want to see.
Procedure GLFontSetShowControls(*f.GLFont, On.b)
  If *f : *f\ShowControls = On : EndIf
EndProcedure

; How many atlas pages this font may own before it starts recycling them.
; Clamped to [2, #GLF_MAX_PAGES] because page 0 is pinned and there must be at
; least one page left that eviction is allowed to take.
Procedure GLFontSetPageBudget(*f.GLFont, Pages.i)
  If Not *f : ProcedureReturn : EndIf
  If Pages < 2 : Pages = 2 : EndIf
  If Pages > #GLF_MAX_PAGES : Pages = #GLF_MAX_PAGES : EndIf
  *f\PageBudget = Pages
EndProcedure

; Diagnostics: pages in use, glyphs rasterised, pages recycled.
Procedure.i GLFontPageCount(*f.GLFont)
  If Not *f : ProcedureReturn 0 : EndIf
  ProcedureReturn *f\PageCount
EndProcedure
Procedure.i GLFontMisses(*f.GLFont)
  If Not *f : ProcedureReturn 0 : EndIf
  ProcedureReturn *f\Misses
EndProcedure
Procedure.i GLFontEvictions(*f.GLFont)
  If Not *f : ProcedureReturn 0 : EndIf
  ProcedureReturn *f\Evictions
EndProcedure

; Ask what happened to one codepoint: #GLF_EMPTY / #GLF_RESIDENT / #GLF_BLANK
; / #GLF_TOFU. This is how a test proves a fallback box was drawn rather than
; assuming it from a picture.
Procedure.i GLFontGlyphState(*f.GLFont, cp.i)
  If Not *f : ProcedureReturn #GLF_EMPTY : EndIf
  Protected *g.GLGlyph = GLF_Glyph(*f, cp)
  If *g = 0 : ProcedureReturn #GLF_EMPTY : EndIf
  ProcedureReturn *g\State
EndProcedure

; ============================================================================
; FONTS BY PIXEL HEIGHT, AND A CACHE KEYED BY THE SIZE ACTUALLY USED
; ============================================================================
; CreateGLFont takes POINTS, and in a DPI-aware process PureBasic scales a
; point size by the desktop factor - so "14" means different numbers of texels
; on different monitors. Every consumer in this repo works around that with its
; own private VFontSize() that divides the request by DesktopResolutionX(),
; and GlUIChrome.pbi carries a whole converge loop for the same reason. Three
; copies of one answer is how they drift.
;
; A RESOLUTION-NATIVE application needs the opposite contract anyway: it says
; how many PIXELS tall the text should be and the engine rasterises exactly
; that, because nothing downstream will scale it any more. Ask, measure the
; height the rasteriser really produced with the SAME TextHeight("A") that
; CreateGLFont measures with, and correct - at most six probes on an 8x8
; scratch image, no GL texture built until the answer is known.
; ============================================================================
Procedure.i GLFontPointsForPixelHeight(FontName.s, WantPixels.i, Style.i = 0)
  Protected pt.i = Round(WantPixels * 0.75, #PB_Round_Nearest)
  Protected pass.i, h.i, fnt.i, img.i, np.i
  If pt < 5 : pt = 5 : EndIf
  For pass = 1 To 6
    h = 0
    fnt = LoadFont(#PB_Any, FontName, pt, Style)
    img = CreateImage(#PB_Any, 8, 8, 32)
    If fnt And img And StartDrawing(ImageOutput(img))
      DrawingFont(FontID(fnt))
      h = TextHeight("A")
      StopDrawing()
    EndIf
    If img : FreeImage(img) : EndIf
    If fnt : FreeFont(fnt) : EndIf
    If h <= 0 : Break : EndIf
    If Abs(WantPixels - h) <= 1 : Break : EndIf
    np = Round(pt * (WantPixels / h), #PB_Round_Nearest)
    If np < 5 : np = 5 : EndIf
    If np = pt : Break : EndIf
    pt = np
  Next
  ProcedureReturn pt
EndProcedure

; A font whose LineHeight is WantPixels pixels, whatever the desktop is doing.
Procedure.i CreateGLFontPx(FontName.s, WantPixels.i, Style.i = 0)
  ProcedureReturn CreateGLFont(FontName, GLFontPointsForPixelHeight(FontName, WantPixels, Style), Style)
EndProcedure

; The same, with a genuinely constant advance - the editor's font.
Procedure.i CreateGLFontFixedPx(FontName.s, WantPixels.i, Style.i = 0, AdvanceOverride.f = 0.0)
  ProcedureReturn CreateGLFontFixed(FontName, GLFontPointsForPixelHeight(FontName, WantPixels, Style),
                                    Style, AdvanceOverride)
EndProcedure

; ----------------------------------------------------------------------------
; THE REGISTRY - one atlas per (face, pixel size, style, fixed), not per ask.
;
; A resolution-native IDE re-asks for its fonts whenever the DPI changes, the
; window moves between monitors, or the user changes the text size. Without a
; registry each of those calls CreateGLFont again and the old atlas - up to
; eight megabytes of it - is simply abandoned, because until this rewrite the
; engine had no FreeGLFont at all. Drag a window between two monitors a few
; times and the leak is measured in tens of megabytes.
;
; GLFontFor() hands back the same font for the same request. Each call stamps
; the entry; GLFontsPurgeUnused() then frees everything that has NOT been
; asked for since the previous purge. So the host's DPI-change handler is:
; re-acquire every font it wants, then purge - and whatever it no longer wants
; goes away without the host having to track what those were.
; ----------------------------------------------------------------------------
Structure GLFontRegEntry
  *f.GLFont
  Stamp.q
EndStructure
Global NewMap GLF_Registry.GLFontRegEntry()
Global GLF_RegStamp.q
Global GLF_PurgeMark.q

Procedure.i GLFontFor(FontName.s, PixelHeight.i, Style.i = 0, FixedAdvance.b = #False)
  Protected key.s = LCase(FontName) + "|" + Str(PixelHeight) + "|" + Str(Style) + "|" + Str(FixedAdvance)
  GLF_RegStamp + 1
  If FindMapElement(GLF_Registry(), key)
    GLF_Registry()\Stamp = GLF_RegStamp
    ProcedureReturn GLF_Registry()\f
  EndIf
  Protected *nf.GLFont
  If FixedAdvance
    *nf = CreateGLFontFixedPx(FontName, PixelHeight, Style)
  Else
    *nf = CreateGLFontPx(FontName, PixelHeight, Style)
  EndIf
  If *nf = 0 : ProcedureReturn 0 : EndIf
  AddMapElement(GLF_Registry(), key)
  GLF_Registry()\f = *nf
  GLF_Registry()\Stamp = GLF_RegStamp
  ProcedureReturn *nf
EndProcedure

Declare FreeGLFont(*f.GLFont)

; Free every registered font not asked for since the last purge. Returns how
; many went. The keys are collected FIRST and deleted afterwards rather than
; deleting inside the ForEach, because a map being mutated under its own
; iterator is not a thing to be clever about.
Procedure.i GLFontsPurgeUnused()
  Protected NewList doomed.s()
  Protected freed.i = 0
  ForEach GLF_Registry()
    If GLF_Registry()\Stamp <= GLF_PurgeMark
      AddElement(doomed()) : doomed() = MapKey(GLF_Registry())
    EndIf
  Next
  ForEach doomed()
    If FindMapElement(GLF_Registry(), doomed())
      FreeGLFont(GLF_Registry()\f)
      DeleteMapElement(GLF_Registry())
      freed + 1
    EndIf
  Next
  GLF_PurgeMark = GLF_RegStamp
  ProcedureReturn freed
EndProcedure

Procedure.i GLFontsRegistered()
  ProcedureReturn MapSize(GLF_Registry())
EndProcedure

Procedure FreeGLFont(*f.GLFont)
  If Not *f : ProcedureReturn : EndIf
  Protected i.i
  For i = 0 To *f\PageCount - 1
    If *f\Pages[i]\TextureID : glDeleteTextures_(1, @*f\Pages[i]\TextureID) : EndIf
  Next
  For i = 0 To #GLF_BLOCKS - 1
    If *f\Block[i] : FreeMemory(*f\Block[i]) : *f\Block[i] = 0 : EndIf
  Next
  If *f\PBFont : FreeFont(*f\PBFont) : *f\PBFont = 0 : EndIf
  FreeStructure(*f)
EndProcedure

; ----------------------------------------------------------------------------
; GetGLTextWidth()
; Description: The width the SAME string would occupy if DrawGLText drew it.
;
; It shares GLF_Glyph with the renderer, which is the point: the old version
; carried its own copy of the 32..126 test, so a measurement and a picture
; could disagree and the alignment computed from the measurement was wrong in
; the same silent way.
; ----------------------------------------------------------------------------
Procedure.f GetGLTextWidth(*f.GLFont, Text.s)
  If Not *f Or Text = "" : ProcedureReturn 0.0 : EndIf

  ; The fixed-advance shortcut. An editor asks for this on every caret move
  ; and every selection drag, and on a monospaced font the answer is a
  ; multiply - there is no reason to walk the string for it.
  Protected n.i
  Protected *p.Character = @Text
  Protected cp.i, lo.i
  Protected TotalW.f = 0.0
  Protected *g.GLGlyph

  While *p\c
    cp = *p\c
    *p + SizeOf(Character)
    ; A codepoint above the BMP arrives as a surrogate pair. Decode it, or
    ; the two halves are two separate unrenderable characters.
    If cp >= $D800 And cp <= $DBFF And *p\c >= $DC00 And *p\c <= $DFFF
      lo = *p\c
      *p + SizeOf(Character)
      cp = $10000 + ((cp - $D800) << 10) + (lo - $DC00)
    EndIf
    If cp < 32 Or cp = $7F
      ; Tab, CR and LF are layout, not text - the host splits on them. Kept
      ; zero-width, exactly as before.
      If Not *f\ShowControls : Continue : EndIf
    EndIf
    If *f\FixedAdvance > 0.0
      TotalW + *f\FixedAdvance
      Continue
    EndIf
    *g = GLF_Glyph(*f, cp)
    If *g : TotalW + *g\Advance : EndIf
  Wend
  ProcedureReturn TotalW
EndProcedure

; ----------------------------------------------------------------------------
; GLTextXForColumn() / GLTextColumnForX()
; Description: Column <-> pixel, using the SAME arithmetic DrawGLText uses.
;
; THIS IS THE API THE EDITOR SHOULD USE, on a proportional font as well as a
; monospaced one. The fiddliest correctness area in a text editor is the point
; where a mouse x becomes a caret column, and the reliable way to get it wrong
; is for the editor to keep its own copy of the advance rule. On a fixed font
; both of these are O(1); on a proportional one they are a prefix sum, and the
; caller does not have to know which.
;
; Column is 0-based and counts CODEPOINTS, not UTF-16 units, so an astral
; character is one column.
; ----------------------------------------------------------------------------
Procedure.f GLTextXForColumn(*f.GLFont, Text.s, Col.i)
  If Not *f Or Col <= 0 : ProcedureReturn 0.0 : EndIf
  If *f\FixedAdvance > 0.0 : ProcedureReturn Col * *f\FixedAdvance : EndIf
  Protected *p.Character = @Text
  Protected cp.i, lo.i, n.i = 0
  Protected x.f = 0.0
  Protected *g.GLGlyph
  While *p\c And n < Col
    cp = *p\c
    *p + SizeOf(Character)
    If cp >= $D800 And cp <= $DBFF And *p\c >= $DC00 And *p\c <= $DFFF
      lo = *p\c : *p + SizeOf(Character)
      cp = $10000 + ((cp - $D800) << 10) + (lo - $DC00)
    EndIf
    n + 1
    If cp < 32 Or cp = $7F
      If Not *f\ShowControls : Continue : EndIf
    EndIf
    *g = GLF_Glyph(*f, cp)
    If *g : x + *g\Advance : EndIf
  Wend
  ProcedureReturn x
EndProcedure

Procedure.i GLTextColumnForX(*f.GLFont, Text.s, X.f)
  If Not *f Or X <= 0.0 : ProcedureReturn 0 : EndIf
  If *f\FixedAdvance > 0.0
    ; Half a cell, so the caret snaps to the nearer edge of the glyph the
    ; pointer is over rather than always to its left edge.
    Protected c.i = Int((X + *f\FixedAdvance * 0.5) / *f\FixedAdvance)
    Protected maxc.i = 0
    Protected *q.Character = @Text
    While *q\c : maxc + 1 : *q + SizeOf(Character) : Wend
    If c > maxc : c = maxc : EndIf
    ProcedureReturn c
  EndIf
  Protected *p.Character = @Text
  Protected cp.i, lo.i, n.i = 0
  Protected acc.f = 0.0
  Protected *g.GLGlyph
  While *p\c
    cp = *p\c
    *p + SizeOf(Character)
    If cp >= $D800 And cp <= $DBFF And *p\c >= $DC00 And *p\c <= $DFFF
      lo = *p\c : *p + SizeOf(Character)
      cp = $10000 + ((cp - $D800) << 10) + (lo - $DC00)
    EndIf
    Protected adv.f = 0.0
    If cp >= 32 And cp <> $7F Or *f\ShowControls
      *g = GLF_Glyph(*f, cp)
      If *g : adv = *g\Advance : EndIf
    EndIf
    If X < acc + adv * 0.5 : ProcedureReturn n : EndIf
    acc + adv
    n + 1
  Wend
  ProcedureReturn n
EndProcedure

; ----------------------------------------------------------------------------
; DrawGLText()
; Description: Renders text using the font's glyph cache.
; Parameters:
;   ScreenX, ScreenY - The top-left anchor point for the text.
;   Scaled           - If #True, maps to virtual BaseWidth/Height.
;   IgnoreCamera     - Defaults to #True (Sticks to screen for UI/HUD).
;
; Two behaviours changed, both of them removing a silent wrong answer:
;
;   1. A string longer than 256 characters used to be TRUNCATED, in silence -
;      `If Len > 256 : Len = 256`. A source line of 300 characters simply
;      stopped. The buffer is now flushed and refilled instead, so length is
;      unbounded.
;   2. The draw count was Len*6, the length of the STRING, not the number of
;      quads actually built. Every skipped character left six zeroed vertices
;      in the middle of the buffer that were still handed to the GPU. They
;      collapsed to a degenerate triangle and drew nothing, so it never
;      showed - but the engine was asking the driver to rasterise geometry it
;      had not written.
; ----------------------------------------------------------------------------
Procedure DrawGLText(*f.GLFont, ScreenX.f, ScreenY.f, Text.s, R.f=1.0, G.f=1.0, B.f=1.0, A.f=1.0, Scaled.b=#False, IgnoreCamera.b=#True)
  If Not *f Or Text = "" : ProcedureReturn : EndIf
  GL_StatTextCalls + 1

  Protected TW.f = Util_WinWidth, TH.f = Util_WinHeight
  If Scaled : TW = Util_BaseWidth : TH = Util_BaseHeight : EndIf
  If TW <= 0.0 Or TH <= 0.0 : ProcedureReturn : EndIf

  glUseProgram(Util_TextShader)
  glUniform4f(Util_TextLoc_Color, R, G, B, A)
  glActiveTexture(#GL_TEXTURE0)
  glUniform1i(Util_TextLoc_Tex, 0)
  glBindVertexArray(Util_TextVAO)
  glBindBuffer(#GL_ARRAY_BUFFER, Util_TextVBO)

  ; #GLF_BATCH_QUADS is the VBO's capacity in quads (24576 bytes / 96 bytes
  ; per quad). The buffer is flushed when it fills OR when the next glyph
  ; lives on a different atlas page.
  #GLF_BATCH_QUADS = 256
  ; ONE STAGING BUFFER FOR THE PROCESS, not one per call.
  ;
  ; The old code did AllocateMemory(Len*96) / FreeMemory on every single
  ; DrawGLText. Measured on an editor-shaped screen that is 392 malloc/free
  ; pairs per redraw, for a buffer whose maximum size is known at compile
  ; time and which is dead before the call returns. The first draft of this
  ; rewrite made it WORSE by allocating the full 24 KB every time regardless
  ; of the string length - which is how a "faster" rewrite quietly buys back
  ; its own gains.
  ;
  ; DrawGLText is not re-entrant (it holds no state across the call and
  ; nothing it calls can re-enter it), so one buffer is enough.
  If GLF_QuadBuf = 0
    GLF_QuadBuf = AllocateMemory(#GLF_BATCH_QUADS * 6 * 4 * 4)
    If GLF_QuadBuf = 0 : glBindVertexArray(0) : ProcedureReturn : EndIf
  EndIf
  Protected *Buffer = GLF_QuadBuf
  Protected *Ptr.Float = *Buffer
  Protected quads.i = 0, curPage.i = -1

  Protected CursorX.f = ScreenX, CursorY.f = ScreenY
  Protected *p.Character = @Text
  Protected cp.i, lo.i
  Protected *g.GLGlyph
  Protected W.f, H.f, RenderX.f, RenderY.f, RenderW.f, RenderH.f
  Protected nx1.f, ny1.f, nx2.f, ny2.f, u1.f, v1.f, u2.f, v2.f
  Protected CamCenterX.f = TW / 2.0, CamCenterY.f = TH / 2.0
  Protected tex.l

  While *p\c
    cp = *p\c
    *p + SizeOf(Character)
    If cp >= $D800 And cp <= $DBFF And *p\c >= $DC00 And *p\c <= $DFFF
      lo = *p\c
      *p + SizeOf(Character)
      cp = $10000 + ((cp - $D800) << 10) + (lo - $DC00)
    EndIf
    If cp < 32 Or cp = $7F
      If Not *f\ShowControls : Continue : EndIf
    EndIf

    *g = GLF_Glyph(*f, cp)
    If *g = 0 : Continue : EndIf
    If *g\State = #GLF_BLANK
      CursorX + *g\Advance
      Continue
    EndIf

    ; A page change forces a flush - one texture per draw call, always.
    If *g\Page <> curPage And quads > 0
      GLF_Clock + 1
      *f\Pages[curPage]\LastUse = GLF_Clock
      glBindTexture_(#GL_TEXTURE_2D, *f\Pages[curPage]\TextureID)
      CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
        glBufferData(#GL_ARRAY_BUFFER, 24576, #Null, #GL_DYNAMIC_DRAW)
      CompilerEndIf
      glBufferSubData(#GL_ARRAY_BUFFER, 0, quads * 6 * 4 * 4, *Buffer)
      glDrawArrays_(#GL_TRIANGLES, 0, quads * 6)
      GL_StatDrawCalls + 1 : GL_StatTextDraws + 1 : GL_StatBufferUploads + 1 : GL_StatGlyphs + quads
      quads = 0 : *Ptr = *Buffer
    EndIf
    curPage = *g\Page

    W = *g\Width : H = *g\Height
    RenderX = CursorX : RenderY = CursorY : RenderW = W : RenderH = H
    If *f\SnapToPixel
      RenderX = Round(RenderX, #PB_Round_Nearest)
      RenderY = Round(RenderY, #PB_Round_Nearest)
    EndIf

    If Not IgnoreCamera
      RenderX = CamCenterX + ((RenderX - GL_CameraX - CamCenterX) * GL_CameraZoom)
      RenderY = CamCenterY + ((RenderY - GL_CameraY - CamCenterY) * GL_CameraZoom)
      RenderW = W * GL_CameraZoom : RenderH = H * GL_CameraZoom
    EndIf

    nx1 = (RenderX / TW) * 2.0 - 1.0 : ny1 = 1.0 - (RenderY / TH) * 2.0
    nx2 = ((RenderX + RenderW) / TW) * 2.0 - 1.0 : ny2 = 1.0 - ((RenderY + RenderH) / TH) * 2.0
    u1 = *g\u1 : v1 = *g\v1 : u2 = *g\u2 : v2 = *g\v2

    *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4 : *Ptr\f = u1 : *Ptr+4 : *Ptr\f = v1 : *Ptr+4
    *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = u1 : *Ptr+4 : *Ptr\f = v2 : *Ptr+4
    *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4 : *Ptr\f = u2 : *Ptr+4 : *Ptr\f = v1 : *Ptr+4
    *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = u1 : *Ptr+4 : *Ptr\f = v2 : *Ptr+4
    *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = u2 : *Ptr+4 : *Ptr\f = v2 : *Ptr+4
    *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4 : *Ptr\f = u2 : *Ptr+4 : *Ptr\f = v1 : *Ptr+4
    quads + 1
    CursorX + *g\Advance

    If quads >= #GLF_BATCH_QUADS
      GLF_Clock + 1
      *f\Pages[curPage]\LastUse = GLF_Clock
      glBindTexture_(#GL_TEXTURE_2D, *f\Pages[curPage]\TextureID)
      CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
        glBufferData(#GL_ARRAY_BUFFER, 24576, #Null, #GL_DYNAMIC_DRAW)
      CompilerEndIf
      glBufferSubData(#GL_ARRAY_BUFFER, 0, quads * 6 * 4 * 4, *Buffer)
      glDrawArrays_(#GL_TRIANGLES, 0, quads * 6)
      GL_StatDrawCalls + 1 : GL_StatTextDraws + 1 : GL_StatBufferUploads + 1 : GL_StatGlyphs + quads
      quads = 0 : *Ptr = *Buffer
    EndIf
  Wend

  If quads > 0
    GLF_Clock + 1
    *f\Pages[curPage]\LastUse = GLF_Clock
    glBindTexture_(#GL_TEXTURE_2D, *f\Pages[curPage]\TextureID)
    CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
      glBufferData(#GL_ARRAY_BUFFER, 24576, #Null, #GL_DYNAMIC_DRAW)
    CompilerEndIf
    glBufferSubData(#GL_ARRAY_BUFFER, 0, quads * 6 * 4 * 4, *Buffer)
    glDrawArrays_(#GL_TRIANGLES, 0, quads * 6)
    GL_StatDrawCalls + 1 : GL_StatTextDraws + 1 : GL_StatBufferUploads + 1 : GL_StatGlyphs + quads
  EndIf

  glBindVertexArray(0)
EndProcedure

; --- Instrumentation readout ------------------------------------------------
Procedure GL_StatsReset()
  GL_StatDrawCalls = 0 : GL_StatTextCalls = 0 : GL_StatTextDraws = 0
  GL_StatGlyphs = 0 : GL_StatBufferUploads = 0
EndProcedure

; ----------------------------------------------------------------------------
; DrawGLPolygon()
; Description: Draws mathematically perfect geometric shapes.
; Parameters:
;   RadiusX, RadiusY - Dimensions of the shape (make them equal for circles).
;   Sides            - Number of vertices (3=Triangle, 4=Diamond, 32=Circle).
;   Solid            - #True fills the shape, #False draws a wireframe outline.
;   IgnoreCamera     - Defaults to #False (Moves with the game world).
; ----------------------------------------------------------------------------
Procedure DrawGLPolygon(X.f, Y.f, RadiusX.f, RadiusY.f, Sides.i, R.f=1.0, G.f=1.0, B.f=1.0, A.f=1.0, Solid.b=#True, Scaled.b=#False, IgnoreCamera.b=#False)
  If Sides < 3 : ProcedureReturn : EndIf 
  glUseProgram(Util_ShapeShader) : glUniform4f(Util_ShapeLoc_Color, R, G, B, A) : glBindVertexArray(Util_ShapeVAO)
  Define TW.f = Util_WinWidth, TH.f = Util_WinHeight : If Scaled : TW = Util_BaseWidth : TH = Util_BaseHeight : EndIf
  
  ;CAMERA MATH
  If Not IgnoreCamera
    Define CamCenterX.f = TW / 2.0, CamCenterY.f = TH / 2.0
    X = CamCenterX + ((X - GL_CameraX - CamCenterX) * GL_CameraZoom)
    Y = CamCenterY + ((Y - GL_CameraY - CamCenterY) * GL_CameraZoom)
    RadiusX * GL_CameraZoom : RadiusY * GL_CameraZoom
  EndIf
  
  Define VertCount = Sides + 2, *Buffer = AllocateMemory(VertCount * 2 * 4), *Ptr.Float = *Buffer
  Define i, Angle.f, nx.f, ny.f
  If Solid
    *Ptr\f = (X / TW) * 2.0 - 1.0 : *Ptr+4 : *Ptr\f = 1.0 - (Y / TH) * 2.0 : *Ptr+4
  Else : VertCount = Sides : EndIf
  For i = 0 To Sides
    Angle = (i * 2.0 * #PI) / Sides
    nx = ((X + Cos(Angle) * RadiusX) / TW) * 2.0 - 1.0 : ny = 1.0 - ((Y + Sin(Angle) * RadiusY) / TH) * 2.0
    *Ptr\f = nx : *Ptr+4 : *Ptr\f = ny : *Ptr+4
  Next
  glBindBuffer(#GL_ARRAY_BUFFER, Util_ShapeVBO) 
  
  ; --- BUFFER ORPHANING (Raspberry Pi ARM Only) ---
  CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
    glBufferData(#GL_ARRAY_BUFFER, 65536, #Null, #GL_DYNAMIC_DRAW)
  CompilerEndIf
  
  glBufferSubData(#GL_ARRAY_BUFFER, 0, VertCount * 8, *Buffer)
  If Solid : glDrawArrays_(#GL_TRIANGLE_FAN, 0, VertCount) : Else : glDrawArrays_(#GL_LINE_LOOP, 0, VertCount) : EndIf
  GL_StatDrawCalls + 1 : GL_StatBufferUploads + 1
  glBindVertexArray(0) : FreeMemory(*Buffer)
EndProcedure

; ----------------------------------------------------------------------------
; DrawGLBox()
; Description: High-speed drawing for standard untextured rectangles.
; Parameters:
;   W, H         - Width and Height.
;   IgnoreCamera - Defaults to #False (Moves with the game world).
; ----------------------------------------------------------------------------
Procedure DrawGLBox(X.f, Y.f, W.f, H.f, R.f=1.0, G.f=1.0, B.f=1.0, A.f=1.0, Scaled.b=#False, IgnoreCamera.b=#False)
  glUseProgram(Util_ShapeShader) : glUniform4f(Util_ShapeLoc_Color, R, G, B, A) : glBindVertexArray(Util_ShapeVAO)
  Define TW.f = Util_WinWidth, TH.f = Util_WinHeight : If Scaled : TW = Util_BaseWidth : TH = Util_BaseHeight : EndIf
  
  ;CAMERA MATH 
  If Not IgnoreCamera
    Define CamCenterX.f = TW / 2.0, CamCenterY.f = TH / 2.0
    X = CamCenterX + ((X - GL_CameraX - CamCenterX) * GL_CameraZoom)
    Y = CamCenterY + ((Y - GL_CameraY - CamCenterY) * GL_CameraZoom)
    W * GL_CameraZoom : H * GL_CameraZoom
  EndIf
  
  Define nx1.f = (X / TW) * 2.0 - 1.0, ny1.f = 1.0 - (Y / TH) * 2.0
  Define nx2.f = ((X + W) / TW) * 2.0 - 1.0, ny2.f = 1.0 - ((Y + H) / TH) * 2.0
  Define *Buffer = AllocateMemory(12 * 4), *Ptr.Float = *Buffer
  *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4 : *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4
  *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4
  glBindBuffer(#GL_ARRAY_BUFFER, Util_ShapeVBO) 
  
  ; --- BUFFER ORPHANING (Raspberry Pi ARM Only) ---
  CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
    glBufferData(#GL_ARRAY_BUFFER, 65536, #Null, #GL_DYNAMIC_DRAW)
  CompilerEndIf
  
  glBufferSubData(#GL_ARRAY_BUFFER, 0, 48, *Buffer) 
  
  glDrawArrays_(#GL_TRIANGLES, 0, 6)
  GL_StatDrawCalls + 1 : GL_StatBufferUploads + 1
  glBindVertexArray(0) : FreeMemory(*Buffer)
EndProcedure

Structure GLStaticMesh : VAO.l : VBO.l : VertexCount.i : EndStructure
Procedure.i CreateGLStaticLines(Array Lines.f(1))
  Define *Mesh.GLStaticMesh = AllocateMemory(SizeOf(GLStaticMesh))
  *Mesh\VertexCount = (ArraySize(Lines()) + 1) / 2
  Define i, nx.f, ny.f, *Buffer = AllocateMemory(*Mesh\VertexCount * 8), *Ptr.Float = *Buffer
  For i = 0 To ArraySize(Lines()) Step 2
    nx = (Lines(i) / Util_BaseWidth) * 2.0 - 1.0 : ny = 1.0 - (Lines(i+1) / Util_BaseHeight) * 2.0
    *Ptr\f = nx : *Ptr+4 : *Ptr\f = ny : *Ptr+4
  Next
  glGenVertexArrays(1, @*Mesh\VAO) : glGenBuffers(1, @*Mesh\VBO)
  glBindVertexArray(*Mesh\VAO) : glBindBuffer(#GL_ARRAY_BUFFER, *Mesh\VBO)
  glBufferData(#GL_ARRAY_BUFFER, *Mesh\VertexCount * 8, *Buffer, #GL_STATIC_DRAW)
  glVertexAttribPointer(0, 2, #GL_FLOAT, #GL_FALSE, 2 * 4, #Null) : glEnableVertexAttribArray(0)
  glBindVertexArray(0) : FreeMemory(*Buffer)
  ProcedureReturn *Mesh
EndProcedure

Procedure DrawGLStaticLines(*Mesh.GLStaticMesh, R.f=1.0, G.f=1.0, B.f=1.0, A.f=1.0, LimitVertices.i = 0)
  If Not *Mesh : ProcedureReturn : EndIf
  glUseProgram(Util_ShapeShader) : glUniform4f(Util_ShapeLoc_Color, R, G, B, A) : glBindVertexArray(*Mesh\VAO)
  Define DrawCount = *Mesh\VertexCount
  If LimitVertices > 0 And LimitVertices < *Mesh\VertexCount : DrawCount = LimitVertices : EndIf
  glDrawArrays_(#GL_LINES, 0, DrawCount) : GL_StatDrawCalls + 1 : glBindVertexArray(0)
EndProcedure

; Procedure GL_ResizeFBO(Width.i, Height.i)
;   If Util_FBOTex
;     glBindTexture_(#GL_TEXTURE_2D, Util_FBOTex)
;     glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_RGBA, Width, Height, 0, #GL_RGBA, #GL_UNSIGNED_BYTE, #Null)
;   EndIf
; EndProcedure

Procedure InitRetroCRT(Width.i, Height.i)
  ; 1. Generate the Framebuffer
  glGenFramebuffers(1, @Util_FBO)
  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)

  ; 2. Generate the blank texture
  glGenTextures_(1, @Util_FBOTex)
  glBindTexture_(#GL_TEXTURE_2D, Util_FBOTex)
  glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_RGBA, Width, Height, 0, #GL_RGBA, #GL_UNSIGNED_BYTE, #Null)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MIN_FILTER, #GL_LINEAR)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MAG_FILTER, #GL_LINEAR)
  glFramebufferTexture2D(#GL_FRAMEBUFFER, #GL_COLOR_ATTACHMENT0, #GL_TEXTURE_2D, Util_FBOTex, 0)

  If glCheckFramebufferStatus(#GL_FRAMEBUFFER) <> 36053 ; GL_FRAMEBUFFER_COMPLETE
    MessageRequester("Error", "Your GPU does not support FBOs!")
  EndIf
  glBindFramebuffer(#GL_FRAMEBUFFER, 0) 

  ; 3. Compile the CRT Shader
  Define Vert.s = "#version 140" + #LF$ + "#extension GL_ARB_explicit_attrib_location : enable" + #LF$ + "layout (location = 0) in vec2 vertex;" + #LF$ + "layout (location = 1) in vec2 uv;" + #LF$ + "out vec2 TexCoords;" + #LF$ + "void main() { gl_Position = vec4(vertex.x, vertex.y, 0.0, 1.0); TexCoords = uv; }"

  Define Frag.s = "#version 140" + #LF$ + "out vec4 FragColor; in vec2 TexCoords; uniform sampler2D screenTex; uniform float time;" + #LF$ + 
  "void main() {" + #LF$ + 
  "  vec2 uv = TexCoords * 2.0 - 1.0;" + #LF$ + 
  "  uv += uv * dot(uv, uv) * 0.015;" + #LF$ + 
  "  uv = uv * 0.5 + 0.5;" + #LF$ + 
  "  if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { FragColor = vec4(0.0,0.0,0.0,1.0); return; }" + #LF$ + 
  "  vec4 color = texture(screenTex, uv);" + #LF$ + 
  "  float scanline = sin(uv.y * 800.0 - (time * 10.0)) * 0.04;" + #LF$ + 
  "  color.rgb -= scanline;" + #LF$ + 
  "  color.rgb *= smoothstep(0.8, 0.3, distance(uv, vec2(0.5)));" + #LF$ + 
  "  FragColor = color;" + #LF$ + 
  "}"

  Util_PostShader = Util_CompileProgram(Vert, Frag)
  
  ; 3.5 Compile the Passthrough Shader
  Define FragPass.s = "#version 140" + #LF$ + "in vec2 TexCoords;" + #LF$ + "out vec4 FragColor;" + #LF$ + "uniform sampler2D screenTex;" + #LF$ + "void main() { FragColor = texture(screenTex, TexCoords); }"
  Util_PassShader = Util_CompileProgram(Vert, FragPass)
  
  
  Define *TexName = UTF8("screenTex") : Util_PostLoc_Tex = glGetUniformLocation(Util_PostShader, *TexName) : FreeMemory(*TexName)
  Define *TimeName = UTF8("time") : Util_PostLoc_Time = glGetUniformLocation(Util_PostShader, *TimeName) : FreeMemory(*TimeName)

  ; 4. Setup the Fullscreen Quad Geometry
  glGenVertexArrays(1, @Util_PostVAO) : glGenBuffers(1, @Util_PostVBO)
  glBindVertexArray(Util_PostVAO) : glBindBuffer(#GL_ARRAY_BUFFER, Util_PostVBO)
  Define *Quad = AllocateMemory(24 * 4) : Define *Ptr.Float = *Quad
  *Ptr\f = -1.0: *Ptr+4: *Ptr\f = -1.0: *Ptr+4: *Ptr\f = 0.0: *Ptr+4: *Ptr\f = 0.0: *Ptr+4
  *Ptr\f = 1.0: *Ptr+4: *Ptr\f = -1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 0.0: *Ptr+4
  *Ptr\f = -1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 0.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4
  *Ptr\f = -1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 0.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4
  *Ptr\f = 1.0: *Ptr+4: *Ptr\f = -1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 0.0: *Ptr+4
  *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = 1.0: *Ptr+4
  glBufferData(#GL_ARRAY_BUFFER, 96, *Quad, #GL_STATIC_DRAW)
  glVertexAttribPointer(0, 2, #GL_FLOAT, #GL_FALSE, 16, 0) : glEnableVertexAttribArray(0)
  glVertexAttribPointer(1, 2, #GL_FLOAT, #GL_FALSE, 16, 8) : glEnableVertexAttribArray(1)
  glBindVertexArray(0) : FreeMemory(*Quad)
EndProcedure

Procedure DrawRetroCRT(ElapsedSeconds.f)
  glUseProgram(Util_PostShader)
  glUniform1f(Util_PostLoc_Time, ElapsedSeconds)
  glActiveTexture(#GL_TEXTURE0)
  glBindTexture_(#GL_TEXTURE_2D, Util_FBOTex)
  glUniform1i(Util_PostLoc_Tex, 0)
  glBindVertexArray(Util_PostVAO)
  glDrawArrays_(#GL_TRIANGLES, 0, 6)
  GL_StatDrawCalls + 1
  glBindVertexArray(0)
EndProcedure

Procedure DrawPassthrough()
  glUseProgram(Util_PassShader)
  glActiveTexture(#GL_TEXTURE0)
  glBindTexture_(#GL_TEXTURE_2D, Util_FBOTex)
  glBindVertexArray(Util_PostVAO)
  glDrawArrays_(#GL_TRIANGLES, 0, 6)
  GL_StatDrawCalls + 1
  glBindVertexArray(0)
EndProcedure

;Call this from the main event loop when #PB_Event_SizeWindow is triggered
; ----------------------------------------------------------------------------
; GL_HandleResize()
; Description: Calculates aspect-correct letterboxing. Call this ONLY when 
;              the OS triggers a #PB_Event_SizeWindow event.
; Parameters:
;   GadgetID - The ID returned by OpenGLWindow().
; ----------------------------------------------------------------------------

Procedure GL_HandleResize(GadgetID.i)
  ; THE CLIENT AREA, NOT THE OUTER WINDOW.
  ;
  ; WindowWidth()/WindowHeight() return the OUTER size by default - the
  ; client area PLUS the borders and the title bar. Those values were then
  ; used for two things that both need the inner size:
  ;
  ;   ResizeGadget(GadgetID, 0, 0, CurW, CurH)   - sizes the GL canvas
  ;   the letterbox math below                    - sizes the viewport
  ;
  ; so the canvas was made taller than the area that is actually visible,
  ; by exactly the title bar plus one border. The bottom strip of the
  ; layout was drawn outside the client rectangle and simply never seen -
  ; on the emulator that is the row of totals under the Variables panel.
  ;
  ; Reported by sparrow2: the bottom was cut off until the window was
  ; maximized. It reads as a layout that is too tall for the window, which
  ; sends you looking at the layout; the layout was always right and the
  ; window it was being fitted into was mismeasured.
  ;
  ; #PB_Window_InnerCoordinate asks for the drawable area, which is what
  ; both users of these numbers meant all along.
  Define CurW = WindowWidth(Util_MainWindowID, #PB_Window_InnerCoordinate)
  Define CurH = WindowHeight(Util_MainWindowID, #PB_Window_InnerCoordinate)
  Define PhysW.i, PhysH.i

  ; On Windows, GetClientRect is the final authority for the drawable pixels.
  ; The window API and the GUI toolkit do not always agree during a maximized
  ; DPI transition: at 125% a 1920x1080 desktop was reported tall enough to
  ; scale the 1600x950 emulator from its width, putting the bottom 70 authored
  ; pixels (the control bar) below the real client. Using the OS client rect
  ; here, then converting only for ResizeGadget's logical units, makes the
  ; render viewport and the actually visible surface the same rectangle.
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected client.RECT
    If GetClientRect_(WindowID(Util_MainWindowID), @client)
      PhysW = client\right - client\left
      PhysH = client\bottom - client\top
      Protected dpiX.f = DesktopResolutionX()
      Protected dpiY.f = DesktopResolutionY()
      If dpiX <= 0.0 : dpiX = 1.0 : EndIf
      If dpiY <= 0.0 : dpiY = 1.0 : EndIf
      CurW = Round(PhysW / dpiX, #PB_Round_Nearest)
      CurH = Round(PhysH / dpiY, #PB_Round_Nearest)
    EndIf
  CompilerElse
    PhysW = CurW * Linux_DPIScale
    PhysH = CurH * Linux_DPIScale
  CompilerEndIf

  ; Prevent crashing or division by zero if the window is minimized (0x0)
  If CurW <= 0 Or CurH <= 0
    ProcedureReturn
  EndIf
  If PhysW <= 0 Or PhysH <= 0
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      PhysW = DesktopScaledX(CurW) : PhysH = DesktopScaledY(CurH)
    CompilerElse
      PhysW = CurW * Linux_DPIScale : PhysH = CurH * Linux_DPIScale
    CompilerEndIf
  EndIf
  
  Util_WinWidth = CurW
  Util_WinHeight = CurH
  
  ;GL_ResizeFBO(CurW, CurH)
  
  ; Make the OpenGL canvas fill the ENTIRE physical window
  ResizeGadget(GadgetID, 0, 0, CurW, CurH)

  ; --- FIXED APPLICATION CANVAS: fill, do not letterbox ----------------
  If GL_ViewportMode = #GL_VIEWPORT_STRETCH
    GL_ViewportX = 0 : GL_ViewportY = 0
    GL_ViewportW = PhysW : GL_ViewportH = PhysH
    ProcedureReturn
  EndIf

  ; --- NATIVE: no canvas, no bars, no scaling ---------------------------
  ; The whole client area is the viewport and one canvas unit is one physical
  ; pixel, so a window twice as wide holds twice as much text at the same
  ; size instead of the same text at twice the size.
  If GL_ViewportMode = #GL_VIEWPORT_NATIVE
    GL_ViewportX = 0
    GL_ViewportY = 0
    GL_ViewportW = PhysW
    GL_ViewportH = PhysH
    If GL_ViewportW < 1 : GL_ViewportW = 1 : EndIf
    If GL_ViewportH < 1 : GL_ViewportH = 1 : EndIf
    ; Util_BaseWidth/Height ARE the viewport here. That is what makes
    ; MapPhysicalToVirtual (GlUI.pbi) come out as identity - it computes
    ; GL_ViewportW / Util_BaseWidth, and nothing there needs to change.
    Util_BaseWidth  = GL_ViewportW
    Util_BaseHeight = GL_ViewportH
    Util_WinWidth   = GL_ViewportW
    Util_WinHeight  = GL_ViewportH
    ProcedureReturn
  EndIf

  ; --- Aspect Correct Letterboxing Math ---
  Define TargetW.f = CurW
  Define TargetH.f = CurW * (Util_BaseHeight / Util_BaseWidth)
  
  If TargetH > CurH
    TargetH = CurH
    TargetW = CurH * (Util_BaseWidth / Util_BaseHeight)
  EndIf
  
  Define OffsetX.f = (CurW - TargetW) / 2.0
  Define OffsetY.f = (CurH - TargetH) / 2.0
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    GL_ViewportX = OffsetX * Linux_DPIScale
    GL_ViewportY = OffsetY * Linux_DPIScale
    GL_ViewportW = TargetW * Linux_DPIScale
    GL_ViewportH = TargetH * Linux_DPIScale
  CompilerElse
    GL_ViewportX = DesktopScaledX(OffsetX)
    GL_ViewportY = DesktopScaledY(OffsetY)
    GL_ViewportW = DesktopScaledX(TargetW)
    GL_ViewportH = DesktopScaledY(TargetH)
  CompilerEndIf
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 661
; FirstLine = 637
; Folding = ------
; EnableXP
; DPIAware
