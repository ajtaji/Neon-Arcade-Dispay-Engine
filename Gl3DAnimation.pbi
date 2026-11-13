Enumeration
  #G3D_Translation
  #G3D_Rotation
  #G3D_Scale
EndEnumeration

Enumeration
  #G3D_Linear
  #G3D_Step
  #G3D_Cubic
EndEnumeration

Procedure.i g3dReadClips(*r.G3DReader,*m.G3DModel)
  Protected clips.i=g3dMember(*r\root,"animations"), channels.i,samplers.i,animation.i,kind.s
  Protected i.i,j.i,k.i,l.i,node.i,channel.i,target.i,sample.i,width.i,lanes.i,mode.i,last.f,length.f
  Protected times.G3DAccess,values.G3DAccess,*clip.G3DClip,*track.G3DTrack
  For i=0 To g3dCount(clips)-1
    animation=g3dAt(clips,i) : *clip=AddElement(*m\clips())
    *clip\name=g3dString(animation,"name")
    If *clip\name="" : *clip\name="clip-"+Str(i) : EndIf
    channels=g3dMember(animation,"channels") : samplers=g3dMember(animation,"samplers")
    For j=0 To g3dCount(channels)-1
      channel=g3dAt(channels,j) : target=g3dMember(channel,"target")
      node=g3dInt(target,"node")
      If node<0 Or node>ArraySize(*m\nodes()) Or *m\nodes(node)\hasMatrix : ProcedureReturn g3dFail("Invalid animation target node.") : EndIf
      *track=AddElement(*clip\tracks()) : *track\node=node
      kind=g3dString(target,"path") : width=3
      Select kind
        Case "translation" : *track\path=#G3D_Translation
        Case "rotation" : *track\path=#G3D_Rotation : width=4
        Case "scale" : *track\path=#G3D_Scale
        Default : ProcedureReturn g3dFail("Unsupported animation target path.")
      EndSelect
      sample=g3dAt(samplers,g3dInt(channel,"sampler"))
      kind=g3dString(sample,"interpolation") : lanes=1
      Select kind
        Case "","LINEAR" : mode=#G3D_Linear
        Case "STEP" : mode=#G3D_Step
        Case "CUBICSPLINE" : mode=#G3D_Cubic : lanes=3
        Default : ProcedureReturn g3dFail("Invalid animation interpolation.")
      EndSelect
      If Not g3dAccess(*r,g3dInt(sample,"input"),@times,"SCALAR") Or times\component<>5126 Or times\count>100000 Or Not g3dAccess(*r,g3dInt(sample,"output"),@values,"VEC"+Str(width)) Or values\component<>5126 Or values\count<>times\count*lanes
        ProcedureReturn g3dFail("Invalid animation sampler accessors.")
      EndIf
      *track\count=times\count : *track\width=width : *track\mode=mode
      ReDim *track\times(times\count-1) : ReDim *track\values(values\count*width-1)
      last=-1
      For k=0 To times\count-1
        *track\times(k)=g3dValue(@times,k,0)
        If Not g3dFloatValid(*track\times(k)) Or *track\times(k)<0 Or *track\times(k)<=last
          ProcedureReturn g3dFail("Animation timestamps must increase.")
        EndIf
        last=*track\times(k)
      Next
      If last>*clip\duration : *clip\duration=last : EndIf
      For k=0 To values\count-1
        length=0
        For l=0 To width-1
          *track\values(k*width+l)=g3dValue(@values,k,l)
          If Not g3dFloatValid(*track\values(k*width+l)) : ProcedureReturn g3dFail("Nonfinite animation value.") : EndIf
          length+*track\values(k*width+l)* *track\values(k*width+l)
        Next
        If width=4 And (lanes=1 Or k%3=1)
          If Abs(length-1)>0.02 : ProcedureReturn g3dFail("Invalid animation quaternion.") : EndIf
          length=Sqr(length)
          For l=0 To 3 : *track\values(k*width+l)/length : Next
        EndIf
      Next
    Next
  Next
  ProcedureReturn 1
EndProcedure

Procedure g3dSample(*t.G3DTrack,time.f,*out)
  Protected lo.i,hi.i=*t\count-1,mid.i,w.i=*t\width,start.i,last.i,j.i
  Protected u.f,v.f,dt.f,u2.f,u3.f,length.f
  If time<=*t\times(0)
    hi=0
  ElseIf time>=*t\times(hi)
    lo=hi
  Else
    While hi-lo>1
      mid=(hi+lo)/2
      If *t\times(mid)>time : hi=mid : Else : lo=mid : EndIf
    Wend
  EndIf
  start=lo*w : last=hi*w
  If *t\mode=#G3D_Cubic : start=start*3+w : last=last*3+w : EndIf
  If hi=lo Or *t\mode=#G3D_Step
    CopyMemory(@*t\values(start),*out,w*4)
    ProcedureReturn
  EndIf
  dt=*t\times(hi)-*t\times(lo) : u=(time-*t\times(lo))/dt
  If *t\mode=#G3D_Cubic
    u2=u*u : u3=u2*u
    For j=0 To w-1
      v=(2*u3-3*u2+1)* *t\values(start+j)+(u3-2*u2+u)*dt* *t\values(start+w+j)
      v+(-2*u3+3*u2)* *t\values(last+j)+(u3-u2)*dt* *t\values(last-w+j)
      PokeF(*out+j*4,v) : length+v*v
    Next
    If w=4
      If length>0.00000001
        length=Sqr(length)
        For j=0 To 3 : PokeF(*out+j*4,PeekF(*out+j*4)/length) : Next
      Else
        CopyMemory(@*t\values(start),*out,16)
      EndIf
    EndIf
  ElseIf w=4
    g3dSlerp(@*t\values(start),@*t\values(last),u,*out)
  Else
    For j=0 To w-1 : PokeF(*out+j*4,*t\values(start+j)+( *t\values(last+j)-*t\values(start+j))*u) : Next
  EndIf
