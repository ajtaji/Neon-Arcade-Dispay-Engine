; Optional desktop OpenGL 3.3 model renderer. Include after GlUtilities.pbi.
XIncludeFile #PB_Compiler_FilePath+"Gl3DMath.pbi"

Structure G3DPrimitive
  vao.l
  vbo.l
  ebo.l
  count.i
  node.i
  material.i
EndStructure

Structure G3DMaterial
  color.f[4]
  emission.f[3]
  metal.f
  rough.f
  twoSided.i
EndStructure

Structure G3DNode
  name.s
  parent.i
  mesh.i
  skin.i
  visible.i
  hasMatrix.i
  rest.G3DPose
  pose.G3DPose
  fadePose.G3DPose
  world.G3DMatrix
  local.G3DMatrix
  spring.i
  stiffness.f
  damping.f
  gravity.f
  offset.f[3]
  velocity.f[3]
  lastTarget.f[3]
  lastMotion.f[3]
  springStarted.i
EndStructure

Structure G3DJoint
  node.i
  inverseBind.G3DMatrix
EndStructure

Structure G3DSkin
  Array joint.G3DJoint(0)
  Array palette.G3DMatrix(0)
  texture.l
EndStructure

Structure G3DTrack
  node.i
  path.i
  mode.i
  width.i
  count.i
  Array times.f(0)
  Array values.f(0)
EndStructure

Structure G3DClip
  name.s
  duration.f
  List tracks.G3DTrack()
EndStructure

Structure G3DModel
  context.i
  transform.G3DMatrix
  Array nodes.G3DNode(0)
  Array order.i(0)
  Array skins.G3DSkin(0)
  Array materials.G3DMaterial(0)
  List primitives.G3DPrimitive()
  List clips.G3DClip()
  *active.G3DClip
  *outgoing.G3DClip
  outgoingTime.f
  time.f
  fade.f
  fadeTime.f
  vertices.i
  procedural.i
EndStructure

Structure G3DPass
  context.i
  fbo.l
  depth.l
  width.i
  height.i
  program.l
  vp.l
  projection.l
  model.l
  viewPos.l
  skin.l
  bones.l
  color.l
  finish.l
  emission.l
  savedProgram.l
  savedVAO.l
  savedActive.l
  savedTexture.l
  savedDepthFunc.l
  savedDepth.a
  savedMask.a
  savedBlend.a
  savedCull.a
  savedScissor.a
EndStructure

Global g3dError.s
Global *g3dPass.G3DPass
Global g3dDeleteProgram.glDeleteProgram, g3dDeleteVAO.glDeleteVertexArrays
Global g3dDeleteBuffer.glDeleteBuffers, g3dAttribInt.glVertexAttribIPointer
Global g3dBindRenderbuffer.glBindRenderbuffer, g3dGenRenderbuffers.glGenRenderbuffers
Global g3dDeleteRenderbuffers.glDeleteRenderbuffers, g3dAttachDepth.glFramebufferRenderbuffer
Global g3dDepthStorage.glRenderbufferStorage
Global g3dUniformMatrix.glUniformMatrix4fv

Procedure.s G3D_Error()
  ProcedureReturn g3dError
EndProcedure

Procedure.i g3dFail(message.s)
  g3dError=message
  ProcedureReturn 0
EndProcedure

Procedure.i g3dGL()
  If Not *GL_CurrentContext Or Not glGenBuffers : ProcedureReturn g3dFail("Select a Neon OpenGL context first.") : EndIf
  g3dDeleteProgram=GetGLProc("glDeleteProgram")
  g3dDeleteVAO=GetGLProc("glDeleteVertexArrays")
  g3dDeleteBuffer=GetGLProc("glDeleteBuffers")
  g3dAttribInt=GetGLProc("glVertexAttribIPointer")
  g3dBindRenderbuffer=GetGLProc("glBindRenderbuffer")
  g3dGenRenderbuffers=GetGLProc("glGenRenderbuffers")
  g3dDeleteRenderbuffers=GetGLProc("glDeleteRenderbuffers")
  g3dAttachDepth=GetGLProc("glFramebufferRenderbuffer")
  g3dDepthStorage=GetGLProc("glRenderbufferStorage")
  g3dUniformMatrix=GetGLProc("glUniformMatrix4fv")
  If Not g3dDeleteProgram Or Not g3dDeleteVAO Or Not g3dDeleteBuffer Or Not g3dAttribInt Or Not g3dBindRenderbuffer Or Not g3dGenRenderbuffers Or Not g3dDeleteRenderbuffers Or Not g3dAttachDepth Or Not g3dDepthStorage Or Not g3dUniformMatrix
    ProcedureReturn g3dFail("Neon 3D requires desktop OpenGL 3.3.")
  EndIf
  ProcedureReturn 1
EndProcedure

Procedure G3D_Free(*m.G3DModel)
  If Not *m : ProcedureReturn : EndIf
  If *m\context And *m\context<>*GL_CurrentContext
    g3dFail("Select the model's OpenGL context before freeing it.")
    ProcedureReturn
  EndIf
  ForEach *m\primitives()
    If *m\primitives()\vao : g3dDeleteVAO(1,@*m\primitives()\vao) : EndIf
    If *m\primitives()\vbo : g3dDeleteBuffer(1,@*m\primitives()\vbo) : EndIf
    If *m\primitives()\ebo : g3dDeleteBuffer(1,@*m\primitives()\ebo) : EndIf
  Next
  Protected i.i
  For i=0 To ArraySize(*m\skins())
    If *m\skins(i)\texture : glDeleteTextures_(1,@*m\skins(i)\texture) : EndIf
  Next
  FreeStructure(*m)
EndProcedure

XIncludeFile #PB_Compiler_FilePath+"Gl3DLoader.pbi"
XIncludeFile #PB_Compiler_FilePath+"Gl3DAnimation.pbi"
XIncludeFile #PB_Compiler_FilePath+"Gl3DRender.pbi"
XIncludeFile #PB_Compiler_FilePath+"Gl3DMesh.pbi"
