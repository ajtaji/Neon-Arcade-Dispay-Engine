EnableExplicit
XIncludeFile #PB_Compiler_FilePath+"../GlMemoryWatch.pbi"
OpenConsole()
Procedure Check(ok.i,message.s)
  If Not ok : PrintN("FAIL "+message) : End 1 : EndIf
EndProcedure
Procedure NativeStore(*address)
  CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm And #PB_Compiler_Processor = #PB_Processor_x64
    !mov rax, [p.p_address]
    !mov byte [rax], 91
  CompilerElse
    PokeA(*address,91)
  CompilerEndIf
EndProcedure
Procedure HasPage(*region.GLMemoryWatch,page.i)
  Protected i.i
  For i=0 To *region\count-1
    If PeekI(*region\pages+i*SizeOf(Integer))=*region\memory+page * *region\pageBytes : ProcedureReturn 1 : EndIf
  Next
  ProcedureReturn 0
EndProcedure
Define *region.GLMemoryWatch,*plain.GLMemoryWatch,i.i,bytes.i=16385,page.i,count.i
Check(Bool(GL_MemoryWatchCreate(0)=0 And GL_MemoryWatchCollect(0)=-1),"invalid arguments")
GL_MemoryWatchFree(0)
*plain=GL_MemoryWatchCreate(bytes,#False)
Check(Bool(*plain<>0 And *plain\tracked=0),"explicit portable allocation")
For i=0 To bytes-1 : Check(Bool(PeekA(*plain\memory+i)=0),"zero initialization") : Next
Check(Bool(GL_MemoryWatchCollect(*plain)=-1),"unsupported is not clean")
GL_MemoryWatchFree(*plain)
*region=GL_MemoryWatchCreate(1)
Check(Bool(*region<>0),"page-size probe")
bytes=*region\pageBytes*4+1 : GL_MemoryWatchFree(*region)
For i=1 To 20
  *region=GL_MemoryWatchCreate(bytes)
  Check(Bool(*region<>0),"tracked allocation")
  If *region\tracked
    page=*region\pageBytes
    Check(Bool(GL_MemoryWatchCollect(*region)=0),"fresh pages are clean")
    PokeA(*region\memory,0) ; same-value write must still be detected
    NativeStore(*region\memory+bytes-1)
    Check(Bool(GL_MemoryWatchCollect(*region)=2 And HasPage(*region,0) And HasPage(*region,(bytes-1)/page)),"native and same-value writes")
    Check(Bool(GL_MemoryWatchCollect(*region)=0),"collection reset")
    PokeQ(*region\memory+page-3,$123456789ABCDEF)
    Check(Bool(GL_MemoryWatchCollect(*region)=2 And HasPage(*region,0) And HasPage(*region,1)),"unaligned cross-page write")
    FillMemory(*region\memory+2*page,page,$5A)
    CopyMemory(*region\memory+2*page,*region\memory+3*page,page)
    Check(Bool(GL_MemoryWatchCollect(*region)=2 And HasPage(*region,2) And HasPage(*region,3)),"bulk writes")
    FillMemory(*region\memory,bytes,$A5)
    Check(Bool(GL_MemoryWatchCollect(*region)=*region\capacity),"all pages including partial tail")
    Check(Bool(GL_MemoryWatchCollect(*region)=0),"clean after reset")
  Else
    Check(Bool(GL_MemoryWatchCollect(*region)=-1),"portable fallback is explicit")
  EndIf
  count=*region\tracked
  GL_MemoryWatchFree(*region)
Next
PrintN("PASS memory watch tracked="+Str(count)+" cycles=20 native/cross-page/bulk/same-value writes, reset and explicit fallback")
