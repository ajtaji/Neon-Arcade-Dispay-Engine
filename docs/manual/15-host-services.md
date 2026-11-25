# Host services

`GlUtilities.pbi` carries the things a program would otherwise ask the operating system for, each with a Windows branch and a Linux branch, so that the program itself never calls either system. A program that does not call them is not affected by them.

## Starting up

- `GL_HostPrepare()` is the first call, before any window. On Windows it asks for per-monitor DPI awareness (version 2, from Windows 10 1607; on older systems it does nothing). On Linux it chooses the X11 back end of the toolkit, makes the X library safe for threads (needed for a second OpenGL context) and installs a filter for one harmless X error some X servers send while an OpenGL gadget is set up, passing every other error to the handler it replaced.
- `GL_HostScaleRead(Gadget)` puts the window's scale factor in `Linux_DPIScale` (Linux; on Windows it does nothing).
- `GL_NoPowerThrottling()` asks Windows 11 not to slow the program down when its window is behind another; `GL_TimerFine(#True)` makes `Delay(1)` wait about one millisecond on Windows instead of about 15.6 (`#False` undoes it). Both do nothing on Linux, where neither is needed.
- `GL_PhysicalCores()` counts the processor's physical cores the program may run on (not hardware threads), at least 1.
- `GL_GetHardwareInfo()` returns the OpenGL vendor, renderer and version as lines of text, and the swap interval on Windows. `GL_SetVSync(1)` turns vertical sync on (0 off) on Windows; on Linux it does nothing and the desktop's compositor decides.

## The keyboard

Key codes are PureBasic's `#PB_Shortcut_...` values. They are the virtual-key codes on Windows and the X keysyms on Linux, so a key code saved in a settings file on one system means another key on the other.

- `GL_KeyHeld(Key)` says whether a key is down now, by asking the system (one call a key; on Linux one round trip to the X server).
- `GL_KeysSnapshot()` reads the whole keyboard once, and `GL_KeySnap(Key)` then answers from that reading: the way to test many keys a frame.
- `GL_KeyName(Key)` is the keyboard's own name for a key, for a settings screen.
- `GL_KeyEventCode(Key)` passes a key code from the OpenGL gadget's key events; on Linux it turns a letter's lower-case code (which key-up events give) into the upper-case one (which key-down events give), so a key is released with the code it was pressed with.
- `#GL_Key_Shift`, `#GL_Key_Control`, `#GL_Key_Alt` and their left and right forms, `#GL_Key_CapsLock`, `#GL_Key_SuperLeft`, `#GL_Key_SuperRight` and the punctuation keys (`#GL_Key_Minus`, `#GL_Key_Equals`, `#GL_Key_BracketLeft`, `#GL_Key_BracketRight`, `#GL_Key_Backslash`, `#GL_Key_Semicolon`, `#GL_Key_Apostrophe`, `#GL_Key_Grave`, `#GL_Key_Comma`, `#GL_Key_Period`, `#GL_Key_Slash`) are codes PureBasic has no constant for. On Linux, `Shift`, `Control` and `Alt` are the left keys.

## Game pads and other controllers

- `GL_PadRead(Port, @Pad.GLPadState)` reads an Xbox-layout pad on port 0 to 3 and returns `#True` when one answers there. `Buttons` holds the XInput bits (D-pad up `$1`, down `$2`, left `$4`, right `$8`, Start `$10`, Back `$20`, left stick press `$40`, right stick press `$80`, LB `$100`, RB `$200`, A `$1000`, B `$2000`, X `$4000`, Y `$8000`), `LT` and `RT` the triggers from 0 to 255, `LX`, `LY`, `RX`, `RY` the sticks from -32768 to 32767, up positive. On Linux the pad is a joystick device whose name holds "box" (the Xbox pad driver), port N being `/dev/input/jsN`, mapped to the same layout.
- `GL_PadRumble(Port, Strength)` runs the pad's motors at `Strength`, 0 (off) to 65535. On Linux it uses the device's force-feedback event node; a pad that cannot vibrate is left alone.
- `GL_JoyRead(Id, @Joy.GLJoyState)` reads any other controller, 0 to 15: 32 buttons as bits, six axes from 0 to 65535 (32767 at rest), the hat in hundredths of a degree clockwise from up (`$FFFF` when centred), and its name.

## Full screen and the window's place

