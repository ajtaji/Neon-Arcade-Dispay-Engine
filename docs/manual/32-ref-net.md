# GlNet.pbi

Sockets (chapter 16 is the guide, with the table of result codes). Every procedure that takes a handle returns `#GL_NET_BADHANDLE` for one that is not open, and `#GL_NET_UNAVAILABLE` comes back from `GL_NetOpen` before `GL_NetInit` has succeeded.

## Constants and globals

- `#GL_NET_TCP` (1), `#GL_NET_UDP` (2) - the kinds of socket. `#GL_NET_MAX` - 256 sockets open at once.
- The result codes `#GL_NET_WOULDBLOCK` (-1), `#GL_NET_INPROGRESS`, `#GL_NET_REFUSED`, `#GL_NET_RESET`, `#GL_NET_UNREACHABLE`, `#GL_NET_TIMEDOUT`, `#GL_NET_ADDRINUSE`, `#GL_NET_NOTCONN`, `#GL_NET_BADHANDLE`, `#GL_NET_BADARG`, `#GL_NET_NORESOLVE`, `#GL_NET_UNAVAILABLE`, `#GL_NET_FULL`, `#GL_NET_OTHER` (-14): chapter 16.
- `GL_NetFromAddr$`, `GL_NetFromPort` - the peer of the last `GL_NetAccept`, or the sender of the last `GL_NetRecvFrom`, as numeric text and a port. `GL_NetOsError` - the system's own number for the last error mapped.

Internal: `GL_NetMapError`, `GL_NetValid`, `GL_NetNonBlock`, `GL_NetAdopt`, `GL_NetAddr`, `GL_NetAddrText`, `GL_NetSendFlags`

### GL_NetInit

Loads the socket library and its functions (and starts Winsock 2.2 on Windows). `#True` when sockets are available; calling it again does nothing more.

### GL_NetOpen

A non-blocking socket: `Kind` `#GL_NET_TCP` or `#GL_NET_UDP`, `Family` 4 (the default) or 6. Returns a handle (1 to 256), or `#GL_NET_UNAVAILABLE`, `#GL_NET_BADARG`, `#GL_NET_FULL`, or the system's error.

### GL_NetBind

Binds a socket to a numeric address and a port (0 to 65535; 0 lets the system pick). 0, or `#GL_NET_BADARG` for an address that is not numeric or not of the socket's family, or the system's error (`#GL_NET_ADDRINUSE` ...).

### GL_NetListen

Starts a TCP socket accepting connections, with a queue of `Backlog` (16). 0, `#GL_NET_BADARG` for a UDP socket, or an error.

### GL_NetAccept

A waiting connection on a listening socket, as a new non-blocking handle; its peer in `GL_NetFromAddr$` and `GL_NetFromPort`. `#GL_NET_WOULDBLOCK` when none is waiting.

### GL_NetConnect

Starts a connection to a numeric address and port. 0 when connected at once, `#GL_NET_INPROGRESS` while it goes on (wait until `GL_NetPoll` says writable, then `GL_NetError`), `#GL_NET_BADARG`, or an error.

### GL_NetError

The outcome of a connection that was in progress: 0 connected, or `#GL_NET_REFUSED`, `#GL_NET_TIMEDOUT`, `#GL_NET_UNREACHABLE`, `#GL_NET_OTHER` (the system's number in `GL_NetOsError`).

### GL_NetSend

Sends `Len` bytes from `*Buf` on a connected socket. The bytes sent (possibly fewer than `Len`: send the rest later), `#GL_NET_WOULDBLOCK`, `#GL_NET_BADARG` (a length below 0 or above 2^31 - 1, or no buffer), or an error (`#GL_NET_RESET` when the peer has gone).

### GL_NetSendTo

Sends a UDP datagram of `Len` bytes to a numeric address and port. The bytes sent, or an error.

### GL_NetRecv

Receives up to `Cap` bytes into `*Buf`. The bytes received; 0 when a TCP peer has closed; `#GL_NET_WOULDBLOCK` when nothing has arrived; `#GL_NET_BADARG` for a capacity of 0 or less or no buffer; or an error.

### GL_NetRecvFrom

Receives a datagram of up to `Cap` bytes, its sender in `GL_NetFromAddr$` and `GL_NetFromPort`. Results as `GL_NetRecv`.

### GL_NetPoll

What a socket is ready for, without waiting: bit 0 readable (data, a waiting connection, or a peer that closed), bit 1 writable (a connection completed), bit 2 an error or hang-up; or an error code.

### GL_NetWaitBegin

Empties the set of sockets `GL_NetWait` waits on.

### GL_NetWaitAdd

Adds a socket to the wait: `Mask` 1 readable, 2 writable, 3 both. 0, or `#GL_NET_BADARG` for another mask.

### GL_NetWait

Waits up to `Milliseconds` (0 or more) until a socket of the set is ready as asked, or has an error. The number ready, 0 when the time passed, `#GL_NET_BADARG` for a negative time, or an error. With an empty set it sleeps for the time and returns 0. Nothing is read.

### GL_NetShutdown

Ends receiving (`How` 0), sending (1) or both (2) on a connection. 0, `#GL_NET_BADARG`, or an error.

### GL_NetClose

Closes a socket and frees its handle. 0.

### GL_NetLocalPort

The port a socket is bound to (the one the system picked after a bind to port 0), or an error.

### GL_NetResolve

The first address of the host `Name$` in `Family` (4 or 6) as numeric text, asking the system's resolver (it waits as long as that takes); "" when it fails or `GL_NetInit` has not succeeded. It sets `GL_NetFromPort` to 0 as it works.