EndProcedure

Procedure g3dApplyClip(*m.G3DModel,*clip.G3DClip,time.f,offset.i)
  Protected *t.G3DTrack,*pose.G3DPose
  ForEach *clip\tracks()
    *t=@*clip\tracks() : *pose=@*m\nodes(*t\node)+offset
    Select *t\path
      Case #G3D_Translation : g3dSample(*t,time,@*pose\p[0])
      Case #G3D_Rotation : g3dSample(*t,time,@*pose\q[0])
      Case #G3D_Scale : g3dSample(*t,time,@*pose\s[0])
    EndSelect
  Next
EndProcedure

Procedure.f g3dClipTime(*clip.G3DClip,time.f,seconds.f)
  If *clip\duration>0 : ProcedureReturn Mod(time+seconds,*clip\duration) : EndIf
  ProcedureReturn 0
EndProcedure

Procedure g3dPose(*m.G3DModel,seconds.f)
  Protected i.i,j.i,*n.G3DNode,*clip.G3DClip=*m\active,a.f
  For i=0 To ArraySize(*m\nodes())
    *n=@*m\nodes(i)
    CopyMemory(@*n\rest,@*n\pose,SizeOf(G3DPose))
    If *m\outgoing : CopyMemory(@*n\rest,@*n\fadePose,SizeOf(G3DPose)) : EndIf
  Next
  If *clip
    *m\time=g3dClipTime(*clip,*m\time,seconds)
    g3dApplyClip(*m,*clip,*m\time,OffsetOf(G3DNode\pose))
  EndIf
  If *m\fade<=0 : ProcedureReturn : EndIf
  *m\fadeTime+seconds : a=*m\fadeTime / *m\fade
  If a>=1
    *m\fade=0 : *m\outgoing=0
    ProcedureReturn
  EndIf
  If *m\outgoing
    *m\outgoingTime=g3dClipTime(*m\outgoing,*m\outgoingTime,seconds)
    g3dApplyClip(*m,*m\outgoing,*m\outgoingTime,OffsetOf(G3DNode\fadePose))
  EndIf
  For i=0 To ArraySize(*m\nodes())
    *n=@*m\nodes(i)
    For j=0 To 2
      *n\pose\p[j]=*n\fadePose\p[j]+(*n\pose\p[j]-*n\fadePose\p[j])*a
      *n\pose\s[j]=*n\fadePose\s[j]+(*n\pose\s[j]-*n\fadePose\s[j])*a
    Next
    g3dSlerp(@*n\fadePose\q[0],@*n\pose\q[0],a,@*n\pose\q[0])
  Next
EndProcedure

Procedure.i G3D_Play(*m.G3DModel,clip.s,blend.f=0.2)
  Protected i.i
  If Not *m Or Not g3dFloatValid(blend) Or blend<0 : ProcedureReturn g3dFail("Invalid animation playback request.") : EndIf
  ForEach *m\clips()
    If *m\clips()\name=clip
      For i=0 To ArraySize(*m\nodes())
        CopyMemory(@*m\nodes(i)\pose,@*m\nodes(i)\fadePose,SizeOf(G3DPose))
      Next
      *m\outgoing=0
      If blend>0 And *m\fade=0
        *m\outgoing=*m\active : *m\outgoingTime=*m\time
      EndIf
      *m\active=@*m\clips() : *m\time=0 : *m\fade=blend : *m\fadeTime=0
      g3dPose(*m,0)
      ProcedureReturn 1
    EndIf
  Next
  ProcedureReturn g3dFail("Animation clip not found: "+clip)
EndProcedure

Procedure.i G3D_Spring(*m.G3DModel,bone.s,stiffness.f=60,damping.f=12,gravity.f=1.1)
  Protected i.i
  If Not *m Or stiffness<1 Or stiffness>1000 Or damping<0 Or damping>100 Or Abs(gravity)>100 Or Not g3dFloatValid(stiffness) Or Not g3dFloatValid(damping) Or Not g3dFloatValid(gravity)
    ProcedureReturn g3dFail("Invalid spring parameters.")
  EndIf
  For i=0 To ArraySize(*m\nodes())
    If *m\nodes(i)\name=bone
      If *m\nodes(i)\hasMatrix : ProcedureReturn g3dFail("A spring bone requires a TRS node.") : EndIf
      *m\nodes(i)\spring=1 : *m\nodes(i)\stiffness=stiffness
      *m\nodes(i)\damping=damping : *m\nodes(i)\gravity=gravity
      ProcedureReturn 1
    EndIf
  Next
  ProcedureReturn g3dFail("Spring bone not found: "+bone)
