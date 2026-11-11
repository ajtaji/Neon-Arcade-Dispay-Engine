CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Import "kernel32.lib"
    GLMemory_GetWriteWatch.l(flags.l,*base,bytes.i,*addresses,*count,*granularity) As "GetWriteWatch"
  EndImport
CompilerEndIf

; Owned zero-filled RAM with optional host dirty-page tracking. Collection and
; destruction require exclusive ownership: join writers before either call.
; A negative collection result requires a full byte comparison/upload; it must
; never be interpreted as a clean region. Unsupported hosts remain usable.
Structure GLMemoryWatch
  *memory
  bytes.i : pageBytes.i : capacity.i : count.i : tracked.i
  *pages
  error.s
EndStructure

Procedure GL_MemoryWatchFree(*region.GLMemoryWatch)
  If Not *region : ProcedureReturn : EndIf
  If *region\memory
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If *region\tracked : VirtualFree_(*region\memory,0,$8000)
      Else : FreeMemory(*region\memory) : EndIf
    CompilerElse
      FreeMemory(*region\memory)
    CompilerEndIf
  EndIf
  If *region\pages : FreeMemory(*region\pages) : EndIf
  FreeStructure(*region)
EndProcedure

Procedure.i GL_MemoryWatchCreate(bytes.i,watch.i=#True)
  Protected *region.GLMemoryWatch
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected info.SYSTEM_INFO
  CompilerEndIf
  If bytes<1 : ProcedureReturn 0 : EndIf
  *region=AllocateStructure(GLMemoryWatch)
  If Not *region : ProcedureReturn 0 : EndIf
  *region\bytes=bytes : *region\pageBytes=4096
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    GetSystemInfo_(@info) : *region\pageBytes=info\dwPageSize
    If watch And *region\pageBytes>0
      *region\memory=VirtualAlloc_(0,bytes,$203000,4) ; RESERVE|COMMIT|WRITE_WATCH, READWRITE
      If *region\memory : *region\tracked=#True : EndIf
    EndIf
  CompilerEndIf
  If Not *region\memory : *region\memory=AllocateMemory(bytes) : EndIf
  If Not *region\memory : GL_MemoryWatchFree(*region) : ProcedureReturn 0 : EndIf
  If *region\tracked
    *region\capacity=(bytes-1)/ *region\pageBytes+1
    *region\pages=AllocateMemory(*region\capacity*SizeOf(Integer))
    If Not *region\pages : GL_MemoryWatchFree(*region) : ProcedureReturn 0 : EndIf
  EndIf
  ProcedureReturn *region
EndProcedure

; Returns number of dirty page addresses in region\pages, or -1 when tracking
; is unavailable/failed. Successful collection resets that observation window.
; Every byte store counts, including same-value stores and writes by native code.
Procedure.i GL_MemoryWatchCollect(*region.GLMemoryWatch)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected count.i,granularity.l,result.i,i.i,address.i
  CompilerEndIf
  If Not *region : ProcedureReturn -1 : EndIf
  *region\count=0 : *region\error=""
  If Not *region\tracked
    *region\error="Host dirty-page tracking unavailable; compare the full region."
    ProcedureReturn -1
  EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    count=*region\capacity
    result=GLMemory_GetWriteWatch(1,*region\memory,*region\bytes,*region\pages,@count,@granularity)
    If result<>0 Or count<0 Or count>*region\capacity Or granularity<>*region\pageBytes
      *region\error="Host dirty-page collection failed; compare the full region."
      ProcedureReturn -1
    EndIf
    For i=0 To count-1
      address=PeekI(*region\pages+i*SizeOf(Integer))-*region\memory
      If address<0 Or address>=*region\bytes Or address%*region\pageBytes
        *region\error="Host returned an invalid dirty page; compare the full region."
        ProcedureReturn -1
      EndIf
    Next
    *region\count=count : ProcedureReturn count
  CompilerElse
    ProcedureReturn -1
  CompilerEndIf
EndProcedure
