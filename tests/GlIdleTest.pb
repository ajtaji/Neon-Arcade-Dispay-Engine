; No visible window: prove an idle deadline blocks, a toolkit event interrupts it, and
; socket waits wake only for the caller's requested interest without consuming the bytes.
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlTypes.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlUtilities.pbi"
XIncludeFile #PB_Compiler_FilePath + "../GlNet.pbi"

Global Checks.i, Fails.i
Global Sender.i
Procedure DelayedSend(unused.i)
  Protected byte.a = 73
  Delay(100)
  GL_NetSendTo(Sender, @byte, 1, "127.0.0.1", unused)
EndProcedure
Procedure Check(name$, ok.i)
  Checks + 1
  If ok : PrintN("ok " + name$) : Else : PrintN("FAIL " + name$) : Fails + 1 : EndIf
EndProcedure

Define t.q, ev.i, u1.i, u2.i, port.i, b.a = 42, got.a, r.i
OpenConsole()
Check("hidden event target", Bool(OpenWindow(0, 0, 0, 16, 16, "idle check", #PB_Window_Invisible)))
While WindowEvent() : Wend
t = GL_Micros()
ev = GL_HostWait(150)
Check("event wait reaches its deadline", Bool(ev = 0 And GL_Micros() - t >= 120000))
AddWindowTimer(0, 1, 100)
t = GL_Micros()
Repeat
  ev = GL_HostWait(1000)
Until ev = #PB_Event_Timer Or GL_Micros() - t > 1200000
Check("timer event interrupts the wait and retains its attributes", Bool(ev = #PB_Event_Timer And EventTimer() = 1 And GL_Micros() - t < 500000))
RemoveWindowTimer(0, 1)
PostEvent(#PB_Event_CloseWindow, 0, 0)
ev = GL_HostWait(1000)
Check("a queued close event is not lost", Bool(ev = #PB_Event_CloseWindow And EventWindow() = 0))
CloseWindow(0)

Check("socket init", GL_NetInit())
u1 = GL_NetOpen(#GL_NET_UDP) : u2 = GL_NetOpen(#GL_NET_UDP)
Check("socket bind", Bool(GL_NetBind(u1, "127.0.0.1", 0) = 0))
port = GL_NetLocalPort(u1)
GL_NetWaitBegin()
Check("invalid wait handle is refused", Bool(GL_NetWaitAdd(0, 1) = #GL_NET_BADHANDLE))
Check("invalid wait mask is refused", Bool(GL_NetWaitAdd(u1, 4) = #GL_NET_BADARG))
GL_NetWaitAdd(u1, 1)
t = GL_Micros()
r = GL_NetWait(150)
Check("read interest ignores a writable socket until the deadline", Bool(r = 0 And GL_Micros() - t >= 120000))
GL_NetSendTo(u2, @b, 1, "127.0.0.1", port)
t = GL_Micros()
Check("incoming data wakes the readiness wait", Bool(GL_NetWait(1000) > 0 And GL_Micros() - t < 500000))
Check("wait does not consume incoming data", Bool(GL_NetRecvFrom(u1, @got, 1) = 1 And got = b))
Sender = u2
Define thread.i = CreateThread(@DelayedSend(), port)
t = GL_Micros()
r = GL_NetWait(1000)
Check("data arriving during the wait wakes it before its deadline", Bool(r > 0 And GL_Micros() - t >= 70000 And GL_Micros() - t < 500000))
WaitThread(thread)
Check("delayed data is intact", Bool(GL_NetRecvFrom(u1, @got, 1) = 1 And got = 73))
GL_NetWaitBegin()
GL_NetWaitAdd(u2, 2)
Check("write interest wakes a writable socket", Bool(GL_NetWait(1000) > 0))
GL_NetClose(u1) : GL_NetClose(u2)
Check("a closed watched socket is ignored", Bool(GL_NetWait(10) = 0))
GL_NetWaitBegin()
Check("negative wait deadline is refused", Bool(GL_NetWait(-1) = #GL_NET_BADARG))
t = GL_Micros()
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Define ct.q, et.q, kt.q, ut.q, cpu0.q
  GetProcessTimes_(GetCurrentProcess_(), @ct, @et, @kt, @ut)
  cpu0 = kt + ut
CompilerEndIf
GL_NetWait(500)
Check("an empty wait set sleeps too", Bool(GL_Micros() - t >= 450000))
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  GetProcessTimes_(GetCurrentProcess_(), @ct, @et, @kt, @ut)
  PrintN("steady_idle_cpu_seconds=" + StrD((kt + ut - cpu0) / 10000000.0, 6))
  Check("steady idle wait consumes under 1 percent of one host core", Bool(kt + ut - cpu0 < 50000))
CompilerEndIf
PrintN("idle host check: " + Str(Checks) + " checks, " + Str(Fails) + " failed")
End Bool(Fails > 0)