- `GL_FullscreenEnter(Window)` makes the window cover the monitor it is on, without changing the display mode; `GL_FullscreenLeave(Window)` puts it back exactly where it was; `GL_FullscreenIsOn()` says which; `GL_FullscreenRect(@Rect)` gives the monitor it covers, in physical pixels. Call `GL_HandleResize` after either.
- `GL_ToggleFullscreen()` is the older form: on Windows it makes the main window a borderless window the size of the primary display; on Linux it maximises the window. It calls `GL_HandleResize` itself.
- `GL_WorkArea(@Rect)` is the primary desktop less its task bars, in logical units (what `OpenWindow` takes); `GL_WindowRect(Window, @Rect)` the window's outer rectangle in physical pixels; `GL_ClientPixels(Window, @W, @H)` its inner size in physical pixels.
- `GL_WindowPlaceGet(Window, @Rect)` gives the window's normal place and returns `#True` when it is maximised; `GL_WindowPlaceSet(Window, @Rect, Maximised)` puts it back, and does nothing (returning `#False`) when that place is on no monitor now. On Windows the place is in physical pixels and is the normal place even while maximised; on Linux it is in the toolkit's units. Store what `Get` gave and give it to `Set` on the same machine.
- `GL_CursorShow(Window, Gadget, Show)` hides or shows the pointer over the window.

The rectangles are `GLHostRect`: `X`, `Y`, `W`, `H`.

## Sound out

`GL_AudioOpen(Rate, Pairs, Count)` opens the sound output for 16-bit stereo at `Rate` samples a second, with `Count` buffers of `Pairs` left-right pairs each, and returns `#True` when it is open. Then, as often as the program likes:

```pb
Define *B, i.i
If GL_AudioOpen(48000, 1024, 4)
  *B = GL_AudioNext()                    ; a free buffer, or 0 while all are queued
  While *B
    For i = 0 To 1023
      PokeW(*B + i * 4, 0) : PokeW(*B + i * 4 + 2, 0)   ; left, right: silence here
    Next
    GL_AudioPlay(*B)                     ; queue it
    *B = GL_AudioNext()
  Wend
EndIf
```

`GL_AudioQueued()` is the number of pairs queued and not yet heard (0: the output has run dry), which a program uses to keep a steady amount ahead. `GL_AudioClose()` stops and closes it. `GL_AudioDriver` names what plays the sound: `"waveOut"` on Windows; on Linux `"PulseAudio"` or `"PipeWire (PulseAudio)"` when a sound server is running and its client library loads, else `"ALSA"` (the default device). On Linux the environment variable `GL_AUDIO` set to `alsa` or `pulse` chooses.

## A second OpenGL context, and worker threads

`GL_SharedContextCreate()` makes, on the window's thread with the window's context current, a second context that shares the window's textures and buffers: a worker thread calls `GL_SharedContextBind(*Context)` and can then upload textures the window draws. It returns a `GLSharedContext` whose `Error` is "" on success; on failure `Error` says why and the program frees it with `GL_SharedContextFree`. On Linux the worker's context is current on a small offscreen surface: it must not draw to the window.

`GL_WorkerCreate(@Job(), *Data)` starts a thread that waits; `GL_WorkerStart(*Worker)` runs `Job(*Data)` on it once (and is refused while a run is going); `GL_WorkerWait(*Worker)` waits for the run to finish; `GL_WorkerClose(*Worker)` waits, stops the thread and frees it. The data belongs to the job from `Start` to `Wait`. A job must not call the UI. Build with `/THREAD`.

## Several windows

The engine's window, canvas, shaders and camera are globals. A program with two OpenGL windows keeps a `GLWindowContext` for each: `GL_ContextCapture(@Context)` after making a window copies the globals into it; `GL_ContextActivate(@Context)` makes that window's context current and copies its values back into the globals, before any work for that window; `GL_ContextForget` clears one. `OpenGLWindow` saves the current context's globals before it opens the next window, so the first window's values are not lost. `GL_ContextIsAlive()` says whether the current context still answers (it may not after the display sleeps or the GPU resets).

## Where the program is loaded

`GL_ProgramBase()` is the address the program is loaded at. An error handler's `ErrorAddress()` less this is an offset that stays the same from run to run, to look up in the build.

## A worked example

Keys, pads and other controllers, full screen on the window's monitor, the pointer hidden in full screen, and a beep:

@include examples/host.pb
