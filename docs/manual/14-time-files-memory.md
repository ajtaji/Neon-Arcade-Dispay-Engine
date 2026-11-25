# Time, files and memory

## Two clocks

The engine has two clocks, for two different questions.

| Clock | Module | What it is | Use it for |
|---|---|---|---|
| `GL_Micros()` | `GlUtilities.pbi` | a monotonic count of microseconds: it never goes back and is not changed by the wall clock being set; its starting point means nothing | the time between frames, animation, timeouts |
| `GL_UtcMicroseconds()` | `GlClock.pbi` | the system's wall clock as microseconds since 1970-01-01 00:00 UTC; -1 when it cannot be read | time stamps, dates |

`GL_Micros` reads the performance counter on Windows and `CLOCK_MONOTONIC` on Linux. `GL_UtcMicroseconds` reads the system time on Windows and `CLOCK_REALTIME` on Linux; it applies no time zone and asks no time server, so it is as right as the machine's own clock. The tile animations and palette cycles take their time from `GL_Micros() / 1000` unless they are given one.

`GL_HostWait(Milliseconds)` waits for the next window event or for the time to pass, whichever is first, and returns the event as `WaitWindowEvent` does (0 for the time out); with 0 or less it does not wait. A program that draws only when something happens sleeps in it instead of spinning.

## The durable file store

`GL_FileStore(Path, *Bytes, Size, CreateNew)` writes `Size` bytes to a file and does not return `#True` until the system says they are on the disk (it flushes the file's buffers, `FlushFileBuffers` or `fsync`, and checks the answer). It guards a file in two ways:

- With `CreateNew = #True` it makes a **new** file and refuses if one is already there. If the write fails part-way it deletes the partial file it made.
- Without it, the file **must already exist with exactly `Size` bytes**; it is opened without being cut short and written over in place. A file of any other size, or a missing file, is refused, and the file is left as it was.

So the store never changes a file's size and never truncates one: it is made for disk images and recordings that keep their size, and for a write-new-then-replace pattern. The tile map and indexed image files are saved that way: the new file is made with `CreateNew` at `Path.new`, and only when it is complete is the old file deleted and the new one renamed in its place.

It writes in pieces of 1 MB, so any size works. A `Size` of 0 writes nothing (and makes an empty file with `CreateNew`); a negative size, an empty path, or no bytes for a non-zero size is refused.

## Watching which memory changed

`GlMemoryWatch.pbi` gives a program a block of zeroed memory and tells it which pages of it have been written since it last asked: what a program that sends a large buffer to the GPU, or compares it with a copy, needs to send or compare only the pages that changed.

- `GL_MemoryWatchCreate(Bytes, Watch)` makes a region (`GLMemoryWatch`) of `Bytes` zeroed bytes, at `\memory`. With `Watch` (the default) it asks the system to track writes, which Windows can do; `\tracked` says whether it did. `\pageBytes` is the page size.
- `GL_MemoryWatchCollect(*Region)` puts the address of every page written since the last collect in `\pages` (an array of `\count` addresses) and returns that count, and starts a new observation. **-1 means it does not know** - tracking is not available on this system, or the system's answer could not be trusted - and `\error` says which: compare or send the whole region then, never treat -1 as "nothing changed". Every store counts, including a store of the value that was already there and stores made by code outside the program.
- `GL_MemoryWatchFree(*Region)` frees it.

Collecting and freeing need the region to themselves: stop any thread that writes to it first.

## Large blocks

`GL_ReserveZeroed(Bytes)` asks the system for a large block of zeroed memory whose pages are given as they are first written (`VirtualAlloc` on Windows, an anonymous `mmap` on Linux), so a block of gigabytes costs only what is used; it returns 0 when the system refuses. `GL_ReleaseReserved(*Memory, Bytes)` gives it back.

## A worked example

@include examples/clock_files.pb

It printed, on a Windows machine:

@include examples/output/clock_files.txt
