; clock_files.pb - the two clocks, the durable file store and a watched memory region. No window.
; Build:  pbcompiler clock_files.pb /CONSOLE /EXE clock_files.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlTypes.pbi"
XIncludeFile #Engine$ + "GlUtilities.pbi"          ; GL_Micros
XIncludeFile #Engine$ + "GlClock.pbi"
XIncludeFile #Engine$ + "GlFile.pbi"
XIncludeFile #Engine$ + "GlMemoryWatch.pbi"
OpenConsole()

; the wall clock (UTC, microseconds since 1970) and the monotonic clock (microseconds, for intervals)
Define Utc.q = GL_UtcMicroseconds(), T0.q = GL_Micros()
PrintN("UTC now: " + FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Utc / 1000000) + " and " +
       Str(Utc % 1000000) + " us")
Delay(20)
PrintN("Delay(20) took " + Str(GL_Micros() - T0) + " us by GL_Micros")

; the file store: CreateNew makes a file that must not exist; without it the file must exist at that exact size
Define Path.s = GetTemporaryDirectory() + "neon_manual_store.bin", *Data = AllocateMemory(1000), i.i
For i = 0 To 999 : PokeA(*Data + i, i & 255) : Next
DeleteFile(Path)
PrintN("create new:                 " + Str(GL_FileStore(Path, *Data, 1000, #True)))
PrintN("create new again (refused): " + Str(GL_FileStore(Path, *Data, 1000, #True)))
PokeA(*Data, 99)
PrintN("overwrite, same size:       " + Str(GL_FileStore(Path, *Data, 1000)))
PrintN("overwrite, other size:      " + Str(GL_FileStore(Path, *Data, 999)) +
       "  (the file stays " + Str(FileSize(Path)) + " bytes)")
DeleteFile(Path)

; a watched region: which pages were written since the last collect
Define *Region.GLMemoryWatch = GL_MemoryWatchCreate(16 * 4096)
If *Region
  GL_MemoryWatchCollect(*Region)                    ; start a fresh observation window
  PokeA(*Region\memory + 5, 1) : PokeA(*Region\memory + 3 * *Region\pageBytes, 1)
  Define n.i = GL_MemoryWatchCollect(*Region)
  If n < 0
    PrintN("no dirty-page tracking here: " + *Region\error)
  Else
    PrintN(Str(n) + " pages written, page size " + Str(*Region\pageBytes))
  EndIf
  GL_MemoryWatchFree(*Region)
EndIf
