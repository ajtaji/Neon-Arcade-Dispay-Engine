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

For DPI-aware builds, enable PureBasic's **DPI aware** compiler option.
