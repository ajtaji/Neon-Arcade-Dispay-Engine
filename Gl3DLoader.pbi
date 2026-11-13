#G3D_MaxFile = 256*1024*1024
#G3D_MaxNodes = 4096

Structure G3DAccess
  *data
  count.i
  stride.i
  component.i
  width.i
  normalized.i
EndStructure

Structure G3DReader
  json.i
  root.i
  *file
  *bin
  bytes.q
EndStructure

Procedure.i g3dMember(object.i,key.s)
  If object And JSONType(object)=#PB_JSON_Object : ProcedureReturn GetJSONMember(object,key) : EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i g3dCount(array.i)
  If array And JSONType(array)=#PB_JSON_Array : ProcedureReturn JSONArraySize(array) : EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i g3dAt(array.i,index.i)
  If index>=0 And index<g3dCount(array) : ProcedureReturn GetJSONElement(array,index) : EndIf
  ProcedureReturn 0
EndProcedure

Procedure.q g3dInt(object.i,key.s,fallback.q=-1)
  Protected a.i=g3dMember(object,key), v.d
  If Not a : ProcedureReturn fallback : EndIf
  If JSONType(a)<>#PB_JSON_Number : ProcedureReturn -1 : EndIf
  v=GetJSONDouble(a)
  If v<-2147483648 Or v>4294967295 Or v<>Int(v) : ProcedureReturn -1 : EndIf
  ProcedureReturn Int(v)
EndProcedure

Procedure.s g3dString(object.i,key.s)
  Protected a.i=g3dMember(object,key)
  If a And JSONType(a)=#PB_JSON_String : ProcedureReturn GetJSONString(a) : EndIf
  ProcedureReturn ""
EndProcedure

Procedure.f g3dNumber(object.i,key.s,fallback.f)
  Protected a.i=g3dMember(object,key)
  If a And JSONType(a)=#PB_JSON_Number : ProcedureReturn GetJSONFloat(a) : EndIf
  ProcedureReturn fallback
EndProcedure

Procedure.i g3dFloatValid(x.f)
  ProcedureReturn Bool((PeekL(@x)&$7F800000)<>$7F800000)
EndProcedure

Procedure.i g3dFloats(a.i,*out,n.i)
  Protected i.i,item.i,x.f
  If Not a : ProcedureReturn 1 : EndIf
  If g3dCount(a)<>n : ProcedureReturn 0 : EndIf
  For i=0 To n-1
    item=g3dAt(a,i)
    If JSONType(item)<>#PB_JSON_Number : ProcedureReturn 0 : EndIf
    x=GetJSONFloat(item)
    If Not g3dFloatValid(x) : ProcedureReturn 0 : EndIf
    PokeF(*out+i*4,x)
  Next
  ProcedureReturn 1
EndProcedure

