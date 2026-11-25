# GlUtilities.pbi: host services

Each procedure here has a Windows branch and a Linux branch (chapter 15 is the guide).

## Constants and globals

The key codes PureBasic has no constant for, with their values on each system:

| Constant | Windows | Linux |
|---|---|---|
| `#GL_Key_Shift`, `#GL_Key_Control`, `#GL_Key_Alt` | $10, $11, $12 (either side) | $FFE1, $FFE3, $FFE9 (the left key) |
| `#GL_Key_ShiftLeft`, `#GL_Key_ShiftRight` | $A0, $A1 | $FFE1, $FFE2 |
| `#GL_Key_ControlLeft`, `#GL_Key_ControlRight` | $A2, $A3 | $FFE3, $FFE4 |
| `#GL_Key_AltLeft`, `#GL_Key_AltRight` | $A4, $A5 | $FFE9, $FFEA |
| `#GL_Key_CapsLock`, `#GL_Key_SuperLeft`, `#GL_Key_SuperRight` | $14, $5B, $5C | $FFE5, $FFEB, $FFEC |
| `#GL_Key_Minus`, `#GL_Key_Equals` | $BD, $BB | $2D, $3D |
| `#GL_Key_BracketLeft`, `#GL_Key_BracketRight`, `#GL_Key_Backslash` | $DB, $DD, $DC | $5B, $5D, $5C |
| `#GL_Key_Semicolon`, `#GL_Key_Apostrophe`, `#GL_Key_Grave` | $BA, $DE, $C0 | $3B, $27, $60 |
| `#GL_Key_Comma`, `#GL_Key_Period`, `#GL_Key_Slash` | $BC, $BE, $BF | $2C, $2E, $2F |

