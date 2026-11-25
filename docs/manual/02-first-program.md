# A first program

## The smallest complete program

The program below opens a window, gives it a canvas of 320 by 240 units, and draws a box and a turning sprite into the canvas every frame. It is the shape every program in this manual has.

@include examples/first_program.pb

Line by line:

- `#Engine$` names the folder that holds the engine's files. The manual's examples sit three folders below it, in `docs/manual/examples/`; in a program of your own, set it to where your copy of the engine is (with the trailing slash). `XIncludeFile #Engine$ + "GlTypes.pbi"` and the lines after it bring in the three modules this program uses, in the order of chapter 1.
- `GL_HostPrepare()` comes before any window. On Windows it asks for per-monitor DPI awareness; on Linux it chooses X11 and makes the X library thread-safe.
- `OpenGLWindow(Title, Width, Height, Flags)` opens the window, puts an OpenGL gadget over its whole client area, loads the OpenGL entry points and compiles the engine's text and shape shaders. It returns the gadget, or 0. The width and height are the window's client area in the desktop's logical units. **Let it make the window**: a window made by hand with `OpenWindow` and `OpenGLGadget` has no shaders, and every engine drawing call then draws nothing, without an error.
- `Util_BaseWidth = 320 : Util_BaseHeight = 240` sets the **canvas**: the size, in canvas units, that the program draws in. `OpenGLWindow` set them to the window's size; a game sets them to the size it was designed for.
- `InitRetroCRT(320, 240)` makes the canvas's framebuffer (`Util_FBO`, its texture `Util_FBOTex`) and the two shaders that show it in the window: a plain copy and a CRT look. The size given here is the framebuffer's pixel size; give it the canvas size.
- `GL_HandleResize(Gadget)` works out where the canvas goes in the window: the largest rectangle with the canvas's shape that fits the client area, centred, in `GL_ViewportX`, `GL_ViewportY`, `GL_ViewportW`, `GL_ViewportH` (physical pixels). Call it once at the start and again on every `#PB_Event_SizeWindow`.
- `LoadGLSprite("hero.png")` loads a picture into an OpenGL texture and returns a `GLSprite`, or 0. Here a missing file falls back to `CreateProceduralRopeSprite()`, a 32 by 64 picture the engine draws for itself, so the program runs anywhere.

## The frame loop

Each turn of the `Repeat` loop is one frame:

1. **Events.** `WindowEvent()` is called until it returns 0, so no event waits behind the frame. A resize calls `GL_HandleResize`. `OpenGLWindow` binds the Escape key to menu event 1001, so Escape arrives as `#PB_Event_Menu` with `EventMenu() = 1001`.
2. **Time.** `GL_Micros()` is a monotonic clock in microseconds. The difference from the last frame, in seconds, moves everything that moves, so the program runs at the same speed whatever the frame rate.
3. **Draw into the canvas.** `glBindFramebuffer(#GL_FRAMEBUFFER, Util_FBO)` and `glViewport_(0, 0, Util_BaseWidth, Util_BaseHeight)` direct drawing into the canvas. Every engine drawing call takes canvas units when its `Scaled` parameter is `#True` (chapter 3).
4. **Present.** Framebuffer 0 is the window. The viewport is set to the letterbox rectangle and `DrawPassthrough()` copies the canvas into it; `DrawRetroCRT(Seconds)` does the same through the CRT shader (a slight barrel curve, moving scanlines, a vignette), with the time in seconds driving the scanlines.
5. **Flip.** `SetGadgetAttribute(Gadget, #PB_OpenGL_FlipBuffers, #True)` shows the frame. `Delay(1)` gives the processor back for a moment. With vertical sync on (`GL_SetVSync(1)`, Windows) the flip waits for the display.

@figure frame 126 One frame of a program on the engine.

## What each frame must not forget

- The canvas framebuffer is drawn with `Scaled = #True` in every engine call. With `#False` the call measures against the window's size (`Util_WinWidth`, `Util_WinHeight`) instead of the canvas, which is right only when drawing straight into the window.
- The viewport is set twice a frame: to the canvas before drawing, to the letterbox before presenting.
- Window events are read every frame. A window whose events are not read is reported by the system as not responding.
- Nothing is freed at the end of this program: the process ends and the system takes everything back. A program that closes one window and goes on frees what it made for that window first (chapter 4).