Procedure.i g3dOpen(path.s,*r.G3DReader)
  Protected file.i, size.q, jsonBytes.q, offset.q, length.q, kind.l, jsonAt.q
  size=FileSize(path)
  If size<28 Or size>#G3D_MaxFile : ProcedureReturn g3dFail("GLB file size is outside the supported range.") : EndIf
  file=ReadFile(#PB_Any,path)
  If Not file : ProcedureReturn g3dFail("Cannot open "+path) : EndIf
  *r\file=AllocateMemory(size,#PB_Memory_NoClear)
  If *r\file And ReadData(file,*r\file,size)<>size
    FreeMemory(*r\file) : *r\file=0
  EndIf
  CloseFile(file)
  If Not *r\file : ProcedureReturn g3dFail("Cannot read GLB.") : EndIf
  If PeekL(*r\file)<>$46546C67 Or PeekL(*r\file+4)<>2 Or (PeekL(*r\file+8)&$FFFFFFFF)<>size
    ProcedureReturn g3dFail("Expected a glTF 2.0 binary container (.glb).")
  EndIf
  offset=12
  While offset+8<=size
    length=PeekL(*r\file+offset)&$FFFFFFFF
    kind=PeekL(*r\file+offset+4)
    If length&3 Or length>size-offset-8 : ProcedureReturn g3dFail("Invalid GLB chunk length.") : EndIf
    offset+8
    Select kind
      Case $4E4F534A
        If offset<>20 Or length=0 : ProcedureReturn g3dFail("Invalid GLB JSON chunk.") : EndIf
        jsonAt=offset : jsonBytes=length
      Case $004E4942
        If Not jsonAt Or *r\bin : ProcedureReturn g3dFail("Invalid GLB binary chunk.") : EndIf
        *r\bin=*r\file+offset : *r\bytes=length
    EndSelect
    offset+length
  Wend
  If offset<>size Or Not jsonAt Or Not *r\bin : ProcedureReturn g3dFail("GLB requires JSON and binary chunks.") : EndIf
  *r\json=CatchJSON(#PB_Any,*r\file+jsonAt,jsonBytes)
  If Not *r\json : ProcedureReturn g3dFail("GLB JSON: "+JSONErrorMessage()) : EndIf
  *r\root=JSONValue(*r\json)
  Protected required.i=g3dMember(*r\root,"extensionsRequired"), i.i, extension.i
  For i=0 To g3dCount(required)-1
    extension=g3dAt(required,i)
    If JSONType(extension)<>#PB_JSON_String Or GetJSONString(extension)<>"KHR_materials_emissive_strength"
      ProcedureReturn g3dFail("GLB requires an unsupported glTF extension.")
    EndIf
  Next
  If g3dString(g3dMember(*r\root,"asset"),"version")<>"2.0"
    ProcedureReturn g3dFail("GLB requires an unsupported glTF version or extension.")
  EndIf
  Protected a.i=g3dMember(*r\root,"buffers"),b.i=g3dAt(a,0)
  length=g3dInt(b,"byteLength")
  If g3dCount(a)<>1 Or g3dMember(b,"uri") Or length<1 Or length>*r\bytes Or *r\bytes-length>3
    ProcedureReturn g3dFail("GLB must reference its single embedded buffer.")
  EndIf
  *r\bytes=length
  ProcedureReturn 1
EndProcedure

Procedure.i g3dAccess(*r.G3DReader,index.i,*a.G3DAccess,expected.s)
  Protected access.i=g3dAt(g3dMember(*r\root,"accessors"),index)
  Protected view.i=g3dAt(g3dMember(*r\root,"bufferViews"),g3dInt(access,"bufferView"))
  Protected base.q=g3dInt(view,"byteOffset",0), span.q=g3dInt(view,"byteLength")
  Protected at.q=g3dInt(access,"byteOffset",0), item.i, bytes.i, type.s=g3dString(access,"type"), n.i
  If Not view Or g3dInt(view,"buffer")<>0 Or g3dMember(access,"sparse") Or base<0 Or span<1 Or at<0 Or base+span>*r\bytes Or type<>expected
    ProcedureReturn 0
  EndIf
  Select type
    Case "SCALAR" : *a\width=1
    Case "VEC2" : *a\width=2
    Case "VEC3" : *a\width=3
    Case "VEC4" : *a\width=4
    Case "MAT4" : *a\width=16
    Default : ProcedureReturn 0
  EndSelect
  *a\component=g3dInt(access,"componentType")
  Select *a\component
    Case 5121 : item=1
    Case 5123 : item=2
    Case 5125,5126 : item=4
    Default : ProcedureReturn 0
  EndSelect
  bytes=item * *a\width
  *a\count=g3dInt(access,"count")
  *a\stride=g3dInt(view,"byteStride",bytes)
  n=g3dMember(access,"normalized")
  *a\normalized=0
  If n And JSONType(n)=#PB_JSON_Boolean : *a\normalized=GetJSONBoolean(n) : EndIf
  If *a\count<1 Or *a\stride<bytes Or *a\stride>252 Or (base+at)%item Or *a\stride%item Or at+(*a\count-1)* *a\stride+bytes>span
    ProcedureReturn 0
  EndIf
  *a\data=*r\bin+base+at
  ProcedureReturn 1
EndProcedure

Procedure.q g3dUnsigned(*a.G3DAccess,row.i,col.i)
  Protected *at=*a\data+row * *a\stride
  Select *a\component
    Case 5121 : ProcedureReturn PeekA(*at+col)
    Case 5123 : ProcedureReturn PeekU(*at+col*2)
    Case 5125 : ProcedureReturn PeekL(*at+col*4)&$FFFFFFFF
  EndSelect
  ProcedureReturn 0
EndProcedure

Procedure.f g3dValue(*a.G3DAccess,row.i,col.i)
  If *a\component=5126 : ProcedureReturn PeekF(*a\data+row * *a\stride+col*4) : EndIf
  If *a\component=5121 : ProcedureReturn g3dUnsigned(*a,row,col)/255.0 : EndIf
  ProcedureReturn g3dUnsigned(*a,row,col)/65535.0
EndProcedure

Procedure.i g3dReadNodes(*r.G3DReader,*m.G3DModel)
  Protected array.i=g3dMember(*r\root,"nodes"), count.i=g3dCount(array)
  Protected i.i,j.i,node.i,k.i,child.i,children.i,roots.i,scene.i,head.i,tail.i
  Protected *n.G3DNode,length.f
  If count<1 Or count>#G3D_MaxNodes : ProcedureReturn g3dFail("Invalid node count.") : EndIf
  ReDim *m\nodes(count-1) : ReDim *m\order(count-1)
  For i=0 To count-1 : *m\nodes(i)\parent=-1 : Next
  For i=0 To count-1
    node=g3dAt(array,i) : *n=@*m\nodes(i)
    *n\name=g3dString(node,"name") : *n\mesh=g3dInt(node,"mesh") : *n\skin=g3dInt(node,"skin")
    *n\rest\q[3]=1
    For j=0 To 2 : *n\rest\s[j]=1 : Next
    *n\hasMatrix=Bool(g3dMember(node,"matrix"))
    If Not g3dFloats(g3dMember(node,"matrix"),@*n\local,16) Or Not g3dFloats(g3dMember(node,"translation"),@*n\rest\p[0],3) Or Not g3dFloats(g3dMember(node,"rotation"),@*n\rest\q[0],4) Or Not g3dFloats(g3dMember(node,"scale"),@*n\rest\s[0],3)
      ProcedureReturn g3dFail("Invalid node transform.")
    EndIf
    length=0
    For j=0 To 3 : length+*n\rest\q[j]* *n\rest\q[j] : Next
    If Abs(length-1)>0.02 : ProcedureReturn g3dFail("Invalid node quaternion.") : EndIf
    length=Sqr(length)
    For j=0 To 3 : *n\rest\q[j]/length : Next
    CopyMemory(@*n\rest,@*n\pose,SizeOf(G3DPose))
    children=g3dMember(node,"children")
    For j=0 To g3dCount(children)-1
      k=g3dAt(children,j)
      If JSONType(k)<>#PB_JSON_Number : ProcedureReturn g3dFail("Invalid node child.") : EndIf
      child=GetJSONQuad(k)
      If child<0 Or child>=count Or *m\nodes(child)\parent>=0
        ProcedureReturn g3dFail("A node has an invalid or duplicate parent.")
      EndIf
      *m\nodes(child)\parent=i
    Next
  Next
  For i=0 To count-1
    If *m\nodes(i)\parent<0 : *m\order(tail)=i : tail+1 : EndIf
  Next
  While head<tail
    children=g3dMember(g3dAt(array,*m\order(head)),"children") : head+1
    For j=0 To g3dCount(children)-1
      *m\order(tail)=GetJSONInteger(g3dAt(children,j)) : tail+1
    Next
  Wend
  If tail<>count : ProcedureReturn g3dFail("GLB node graph contains a cycle.") : EndIf
  scene=g3dAt(g3dMember(*r\root,"scenes"),g3dInt(*r\root,"scene",0))
  roots=g3dMember(scene,"nodes")
  If Not g3dCount(roots) : ProcedureReturn g3dFail("GLB has no drawable default scene.") : EndIf
  For j=0 To g3dCount(roots)-1
    k=g3dAt(roots,j)
    If JSONType(k)<>#PB_JSON_Number : ProcedureReturn g3dFail("Invalid scene root.") : EndIf
    i=GetJSONQuad(k)
    If i<0 Or i>=count Or *m\nodes(i)\parent>=0 : ProcedureReturn g3dFail("Invalid scene root.") : EndIf
    *m\nodes(i)\visible=1
  Next
  For j=0 To count-1
    i=*m\order(j) : k=*m\nodes(i)\parent
    If k>=0 : *m\nodes(i)\visible=*m\nodes(k)\visible : EndIf
  Next
  ProcedureReturn 1
EndProcedure

Procedure.i g3dReadSkins(*r.G3DReader,*m.G3DModel)
  Protected a.i=g3dMember(*r\root,"skins"),count.i=g3dCount(a),i.i,j.i,k.i,n.i,skin.i,joints.i,maxTexels.l
  Protected *s.G3DSkin, inverse.G3DAccess
  ReDim *m\skins(count)
  glGetIntegerv_(#GL_MAX_TEXTURE_SIZE,@maxTexels)
  For i=0 To count-1
    *s=@*m\skins(i) : skin=g3dAt(a,i)
    joints=g3dMember(skin,"joints") : n=g3dCount(joints)
    If n<1 Or n>65536 Or n>maxTexels : ProcedureReturn g3dFail("Skin exceeds the available GPU joint palette.") : EndIf
    ReDim *s\joint(n-1) : ReDim *s\palette(n-1)
    k=g3dInt(skin,"inverseBindMatrices")
    If k>=0
      If Not g3dAccess(*r,k,@inverse,"MAT4") Or inverse\component<>5126 Or inverse\count<n : ProcedureReturn g3dFail("Invalid inverse bind matrices.") : EndIf
    EndIf
    For j=0 To n-1
      If JSONType(g3dAt(joints,j))<>#PB_JSON_Number : ProcedureReturn g3dFail("Invalid joint node.") : EndIf
      *s\joint(j)\node=GetJSONQuad(g3dAt(joints,j))
      If *s\joint(j)\node<0 Or *s\joint(j)\node>ArraySize(*m\nodes()) : ProcedureReturn g3dFail("Invalid joint node.") : EndIf
      If k<0
        G3D_Identity(@*s\joint(j)\inverseBind)
      Else
        Protected lane.i
        For lane=0 To 15
          *s\joint(j)\inverseBind\v[lane]=g3dValue(@inverse,j,lane)
          If Not g3dFloatValid(*s\joint(j)\inverseBind\v[lane]) : ProcedureReturn g3dFail("Nonfinite inverse bind matrix.") : EndIf
        Next
      EndIf
    Next
    glGenTextures_(1,@*s\texture)
    glBindTexture_(#GL_TEXTURE_2D,*s\texture)
    glTexImage2D_(#GL_TEXTURE_2D,0,#GL_RGBA32F,4,n,0,#GL_RGBA,#GL_FLOAT,0)
    glTexParameteri_(#GL_TEXTURE_2D,#GL_TEXTURE_MIN_FILTER,#GL_NEAREST)
    glTexParameteri_(#GL_TEXTURE_2D,#GL_TEXTURE_MAG_FILTER,#GL_NEAREST)
    If Not *s\texture Or glGetError_() : ProcedureReturn g3dFail("Cannot allocate a skin palette.") : EndIf
  Next
  ProcedureReturn 1
EndProcedure

Procedure.i g3dReadMaterials(*r.G3DReader,*m.G3DModel)
  Protected a.i=g3dMember(*r\root,"materials"),i.i,j.i,mat.i,pbr.i,ext.i,v.i
  Protected *p.G3DMaterial,strength.f
  ReDim *m\materials(g3dCount(a))
  For i=0 To ArraySize(*m\materials())
    mat=g3dAt(a,i) : pbr=g3dMember(mat,"pbrMetallicRoughness") : *p=@*m\materials(i)
    For j=0 To 3 : *p\color[j]=1 : Next
    *p\metal=g3dNumber(pbr,"metallicFactor",1) : *p\rough=g3dNumber(pbr,"roughnessFactor",1)
    If g3dMember(pbr,"baseColorTexture") Or g3dMember(pbr,"metallicRoughnessTexture") Or g3dMember(mat,"normalTexture") Or g3dMember(mat,"occlusionTexture") Or g3dMember(mat,"emissiveTexture")
      ProcedureReturn g3dFail("This renderer supports factor-based materials; texture maps are unsupported.")
    EndIf
    If (g3dString(mat,"alphaMode")<>"" And g3dString(mat,"alphaMode")<>"OPAQUE") Or Not g3dFloats(g3dMember(pbr,"baseColorFactor"),@*p\color[0],4) Or Not g3dFloats(g3dMember(mat,"emissiveFactor"),@*p\emission[0],3)
      ProcedureReturn g3dFail("Invalid or unsupported material.")
    EndIf
    v=g3dMember(mat,"doubleSided")
    If v And JSONType(v)=#PB_JSON_Boolean : *p\twoSided=GetJSONBoolean(v) : EndIf
    ext=g3dMember(g3dMember(mat,"extensions"),"KHR_materials_emissive_strength")
    strength=g3dNumber(ext,"emissiveStrength",1)
    For j=0 To 2 : *p\emission[j]*strength : Next
  Next
  ProcedureReturn 1
EndProcedure

Structure G3DVertex
  position.f[3]
  normal.f[3]
  joint.u[4]
  weight.f[4]
EndStructure

Procedure.i g3dReadPrimitive(*r.G3DReader,*m.G3DModel,node.i,primitive.i)
  Protected attr.i=g3dMember(primitive,"attributes"), i.i,j.i,k.i, jointMax.i, skin.i=*m\nodes(node)\skin
  Protected pos.G3DAccess,norm.G3DAccess,joints.G3DAccess,weights.G3DAccess,indices.G3DAccess
  Protected *v.G3DVertex,*vertices,*outIndices, *p.G3DPrimitive, material.i=g3dInt(primitive,"material")
  Protected count.i,indexCount.i, indexed.i=g3dInt(primitive,"indices"),total.f,ok.i
  If g3dInt(primitive,"mode",4)<>4 Or g3dMember(primitive,"targets") Or g3dMember(attr,"JOINTS_1") Or g3dMember(attr,"WEIGHTS_1")
    ProcedureReturn g3dFail("Only triangle primitives with up to four skin influences are supported.")
  EndIf
  If Not g3dAccess(*r,g3dInt(attr,"POSITION"),@pos,"VEC3") Or pos\component<>5126 Or Not g3dAccess(*r,g3dInt(attr,"NORMAL"),@norm,"VEC3") Or norm\component<>5126 Or pos\count<>norm\count
    ProcedureReturn g3dFail("A triangle primitive requires matching float POSITION and NORMAL streams.")
  EndIf
  count=pos\count
  If count>4000000 : ProcedureReturn g3dFail("Primitive vertex limit exceeded.") : EndIf
  If skin>=0
    If skin>=ArraySize(*m\skins()) : ProcedureReturn g3dFail("Invalid mesh skin.") : EndIf
    jointMax=ArraySize(*m\skins(skin)\joint())
    If Not g3dAccess(*r,g3dInt(attr,"JOINTS_0"),@joints,"VEC4") Or Not g3dAccess(*r,g3dInt(attr,"WEIGHTS_0"),@weights,"VEC4") Or joints\count<>count Or weights\count<>count Or joints\normalized Or (joints\component<>5121 And joints\component<>5123) Or (weights\component<>5126 And ((weights\component<>5121 And weights\component<>5123) Or Not weights\normalized))
      ProcedureReturn g3dFail("Invalid JOINTS_0 or WEIGHTS_0 stream.")
    EndIf
  EndIf
  indexCount=count
  If indexed>=0
    If Not g3dAccess(*r,indexed,@indices,"SCALAR") Or indices\component=5126 Or indices\normalized
      ProcedureReturn g3dFail("Invalid index stream.")
    EndIf
    indexCount=indices\count
  EndIf
  If indexCount%3 Or indexCount>12000000 Or material>=ArraySize(*m\materials())
    ProcedureReturn g3dFail("Invalid triangle count or material index.")
  EndIf
  *vertices=AllocateMemory(count*SizeOf(G3DVertex))
  If Not *vertices : ProcedureReturn g3dFail("Cannot allocate the vertex stream.") : EndIf
  If indexed>=0
    *outIndices=AllocateMemory(indexCount*4,#PB_Memory_NoClear)
    If Not *outIndices : FreeMemory(*vertices) : ProcedureReturn g3dFail("Cannot allocate indices.") : EndIf
  EndIf
  Repeat
    For i=0 To count-1
      *v=*vertices+i*SizeOf(G3DVertex)
      For j=0 To 2
        *v\position[j]=g3dValue(@pos,i,j) : *v\normal[j]=g3dValue(@norm,i,j)
        If Not g3dFloatValid(*v\position[j]) Or Not g3dFloatValid(*v\normal[j]) : Break 3 : EndIf
      Next
      If skin>=0
        total=0
        For j=0 To 3
          k=g3dUnsigned(@joints,i,j)
          If k>jointMax : Break 3 : EndIf
          *v\joint[j]=k : *v\weight[j]=g3dValue(@weights,i,j)
          If Not g3dFloatValid(*v\weight[j]) Or *v\weight[j]<0 Or *v\weight[j]>1 : Break 3 : EndIf
          total+*v\weight[j]
        Next
        If total<=0 : Break 2 : EndIf
        For j=0 To 3 : *v\weight[j]/total : Next
      EndIf
    Next
    If indexed>=0
      For i=0 To indexCount-1
        k=g3dUnsigned(@indices,i,0)
        If k>=count : Break 2 : EndIf
        PokeL(*outIndices+i*4,k)
      Next
    EndIf
    ok=1
  Until #True
  If ok
    *p=AddElement(*m\primitives()) : *p\node=node
    If material<0 : material=ArraySize(*m\materials()) : EndIf
    *p\material=material : *p\count=indexCount
    glGenVertexArrays(1,@*p\vao) : glGenBuffers(1,@*p\vbo)
    glBindVertexArray(*p\vao)
    glBindBuffer(#GL_ARRAY_BUFFER,*p\vbo)
    glBufferData(#GL_ARRAY_BUFFER,count*SizeOf(G3DVertex),*vertices,#GL_STATIC_DRAW)
    glVertexAttribPointer(0,3,#GL_FLOAT,0,SizeOf(G3DVertex),OffsetOf(G3DVertex\position))
    glVertexAttribPointer(1,3,#GL_FLOAT,0,SizeOf(G3DVertex),OffsetOf(G3DVertex\normal))
    g3dAttribInt(2,4,#GL_UNSIGNED_SHORT,SizeOf(G3DVertex),OffsetOf(G3DVertex\joint))
    glVertexAttribPointer(3,4,#GL_FLOAT,0,SizeOf(G3DVertex),OffsetOf(G3DVertex\weight))
    For i=0 To 3 : glEnableVertexAttribArray(i) : Next
    If *outIndices
      glGenBuffers(1,@*p\ebo) : glBindBuffer(#GL_ELEMENT_ARRAY_BUFFER,*p\ebo)
      glBufferData(#GL_ELEMENT_ARRAY_BUFFER,indexCount*4,*outIndices,#GL_STATIC_DRAW)
    EndIf
    If glGetError_() Or Not *p\vao Or Not *p\vbo Or (indexed>=0 And Not *p\ebo) : ok=0 : EndIf
    *m\vertices+count
  EndIf
  If *outIndices : FreeMemory(*outIndices) : EndIf
  FreeMemory(*vertices)
  If Not ok : ProcedureReturn g3dFail("Invalid vertex/index data or GPU upload failed.") : EndIf
  ProcedureReturn 1
EndProcedure

Procedure.i g3dReadMeshes(*r.G3DReader,*m.G3DModel)
  Protected meshes.i=g3dMember(*r\root,"meshes"), i.i,j.i, mesh.i, primitives.i
  For i=0 To ArraySize(*m\nodes())
    If *m\nodes(i)\visible And *m\nodes(i)\mesh>=0
      mesh=g3dAt(meshes,*m\nodes(i)\mesh) : primitives=g3dMember(mesh,"primitives")
      If Not g3dCount(primitives) : ProcedureReturn g3dFail("Invalid mesh primitive list.") : EndIf
      For j=0 To g3dCount(primitives)-1
        If Not g3dReadPrimitive(*r,*m,i,g3dAt(primitives,j)) : ProcedureReturn 0 : EndIf
      Next
    EndIf
  Next
  If Not ListSize(*m\primitives()) : ProcedureReturn g3dFail("GLB default scene contains no triangle mesh.") : EndIf
  ProcedureReturn 1
EndProcedure