`GL_KeySnapState()` is the keyboard as `GL_KeysSnapshot` last read it (256 bytes on Windows; the X server's 32-byte key map on Linux). `GL_AudioDriver` names the sound output in use, or "" when none is open.

## Starting up and the machine

### GL_HostPrepare

The first call of a program, before any window. Windows: per-monitor DPI awareness, version 2 (when the system has it). Linux: the X11 back end, a thread-safe X library, and a filter for one harmless GLX error some X servers raise while an OpenGL gadget is set up.

### GL_HostScaleRead

Linux: puts the scale factor of the window holding `Gadget` in `Linux_DPIScale` (1 when the toolkit says 0 or less). Windows: nothing.

### GL_NoPowerThrottling

Windows 11: asks the system not to slow the program when its window is behind another. Other systems: nothing.

### GL_TimerFine

Windows: `On` makes the system timer tick every millisecond (so `Delay(1)` waits about 1 ms), `#False` lets it go. Linux: nothing.

### GL_PhysicalCores

The number of physical processor cores the program may run on, at least 1. Windows: the cores in the process's affinity mask. Linux: the distinct cores in `/proc/cpuinfo`, reduced in proportion when the process's affinity allows fewer processors.

### GL_ProgramBase

The address the program is loaded at (Windows: the module handle; Linux: the first loaded object's base).

### GL_Micros

A monotonic clock in microseconds (64-bit). Only differences between two readings mean anything.

### GL_HostWait

Waits up to `Milliseconds` for a window event and returns it as `WaitWindowEvent` does (0 when the time passed); with 0 or less, returns the next event without waiting, as `WindowEvent`.

### GL_ReserveZeroed

Returns a block of `Bytes` zeroed bytes whose pages the system supplies as they are first written, or 0.

### GL_ReleaseReserved

Gives back a block from `GL_ReserveZeroed`; pass the same `Bytes`. A null address does nothing.

## Keys

### GL_KeyHeld

`#True` while the key is down now (`Key` a `#PB_Shortcut_` code or a `#GL_Key_` constant); `#False` also when the keyboard cannot be read or `Key` is 0.

### GL_KeysSnapshot

Reads the whole keyboard into `GL_KeySnapState()`; call it once a frame before `GL_KeySnap`.

### GL_KeySnap

Whether the key was down in the last `GL_KeysSnapshot`.

### GL_KeyEventCode

The key code of an OpenGL gadget's KeyDown or KeyUp event made the same on both systems: on Linux a letter's lower-case code ($61 to $7A) becomes the upper-case one; on Windows the code is returned unchanged.

### GL_KeyName

The keyboard's own name for a key ("Esc", "Shift"); `"Key "` and the number when it has none; "" for 0.

## Pads and controllers

### Structure GLPadState

An Xbox-layout pad, field for field as XInput gives it: `Buttons` (16 bits: D-pad up $1, down $2, left $4, right $8, Start $10, Back $20, left stick $40, right stick $80, LB $100, RB $200, A $1000, B $2000, X $4000, Y $8000), `LT`, `RT` (0 to 255), `LX`, `LY`, `RX`, `RY` (-32768 to 32767, up positive).

### GL_PadRead

Reads the pad on `Port` (0 to 3) into `*P` and returns `#True`, or clears `*P` and returns `#False` when no pad answers there. Linux: ports are the joystick devices `/dev/input/js0` to `js15`, and only a device whose name holds "box" is read as a pad.

### GL_PadRumble

Runs pad `Port`'s two motors at `Strength`, 0 (off) to 65535. A pad or system that cannot does nothing.

### Structure GLJoyState

Any controller: `Buttons` (32 bits), `Axis[0]` to `Axis[5]` (0 to 65535, 32767 at rest), `POV` (the hat, hundredths of a degree clockwise from up, $FFFF centred), `Name`.

### GL_JoyRead

Reads controller `Id` (0 to 15) into `*J` and returns `#True`, or `#False` when none answers (the fields then hold their resting values). On Linux a device that has gone is looked for again a second later.

## Full screen, the window and the desktop

### Structure GLHostRect

A rectangle: `X`, `Y`, `W`, `H`, integers.

### GL_FullscreenEnter

Makes window `Win` cover the monitor it is on, borderless, without changing the display mode, and remembers where it was. Nothing if already full screen.

### GL_FullscreenLeave

Puts the window back where it was before `GL_FullscreenEnter`.

### GL_FullscreenIsOn

`#True` between `GL_FullscreenEnter` and `GL_FullscreenLeave`.

### GL_FullscreenRect

The monitor covered, in physical pixels, as measured at `GL_FullscreenEnter`.

### GL_WindowRect

The window's outer rectangle, frame included, in physical pixels.

### GL_ClientPixels

The window's inner size in physical pixels, into `*W` and `*H` (integers).

### GL_WorkArea

The primary desktop less its task bars, in logical units.

### GL_WindowPlaceGet

The window's normal place into `*R`; returns `#True` when it is maximised. Windows: physical pixels, the normal place even while maximised. Linux: the toolkit's units, and while maximised the maximised place.

### GL_WindowPlaceSet

Puts the window at `*R`, maximised when `Max`, and returns `#True`; returns `#False` and does nothing when the rectangle is on no monitor now.

### GL_CursorShow

Hides (`Show` `#False`) or shows the pointer over the window. Calls that do not change the state do nothing.

## Sound out

### GL_AudioOpen

Opens the sound output: 16-bit signed stereo at `Rate` samples a second, `Count` buffers of `Pairs` left-right pairs. Returns `#True` when open. It closes any output open before. On Linux the sound server is used when one is running and its client library loads (unless `GL_AUDIO=alsa`), else ALSA's default device.

### GL_AudioNext

A buffer to fill with `Pairs` pairs (left, right, each a 16-bit word), or 0 while every buffer is queued. On Linux it is the same scratch buffer each time, copied out by `GL_AudioPlay`.

### GL_AudioPlay

Queues a buffer `GL_AudioNext` gave.

### GL_AudioQueued

The pairs queued and not yet played (0: the output has run dry). A buffer handed out and not yet given to `GL_AudioPlay` is not counted.

### GL_AudioClose

Stops the output and closes it.

## A second context and worker threads

### Structure GLSharedContext

A second OpenGL context: `Context`, its drawing surface (`Surface`) and window or display (`Window`), and `Error`, "" on success or what failed.

### GL_SharedContextCreate

Makes a context that shares the current context's textures and buffers (or a context of its own when none is current), on the calling thread, and returns its `GLSharedContext`. Check `Error`; on failure the program frees it.

### GL_SharedContextBind

Makes the shared context current on the calling thread (the worker's); `#True` when it is.

### GL_SharedContextFree

Frees the shared context and the structure.

### Prototype GLWorkFn

The shape of a worker's job: `Procedure Job(*Data)`.

### Structure GLWorkerS

A worker: its job and data, its thread and two semaphores, and whether a run is going. A program holds it as a handle and reads nothing in it.

### GL_WorkerCreate

Starts a thread that waits for runs of `fn(*data)`; returns the worker, or 0. Needs `/THREAD`.

### GL_WorkerStart

Starts one run; `#False` while a run is going or after the worker was closed.

### GL_WorkerWait

Waits until the run started last has finished; returns at once when none is going.

### GL_WorkerClose

Waits for a run, stops the thread and frees the worker.
