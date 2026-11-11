; Host UTC is a wall-clock sample, distinct from GL_Micros' monotonic timer.
; Unix microseconds; no local timezone conversion and no network side effects.
CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  Structure GLClockTimespec
    seconds.i
    nanos.i
  EndStructure
  ImportC ""
    GLClock_gettime.i(clock.i,*sample.GLClockTimespec) As "clock_gettime"
  EndImport
CompilerEndIf

Procedure.q GL_UtcMicroseconds()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected ticks.q
    GetSystemTimeAsFileTime_(@ticks)
    ProcedureReturn (ticks-116444736000000000)/10
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    Protected sample.GLClockTimespec
    If GLClock_gettime(0,@sample)<>0 : ProcedureReturn -1 : EndIf
    ProcedureReturn sample\seconds*1000000+sample\nanos/1000
  CompilerElse
    ProcedureReturn -1
  CompilerEndIf
EndProcedure
