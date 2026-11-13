# Neon Arcade Display Engine

A PureBasic rendering and user-interface framework built on OpenGL. The engine uses a fixed-resolution framebuffer for game rendering, preserves aspect ratio when the window changes size, and maps input back into virtual-canvas coordinates.

## Current features

- OpenGL constants, extensions, feature flags, and procedure bindings
- Window and OpenGL context setup for Windows and Linux
- Fixed-resolution framebuffer rendering with letterboxing
- Camera translation and zoom
- Sprite loading, batching, animation data, and instanced particles
- AABB, circle, pixel-perfect, SAT, and line collision helpers
- Runtime glyph caching with Unicode code-point lookup and paged texture atlases
- Immediate-mode neon UI controls and application chrome
- CRT and passthrough presentation paths
- HiDPI-aware viewport and input mapping

## Requirements

- PureBasic
- An OpenGL-capable desktop environment

The platform-specific code currently covers Windows and Linux. Applications are responsible for selecting the PureBasic subsystems they use, such as image decoders, before loading assets.

## Include order

Place the engine files where the compiler can resolve the include paths, then include the modules needed by the application:

```purebasic
XIncludeFile "GlTypes.pbi"
XIncludeFile "GlUtilities.pbi"
XIncludeFile "GlMath.pbi"
XIncludeFile "GlSpriteFunctions.pbi"
XIncludeFile "GlUI.pbi"
XIncludeFile "GlUIChrome.pbi"
```

`GlUtilities.pbi` loads the OpenGL binding files. `GlUI.pbi` uses the collision helpers in `GlMath.pbi`. `GlUIChrome.pbi` provides the higher-level application chrome and can be omitted when it is not needed.

## Optional 3D module

Include `Gl3D.pbi` after `GlUtilities.pbi` for desktop OpenGL 3.3 and up.
Create the window as usual, call `InitRetroCRT`, capture the window context
with `GL_ContextCapture`, and initialize a `G3DPass` with `G3D_Init`.
The pass owns a depth renderbuffer on the existing Neon canvas. With
`Util_FBO` bound, render between `G3D_Begin` and `G3D_End`, draw the UI,
then present with `DrawPassthrough` or `DrawRetroCRT`. Free models with
`G3D_Free` and release the pass with `G3D_Shutdown` before closing the
owning context.

`G3D_Load` reads a glTF 2.0 `.glb` with PureBasic’s JSON reader. The loader
accepts triangle primitives with float positions and normals, indexed or
non-indexed geometry, one embedded buffer, and up to four joint influences
per vertex. It supports TRS and matrix nodes, inverse bind matrices, and
opaque factor-based metallic, roughness and emissive materials, including
emissive strength. Reflection comes from a studio environment defined in
the shader. External buffers, texture maps, sparse accessors, compressed
mesh extensions and morph targets are outside the current format support.

Use `G3D_Play(model, clip, blendSeconds)` for looping clips and crossfades,
`G3D_Update(model, deltaSeconds)` to advance animation and springs, and
`G3D_Draw(model, camera)` during the pass. The CPU builds the joint palette
and the vertex shader skins the vertices. `G3D_Spring` enables gravity and
damped motion for a named bone. `G3D_Impulse(model, x, y, z)` applies a
velocity impulse in model space. `G3D_Load` enables springs for common bust
and hip secondary-bone names. Use `G3D_LookAt` for a perspective camera and
`G3D_Mesh` to upload procedural triangles.

Applications can supply a vertex projection to the 3D pass when they
initialize it. Pass GLSL defining
`projectVertex(inout vec3 point, inout vec3 normal)` to `G3D_Init`.
Set its four `projectionParams` values with `G3D_SetProjection` between
`G3D_Begin` and `G3D_End`. The default pass uses the supplied mesh
positions and normals directly.

## Network host services (`GlNet.pbi`, optional)

`XIncludeFile "GlNet.pbi"` after `GlUtilities.pbi` gives an application TCP and UDP sockets and name resolution
without calling the OS: `GL_NetInit`, `GL_NetOpen`, `GL_NetBind`, `GL_NetListen`, `GL_NetAccept`, `GL_NetConnect`,
`GL_NetSend`/`GL_NetSendTo`, `GL_NetRecv`/`GL_NetRecvFrom`, `GL_NetPoll`, `GL_NetShutdown`, `GL_NetClose`,
`GL_NetResolve`, `GL_NetLocalPort`, `GL_NetError`. Windows uses ws2_32.dll and Linux uses libc, both loaded at run
time. Every socket is non-blocking, and every failure is a fixed result code (`#GL_NET_*`, the same on both
systems), never an assert. The one call that waits is `GL_NetResolve`, which uses the system resolver. The model
and the codes are at the top of the file. `tests/GlNetTest.pb` proves loopback TCP and UDP (31 checks; run on
Windows and on Linux).

