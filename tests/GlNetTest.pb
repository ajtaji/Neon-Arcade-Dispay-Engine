; GlNetTest.pb - proves GlNet.pbi on this machine: loopback TCP (listen, a non-blocking connect,
; accept, send and receive both ways, the peer's close read as 0 bytes, a refused connect) and UDP
; (send to, receive from, the sender's address), name resolution of "localhost", and the result
; codes of bad calls. Everything is bound to 127.0.0.1, port 0 (the system picks a free one).
;   Windows:  pbcompiler tests\GlNetTest.pb /CONSOLE /EXE GlNetTest.exe
;   Linux:    pbcompiler tests/GlNetTest.pb -cl -o GlNetTest
; Exit code 0 = every check passed; it prints one line per check.
EnableExplicit
XIncludeFile #PB_Compiler_FilePath + "../GlNet.pbi"

Global Fails.i, Checks.i
Procedure Check(name$, ok.i)
  Checks + 1
  If ok : PrintN("ok   " + name$) : Else : PrintN("FAIL " + name$) : Fails + 1 : EndIf
EndProcedure

; wait (up to 2 s) until GL_NetPoll(h) has one of the bits in mask
Procedure.i WaitFor(h.i, mask.i)
  Protected i.i, r.i
  For i = 0 To 400
    r = GL_NetPoll(h)
    If r < 0 : ProcedureReturn r : EndIf
    If r & mask : ProcedureReturn r : EndIf
    Delay(5)
  Next
  ProcedureReturn 0
EndProcedure

Define srv.i, cli.i, acc.i, rc.i, port.i, n.i, i.i, *buf = AllocateMemory(4096), *big, got.i, u1.i, u2.i, p2.i, a$
OpenConsole()
Check("GL_NetInit", GL_NetInit())
Check("GL_NetOpen with a bad kind is BADARG", Bool(GL_NetOpen(7) = #GL_NET_BADARG))
Check("a bad handle is BADHANDLE", Bool(GL_NetSend(99, *buf, 1) = #GL_NET_BADHANDLE))

; ---- TCP
srv = GL_NetOpen(#GL_NET_TCP)
Check("TCP open", Bool(srv >= 1))
Check("bind 127.0.0.1:0", Bool(GL_NetBind(srv, "127.0.0.1", 0) = 0))
Check("bind with a bad address is BADARG", Bool(GL_NetBind(GL_NetOpen(#GL_NET_TCP), "not-an-address", 0) = #GL_NET_BADARG))
Check("listen", Bool(GL_NetListen(srv) = 0))
port = GL_NetLocalPort(srv)
Check("the listener's port (" + Str(port) + ")", Bool(port > 0))
Check("nothing to accept yet: WOULDBLOCK", Bool(GL_NetAccept(srv) = #GL_NET_WOULDBLOCK))
cli = GL_NetOpen(#GL_NET_TCP)
rc = GL_NetConnect(cli, "127.0.0.1", port)
Check("non-blocking connect: 0 or INPROGRESS (" + Str(rc) + ")", Bool(rc = 0 Or rc = #GL_NET_INPROGRESS))
Check("the client becomes writable", Bool(WaitFor(cli, 2) & 2))
Check("the connect's outcome is 0", Bool(GL_NetError(cli) = 0))
Check("the listener becomes readable", Bool(WaitFor(srv, 1) & 1))
acc = GL_NetAccept(srv)
Check("accept", Bool(acc >= 1))
Check("the peer address is 127.0.0.1", Bool(GL_NetFromAddr$ = "127.0.0.1"))
Check("nothing to read yet: WOULDBLOCK", Bool(GL_NetRecv(acc, *buf, 4096) = #GL_NET_WOULDBLOCK))
PokeS(*buf, "hello zentaji", -1, #PB_Ascii)
Check("send 13 bytes", Bool(GL_NetSend(cli, *buf, 13) = 13))
WaitFor(acc, 1)
FillMemory(*buf, 64, 0)
n = GL_NetRecv(acc, *buf, 4096)
Check("receive them (" + Str(n) + ")", Bool(n = 13 And PeekS(*buf, 13, #PB_Ascii) = "hello zentaji"))
; a larger transfer the other way: 200 KB, sent and received in non-blocking pieces
*big = AllocateMemory(200000)
For i = 0 To 199999 : PokeA(*big + i, (i * 7) & 255) : Next
Define sent.i, ok.i = #True, t.i
While (sent < 200000 Or got < 200000) And t < 4000
  If sent < 200000
    n = GL_NetSend(acc, *big + sent, 200000 - sent)
    If n > 0 : sent + n : ElseIf n <> #GL_NET_WOULDBLOCK : ok = #False : Break : EndIf
  EndIf
  n = GL_NetRecv(cli, *buf, 4096)
  If n > 0
    For i = 0 To n - 1
      If PeekA(*buf + i) <> ((got + i) * 7) & 255 : ok = #False : EndIf
    Next
    got + n
  ElseIf n <> #GL_NET_WOULDBLOCK
    ok = #False : Break
  EndIf
  If n = #GL_NET_WOULDBLOCK : Delay(1) : t + 1 : EndIf
Wend
Check("200,000 bytes server -> client, in order", Bool(ok And sent = 200000 And got = 200000))
Check("shutdown send", Bool(GL_NetShutdown(cli, 1) = 0))
WaitFor(acc, 1)
Check("the peer's shutdown reads as 0 bytes", Bool(GL_NetRecv(acc, *buf, 4096) = 0))
Check("close", Bool(GL_NetClose(acc) = 0 And GL_NetClose(cli) = 0))
Check("a closed handle is BADHANDLE", Bool(GL_NetRecv(cli, *buf, 16) = #GL_NET_BADHANDLE))
; a refused connect: the listener's port once it is closed
GL_NetClose(srv)
cli = GL_NetOpen(#GL_NET_TCP)
rc = GL_NetConnect(cli, "127.0.0.1", port)
If rc = #GL_NET_INPROGRESS
  WaitFor(cli, 6)
  rc = GL_NetError(cli)
EndIf
Check("connect to a closed port is REFUSED (" + Str(rc) + ")", Bool(rc = #GL_NET_REFUSED))
GL_NetClose(cli)

; ---- UDP
u1 = GL_NetOpen(#GL_NET_UDP) : u2 = GL_NetOpen(#GL_NET_UDP)
Check("UDP open x2", Bool(u1 >= 1 And u2 >= 1))
Check("UDP bind", Bool(GL_NetBind(u1, "127.0.0.1", 0) = 0 And GL_NetBind(u2, "127.0.0.1", 0) = 0))
p2 = GL_NetLocalPort(u2)
Check("nothing received yet: WOULDBLOCK", Bool(GL_NetRecvFrom(u2, *buf, 4096) = #GL_NET_WOULDBLOCK))
PokeS(*buf, "datagram", -1, #PB_Ascii)
Check("sendto 8 bytes", Bool(GL_NetSendTo(u1, *buf, 8, "127.0.0.1", p2) = 8))
WaitFor(u2, 1)
FillMemory(*buf, 64, 0)
n = GL_NetRecvFrom(u2, *buf, 4096)
Check("recvfrom 8 bytes from 127.0.0.1:" + Str(GL_NetLocalPort(u1)), Bool(n = 8 And PeekS(*buf, 8, #PB_Ascii) = "datagram" And GL_NetFromAddr$ = "127.0.0.1" And GL_NetFromPort = GL_NetLocalPort(u1)))
GL_NetClose(u1) : GL_NetClose(u2)

; ---- names
a$ = GL_NetResolve("localhost")
Check("resolve localhost -> " + a$, Bool(a$ = "127.0.0.1"))
Check("resolve a bad name -> empty", Bool(GL_NetResolve("no-such-host.invalid") = ""))

PrintN(Str(Checks) + " checks, " + Str(Fails) + " failed")
If Fails : End 1 : EndIf
End 0
