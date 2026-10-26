# Neon Arcade Display Engine

A PureBasic 2D rendering and user-interface framework built on OpenGL. The engine uses a fixed-resolution framebuffer for game rendering, preserves aspect ratio when the window changes size, and maps input back into virtual-canvas coordinates.

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

Every item in both lists produces a *wrong-looking UI* rather than an error:
a blank window, controls with frames but no labels, soft text, or widgets
that vanish inside a scissor. None of them raise anything.
