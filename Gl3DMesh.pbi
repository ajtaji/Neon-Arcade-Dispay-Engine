; Static unskinned geometry for applications that generate their own meshes.
; Each vertex contains position.xyz followed by normal.xyz; count is vertices.
; Updates replace a model's single stream and reuse its VAO and GPU buffer.
Procedure.i G3D_Mesh(*vertices,count.i,*material.G3DMaterial,*m.G3DModel=0)
  Protected *p.G3DPrimitive,oldVAO.l,oldBuffer.l,created.i,i.i
  If Not *vertices Or Not *material Or count<3 Or count%3 Or count>4000000 Or Not g3dGL()
    ProcedureReturn g3dFail("Invalid procedural triangle stream.")
  EndIf
  If *m
    If *m\context<>*GL_CurrentContext Or Not *m\procedural : ProcedureReturn g3dFail("Wrong procedural model or GL context.") : EndIf
    FirstElement(*m\primitives()) : *p=@*m\primitives()
  Else
    *m=AllocateStructure(G3DModel)
    If Not *m : ProcedureReturn g3dFail("Cannot allocate procedural model.") : EndIf
    created=1 : *m\procedural=1 : *m\context=*GL_CurrentContext
    *p=AddElement(*m\primitives())
    G3D_Identity(@*m\transform) : G3D_Identity(@*m\nodes(0)\world)
    *m\nodes(0)\skin=-1
    glGenVertexArrays(1,@*p\vao) : glGenBuffers(1,@*p\vbo)
  EndIf
  glGetIntegerv_(#GL_VERTEX_ARRAY_BINDING,@oldVAO) : glGetIntegerv_(#GL_ARRAY_BUFFER_BINDING,@oldBuffer)
  glBindVertexArray(*p\vao) : glBindBuffer(#GL_ARRAY_BUFFER,*p\vbo)
  glBufferData(#GL_ARRAY_BUFFER,count*24,*vertices,#GL_DYNAMIC_DRAW)
  If created
    For i=0 To 1
      glVertexAttribPointer(i,3,#GL_FLOAT,0,24,i*12) : glEnableVertexAttribArray(i)
    Next
  EndIf
  glBindVertexArray(oldVAO) : glBindBuffer(#GL_ARRAY_BUFFER,oldBuffer)
  If Not *p\vao Or Not *p\vbo Or glGetError_()
    If created : G3D_Free(*m) : EndIf
    ProcedureReturn g3dFail("Cannot upload procedural mesh.")
  EndIf
  CopyMemory(*material,@*m\materials(0),SizeOf(G3DMaterial))
  *p\count=count : *m\vertices=count
  ProcedureReturn *m
EndProcedure
