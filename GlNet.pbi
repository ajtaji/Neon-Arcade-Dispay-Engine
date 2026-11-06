; ======================================================================
; GlNet.pbi - NETWORK HOST SERVICES: TCP and UDP sockets, name resolution
; ======================================================================
; A host service like GL_Audio*: the OS socket API lives here, so an
; application calls GL_Net* and never the OS. Windows (ws2_32.dll) and
; Linux (libc), both loaded at run time (OpenLibrary + GetFunction), so a
; program that never calls GL_NetInit loads nothing and links nothing.
; Include it after GlUtilities.pbi; it uses nothing else of the engine.
;
; THE MODEL
;   GL_NetInit()                         #True when sockets are available
;   h = GL_NetOpen(Kind [, Family])      Kind #GL_NET_TCP / #GL_NET_UDP, Family 4 or 6
;                                        -> a handle >= 1, or an error < 0
;   GL_NetBind(h, Addr$, Port)           a numeric address ("127.0.0.1", "::1", "0.0.0.0")
;   GL_NetListen(h, Backlog)             TCP: start accepting
;   c = GL_NetAccept(h)                  a new handle, or #GL_NET_WOULDBLOCK
;                                        (GL_NetFromAddr$ / GL_NetFromPort = the peer's address and port)
;   GL_NetConnect(h, Addr$, Port)        0, #GL_NET_INPROGRESS (poll for writable), or an error
;   n = GL_NetSend(h, *Buf, Len)         bytes sent, #GL_NET_WOULDBLOCK, or an error
;   n = GL_NetSendTo(h, *Buf, Len, Addr$, Port)        UDP
;   n = GL_NetRecv(h, *Buf, Cap)         bytes, 0 = the peer closed (TCP), WOULDBLOCK, or an error
;   n = GL_NetRecvFrom(h, *Buf, Cap)     UDP; GL_NetFromAddr$ / GL_NetFromPort say who sent it
;   r = GL_NetPoll(h)                    bit0 readable, bit1 writable, bit2 error or hang-up; < 0 an error
;   GL_NetWaitBegin()                    clear the idle wait's interest set
;   GL_NetWaitAdd(h, Mask)               add read (1), write (2), or both (3); errors always wake
;   n = GL_NetWait(Milliseconds)         BLOCK until readiness or timeout; no socket is consumed
;   GL_NetShutdown(h, How)               0 receive, 1 send, 2 both
;   GL_NetClose(h)
;   a$ = GL_NetResolve(Name$ [, Family]) the first address of a host name, "" when it fails
;   p = GL_NetLocalPort(h)               the port a socket is bound to (after Bind to port 0)
;   GL_NetError(h)                       a connect's outcome: 0 or an error code (SO_ERROR)
;
; EVERY SOCKET IS NON-BLOCKING. GL_NetWait is an explicit readiness wait; GL_NetResolve asks the system
; resolver and can take as long as it does (call it off the frame loop, or accept the stall). Errors
; are RESULT CODES (never an assert, never a message box): the fixed list #GL_NET_* below, the same on
; both systems (the OS's own number is in GL_NetOsError for diagnostics).
;
; SECURITY (read this before exposing anything)
;   - NOTHING LISTENS unless the application calls GL_NetListen (TCP) or GL_NetBind on a UDP socket.
;     GL_NetInit opens no socket.
;   - Bind to LOOPBACK ("127.0.0.1" / "::1") unless the user asked for the network: a socket bound to
;     "0.0.0.0" or "::" is reachable from every machine that can reach this one, through the firewall's
;     rules. The engine never picks an address for you; Bind's address is required.
;   - An emulator that gives a guest program sockets is giving UNTRUSTED CODE network access with the
;     user's rights: put a policy in front (what may be connected to, which ports may listen, whether at
;     all), off by default, and say so to the user. The engine is the mechanism, not the policy.
;   - Received bytes are data from anyone: bounds-check them; GL_NetRecv never writes past Cap.
;   - On Linux, sending to a closed TCP peer raises no SIGPIPE (MSG_NOSIGNAL): it returns #GL_NET_RESET.
; ======================================================================

#GL_NET_TCP = 1
#GL_NET_UDP = 2
#GL_NET_MAX = 256                        ; open sockets at once

; result codes (negative); 0 and positive values are successes
#GL_NET_WOULDBLOCK = -1                  ; nothing now: try again later
#GL_NET_INPROGRESS = -2                  ; a connect has started: poll for writable, then GL_NetError
#GL_NET_REFUSED = -3
#GL_NET_RESET = -4                       ; the connection was reset or the peer is gone
#GL_NET_UNREACHABLE = -5                 ; network or host unreachable
#GL_NET_TIMEDOUT = -6
#GL_NET_ADDRINUSE = -7
#GL_NET_NOTCONN = -8
#GL_NET_BADHANDLE = -9
#GL_NET_BADARG = -10                     ; a bad address, port, kind or buffer
#GL_NET_NORESOLVE = -11
#GL_NET_UNAVAILABLE = -12                ; no socket library, or GL_NetInit was not called / failed
#GL_NET_FULL = -13                       ; #GL_NET_MAX sockets are open
#GL_NET_OTHER = -14

CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  #GL_NET_AF6 = 23 : #GL_NET_SOL = $FFFF : #GL_NET_SOERR = $1007 : #GL_NET_AIADDR = 32
  Prototype.l GLNetWSAStartup(ver.l, *data)
  Prototype.i GLNetSocket(af.l, type.l, proto.l)
  Prototype.l GLNetClose(s.i)
  Prototype.l GLNetIoctl(s.i, cmd.l, *arg)
  Prototype.l GLNetLastErr()
  Prototype.l GLNetPollFn(*fds, n.l, timeout.l)
  Prototype.i GLNetAcceptFn(s.i, *addr, *len)
  Prototype.l GLNetConnectFn(s.i, *addr, len.l)
  Prototype.l GLNetBindFn(s.i, *addr, len.l)
  Prototype.l GLNetListenFn(s.i, backlog.l)
  Prototype.l GLNetSendFn(s.i, *buf, len.l, flags.l)
  Prototype.l GLNetRecvFn(s.i, *buf, len.l, flags.l)
  Prototype.l GLNetSendToFn(s.i, *buf, len.l, flags.l, *to, tolen.l)
  Prototype.l GLNetRecvFromFn(s.i, *buf, len.l, flags.l, *from, *fromlen)
  Prototype.l GLNetShutdownFn(s.i, how.l)
  Prototype.l GLNetGetAddrInfo(node.p-ascii, *service, *hints, *res)
  Prototype GLNetFreeAddrInfo(*ai)
  Prototype.l GLNetGetSockOpt(s.i, level.l, name.l, *val, *len)
  Prototype.l GLNetGetSockName(s.i, *addr, *len)
CompilerElse
  #GL_NET_AF6 = 10 : #GL_NET_SOL = 1 : #GL_NET_SOERR = 4 : #GL_NET_AIADDR = 24
  PrototypeC.l GLNetSocket(af.l, type.l, proto.l)
  PrototypeC.l GLNetClose(fd.l)
  PrototypeC.l GLNetFcntl(fd.l, cmd.l, arg.l)
  PrototypeC.i GLNetErrnoLoc()
  PrototypeC.l GLNetPollFn(*fds, n.i, timeout.l)
  PrototypeC.l GLNetAcceptFn(fd.l, *addr, *len)
  PrototypeC.l GLNetConnectFn(fd.l, *addr, len.l)
  PrototypeC.l GLNetBindFn(fd.l, *addr, len.l)
  PrototypeC.l GLNetListenFn(fd.l, backlog.l)
  PrototypeC.i GLNetSendFn(fd.l, *buf, len.i, flags.l)
  PrototypeC.i GLNetRecvFn(fd.l, *buf, len.i, flags.l)
  PrototypeC.i GLNetSendToFn(fd.l, *buf, len.i, flags.l, *to, tolen.l)
  PrototypeC.i GLNetRecvFromFn(fd.l, *buf, len.i, flags.l, *from, *fromlen)
  PrototypeC.l GLNetShutdownFn(fd.l, how.l)
  PrototypeC.l GLNetGetAddrInfo(node.p-utf8, *service, *hints, *res)
  PrototypeC GLNetFreeAddrInfo(*ai)
  PrototypeC.l GLNetGetSockOpt(fd.l, level.l, name.l, *val, *len)
  PrototypeC.l GLNetGetSockName(fd.l, *addr, *len)
CompilerEndIf

Structure GLNetSa                       ; a sockaddr_in / sockaddr_in6 (28 bytes) and room to spare
  b.a[32]
EndStructure
Structure GLNetHints                    ; struct addrinfo (48 bytes on both systems)
  b.a[48]
EndStructure
Structure GLNetSock
  used.i : os.i : kind.i : family.i
EndStructure
; A caller supplies only work it can consume: readable data already reported to a guest, or a
; permanently writable socket, must not turn an idle wait into a busy loop. Rebuild the interest
; set before each wait. Masks are the GL_NetPoll bits (1 read, 2 write); errors always wake it.
Global Dim GL_NetWaitMask.i(#GL_NET_MAX)
Global Dim GL_NetSocks.GLNetSock(#GL_NET_MAX)
Global GL_NetLib.i, GL_NetReady.i, GL_NetOsError.i, GL_NetFromAddr$, GL_NetFromPort.i
Global GL_NetSocketF.GLNetSocket, GL_NetCloseF.GLNetClose, GL_NetPollF.GLNetPollFn, GL_NetAcceptF.GLNetAcceptFn
Global GL_NetConnectF.GLNetConnectFn, GL_NetBindF.GLNetBindFn, GL_NetListenF.GLNetListenFn
Global GL_NetSendF.GLNetSendFn, GL_NetRecvF.GLNetRecvFn, GL_NetSendToF.GLNetSendToFn, GL_NetRecvFromF.GLNetRecvFromFn
Global GL_NetShutdownF.GLNetShutdownFn, GL_NetGAIF.GLNetGetAddrInfo, GL_NetFAIF.GLNetFreeAddrInfo
Global GL_NetGSOF.GLNetGetSockOpt, GL_NetGSNF.GLNetGetSockName
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Global GL_NetIoctlF.GLNetIoctl, GL_NetLastErrF.GLNetLastErr
CompilerElse
  Global GL_NetFcntlF.GLNetFcntl, GL_NetErrnoF.GLNetErrnoLoc
CompilerEndIf

Procedure.i GL_NetInit()
  If GL_NetReady : ProcedureReturn #True : EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected *wsa, st.GLNetWSAStartup
    GL_NetLib = OpenLibrary(#PB_Any, "ws2_32.dll")
    If GL_NetLib = 0 : ProcedureReturn #False : EndIf
    st = GetFunction(GL_NetLib, "WSAStartup")
    GL_NetSocketF = GetFunction(GL_NetLib, "socket") : GL_NetCloseF = GetFunction(GL_NetLib, "closesocket")
    GL_NetIoctlF = GetFunction(GL_NetLib, "ioctlsocket") : GL_NetLastErrF = GetFunction(GL_NetLib, "WSAGetLastError")
    GL_NetPollF = GetFunction(GL_NetLib, "WSAPoll")
  CompilerElse
    GL_NetLib = OpenLibrary(#PB_Any, "libc.so.6")
    If GL_NetLib = 0 : ProcedureReturn #False : EndIf
    GL_NetSocketF = GetFunction(GL_NetLib, "socket") : GL_NetCloseF = GetFunction(GL_NetLib, "close")
    GL_NetFcntlF = GetFunction(GL_NetLib, "fcntl") : GL_NetErrnoF = GetFunction(GL_NetLib, "__errno_location")
    GL_NetPollF = GetFunction(GL_NetLib, "poll")
  CompilerEndIf
  GL_NetAcceptF = GetFunction(GL_NetLib, "accept") : GL_NetConnectF = GetFunction(GL_NetLib, "connect")
  GL_NetBindF = GetFunction(GL_NetLib, "bind") : GL_NetListenF = GetFunction(GL_NetLib, "listen")
  GL_NetSendF = GetFunction(GL_NetLib, "send") : GL_NetRecvF = GetFunction(GL_NetLib, "recv")
  GL_NetSendToF = GetFunction(GL_NetLib, "sendto") : GL_NetRecvFromF = GetFunction(GL_NetLib, "recvfrom")
  GL_NetShutdownF = GetFunction(GL_NetLib, "shutdown") : GL_NetGAIF = GetFunction(GL_NetLib, "getaddrinfo")
  GL_NetFAIF = GetFunction(GL_NetLib, "freeaddrinfo") : GL_NetGSOF = GetFunction(GL_NetLib, "getsockopt")
  GL_NetGSNF = GetFunction(GL_NetLib, "getsockname")
  If GL_NetSocketF = 0 Or GL_NetCloseF = 0 Or GL_NetPollF = 0 Or GL_NetAcceptF = 0 Or GL_NetConnectF = 0 Or
     GL_NetBindF = 0 Or GL_NetListenF = 0 Or GL_NetSendF = 0 Or GL_NetRecvF = 0 Or GL_NetSendToF = 0 Or
     GL_NetRecvFromF = 0 Or GL_NetShutdownF = 0 Or GL_NetGAIF = 0 Or GL_NetFAIF = 0 Or GL_NetGSOF = 0 Or GL_NetGSNF = 0
    CloseLibrary(GL_NetLib) : GL_NetLib = 0 : ProcedureReturn #False
  EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If st = 0 Or GL_NetIoctlF = 0 Or GL_NetLastErrF = 0 : CloseLibrary(GL_NetLib) : GL_NetLib = 0 : ProcedureReturn #False : EndIf
    *wsa = AllocateMemory(1024)
    If st($0202, *wsa) <> 0 : FreeMemory(*wsa) : CloseLibrary(GL_NetLib) : GL_NetLib = 0 : ProcedureReturn #False : EndIf
    FreeMemory(*wsa)
  CompilerElse
    If GL_NetFcntlF = 0 Or GL_NetErrnoF = 0 : CloseLibrary(GL_NetLib) : GL_NetLib = 0 : ProcedureReturn #False : EndIf
  CompilerEndIf
  GL_NetReady = #True
  ProcedureReturn #True
EndProcedure

; the OS's last error -> a #GL_NET_ code
Procedure.i GL_NetMapError()
  Protected e.i
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    e = GL_NetLastErrF()
    GL_NetOsError = e
    Select e
      Case 10035 : ProcedureReturn #GL_NET_WOULDBLOCK
      Case 10036, 10037 : ProcedureReturn #GL_NET_INPROGRESS
      Case 10061 : ProcedureReturn #GL_NET_REFUSED
      Case 10054, 10053, 10052, 10058 : ProcedureReturn #GL_NET_RESET
      Case 10050, 10051, 10065 : ProcedureReturn #GL_NET_UNREACHABLE
      Case 10060 : ProcedureReturn #GL_NET_TIMEDOUT
      Case 10048 : ProcedureReturn #GL_NET_ADDRINUSE
      Case 10057 : ProcedureReturn #GL_NET_NOTCONN
      Case 10014, 10022, 10047, 10049 : ProcedureReturn #GL_NET_BADARG
    EndSelect
  CompilerElse
    e = PeekL(GL_NetErrnoF())
    GL_NetOsError = e
    Select e
      Case 11 : ProcedureReturn #GL_NET_WOULDBLOCK
      Case 115, 114 : ProcedureReturn #GL_NET_INPROGRESS
      Case 111 : ProcedureReturn #GL_NET_REFUSED
      Case 104, 32, 103 : ProcedureReturn #GL_NET_RESET
      Case 100, 101, 113 : ProcedureReturn #GL_NET_UNREACHABLE
      Case 110 : ProcedureReturn #GL_NET_TIMEDOUT
      Case 98 : ProcedureReturn #GL_NET_ADDRINUSE
      Case 107 : ProcedureReturn #GL_NET_NOTCONN
      Case 14, 22, 97, 99 : ProcedureReturn #GL_NET_BADARG
    EndSelect
  CompilerEndIf
  ProcedureReturn #GL_NET_OTHER
EndProcedure

Procedure.i GL_NetValid(h.i)
  ProcedureReturn Bool(GL_NetReady And h >= 1 And h <= #GL_NET_MAX And GL_NetSocks(h)\used)
EndProcedure

Procedure.i GL_NetNonBlock(os.i)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected one.l = 1
    ProcedureReturn Bool(GL_NetIoctlF(os, $8004667E, @one) = 0)     ; FIONBIO
  CompilerElse
    Protected fl.l = GL_NetFcntlF(os, 3, 0)                         ; F_GETFL
    If fl < 0 : ProcedureReturn #False : EndIf
    ProcedureReturn Bool(GL_NetFcntlF(os, 4, fl | $800) = 0)        ; F_SETFL, O_NONBLOCK
  CompilerEndIf
EndProcedure

Procedure.i GL_NetAdopt(os.i, kind.i, family.i)     ; a new OS socket -> a handle (closed when the table is full)
  Protected h.i
  For h = 1 To #GL_NET_MAX
    If Not GL_NetSocks(h)\used
      GL_NetSocks(h)\used = #True : GL_NetSocks(h)\os = os : GL_NetSocks(h)\kind = kind : GL_NetSocks(h)\family = family
      ProcedureReturn h
    EndIf
  Next
  GL_NetCloseF(os)
  ProcedureReturn #GL_NET_FULL
EndProcedure

Procedure.i GL_NetOpen(Kind.i, Family.i = 4)
  Protected af.i = 2, os.i
  If Not GL_NetReady : ProcedureReturn #GL_NET_UNAVAILABLE : EndIf
  If (Kind <> #GL_NET_TCP And Kind <> #GL_NET_UDP) Or (Family <> 4 And Family <> 6) : ProcedureReturn #GL_NET_BADARG : EndIf
  If Family = 6 : af = #GL_NET_AF6 : EndIf
  If Kind = #GL_NET_TCP
    os = GL_NetSocketF(af, 1, 6)                                   ; SOCK_STREAM, IPPROTO_TCP
  Else
    os = GL_NetSocketF(af, 2, 17)                                  ; SOCK_DGRAM, IPPROTO_UDP
  EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If os = -1 Or os = 0 : ProcedureReturn GL_NetMapError() : EndIf
  CompilerElse
    If os < 0 : ProcedureReturn GL_NetMapError() : EndIf
  CompilerEndIf
  If Not GL_NetNonBlock(os) : GL_NetCloseF(os) : ProcedureReturn #GL_NET_OTHER : EndIf
  ProcedureReturn GL_NetAdopt(os, Kind, Family)
EndProcedure

; a numeric address and a port -> a sockaddr in *sa (28 bytes); its length, or 0 for a bad address
Procedure.i GL_NetAddr(Addr$, Port.i, Family.i, *sa, Numeric.i = #True)
  Protected hints.GLNetHints, *res, *ai, rc.i, len.i, *sa2
  If Port < 0 Or Port > 65535 : ProcedureReturn 0 : EndIf
  FillMemory(@hints, SizeOf(GLNetHints), 0)
  If Numeric : PokeL(@hints, 4) : EndIf                           ; ai_flags AI_NUMERICHOST (4 on both)
  If Family = 6 : PokeL(@hints + 4, #GL_NET_AF6) : Else : PokeL(@hints + 4, 2) : EndIf
  rc = GL_NetGAIF(Addr$, 0, @hints, @*res)
  If rc <> 0 Or *res = 0 : ProcedureReturn 0 : EndIf
  *sa2 = PeekI(*res + #GL_NET_AIADDR)
  If Family = 6 : len = 28 : Else : len = 16 : EndIf
  If *sa2 : CopyMemory(*sa2, *sa, len) : Else : len = 0 : EndIf
  GL_NetFAIF(*res)
  If len
    PokeA(*sa + 2, (Port >> 8) & 255) : PokeA(*sa + 3, Port & 255) ; network byte order
  EndIf
  ProcedureReturn len
EndProcedure

Procedure.s GL_NetAddrText(*sa)                    ; a sockaddr -> its numeric text; GL_NetFromPort = its port
  Protected s$, i.i, fam.i = PeekU(*sa)
  GL_NetFromPort = (PeekA(*sa + 2) << 8) | PeekA(*sa + 3)
  If fam = 2
    ProcedureReturn Str(PeekA(*sa + 4)) + "." + Str(PeekA(*sa + 5)) + "." + Str(PeekA(*sa + 6)) + "." + Str(PeekA(*sa + 7))
  EndIf
  For i = 0 To 7
    If i : s$ + ":" : EndIf
    s$ + LCase(Hex((PeekA(*sa + 8 + 2 * i) << 8) | PeekA(*sa + 9 + 2 * i)))
  Next
  ProcedureReturn s$
EndProcedure

Procedure.i GL_NetBind(h.i, Addr$, Port.i)
  Protected sa.GLNetSa, len.i
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  len = GL_NetAddr(Addr$, Port, GL_NetSocks(h)\family, @sa)
  If len = 0 : ProcedureReturn #GL_NET_BADARG : EndIf
  If GL_NetBindF(GL_NetSocks(h)\os, @sa, len) <> 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i GL_NetListen(h.i, Backlog.i = 16)
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If GL_NetSocks(h)\kind <> #GL_NET_TCP : ProcedureReturn #GL_NET_BADARG : EndIf
  If GL_NetListenF(GL_NetSocks(h)\os, Backlog) <> 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i GL_NetAccept(h.i)
  Protected os.i, sa.GLNetSa, len.l = 28
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  os = GL_NetAcceptF(GL_NetSocks(h)\os, @sa, @len)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If os = -1 Or os = 0 : ProcedureReturn GL_NetMapError() : EndIf
  CompilerElse
    If os < 0 : ProcedureReturn GL_NetMapError() : EndIf
  CompilerEndIf
  GL_NetFromAddr$ = GL_NetAddrText(@sa)
  If Not GL_NetNonBlock(os) : GL_NetCloseF(os) : ProcedureReturn #GL_NET_OTHER : EndIf
  ProcedureReturn GL_NetAdopt(os, #GL_NET_TCP, GL_NetSocks(h)\family)
EndProcedure

Procedure.i GL_NetConnect(h.i, Addr$, Port.i)
  Protected sa.GLNetSa, len.i, e.i
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  len = GL_NetAddr(Addr$, Port, GL_NetSocks(h)\family, @sa)
  If len = 0 : ProcedureReturn #GL_NET_BADARG : EndIf
  If GL_NetConnectF(GL_NetSocks(h)\os, @sa, len) = 0 : ProcedureReturn 0 : EndIf
  e = GL_NetMapError()
  If e = #GL_NET_WOULDBLOCK : e = #GL_NET_INPROGRESS : EndIf     ; Windows says WOULDBLOCK for a started connect
  ProcedureReturn e
EndProcedure

Procedure.i GL_NetError(h.i)                       ; SO_ERROR: a non-blocking connect's outcome (0 = connected)
  Protected v.l, len.l = 4
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If GL_NetGSOF(GL_NetSocks(h)\os, #GL_NET_SOL, #GL_NET_SOERR, @v, @len) <> 0 : ProcedureReturn GL_NetMapError() : EndIf
  If v = 0 : ProcedureReturn 0 : EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Select v
      Case 10061 : ProcedureReturn #GL_NET_REFUSED
      Case 10060 : ProcedureReturn #GL_NET_TIMEDOUT
      Case 10050, 10051, 10065 : ProcedureReturn #GL_NET_UNREACHABLE
    EndSelect
  CompilerElse
    Select v
      Case 111 : ProcedureReturn #GL_NET_REFUSED
      Case 110 : ProcedureReturn #GL_NET_TIMEDOUT
      Case 100, 101, 113 : ProcedureReturn #GL_NET_UNREACHABLE
    EndSelect
  CompilerEndIf
  GL_NetOsError = v
  ProcedureReturn #GL_NET_OTHER
EndProcedure

Procedure.i GL_NetSendFlags()
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    ProcedureReturn $4000                                          ; MSG_NOSIGNAL
  CompilerElse
    ProcedureReturn 0
  CompilerEndIf
EndProcedure

Procedure.i GL_NetSend(h.i, *Buf, Len.i)
  Protected n.i
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If Len < 0 Or Len > $7FFFFFFF Or (*Buf = 0 And Len) : ProcedureReturn #GL_NET_BADARG : EndIf
  n = GL_NetSendF(GL_NetSocks(h)\os, *Buf, Len, GL_NetSendFlags())
  If n < 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn n
EndProcedure

Procedure.i GL_NetSendTo(h.i, *Buf, Len.i, Addr$, Port.i)
  Protected sa.GLNetSa, salen.i, n.i
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If Len < 0 Or Len > $7FFFFFFF Or (*Buf = 0 And Len) : ProcedureReturn #GL_NET_BADARG : EndIf
  salen = GL_NetAddr(Addr$, Port, GL_NetSocks(h)\family, @sa)
  If salen = 0 : ProcedureReturn #GL_NET_BADARG : EndIf
  n = GL_NetSendToF(GL_NetSocks(h)\os, *Buf, Len, GL_NetSendFlags(), @sa, salen)
  If n < 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn n
EndProcedure

Procedure.i GL_NetRecv(h.i, *Buf, Cap.i)
  Protected n.i
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If Cap <= 0 Or Cap > $7FFFFFFF Or *Buf = 0 : ProcedureReturn #GL_NET_BADARG : EndIf
  n = GL_NetRecvF(GL_NetSocks(h)\os, *Buf, Cap, 0)
  If n < 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn n
EndProcedure

Procedure.i GL_NetRecvFrom(h.i, *Buf, Cap.i)
  Protected n.i, sa.GLNetSa, len.l = 28
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If Cap <= 0 Or Cap > $7FFFFFFF Or *Buf = 0 : ProcedureReturn #GL_NET_BADARG : EndIf
  n = GL_NetRecvFromF(GL_NetSocks(h)\os, *Buf, Cap, 0, @sa, @len)
  If n < 0 : ProcedureReturn GL_NetMapError() : EndIf
  GL_NetFromAddr$ = GL_NetAddrText(@sa)
  ProcedureReturn n
EndProcedure

Procedure.i GL_NetPoll(h.i)                        ; bit0 readable, bit1 writable, bit2 error / hang-up
  Protected fd.GLNetSa, rc.i, rev.i, r.i
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  FillMemory(@fd, 16, 0)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    PokeQ(@fd, GL_NetSocks(h)\os) : PokeW(@fd + 8, $0110)         ; WSAPOLLFD: POLLRDNORM | POLLWRNORM
    rc = GL_NetPollF(@fd, 1, 0)
    If rc < 0 : ProcedureReturn GL_NetMapError() : EndIf
    rev = PeekW(@fd + 10) & $FFFF
    If rev & $0100 : r | 1 : EndIf
    If rev & $0010 : r | 2 : EndIf
    If rev & $0007 : r | 4 : EndIf                                 ; POLLERR, POLLHUP, POLLNVAL
    If rev & $0002 : r | 1 : EndIf                                 ; a hang-up reads as 0 bytes
  CompilerElse
    PokeL(@fd, GL_NetSocks(h)\os) : PokeW(@fd + 4, 5)             ; pollfd: POLLIN | POLLOUT
    rc = GL_NetPollF(@fd, 1, 0)
    If rc < 0 : ProcedureReturn GL_NetMapError() : EndIf
    rev = PeekW(@fd + 6) & $FFFF
    If rev & 1 : r | 1 : EndIf
    If rev & 4 : r | 2 : EndIf
    If rev & $38 : r | 4 : EndIf                                   ; POLLERR, POLLHUP, POLLNVAL
    If rev & $10 : r | 1 : EndIf
  CompilerEndIf
  ProcedureReturn r
EndProcedure

Procedure GL_NetWaitBegin()
  Protected h.i
  For h = 1 To #GL_NET_MAX : GL_NetWaitMask(h) = 0 : Next
EndProcedure

Procedure.i GL_NetWaitAdd(h.i, Mask.i)
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If Mask < 1 Or Mask > 3 : ProcedureReturn #GL_NET_BADARG : EndIf
  GL_NetWaitMask(h) | Mask
  ProcedureReturn 0
EndProcedure

; Sleep in the OS readiness wait, without opening/closing/consuming a socket. Windows WSAPoll
; uses 16-byte WSAPOLLFDs (SOCKET is 64-bit); Linux poll uses 8-byte pollfds (fd is 32-bit).
; timeout is milliseconds, >= 0. Return ready count, 0 at the deadline, or a GL_NET error.
Procedure.i GL_NetWait(Milliseconds.i)
  Protected Dim fds.a(#GL_NET_MAX * 16), h.i, n.i, stride.i, mask.i, r.i
  If Milliseconds < 0 : ProcedureReturn #GL_NET_BADARG : EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    stride = 16
  CompilerElse
    stride = 8
  CompilerEndIf
  For h = 1 To #GL_NET_MAX
    If GL_NetWaitMask(h) And GL_NetValid(h)
      mask = 0
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        PokeI(@fds(n * stride), GL_NetSocks(h)\os)
        If GL_NetWaitMask(h) & 1 : mask | $100 : EndIf   ; POLLRDNORM
        If GL_NetWaitMask(h) & 2 : mask | $10 : EndIf    ; POLLWRNORM
        PokeW(@fds(n * stride + 8), mask)
      CompilerElse
        PokeL(@fds(n * stride), GL_NetSocks(h)\os)
        If GL_NetWaitMask(h) & 1 : mask | 1 : EndIf      ; POLLIN
        If GL_NetWaitMask(h) & 2 : mask | 4 : EndIf      ; POLLOUT
        PokeW(@fds(n * stride + 4), mask)
      CompilerEndIf
      n + 1
    EndIf
  Next
  If n = 0 : Delay(Milliseconds) : ProcedureReturn 0 : EndIf
  r = GL_NetPollF(@fds(0), n, Milliseconds)
  If r < 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn r
EndProcedure

Procedure.i GL_NetShutdown(h.i, How.i)
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If How < 0 Or How > 2 : ProcedureReturn #GL_NET_BADARG : EndIf
  If GL_NetShutdownF(GL_NetSocks(h)\os, How) <> 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn 0
EndProcedure

Procedure.i GL_NetClose(h.i)
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  GL_NetCloseF(GL_NetSocks(h)\os)
  GL_NetSocks(h)\used = #False : GL_NetSocks(h)\os = 0
  ProcedureReturn 0
EndProcedure

Procedure.i GL_NetLocalPort(h.i)
  Protected sa.GLNetSa, len.l = 28
  If Not GL_NetValid(h) : ProcedureReturn #GL_NET_BADHANDLE : EndIf
  If GL_NetGSNF(GL_NetSocks(h)\os, @sa, @len) <> 0 : ProcedureReturn GL_NetMapError() : EndIf
  ProcedureReturn (PeekA(@sa + 2) << 8) | PeekA(@sa + 3)
EndProcedure

Procedure.s GL_NetResolve(Name$, Family.i = 4)    ; BLOCKING (the system resolver): "" when it fails
  Protected sa.GLNetSa
  If Not GL_NetReady Or Name$ = "" : ProcedureReturn "" : EndIf
  If GL_NetAddr(Name$, 0, Family, @sa, #False) = 0 : ProcedureReturn "" : EndIf
  ProcedureReturn GL_NetAddrText(@sa)
EndProcedure
