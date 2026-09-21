; ============================================================================
; GlSpriteFunctions.pbi - Modern 2D Sprite Manager (V2 with Memory Support)
; ============================================================================
;Declare.i GenerateSpriteHull(*Sprite)


;   INTERNAL: Core Image Processor  
Procedure.i Internal_ProcessGLSprite(Img.i, ColorKey.i = -1)
  Define *Sprite.GLSprite = AllocateMemory(SizeOf(GLSprite))
  *Sprite\Width = ImageWidth(Img)
  *Sprite\Height = ImageHeight(Img)
  *Sprite\AlphaMask = AllocateMemory(*Sprite\Width * *Sprite\Height)
  
  Define BufferImg = CreateImage(#PB_Any, *Sprite\Width, *Sprite\Height, 32, #PB_Image_Transparent)
  StartDrawing(ImageOutput(BufferImg))
    DrawingMode(#PB_2DDrawing_AlphaBlend) : DrawImage(ImageID(Img), 0, 0)
    DrawingMode(#PB_2DDrawing_AllChannels)
    Define x, y, CurrentColor, AlphaVal
    For y = 0 To *Sprite\Height - 1
      For x = 0 To *Sprite\Width - 1
        CurrentColor = Point(x, y)
        If ColorKey <> -1 And (CurrentColor & $FFFFFF) = ColorKey
          Plot(x, y, RGBA(0, 0, 0, 0)) : AlphaVal = 0
        Else
          AlphaVal = Alpha(CurrentColor)
        EndIf
        If AlphaVal > 0 : PokeB(*Sprite\AlphaMask + (y * *Sprite\Width) + x, 1) : EndIf
      Next
    Next
  StopDrawing()
  
  glGenTextures_(1, @*Sprite\TextureID) : glBindTexture_(#GL_TEXTURE_2D, *Sprite\TextureID)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MIN_FILTER, #GL_NEAREST)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_MAG_FILTER, #GL_NEAREST)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_S, #GL_CLAMP_TO_EDGE)
  glTexParameteri_(#GL_TEXTURE_2D, #GL_TEXTURE_WRAP_T, #GL_CLAMP_TO_EDGE)
  
StartDrawing(ImageOutput(BufferImg))
    Define PixelFormat.l = #GL_BGRA_EXT
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      PixelFormat = #GL_RGBA
    CompilerEndIf
    
    glTexImage2D_(#GL_TEXTURE_2D, 0, #GL_RGBA, *Sprite\Width, *Sprite\Height, 0, PixelFormat, #GL_UNSIGNED_BYTE, DrawingBuffer())
  StopDrawing()
  FreeImage(BufferImg)
  ProcedureReturn *Sprite
EndProcedure

;   PUBLIC API  

Procedure.i LoadGLSprite(Filename.s, ColorKey.i = -1)
  Define Img = LoadImage(#PB_Any, Filename)
  If Not Img : ProcedureReturn 0 : EndIf
  Define *Sprite = Internal_ProcessGLSprite(Img, ColorKey)
  FreeImage(Img)
  ProcedureReturn *Sprite
EndProcedure

;Procedural Texture Generator

Procedure.i CreateProceduralRopeSprite()
  Define W = 32, H = 64
  Define Img = CreateImage(#PB_Any, W, H, 32, #PB_Image_Transparent)
  
  StartDrawing(ImageOutput(Img))
    DrawingMode(#PB_2DDrawing_AlphaBlend)
    
    ; 1. Base dark orange background
    Box(0, 0, W, H, RGBA(180, 120, 0, 255))
    
    ; 2. Bright yellow highlight down the center to create a 3D cylindrical illusion
    Box(W/4, 0, W/2, H, RGBA(255, 210, 50, 255))
    
    ; 3. Dark borders for crisp rendering against the background
    Box(0, 0, 3, H, RGBA(80, 50, 0, 255))
    Box(W-3, 0, 3, H, RGBA(80, 50, 0, 255))
    
    ; 4. Horizontal ridges to simulate the twists of a physical rope
    Define y
    For y = 0 To H Step 8
      Box(0, y, W, 2, RGBA(100, 60, 0, 150))
    Next
  StopDrawing()
  
  ; Pass our procedurally drawn RAM image directly to your engine's internal GL allocator
  Define *Sprite = Internal_ProcessGLSprite(Img)
  
  ; Free the CPU RAM image since OpenGL now owns the pixels on the GPU
  FreeImage(Img) 
  
  ProcedureReturn *Sprite
EndProcedure

;Loads directly from packed EXE memory!

Procedure.i LoadGLSpriteMemory(*MemAddress, ColorKey.i = -1)
  Define Img = CatchImage(#PB_Any, *MemAddress)
  If Not Img : ProcedureReturn 0 : EndIf
  Define *Sprite = Internal_ProcessGLSprite(Img, ColorKey)
  FreeImage(Img)
  ProcedureReturn *Sprite
EndProcedure

Procedure DrawGLSprite(*Sprite.GLSprite, ScreenX.f, ScreenY.f, AngleRadians.f=0.0, Scale.f=1.0, R.f=1.0, G.f=1.0, B.f=1.0, A.f=1.0, Scaled.b=#False, SrcX.f=-1.0, SrcY.f=-1.0, SrcW.f=-1.0, SrcH.f=-1.0, IgnoreCamera.b=#False)
  If Not *Sprite : ProcedureReturn : EndIf
  glUseProgram(Util_TextShader) : glUniform4f(Util_TextLoc_Color, R, G, B, A) 
  glActiveTexture(#GL_TEXTURE0) : glBindTexture_(#GL_TEXTURE_2D, *Sprite\TextureID)
  glUniform1i(Util_TextLoc_Tex, 0) : glBindVertexArray(Util_TextVAO)
  
  Define TW.f = Util_WinWidth, TH.f = Util_WinHeight : If Scaled : TW = Util_BaseWidth : TH = Util_BaseHeight : EndIf
  
  ;   CAMERA MATH  
  If Not IgnoreCamera
    Define CamCenterX.f = TW / 2.0, CamCenterY.f = TH / 2.0
    ScreenX = CamCenterX + ((ScreenX - GL_CameraX - CamCenterX) * GL_CameraZoom)
    ScreenY = CamCenterY + ((ScreenY - GL_CameraY - CamCenterY) * GL_CameraZoom)
    Scale * GL_CameraZoom
  EndIf
  
  Define u1.f = 0.0, v1.f = 0.0, u2.f = 1.0, v2.f = 1.0
  Define DrawW.f = *Sprite\Width, DrawH.f = *Sprite\Height
  
  If SrcX <> -1.0
    u1 = SrcX / *Sprite\Width : v1 = SrcY / *Sprite\Height
    u2 = (SrcX + SrcW) / *Sprite\Width : v2 = (SrcY + SrcH) / *Sprite\Height
    DrawW = SrcW : DrawH = SrcH
  EndIf
  
  Define W.f = DrawW * Scale, H.f = DrawH * Scale
  Define HalfW.f = W / 2.0, HalfH.f = H / 2.0
  Define TL_x.f = -HalfW, TL_y.f = -HalfH, TR_x.f = HalfW, TR_y.f = -HalfH
  Define BL_x.f = -HalfW, BL_y.f = HalfH,  BR_x.f = HalfW, BR_y.f = HalfH
  
  Define CosA.f = Cos(AngleRadians), SinA.f = Sin(AngleRadians)
  Define CenterX.f = ScreenX + HalfW, CenterY.f = ScreenY + HalfH
  
  Define Rot_TL_x.f = CenterX + (TL_x * CosA - TL_y * SinA), Rot_TL_y.f = CenterY + (TL_x * SinA + TL_y * CosA)
  Define Rot_TR_x.f = CenterX + (TR_x * CosA - TR_y * SinA), Rot_TR_y.f = CenterY + (TR_x * SinA + TR_y * CosA)
  Define Rot_BL_x.f = CenterX + (BL_x * CosA - BL_y * SinA), Rot_BL_y.f = CenterY + (BL_x * SinA + BL_y * CosA)
  Define Rot_BR_x.f = CenterX + (BR_x * CosA - BR_y * SinA), Rot_BR_y.f = CenterY + (BR_x * SinA + BR_y * CosA)
  
  Define nx1.f = (Rot_TL_x / TW) * 2.0 - 1.0, ny1.f = 1.0 - (Rot_TL_y / TH) * 2.0
  Define nx2.f = (Rot_TR_x / TW) * 2.0 - 1.0, ny2.f = 1.0 - (Rot_TR_y / TH) * 2.0
  Define nx3.f = (Rot_BL_x / TW) * 2.0 - 1.0, ny3.f = 1.0 - (Rot_BL_y / TH) * 2.0
  Define nx4.f = (Rot_BR_x / TW) * 2.0 - 1.0, ny4.f = 1.0 - (Rot_BR_y / TH) * 2.0
  
  Define *Buffer = AllocateMemory(24 * 4), *Ptr.Float = *Buffer

  Define V_Top.f = v2, V_Bottom.f = v1
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    V_Top = v1 : V_Bottom = v2 
  CompilerEndIf
  
  *Ptr\f = nx1 : *Ptr+4 : *Ptr\f = ny1 : *Ptr+4 : *Ptr\f = u1 : *Ptr+4 : *Ptr\f = V_Top : *Ptr+4
  *Ptr\f = nx3 : *Ptr+4 : *Ptr\f = ny3 : *Ptr+4 : *Ptr\f = u1 : *Ptr+4 : *Ptr\f = V_Bottom : *Ptr+4
  *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = u2 : *Ptr+4 : *Ptr\f = V_Top : *Ptr+4
  
  *Ptr\f = nx3 : *Ptr+4 : *Ptr\f = ny3 : *Ptr+4 : *Ptr\f = u1 : *Ptr+4 : *Ptr\f = V_Bottom : *Ptr+4
  *Ptr\f = nx4 : *Ptr+4 : *Ptr\f = ny4 : *Ptr+4 : *Ptr\f = u2 : *Ptr+4 : *Ptr\f = V_Bottom : *Ptr+4
  *Ptr\f = nx2 : *Ptr+4 : *Ptr\f = ny2 : *Ptr+4 : *Ptr\f = u2 : *Ptr+4 : *Ptr\f = V_Top : *Ptr+4
  
  glBindBuffer(#GL_ARRAY_BUFFER, Util_TextVBO) 
  
  ; --- BUFFER ORPHANING (Raspberry Pi ARM Only) ---
  CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
    glBufferData(#GL_ARRAY_BUFFER, 24576, #Null, #GL_DYNAMIC_DRAW)
  CompilerEndIf
  
  glBufferSubData(#GL_ARRAY_BUFFER, 0, 96, *Buffer)
  glDrawArrays_(#GL_TRIANGLES, 0, 6)
  glBindVertexArray(0) : FreeMemory(*Buffer)
EndProcedure
; ============================================================================
; HIGH-PERFORMANCE SPRITE BATCHER
; ============================================================================
Global GL_BatchShader.l, GL_BatchVAO.l, GL_BatchVBO.l, GL_BatchTexLoc.l
Global *GL_BatchBuffer, GL_BatchCount.i, GL_MaxBatch.i = 10000
Global GL_CurrentBatchTexture.l

Procedure InitSpriteBatcher()
  Define Vert.s = "#version 140" + #LF$ + "#extension GL_ARB_explicit_attrib_location : enable" + #LF$ + "layout (location = 0) in vec2 pos;" + #LF$ + "layout (location = 1) in vec2 uv;" + #LF$ + "layout (location = 2) in vec4 col;" + #LF$ + "out vec2 TexCoords;" + #LF$ + "out vec4 VertexColor;" + #LF$ + "void main() { gl_Position = vec4(pos.x, pos.y, 0.0, 1.0); TexCoords = uv; VertexColor = col; }"
  
  Define Frag.s = "#version 140" + #LF$ + "in vec2 TexCoords;" + #LF$ + "in vec4 VertexColor;" + #LF$ + "out vec4 color;" + #LF$ + "uniform sampler2D tex;" + #LF$ + "void main() { color = texture(tex, TexCoords) * VertexColor; }"
  GL_BatchShader = Util_CompileProgram(Vert, Frag)
  Define *TexName = UTF8("tex") : GL_BatchTexLoc = glGetUniformLocation(GL_BatchShader, *TexName) : FreeMemory(*TexName)

  glGenVertexArrays(1, @GL_BatchVAO) : glGenBuffers(1, @GL_BatchVBO)
  glBindVertexArray(GL_BatchVAO) : glBindBuffer(#GL_ARRAY_BUFFER, GL_BatchVBO)

  ; Pre-allocate memory for 10,000 sprites (6 verts * 8 floats * 4 bytes = ~1.9 MB)
  *GL_BatchBuffer = AllocateMemory(GL_MaxBatch * 6 * 8 * 4)
  glBufferData(#GL_ARRAY_BUFFER, GL_MaxBatch * 6 * 8 * 4, #Null, #GL_DYNAMIC_DRAW)

  glVertexAttribPointer(0, 2, #GL_FLOAT, #GL_FALSE, 32, 0)  : glEnableVertexAttribArray(0)
  glVertexAttribPointer(1, 2, #GL_FLOAT, #GL_FALSE, 32, 8)  : glEnableVertexAttribArray(1)
  glVertexAttribPointer(2, 4, #GL_FLOAT, #GL_FALSE, 32, 16) : glEnableVertexAttribArray(2)

  glBindVertexArray(0)
EndProcedure

Procedure BeginBatch(*Sprite.GLSprite)
  If Not *Sprite : ProcedureReturn : EndIf
  GL_CurrentBatchTexture = *Sprite\TextureID
  GL_BatchCount = 0
EndProcedure

Procedure AddBatchedSprite(ScreenX.f, ScreenY.f, Width.f, Height.f, AngleRadians.f=0.0, R.f=1.0, G.f=1.0, B.f=1.0, A.f=1.0, IgnoreCamera.b=#False)
  If GL_BatchCount >= GL_MaxBatch : ProcedureReturn : EndIf

  Define TW.f = Util_WinWidth, TH.f = Util_WinHeight

  ; Apply Camera Math dynamically
  If Not IgnoreCamera
    Define CamCenterX.f = TW / 2.0, CamCenterY.f = TH / 2.0
    ScreenX = CamCenterX + ((ScreenX - GL_CameraX - CamCenterX) * GL_CameraZoom)
    ScreenY = CamCenterY + ((ScreenY - GL_CameraY - CamCenterY) * GL_CameraZoom)
    Width * GL_CameraZoom : Height * GL_CameraZoom
  EndIf

  Define HalfW.f = Width / 2.0, HalfH.f = Height / 2.0
  Define TL_x.f = -HalfW, TL_y.f = -HalfH, TR_x.f = HalfW, TR_y.f = -HalfH
  Define BL_x.f = -HalfW, BL_y.f = HalfH,  BR_x.f = HalfW, BR_y.f = HalfH

  Define CosA.f = Cos(AngleRadians), SinA.f = Sin(AngleRadians)
  Define CenterX.f = ScreenX + HalfW, CenterY.f = ScreenY + HalfH

  Define Rot_TL_x.f = CenterX + (TL_x * CosA - TL_y * SinA), Rot_TL_y.f = CenterY + (TL_x * SinA + TL_y * CosA)
  Define Rot_TR_x.f = CenterX + (TR_x * CosA - TR_y * SinA), Rot_TR_y.f = CenterY + (TR_x * SinA + TR_y * CosA)
  Define Rot_BL_x.f = CenterX + (BL_x * CosA - BL_y * SinA), Rot_BL_y.f = CenterY + (BL_x * SinA + BL_y * CosA)
  Define Rot_BR_x.f = CenterX + (BR_x * CosA - BR_y * SinA), Rot_BR_y.f = CenterY + (BR_x * SinA + BR_y * CosA)

  Define nx1.f = (Rot_TL_x / TW) * 2.0 - 1.0, ny1.f = 1.0 - (Rot_TL_y / TH) * 2.0
  Define nx2.f = (Rot_TR_x / TW) * 2.0 - 1.0, ny2.f = 1.0 - (Rot_TR_y / TH) * 2.0
  Define nx3.f = (Rot_BL_x / TW) * 2.0 - 1.0, ny3.f = 1.0 - (Rot_BL_y / TH) * 2.0
  Define nx4.f = (Rot_BR_x / TW) * 2.0 - 1.0, ny4.f = 1.0 - (Rot_BR_y / TH) * 2.0

  Define V_Top.f = 1.0, V_Bottom.f = 0.0
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    V_Top = 0.0 : V_Bottom = 1.0
  CompilerEndIf

  ; Direct Pointer Math injection for maximum speed
  Define *Ptr.Float = *GL_BatchBuffer + (GL_BatchCount * 192)

  *Ptr\f = nx1: *Ptr+4: *Ptr\f = ny1: *Ptr+4: *Ptr\f = 0.0: *Ptr+4: *Ptr\f = V_Top: *Ptr+4: *Ptr\f = R: *Ptr+4: *Ptr\f = G: *Ptr+4: *Ptr\f = B: *Ptr+4: *Ptr\f = A: *Ptr+4
  *Ptr\f = nx3: *Ptr+4: *Ptr\f = ny3: *Ptr+4: *Ptr\f = 0.0: *Ptr+4: *Ptr\f = V_Bottom: *Ptr+4: *Ptr\f = R: *Ptr+4: *Ptr\f = G: *Ptr+4: *Ptr\f = B: *Ptr+4: *Ptr\f = A: *Ptr+4
  *Ptr\f = nx2: *Ptr+4: *Ptr\f = ny2: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = V_Top: *Ptr+4: *Ptr\f = R: *Ptr+4: *Ptr\f = G: *Ptr+4: *Ptr\f = B: *Ptr+4: *Ptr\f = A: *Ptr+4

  *Ptr\f = nx3: *Ptr+4: *Ptr\f = ny3: *Ptr+4: *Ptr\f = 0.0: *Ptr+4: *Ptr\f = V_Bottom: *Ptr+4: *Ptr\f = R: *Ptr+4: *Ptr\f = G: *Ptr+4: *Ptr\f = B: *Ptr+4: *Ptr\f = A: *Ptr+4
  *Ptr\f = nx4: *Ptr+4: *Ptr\f = ny4: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = V_Bottom: *Ptr+4: *Ptr\f = R: *Ptr+4: *Ptr\f = G: *Ptr+4: *Ptr\f = B: *Ptr+4: *Ptr\f = A: *Ptr+4
  *Ptr\f = nx2: *Ptr+4: *Ptr\f = ny2: *Ptr+4: *Ptr\f = 1.0: *Ptr+4: *Ptr\f = V_Top: *Ptr+4: *Ptr\f = R: *Ptr+4: *Ptr\f = G: *Ptr+4: *Ptr\f = B: *Ptr+4: *Ptr\f = A: *Ptr+4

  GL_BatchCount + 1
EndProcedure

Procedure EndBatch()
  If GL_BatchCount = 0 : ProcedureReturn : EndIf

  glUseProgram(GL_BatchShader)
  glActiveTexture(#GL_TEXTURE0)
  glBindTexture_(#GL_TEXTURE_2D, GL_CurrentBatchTexture)
  glUniform1i(GL_BatchTexLoc, 0)

  glBindVertexArray(GL_BatchVAO)
  glBindBuffer(#GL_ARRAY_BUFFER, GL_BatchVBO)

  ; --- BUFFER ORPHANING (Raspberry Pi ARM Only) ---
  CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
    glBufferData(#GL_ARRAY_BUFFER, GL_MaxBatch * 6 * 8 * 4, #Null, #GL_DYNAMIC_DRAW)
  CompilerEndIf

  glBufferSubData(#GL_ARRAY_BUFFER, 0, GL_BatchCount * 192, *GL_BatchBuffer)
  ; Draw the massive array in a single GPU call
  glDrawArrays_(#GL_TRIANGLES, 0, GL_BatchCount * 6)

  glBindVertexArray(0)
EndProcedure
; ============================================================================
; HARDWARE INSTANCED PARTICLE ENGINE (10,000+ Perfect Circles)
; ============================================================================
Structure InstancedParticle
  X.f : Y.f
  Size.f : Angle.f
  R.f : G.f : B.f : A.f
EndStructure

#MAX_PARTICLES = 10000
Global Dim GL_Particles.InstancedParticle(#MAX_PARTICLES)
Global GL_ParticleCount.i = 0

Global GL_PartShader.l, GL_PartVAO.l, GL_PartQuadVBO.l, GL_PartDataVBO.l
Global GL_PartLoc_Screen.l, GL_PartLoc_Cam.l

Procedure InitParticleEngine()
  ; The Vertex Shader does ALL the heavy lifting for 10,000 particles simultaneously
  Define Vert.s = "#version 140" + #LF$ + "#extension GL_ARB_explicit_attrib_location : enable" + #LF$ + "layout (location = 0) in vec2 quad;" + #LF$ + "layout (location = 1) in vec4 transform;" + #LF$ + "layout (location = 2) in vec4 color;" + #LF$ + "out vec4 PartColor; out vec2 LocalPos;" + #LF$ + "uniform vec2 screenSize; uniform vec3 cam;" + #LF$ + "void main() {" + #LF$ + "  LocalPos = quad;" + #LF$ + "  float s = sin(transform.w), c = cos(transform.w);" + #LF$ + "  vec2 scaled = quad * transform.z;" + #LF$ + "  vec2 rotated = vec2(scaled.x * c - scaled.y * s, scaled.x * s + scaled.y * c);" + #LF$ + "  vec2 worldPos = rotated + transform.xy;" + #LF$ + "  vec2 center = screenSize / 2.0;" + #LF$ + "  vec2 screenPos = center + ((worldPos - cam.xy - center) * cam.z);" + #LF$ + "  vec2 ndc = (screenPos / screenSize) * 2.0 - 1.0;" + #LF$ + "  gl_Position = vec4(ndc.x, -ndc.y, 0.0, 1.0);" + #LF$ + "  PartColor = color;" + #LF$ + "}"

  Define Frag.s = "#version 140" + #LF$ + "in vec4 PartColor; in vec2 LocalPos; out vec4 FragColor;" + #LF$ + "void main() {" + #LF$ + "  float dist = length(LocalPos);" + #LF$ + "  if(dist > 1.0) discard;" + #LF$ + "  float alpha = smoothstep(1.0, 0.8, dist);" + #LF$ + "  FragColor = vec4(PartColor.rgb, PartColor.a * alpha);" + #LF$ + "}"

  GL_PartShader = Util_CompileProgram(Vert, Frag)
  Define *SName = UTF8("screenSize") : GL_PartLoc_Screen = glGetUniformLocation(GL_PartShader, *SName) : FreeMemory(*SName)
  Define *CName = UTF8("cam") : GL_PartLoc_Cam = glGetUniformLocation(GL_PartShader, *CName) : FreeMemory(*CName)

  glGenVertexArrays(1, @GL_PartVAO)
  glBindVertexArray(GL_PartVAO)

  ; 1. Base Quad Geometry (A simple 1x1 square centered at 0,0)
  glGenBuffers(1, @GL_PartQuadVBO)
  glBindBuffer(#GL_ARRAY_BUFFER, GL_PartQuadVBO)
  Define *Quad = AllocateMemory(12 * 4), *QPtr.Float = *Quad
  *QPtr\f=-0.5:*QPtr+4:*QPtr\f=-0.5:*QPtr+4:*QPtr\f=0.5:*QPtr+4:*QPtr\f=-0.5:*QPtr+4:*QPtr\f=-0.5:*QPtr+4:*QPtr\f=0.5:*QPtr+4
  *QPtr\f=-0.5:*QPtr+4:*QPtr\f=0.5:*QPtr+4:*QPtr\f=0.5:*QPtr+4:*QPtr\f=-0.5:*QPtr+4:*QPtr\f=0.5:*QPtr+4:*QPtr\f=0.5:*QPtr+4
  glBufferData(#GL_ARRAY_BUFFER, 48, *Quad, #GL_STATIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 2, #GL_FLOAT, #GL_FALSE, 8, 0)
  FreeMemory(*Quad)

  ; 2. The Instanced Data Buffer (Dynamic)
  glGenBuffers(1, @GL_PartDataVBO)
  glBindBuffer(#GL_ARRAY_BUFFER, GL_PartDataVBO)
  glBufferData(#GL_ARRAY_BUFFER, #MAX_PARTICLES * SizeOf(InstancedParticle), #Null, #GL_DYNAMIC_DRAW)
  
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 4, #GL_FLOAT, #GL_FALSE, SizeOf(InstancedParticle), 0)
  glVertexAttribDivisor(1, 1) ; Tell the GPU to advance this every 1 instance!

  glEnableVertexAttribArray(2)
  glVertexAttribPointer(2, 4, #GL_FLOAT, #GL_FALSE, SizeOf(InstancedParticle), 16)
  glVertexAttribDivisor(2, 1) ; Tell the GPU to advance this every 1 instance!

  glBindVertexArray(0)
EndProcedure

Procedure ClearParticles()
  GL_ParticleCount = 0
EndProcedure

Procedure AddParticle(X.f, Y.f, Size.f, Angle.f, R.f, G.f, B.f, A.f)
  If GL_ParticleCount >= #MAX_PARTICLES : ProcedureReturn : EndIf
  GL_Particles(GL_ParticleCount)\X = X
  GL_Particles(GL_ParticleCount)\Y = Y
  GL_Particles(GL_ParticleCount)\Size = Size
  GL_Particles(GL_ParticleCount)\Angle = Angle
  GL_Particles(GL_ParticleCount)\R = R
  GL_Particles(GL_ParticleCount)\G = G
  GL_Particles(GL_ParticleCount)\B = B
  GL_Particles(GL_ParticleCount)\A = A
  GL_ParticleCount + 1
EndProcedure

Procedure RenderParticles()
  If GL_ParticleCount = 0 : ProcedureReturn : EndIf
  
  glUseProgram(GL_PartShader)
  glUniform2f(GL_PartLoc_Screen, Util_WinWidth, Util_WinHeight)
  glUniform3f(GL_PartLoc_Cam, GL_CameraX, GL_CameraY, GL_CameraZoom)

  glBindVertexArray(GL_PartVAO)
  glBindBuffer(#GL_ARRAY_BUFFER, GL_PartDataVBO)
  
  ; --- BUFFER ORPHANING (Raspberry Pi ARM Only) ---
  CompilerIf #PB_Compiler_Processor = #PB_Processor_Arm64 Or #PB_Compiler_Processor = #PB_Processor_Arm32
    glBufferData(#GL_ARRAY_BUFFER, #MAX_PARTICLES * SizeOf(InstancedParticle), #Null, #GL_DYNAMIC_DRAW)
  CompilerEndIf
  
  glBufferSubData(#GL_ARRAY_BUFFER, 0, GL_ParticleCount * SizeOf(InstancedParticle), @GL_Particles(0))
  ; Draw the 6 vertices of the quad multiplied by the number of particles!
  glDrawArraysInstanced(#GL_TRIANGLES, 0, 6, GL_ParticleCount)
  
  glBindVertexArray(0)
EndProcedure

; ============================================================================
; 5. SPLINES & RAYCASTING
; ============================================================================

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 366
; FirstLine = 337
; Folding = ----
; EnableXP
; DPIAware