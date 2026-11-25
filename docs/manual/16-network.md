# Networking

`GlNet.pbi` gives a program TCP and UDP sockets over IPv4 and IPv6, and name resolution, without calling the operating system itself. It loads the system's socket library when `GL_NetInit` is first called (ws2_32.dll on Windows, the C library on Linux), so a program that never calls it loads nothing. It uses nothing else of the engine and works in a program with no window.

## The model

| Call | Does | Returns |
|---|---|---|
| `GL_NetInit()` | loads the socket library | `#True` when sockets are available |
| `GL_NetOpen(Kind, Family)` | a socket: `#GL_NET_TCP` or `#GL_NET_UDP`, IPv4 (`Family` 4) or IPv6 (6) | a handle of 1 or more, or an error |
| `GL_NetBind(h, Address, Port)` | binds to a numeric address and a port (0: the system picks one) | 0 or an error |
| `GL_NetListen(h, Backlog)` | a TCP socket starts accepting | 0 or an error |
| `GL_NetAccept(h)` | a waiting connection, as a new handle; the peer's address and port in `GL_NetFromAddr$`, `GL_NetFromPort` | a handle, `#GL_NET_WOULDBLOCK`, or an error |
| `GL_NetConnect(h, Address, Port)` | starts a connection to a numeric address | 0 (connected), `#GL_NET_INPROGRESS`, or an error |
| `GL_NetError(h)` | the outcome of a connection that was in progress | 0 (connected) or an error |
| `GL_NetSend(h, *Buffer, Length)` | sends on a connected socket | bytes sent, `#GL_NET_WOULDBLOCK`, or an error |
| `GL_NetSendTo(h, *Buffer, Length, Address, Port)` | sends a UDP datagram | bytes sent, or an error |
| `GL_NetRecv(h, *Buffer, Capacity)` | receives, never more than `Capacity` bytes | bytes received, 0 when a TCP peer has closed, `#GL_NET_WOULDBLOCK`, or an error |
| `GL_NetRecvFrom(h, *Buffer, Capacity)` | receives a datagram; the sender in `GL_NetFromAddr$`, `GL_NetFromPort` | bytes, `#GL_NET_WOULDBLOCK`, or an error |
| `GL_NetPoll(h)` | what a socket is ready for now | bit 0 readable, bit 1 writable, bit 2 an error or hang-up; or an error |
| `GL_NetWaitBegin()`, `GL_NetWaitAdd(h, Mask)`, `GL_NetWait(Ms)` | wait, sleeping, until one of the chosen sockets is ready or the time passes | the number ready, 0 at the deadline, or an error |
| `GL_NetShutdown(h, How)` | ends receiving (0), sending (1) or both (2) | 0 or an error |
| `GL_NetClose(h)` | closes the socket and frees the handle | 0 or an error |
| `GL_NetLocalPort(h)` | the port a socket is bound to | the port, or an error |
| `GL_NetResolve(Name, Family)` | the first address of a host name, as text | the address, or "" |

**Every socket is non-blocking.** A call that would have to wait returns `#GL_NET_WOULDBLOCK` (try again later) or, for a connection, `#GL_NET_INPROGRESS` (poll for writable, then `GL_NetError`). Two calls wait: `GL_NetWait`, by design, and `GL_NetResolve`, which asks the system's resolver and takes as long as that does - call it away from the frame loop. At most 256 sockets are open at once (`#GL_NET_MAX`).

`GL_NetWait` waits on the sockets added since `GL_NetWaitBegin`: `Mask` 1 to wake when one is readable, 2 when writable, 3 for either; an error always wakes it. It consumes nothing. Add only what the program will act on: a socket that is always writable, added for writing, wakes the wait at once every time. With nothing added it simply sleeps for the time.

## Result codes

Every failure is a negative result code, the same on both systems; zero and positive values are successes. The system's own error number is kept in `GL_NetOsError` for diagnosis.

| Code | Value | Meaning |
|---|---|---|
| `#GL_NET_WOULDBLOCK` | -1 | nothing now: try again later |
| `#GL_NET_INPROGRESS` | -2 | a connection has started |
| `#GL_NET_REFUSED` | -3 | nothing is listening there |
| `#GL_NET_RESET` | -4 | the connection was reset, or the peer is gone |
| `#GL_NET_UNREACHABLE` | -5 | the network or the host cannot be reached |
| `#GL_NET_TIMEDOUT` | -6 | the connection timed out |
| `#GL_NET_ADDRINUSE` | -7 | the address and port are taken |
| `#GL_NET_NOTCONN` | -8 | the socket is not connected |
| `#GL_NET_BADHANDLE` | -9 | not an open handle |
| `#GL_NET_BADARG` | -10 | a bad address, port, kind or buffer |
| `#GL_NET_NORESOLVE` | -11 | a name could not be resolved (defined for that; no procedure returns it now: `GL_NetResolve` returns "" instead) |
| `#GL_NET_UNAVAILABLE` | -12 | no socket library, or `GL_NetInit` was not called or failed |
| `#GL_NET_FULL` | -13 | 256 sockets are open |
| `#GL_NET_OTHER` | -14 | any other failure |

## Addresses

Addresses are numeric text: `"127.0.0.1"`, `"::1"`, `"0.0.0.0"`, `"::"`. A name is turned into an address with `GL_NetResolve` first. The addresses the module writes (`GL_NetFromAddr$`, `GL_NetResolve`) are numeric too; an IPv6 address is written as its eight groups in full, without the `::` shortening.

## Security

- **Nothing listens unless the program asks.** `GL_NetInit` opens no socket; a socket accepts connections only after `GL_NetListen`, or receives datagrams only after a UDP socket is bound.
- **Bind to the loopback address** (`127.0.0.1` or `::1`) unless the user asked to be reachable from the network. A socket bound to `0.0.0.0` or `::` can be reached by every machine that can reach this one, as far as the firewall lets it. The engine never chooses an address: `GL_NetBind` needs one.
- **A program that gives sockets to code it runs** - an emulator handing them to a guest program, a scripting host - gives that code network access with the user's rights. Put a rule in front of it (what may be connected to, what may listen, whether at all), off unless the user turns it on.
- **Received bytes are data from anyone.** Check them before using them. `GL_NetRecv` never writes past `Capacity`.
- On Linux, sending to a TCP peer that has gone returns `#GL_NET_RESET` and raises no signal.

## A worked example

A datagram sent between two sockets on the loopback address and echoed back, then a TCP connection made without blocking:

@include examples/udp_echo.pb

It printed:

@include examples/output/udp_echo.txt

The ports are chosen by the system and differ from run to run. `tests/GlNetTest.pb` in the repository checks the module more fully (appendix B).
