; Column-major matrices, glTF quaternion order (x,y,z,w).
Structure G3DMatrix
  v.f[16]
EndStructure

Structure G3DPose
  p.f[3]
  q.f[4]
  s.f[3]
EndStructure

Structure G3DCamera
  viewProjection.G3DMatrix
  eye.f[3]
EndStructure

Procedure G3D_Identity(*m.G3DMatrix)
  FillMemory(*m, SizeOf(G3DMatrix), 0)
  *m\v[0]=1 : *m\v[5]=1 : *m\v[10]=1 : *m\v[15]=1
EndProcedure

Procedure g3dMul(*a.G3DMatrix, *b.G3DMatrix, *out.G3DMatrix)
  Protected m.G3DMatrix, c.i, r.i, k.i
  For c=0 To 3
    For r=0 To 3
      For k=0 To 3
        m\v[c*4+r]+*a\v[k*4+r] * *b\v[c*4+k]
      Next
    Next
  Next
  CopyMemory(@m,*out,SizeOf(G3DMatrix))
EndProcedure

Procedure g3dSlerp(*a.Float,*b.Float,t.f,*out.Float)
  Protected dot.f, a.f, b.f, sign.f=1, angle.f, length.f, i.i
  For i=0 To 3 : dot+PeekF(*a+i*4)*PeekF(*b+i*4) : Next
  If dot<0 : dot=-dot : sign=-1 : EndIf
  a=1-t : b=t
  If dot<0.9995
    angle=ACos(dot)
    a=Sin(a*angle)/Sin(angle) : b=Sin(b*angle)/Sin(angle)
  EndIf
  For i=0 To 3
    angle=a*PeekF(*a+i*4)+sign*b*PeekF(*b+i*4)
    PokeF(*out+i*4,angle) : length+angle*angle
  Next
  If length>0
    length=Sqr(length)
    For i=0 To 3 : PokeF(*out+i*4,PeekF(*out+i*4)/length) : Next
  EndIf
EndProcedure

Procedure g3dPoseMatrix(*pose.G3DPose,*m.G3DMatrix)
  Protected x.f=*pose\q[0], y.f=*pose\q[1], z.f=*pose\q[2], w.f=*pose\q[3]
  G3D_Identity(*m)
  *m\v[0]=(1-2*(y*y+z*z))* *pose\s[0]
  *m\v[1]=2*(x*y+w*z)* *pose\s[0]
  *m\v[2]=2*(x*z-w*y)* *pose\s[0]
  *m\v[4]=2*(x*y-w*z)* *pose\s[1]
  *m\v[5]=(1-2*(x*x+z*z))* *pose\s[1]
  *m\v[6]=2*(y*z+w*x)* *pose\s[1]
  *m\v[8]=2*(x*z+w*y)* *pose\s[2]
  *m\v[9]=2*(y*z-w*x)* *pose\s[2]
  *m\v[10]=(1-2*(x*x+y*y))* *pose\s[2]
  *m\v[12]=*pose\p[0] : *m\v[13]=*pose\p[1] : *m\v[14]=*pose\p[2]
EndProcedure

Procedure G3D_Transform(*m.G3DMatrix,x.f,y.f,z.f,yaw.f,scale.f=1)
  Protected p.G3DPose
  p\p[0]=x : p\p[1]=y : p\p[2]=z
  p\q[1]=Sin(yaw*0.5) : p\q[3]=Cos(yaw*0.5)
  p\s[0]=scale : p\s[1]=scale : p\s[2]=scale
  g3dPoseMatrix(@p,*m)
EndProcedure

; Perspective camera with a Y-up default. Angles are radians and distances use scene units.
Procedure.i G3D_LookAt(*camera.G3DCamera,x.f,y.f,z.f,tx.f,ty.f,tz.f,aspect.f,fov.f=0.85,near.f=0.05,far.f=150,upX.f=0,upY.f=1,upZ.f=0)
  Protected v.G3DMatrix,p.G3DMatrix,fx.f=tx-x,fy.f=ty-y,fz.f=tz-z,sx.f,sy.f,sz.f,ux.f,uy.f,uz.f
  Protected length.f=Sqr(fx*fx+fy*fy+fz*fz),f.f
  If Not *camera Or aspect<=0 Or near<=0 Or far<=near Or fov<=0 Or fov>=#PI Or length<0.00001
    ProcedureReturn #False
  EndIf
  fx/length : fy/length : fz/length
  sx=fy*upZ-fz*upY : sy=fz*upX-fx*upZ : sz=fx*upY-fy*upX
  length=Sqr(sx*sx+sy*sy+sz*sz)
  If length<0.00001 : ProcedureReturn #False : EndIf
  sx/length : sy/length : sz/length
  ux=sy*fz-sz*fy : uy=sz*fx-sx*fz : uz=sx*fy-sy*fx
  G3D_Identity(@v)
  v\v[0]=sx : v\v[4]=sy : v\v[8]=sz : v\v[12]=-(sx*x+sy*y+sz*z)
  v\v[1]=ux : v\v[5]=uy : v\v[9]=uz : v\v[13]=-(ux*x+uy*y+uz*z)
  v\v[2]=-fx : v\v[6]=-fy : v\v[10]=-fz : v\v[14]=fx*x+fy*y+fz*z
  f=1/Tan(fov/2)
  p\v[0]=f/aspect : p\v[5]=f : p\v[10]=(far+near)/(near-far)
  p\v[11]=-1 : p\v[14]=2*far*near/(near-far)
  g3dMul(@p,@v,@*camera\viewProjection)
  *camera\eye[0]=x : *camera\eye[1]=y : *camera\eye[2]=z
  ProcedureReturn #True
EndProcedure
