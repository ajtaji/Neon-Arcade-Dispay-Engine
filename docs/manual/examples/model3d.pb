; model3d.pb - the 3D pass on the canvas: a cube made in code, a glTF model when one is given, a camera
; that circles them, and 2D text drawn over the 3D picture.
; Build:  pbcompiler model3d.pb /EXE model3d.exe /THREAD /DPIAWARE      Run:  model3d [model.glb] [clip]
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"
XIncludeFile #Engine$ + "Gl3D.pbi"

#CanvasW = 960 : #CanvasH = 540

; 36 vertices (12 triangles) of a cube of side 1 about the origin, each vertex x, y, z then its normal.
; A face is its normal N and two axes U, V with U x V = N, so that its corners run counter-clockwise
; seen from outside (OpenGL's front face): N/2 + U*a + V*b for (a, b) = (-,-) (+,-) (+,+) (-,+).
Procedure.i CubeVertices()
  Protected *v = AllocateMemory(36 * 6 * 4), *p.Float = *v, f.i, k.i, j.i, a.f, b.f
  Protected Dim N.f(2), Dim U.f(2), Dim V.f(2)
  Restore Faces
  For f = 0 To 5
    For j = 0 To 2 : Read.f N(j) : Next
    For j = 0 To 2 : Read.f U(j) : Next
    For j = 0 To 2 : Read.f V(j) : Next
    For k = 0 To 5                                  ; triangles 0 1 2 and 0 2 3 of the corners
      Select PeekA(?Corners + k)
        Case 0 : a = -0.5 : b = -0.5
        Case 1 : a = 0.5 : b = -0.5
        Case 2 : a = 0.5 : b = 0.5
        Case 3 : a = -0.5 : b = 0.5
      EndSelect
      For j = 0 To 2 : *p\f = N(j) * 0.5 + U(j) * a + V(j) * b : *p + 4 : Next
      For j = 0 To 2 : *p\f = N(j) : *p + 4 : Next
    Next
  Next
  ProcedureReturn *v
  DataSection
    Corners: : Data.a 0, 1, 2, 0, 2, 3
    Faces:                                          ; N, U, V for +x -x +y -y +z -z
    Data.f 1, 0, 0,  0, 1, 0,  0, 0, 1
    Data.f -1, 0, 0,  0, 0, 1,  0, 1, 0
    Data.f 0, 1, 0,  0, 0, 1,  1, 0, 0
    Data.f 0, -1, 0,  1, 0, 0,  0, 0, 1
    Data.f 0, 0, 1,  1, 0, 0,  0, 1, 0
    Data.f 0, 0, -1,  0, 1, 0,  1, 0, 0
  EndDataSection
EndProcedure

GL_HostPrepare()
#WinFlags = #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget
Define Gadget.i = OpenGLWindow("3D", 960, 540, #WinFlags)
If Gadget = 0 : End 1 : EndIf
Util_BaseWidth = #CanvasW : Util_BaseHeight = #CanvasH
InitRetroCRT(#CanvasW, #CanvasH)                    ; the 3D pass attaches its depth buffer to this canvas
GL_HandleResize(Gadget)
Define Context.GLWindowContext
GL_ContextCapture(@Context)                         ; the 3D module checks that its context is the current one
Define Pass.G3DPass
If Not G3D_Init(@Pass) : MessageRequester("3D", G3D_Error()) : End 1 : EndIf

Define Steel.G3DMaterial
Steel\color[0] = 0.75 : Steel\color[1] = 0.78 : Steel\color[2] = 0.82 : Steel\color[3] = 1
Steel\metal = 1.0 : Steel\rough = 0.3
Define *Verts = CubeVertices()
Define *Cube.G3DModel = G3D_Mesh(*Verts, 36, @Steel)
FreeMemory(*Verts)                                  ; the vertices are on the GPU now
If *Cube = 0 : MessageRequester("3D", G3D_Error()) : End 1 : EndIf

Define *Model.G3DModel
If CountProgramParameters() > 0
  *Model = G3D_Load(ProgramParameter(0))
  If *Model = 0 : MessageRequester("3D", G3D_Error()) : End 1 : EndIf
  If CountProgramParameters() > 1 And Not G3D_Play(*Model, ProgramParameter(1), 0.3) : Debug G3D_Error() : EndIf
EndIf

Define *Font.GLFont = CreateGLFontPx("Segoe UI", 18)
Define Camera.G3DCamera, Quit.i, Event.i, T.f, Last.q = GL_Micros(), Now.q, Dt.f
Repeat
  Repeat
    Event = WindowEvent()
    If Event = #PB_Event_CloseWindow : Quit = #True : EndIf
    If Event = #PB_Event_SizeWindow : GL_HandleResize(Gadget) : EndIf
  Until Event = 0
  Now = GL_Micros() : Dt = (Now - Last) / 1000000.0 : Last = Now : T + Dt
  G3D_LookAt(@Camera, Sin(T * 0.4) * 4, 2, Cos(T * 0.4) * 4, 0, 0.5, 0, #CanvasW / #CanvasH)
  G3D_Transform(@*Cube\transform, 1.2, 0.5, 0, T, 1.0)            ; position, a turn about y, a scale
  If *Model : G3D_Update(*Model, Dt) : EndIf                       ; clips and springs move by the time

  glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
  glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)
  glClearColor_(0.08, 0.09, 0.12, 1.0) : glClear_(#GL_COLOR_BUFFER_BIT)
  If G3D_Begin(@Pass)                                               ; depth test on, depth cleared
    G3D_Draw(*Cube, @Camera)
    If *Model : G3D_Draw(*Model, @Camera) : EndIf
    G3D_End()                                                       ; the 2D state back
  EndIf
  DrawGLText(*Font, 16, 12, "G3D: the cube is G3D_Mesh, the camera G3D_LookAt", 0.9, 0.9, 0.9, 1.0, #True)
  glBindFramebuffer(#GL_FRAMEBUFFER, 0)
  glClearColor_(0, 0, 0, 1) : glClear_(#GL_COLOR_BUFFER_BIT)
  glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
  DrawPassthrough()
  SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)
  Delay(1)
Until Quit
If *Model : G3D_Free(*Model) : EndIf
G3D_Free(*Cube)
G3D_Shutdown(@Pass)