**Security.**
- Nothing listens unless the application calls `GL_NetListen`, or binds a UDP socket. `GL_NetInit` opens nothing.
- Bind to loopback (`127.0.0.1` / `::1`) unless the user asked for the network. `0.0.0.0` or `::` is reachable from
  every machine that can reach this one. The engine never chooses an address for you.
- An emulator that hands sockets to a guest program gives untrusted code network access with the user's rights. Put
  a policy in front of it (what may be connected to, what may listen, whether at all), off by default. The engine
  is the mechanism; the policy is the application's.
- Received bytes come from anyone. `GL_NetRecv` never writes past its capacity. On Linux, a send to a closed peer
  returns `#GL_NET_RESET` and raises no SIGPIPE.

## Rendering flow

The usual frame renders the game into the engine framebuffer and then presents that framebuffer to the window:

```purebasic
glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)
glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)

; Draw the game world and interface here.

glBindFramebuffer(#GL_FRAMEBUFFER, 0)
glViewport_(GL_ViewportX, GL_ViewportY, GL_ViewportW, GL_ViewportH)
DrawRetroCRT() ; or DrawPassthrough()
```

Set `Util_BaseWidth` and `Util_BaseHeight` to the authored canvas size. Call `GL_HandleResize()` after creating the window and whenever PureBasic reports a window-size event. Pass mouse coordinates through `MapPhysicalToVirtual()` before UI hit testing.

**On Windows, give it `WindowMouseX(Win)` / `WindowMouseY(Win)` exactly as they are.** In a DPI-aware window they are already physical pixels (measured: 400 at physical x = 400 on a 125% desktop), while `WindowWidth`/`GadgetWidth` are logical. Multiplying the mouse by the scale, by `DesktopResolutionX()` or by physical/logical "to convert it" scales it twice. For a 1:1 application also set `Neon_UIScale` to physical/logical and build the fonts at that scale, or the chrome's tabs, rows and menus are sized at 100% beside a 125% layout. The full, measured checklist is section 5a of the hosting block in `GlUIChrome.pbi`.

For DPI-aware builds, enable PureBasic's **DPI aware** compiler option.

## Building an application against the engine

The engine's location is passed in, so no file needs editing per machine
(the trailing slash matters):

**Windows** (x64, from PowerShell)

```
pbcompiler App.pb /EXE App.exe /THREAD /DPIAWARE ^
   /CONSTANT GL_ENGINE_DIR$=C:/path/to/engine/
```

**Linux** — the flags differ: `/EXE` → `-o`, `/CONSOLE` → `-cl`, `/THREAD` → `-t`

```
pbcompiler App.pb -o App -t \
   --constant GL_ENGINE_DIR$=/path/to/engine/
```

`/DPIAWARE` is Windows-only and is not optional there: without it the OS
scales the whole window by the desktop factor, so a 1180-wide layout becomes
1475 at 125% and runs off the monitor. Linux has no equivalent switch and
needs none — GTK reports the backing scale at run time into `Linux_DPIScale`.

### Before you write any drawing code

Two comment blocks carry the things that otherwise get rediscovered:

- **`GlUtilities.pbi`, "HiDPI: THE FIVE THINGS"** — DPI, window sizing, the
  authored canvas, font sizing, and the three size globals and their units.
- **`GlUIChrome.pbi`, "HOSTING THIS ENGINE IN AN APPLICATION"** — the host
  checklist: let `OpenGLWindow()` make the window (it compiles the shaders
  every `Neon_` call needs), assign the chrome's four font globals, the
  per-frame pipeline, pixel snapping for sharp text, and `Neon_S()`.

- **`GlUtilities.pbi`, "HOST SERVICES"** — everything an application needs
  from the OS beyond a window, with a Windows and a Linux branch each, so the
  application itself never calls the OS: `GL_HostPrepare()` (first thing),
  a microsecond clock, physical core count, large zeroed memory, keys held and
  key names, full screen on the window's monitor, the pointer, the program's
  load address for crash reports, a second GL context for a worker thread,
  16-bit stereo sound out, the work area and the window's place, and game
  controllers. An application that needs something more from the OS adds it
  there, documented, rather than calling the OS itself.

Every item in both lists produces a *wrong-looking UI* rather than an error:
a blank window, controls with frames but no labels, soft text, or widgets
that vanish inside a scissor. None of them raise anything.

`GlClock.pbi` provides `GL_UtcMicroseconds()`: the host wall clock as Unix
microseconds in UTC, using Windows FILETIME or Linux CLOCK_REALTIME. It is
separate from the monotonic `GL_Micros()` timer and returns -1 when unavailable.
It inherits the host's time synchronization; it does not contact a time server
or apply a local timezone. Zentaji uses a recorded boot sample to seed its RTC.
