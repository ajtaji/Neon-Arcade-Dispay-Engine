; udp_echo.pb - two sockets on the loopback address: a UDP datagram sent, waited for and echoed back,
; and a TCP connection made without blocking. No window; nothing leaves the machine.
; Build:  pbcompiler udp_echo.pb /CONSOLE /EXE udp_echo.exe
EnableExplicit
#Engine$ = #PB_Compiler_FilePath + "../../../"
XIncludeFile #Engine$ + "GlNet.pbi"
OpenConsole()

If Not GL_NetInit() : PrintN("no socket library") : End 1 : EndIf
Define Server.i = GL_NetOpen(#GL_NET_UDP), Client.i = GL_NetOpen(#GL_NET_UDP)
If Server < 0 Or Client < 0 : PrintN("open failed: " + Str(Server) + " " + Str(Client)) : End 1 : EndIf
GL_NetBind(Server, "127.0.0.1", 0)                  ; port 0: the system picks a free one
Define Port.i = GL_NetLocalPort(Server)
PrintN("server bound to 127.0.0.1:" + Str(Port))

Define *Buf = AllocateMemory(256), Msg.s = "hello", n.i
PokeS(*Buf, Msg, -1, #PB_UTF8)
n = GL_NetSendTo(Client, *Buf, StringByteLength(Msg, #PB_UTF8), "127.0.0.1", Port)
PrintN("sent " + Str(n) + " bytes")

GL_NetWaitBegin() : GL_NetWaitAdd(Server, 1)       ; wake when the server has something to read
PrintN("ready sockets: " + Str(GL_NetWait(1000)))
n = GL_NetRecvFrom(Server, *Buf, 256)
PrintN("server got " + Str(n) + " bytes: " + PeekS(*Buf, n, #PB_UTF8) +
       " from " + GL_NetFromAddr$ + ":" + Str(GL_NetFromPort))
GL_NetSendTo(Server, *Buf, n, GL_NetFromAddr$, GL_NetFromPort)     ; echo it back to the sender

Define Tries.i
Repeat
  n = GL_NetRecvFrom(Client, *Buf, 256)
  If n = #GL_NET_WOULDBLOCK : Delay(5) : Tries + 1 : EndIf         ; nothing yet: try again later
Until n <> #GL_NET_WOULDBLOCK Or Tries > 200
PrintN("client got the echo: " + Str(n) + " bytes")

; TCP: a listener, a connect that returns at once, then readiness and the outcome
Define Listener.i = GL_NetOpen(#GL_NET_TCP), Conn.i = GL_NetOpen(#GL_NET_TCP), Peer.i
GL_NetBind(Listener, "127.0.0.1", 0) : GL_NetListen(Listener)
n = GL_NetConnect(Conn, "127.0.0.1", GL_NetLocalPort(Listener))
PrintN("connect: " + Str(n) + " (0 connected, " + Str(#GL_NET_INPROGRESS) + " in progress)")
Tries = 0
While GL_NetPoll(Conn) & 2 = 0 And Tries < 200 : Delay(5) : Tries + 1 : Wend
PrintN("writable; outcome " + Str(GL_NetError(Conn)))
Tries = 0
Repeat : Peer = GL_NetAccept(Listener) : If Peer = #GL_NET_WOULDBLOCK : Delay(5) : Tries + 1 : EndIf
Until Peer <> #GL_NET_WOULDBLOCK Or Tries > 200
PrintN("accepted handle " + Str(Peer) + " from " + GL_NetFromAddr$)
PrintN("a refused call: GL_NetSend on handle 999 = " + Str(GL_NetSend(999, *Buf, 1)) + " (#GL_NET_BADHANDLE)")
GL_NetClose(Peer) : GL_NetClose(Conn) : GL_NetClose(Listener) : GL_NetClose(Client) : GL_NetClose(Server)
