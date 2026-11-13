Procedure.l g3dUniform(program.l,name.s)
  Protected *text=UTF8(name), location.l
  If Not *text : ProcedureReturn -1 : EndIf
  location=glGetUniformLocation(program,*text)
  FreeMemory(*text)
  ProcedureReturn location
EndProcedure

; Optional GLSL defines projectVertex(inout vec3 point, inout vec3 normal).
Procedure.i G3D_Init(*pass.G3DPass,geometryProjection.s="")
  Protected oldFbo.l,oldRb.l,version.l,minor.l,attachment.l,complete.i,vs.s,fs.s
  Protected inspectAttachment.glGetFramebufferAttachmentParameteriv
  If Not *pass Or *pass\context Or Not Util_FBO Or Not g3dGL()
    ProcedureReturn g3dFail("Initialize the Neon framebuffer before the 3D pass.")
  EndIf
  glGetIntegerv_(#GL_MAJOR_VERSION,@version) : glGetIntegerv_(#GL_MINOR_VERSION,@minor)
  If version<3 Or (version=3 And minor<3) : ProcedureReturn g3dFail("Neon 3D requires desktop OpenGL 3.3.") : EndIf
  *pass\width=Util_BaseWidth : *pass\height=Util_BaseHeight
  *pass\fbo=Util_FBO
  glGetIntegerv_(#GL_DRAW_FRAMEBUFFER_BINDING,@oldFbo) : glGetIntegerv_(#GL_RENDERBUFFER_BINDING,@oldRb)
  inspectAttachment=GetGLProc("glGetFramebufferAttachmentParameteriv")
  If Not inspectAttachment : ProcedureReturn g3dFail("Missing framebuffer attachment query.") : EndIf
  glBindFramebuffer(#GL_DRAW_FRAMEBUFFER,*pass\fbo)
  inspectAttachment(#GL_DRAW_FRAMEBUFFER,#GL_DEPTH_ATTACHMENT,#GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE,@attachment)
  glBindFramebuffer(#GL_DRAW_FRAMEBUFFER,oldFbo)
  If attachment<>#GL_NONE : ProcedureReturn g3dFail("The Neon framebuffer already has a depth attachment.") : EndIf
  g3dGenRenderbuffers(1,@*pass\depth)
  If Not *pass\depth : ProcedureReturn g3dFail("Cannot allocate the 3D depth attachment.") : EndIf
  g3dBindRenderbuffer(#GL_RENDERBUFFER,*pass\depth)
  g3dDepthStorage(#GL_RENDERBUFFER,#GL_DEPTH_COMPONENT24,*pass\width,*pass\height)
  glBindFramebuffer(#GL_DRAW_FRAMEBUFFER,*pass\fbo)
  g3dAttachDepth(#GL_DRAW_FRAMEBUFFER,#GL_DEPTH_ATTACHMENT,#GL_RENDERBUFFER,*pass\depth)
  complete=Bool(glCheckFramebufferStatus(#GL_DRAW_FRAMEBUFFER)=#GL_FRAMEBUFFER_COMPLETE And glGetError_()=0)
  If Not complete
    g3dAttachDepth(#GL_DRAW_FRAMEBUFFER,#GL_DEPTH_ATTACHMENT,#GL_RENDERBUFFER,0)
    g3dDeleteRenderbuffers(1,@*pass\depth) : *pass\depth=0
  EndIf
  glBindFramebuffer(#GL_DRAW_FRAMEBUFFER,oldFbo) : g3dBindRenderbuffer(#GL_RENDERBUFFER,oldRb)
  If Not complete : ProcedureReturn g3dFail("The Neon framebuffer could not accept a depth attachment.") : EndIf
  vs="#version 330 core"+#LF$+
     "layout(location=0) in vec3 pos; layout(location=1) in vec3 normal;"+#LF$+
     "layout(location=2) in uvec4 joints; layout(location=3) in vec4 weights;"+#LF$+
     "uniform mat4 vp, model; uniform sampler2D bones; uniform int skinned;"+#LF$+
     "out vec3 worldPos, worldNormal; uniform vec4 projectionParams;"+#LF$+
     geometryProjection+#LF$+
     "mat4 joint(uint i){ int n=int(i); return mat4(texelFetch(bones,ivec2(0,n),0),texelFetch(bones,ivec2(1,n),0),texelFetch(bones,ivec2(2,n),0),texelFetch(bones,ivec2(3,n),0)); }"+#LF$+
     "void main(){ mat4 m=model; if(skinned!=0) m*=joint(joints.x)*weights.x+joint(joints.y)*weights.y+joint(joints.z)*weights.z+joint(joints.w)*weights.w;"+#LF$+
     " vec3 point=pos, norm=normal;"
  If geometryProjection<>"" : vs+" projectVertex(point,norm);" : EndIf
  vs+" vec4 p=m*vec4(point,1); worldPos=p.xyz; worldNormal=transpose(inverse(mat3(m)))*norm; gl_Position=vp*p; }"
  fs="#version 330 core"+#LF$+
     "in vec3 worldPos, worldNormal; out vec4 pixel; uniform vec4 color, finish, emission, eye;"+#LF$+
     "vec3 studio(vec3 r,float rough){ float sky=smoothstep(-0.1,0.65,r.y);"+#LF$+
     " vec3 env=mix(vec3(0.026,0.029,0.045),vec3(.28,.39,.61),sky);"+#LF$+
     " float spread=mix(100.0,4.0,rough*rough);"+#LF$+
     " env+=vec3(1.40,1.64,2.08)*pow(max(dot(r,normalize(vec3(-.7,.6,.5))),0.0),spread*.32);"+#LF$+
     " env+=vec3(2.7,1.35,.47)*pow(max(dot(r,normalize(vec3(.8,.45,.34))),0.0),spread*.52);"+#LF$+
     " env+=vec3(.52,.72,1.25)*pow(max(dot(r,normalize(vec3(.07,.25,-1))),0.0),spread*.18); return env; }"+#LF$+
     "void main(){ vec3 n=normalize(worldNormal); if(!gl_FrontFacing) n=-n; vec3 v=normalize(eye.xyz-worldPos);"+#LF$+
     " float metal=clamp(finish.x,0,1), rough=clamp(finish.y,.035,1);"+#LF$+
     " vec3 f0=mix(vec3(.045),color.rgb,metal); vec3 f=f0+(1-f0)*pow(1-max(dot(n,v),0.0),5.0);"+#LF$+
     " vec3 lit=color.rgb*(1-metal)*(.12+.72*max(dot(n,normalize(vec3(-.55,.8,.55))),0.0));"+#LF$+
     " lit+=studio(reflect(-v,n),rough)*f+emission.rgb; lit=lit/(lit+vec3(.8)); pixel=vec4(pow(max(lit,0),vec3(1.0/2.2)),1); }"
  *pass\program=Util_CompileProgram(vs,fs)
  *pass\projection=g3dUniform(*pass\program,"projectionParams")
  *pass\vp=g3dUniform(*pass\program,"vp") : *pass\model=g3dUniform(*pass\program,"model")
  *pass\viewPos=g3dUniform(*pass\program,"eye") : *pass\skin=g3dUniform(*pass\program,"skinned")
  *pass\bones=g3dUniform(*pass\program,"bones") : *pass\color=g3dUniform(*pass\program,"color")
  *pass\finish=g3dUniform(*pass\program,"finish") : *pass\emission=g3dUniform(*pass\program,"emission")
  *pass\context=*GL_CurrentContext
  ProcedureReturn 1
EndProcedure

Procedure.i G3D_Begin(*pass.G3DPass)
  Protected fbo.l
  If Not *pass Or Not *pass\context Or *pass\context<>*GL_CurrentContext Or *g3dPass Or Util_FBO<>*pass\fbo Or Util_BaseWidth<>*pass\width Or Util_BaseHeight<>*pass\height
    ProcedureReturn g3dFail("Invalid 3D pass, context, or canvas size.")
  EndIf
  glGetIntegerv_(#GL_DRAW_FRAMEBUFFER_BINDING,@fbo)
  If fbo<>*pass\fbo : ProcedureReturn g3dFail("Bind the Neon framebuffer before beginning 3D.") : EndIf
  glGetIntegerv_(#GL_CURRENT_PROGRAM,@*pass\savedProgram)
  glGetIntegerv_(#GL_VERTEX_ARRAY_BINDING,@*pass\savedVAO)
  glGetIntegerv_(#GL_ACTIVE_TEXTURE,@*pass\savedActive)
  glActiveTexture(#GL_TEXTURE0)
  glGetIntegerv_(#GL_TEXTURE_BINDING_2D,@*pass\savedTexture)
  glGetIntegerv_(#GL_DEPTH_FUNC,@*pass\savedDepthFunc)
  glGetBooleanv_(#GL_DEPTH_WRITEMASK,@*pass\savedMask)
  *pass\savedDepth=glIsEnabled_(#GL_DEPTH_TEST)
  *pass\savedBlend=glIsEnabled_(#GL_BLEND)
  *pass\savedCull=glIsEnabled_(#GL_CULL_FACE)
  *pass\savedScissor=glIsEnabled_(#GL_SCISSOR_TEST)
  glDisable_(#GL_BLEND) : glDisable_(#GL_SCISSOR_TEST)
  glEnable_(#GL_DEPTH_TEST) : glDepthFunc_(#GL_LESS) : glDepthMask_(#True)
  glClear_(#GL_DEPTH_BUFFER_BIT)
  glUseProgram(*pass\program) : glUniform1i(*pass\bones,0)
  *g3dPass=*pass
  ProcedureReturn 1
EndProcedure

Procedure g3dToggle(cap.l,enabled.i)
  If enabled : glEnable_(cap) : Else : glDisable_(cap) : EndIf
EndProcedure

Procedure G3D_SetProjection(*pass.G3DPass,x.f,y.f,z.f,w.f)
  If Not *pass Or *g3dPass<>*pass Or *pass\projection<0 : ProcedureReturn : EndIf
  glUniform4f(*pass\projection,x,y,z,w)
EndProcedure

Procedure G3D_End()
  Protected *pass.G3DPass=*g3dPass
  If Not *pass Or *pass\context<>*GL_CurrentContext : ProcedureReturn : EndIf
  glBindVertexArray(*pass\savedVAO)
  glBindTexture_(#GL_TEXTURE_2D,*pass\savedTexture)
  glActiveTexture(*pass\savedActive)
  glUseProgram(*pass\savedProgram)
  glDepthFunc_(*pass\savedDepthFunc) : glDepthMask_(*pass\savedMask)
  g3dToggle(#GL_DEPTH_TEST,*pass\savedDepth) : g3dToggle(#GL_BLEND,*pass\savedBlend)
  g3dToggle(#GL_CULL_FACE,*pass\savedCull) : g3dToggle(#GL_SCISSOR_TEST,*pass\savedScissor)
  *g3dPass=0
EndProcedure

Procedure G3D_Shutdown(*pass.G3DPass)
  Protected old.l
  If Not *pass Or Not *pass\context Or *pass\context<>*GL_CurrentContext : ProcedureReturn : EndIf
  If *g3dPass=*pass : G3D_End() : EndIf
  glGetIntegerv_(#GL_DRAW_FRAMEBUFFER_BINDING,@old)
  glBindFramebuffer(#GL_DRAW_FRAMEBUFFER,*pass\fbo)
  g3dAttachDepth(#GL_DRAW_FRAMEBUFFER,#GL_DEPTH_ATTACHMENT,#GL_RENDERBUFFER,0)
  glBindFramebuffer(#GL_DRAW_FRAMEBUFFER,old)
  g3dDeleteRenderbuffers(1,@*pass\depth) : g3dDeleteProgram(*pass\program)
  ClearStructure(*pass,G3DPass)
EndProcedure

Procedure.i G3D_Draw(*m.G3DModel,*camera.G3DCamera)
  Protected *pass.G3DPass=*g3dPass, current.G3DMatrix,*n.G3DNode,*p.G3DPrimitive,*mat.G3DMaterial,*s.G3DSkin
  Protected i.i,j.i,n.i, lastSkin.i=-2
  If Not *pass Or Not *m Or Not *camera Or *pass\context<>*GL_CurrentContext Or *m\context<>*pass\context
    ProcedureReturn g3dFail("Draw requires a camera and a model in the active 3D pass.")
  EndIf
  For i=0 To ArraySize(*m\skins())-1
    *s=@*m\skins(i) : n=ArraySize(*s\joint())+1
    For j=0 To n-1
      g3dMul(@*m\nodes(*s\joint(j)\node)\world,@*s\joint(j)\inverseBind,@*s\palette(j))
    Next
    glBindTexture_(#GL_TEXTURE_2D,*s\texture)
    glTexSubImage2D_(#GL_TEXTURE_2D,0,0,0,4,n,#GL_RGBA,#GL_FLOAT,@*s\palette(0))
    GL_StatBufferUploads+1
  Next
  g3dUniformMatrix(*pass\vp,1,#GL_FALSE,@*camera\viewProjection)
  glUniform4f(*pass\viewPos,*camera\eye[0],*camera\eye[1],*camera\eye[2],1)
  ForEach *m\primitives()
    *p=@*m\primitives() : *n=@*m\nodes(*p\node) : *mat=@*m\materials(*p\material)
    If *n\skin<>lastSkin
      lastSkin=*n\skin
      glUniform1i(*pass\skin,Bool(lastSkin>=0))
      If lastSkin>=0 : glBindTexture_(#GL_TEXTURE_2D,*m\skins(lastSkin)\texture) : EndIf
    EndIf
    If lastSkin>=0
      ; World joint matrices already include the rig hierarchy.
      g3dUniformMatrix(*pass\model,1,#GL_FALSE,@*m\transform)
    Else
      g3dMul(@*m\transform,@*n\world,@current)
      g3dUniformMatrix(*pass\model,1,#GL_FALSE,@current)
    EndIf
    glUniform4f(*pass\color,*mat\color[0],*mat\color[1],*mat\color[2],*mat\color[3])
    glUniform4f(*pass\finish,*mat\metal,*mat\rough,0,0)
    glUniform4f(*pass\emission,*mat\emission[0],*mat\emission[1],*mat\emission[2],0)
    g3dToggle(#GL_CULL_FACE,Bool(Not *mat\twoSided))
    glBindVertexArray(*p\vao)
    If *p\ebo
      glDrawElements_(#GL_TRIANGLES,*p\count,#GL_UNSIGNED_INT,0)
    Else
      glDrawArrays_(#GL_TRIANGLES,0,*p\count)
    EndIf
    GL_StatDrawCalls+1
  Next
  If glGetError_() : ProcedureReturn g3dFail("OpenGL rejected the 3D draw.") : EndIf
  ProcedureReturn 1
EndProcedure