EndProcedure

; Impulse adds a local velocity change in scene units per second.
Procedure G3D_Impulse(*m.G3DModel,x.f,y.f,z.f)
  Protected i.i
  If Not *m Or Not g3dFloatValid(x) Or Not g3dFloatValid(y) Or Not g3dFloatValid(z) : ProcedureReturn : EndIf
  For i=0 To ArraySize(*m\nodes())
    If *m\nodes(i)\spring
      *m\nodes(i)\velocity[0]+x : *m\nodes(i)\velocity[1]+y : *m\nodes(i)\velocity[2]+z
    EndIf
  Next
EndProcedure

Procedure.i G3D_Update(*m.G3DModel,seconds.f)
  Protected i.i,j.i,bone.i,*n.G3DNode,*parent.G3DMatrix,local.G3DMatrix,base.G3DMatrix
  Protected substep.f,left.f,dt.f,target.f,motion.f,force.f,offset.f,speed.f
  If Not *m Or Not g3dFloatValid(seconds) Or seconds<0 : ProcedureReturn g3dFail("Invalid animation step.") : EndIf
  dt=seconds
  If dt>0.1 : dt=0.1 : EndIf
  g3dPose(*m,dt)
  For bone=0 To ArraySize(*m\order())
    i=*m\order(bone) : *n=@*m\nodes(i)
    If *n\hasMatrix : CopyMemory(@*n\local,@local,SizeOf(G3DMatrix)) : Else : g3dPoseMatrix(@*n\pose,@local) : EndIf
    *parent=0
    If *n\parent>=0
      *parent=@*m\nodes(*n\parent)\world
      g3dMul(*parent,@local,@base)
    Else
      CopyMemory(@local,@base,SizeOf(G3DMatrix))
    EndIf
    If *n\spring
      For j=0 To 2
        force=0
        target=base\v[12+j]
        If dt>0
          If *n\springStarted
            motion=(target-*n\lastTarget[j])/dt
            force=-(motion-*n\lastMotion[j])/dt*0.035
            If force>40 : force=40 : ElseIf force<-40 : force=-40 : EndIf
            *n\lastMotion[j]=motion
          EndIf
          *n\lastTarget[j]=target
        EndIf
        If j=1 : force-*n\gravity : EndIf
        offset=*n\offset[j] : speed=*n\velocity[j] : left=dt
        While left>0
          substep=left : If substep>0.008333333 : substep=0.008333333 : EndIf
          speed+(force-*n\stiffness*offset-*n\damping*speed)*substep
          offset+speed*substep
          left-substep
        Wend
        *n\offset[j]=offset : *n\velocity[j]=speed
        base\v[12+j]+offset
      Next
      If dt>0 : *n\springStarted=1 : EndIf
    EndIf
    CopyMemory(@base,@*n\world,SizeOf(G3DMatrix))
  Next
  ProcedureReturn 1
EndProcedure

Procedure.i G3D_Load(path.s)
  Protected *m.G3DModel,r.G3DReader,ok.i,i.i,name.s
  Protected oldVAO.l,oldArray.l,oldTexture.l
  If Not g3dGL() : ProcedureReturn 0 : EndIf
  g3dError=""
  glGetIntegerv_(#GL_VERTEX_ARRAY_BINDING,@oldVAO) : glGetIntegerv_(#GL_ARRAY_BUFFER_BINDING,@oldArray)
  glGetIntegerv_(#GL_TEXTURE_BINDING_2D,@oldTexture)
  If g3dOpen(path,@r)
    *m=AllocateStructure(G3DModel)
    If *m
      *m\context=*GL_CurrentContext
      G3D_Identity(@*m\transform)
      If g3dReadNodes(@r,*m) And g3dReadMaterials(@r,*m) And g3dReadSkins(@r,*m) And g3dReadMeshes(@r,*m) And g3dReadClips(@r,*m)
        For i=0 To ArraySize(*m\nodes())
          name=LCase(*m\nodes(i)\name)
          If Not *m\nodes(i)\hasMatrix And (Left(name,7)="breast." Or Left(name,6)="glute." Or Left(name,5)="bust." Or Left(name,4)="hip.")
            G3D_Spring(*m,*m\nodes(i)\name)
          EndIf
        Next
        G3D_Update(*m,0)
        ok=1
      EndIf
    Else
      g3dFail("Cannot allocate model.")
    EndIf
  EndIf
  If r\json : FreeJSON(r\json) : EndIf
  If r\file : FreeMemory(r\file) : EndIf
  glBindVertexArray(oldVAO) : glBindBuffer(#GL_ARRAY_BUFFER,oldArray)
  glBindTexture_(#GL_TEXTURE_2D,oldTexture)
  If Not ok : G3D_Free(*m) : ProcedureReturn 0 : EndIf
  ProcedureReturn *m
EndProcedure
