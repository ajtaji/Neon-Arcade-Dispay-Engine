# GlClock.pbi, GlFile.pbi, GlMemoryWatch.pbi

Three small modules that need nothing else of the engine (chapter 14 is the guide).

Internal: `GLClockTimespec`

## GlClock.pbi

### GL_UtcMicroseconds

The system's wall clock as microseconds since 1970-01-01 00:00:00 UTC (a 64-bit integer), or -1 when it cannot be read or the system is not Windows or Linux. No time zone is applied and no time server is asked.

## GlFile.pbi

### GL_FileStore

Writes `size` bytes from `*bytes` to `path` and returns `#True` only when they are on the disk (the file flushed and the flush confirmed).

- `CreateNew = #True` - makes a new file (on Linux readable and writable by its user only); refused if the file exists. A partial file left by a failed write is deleted.
- `CreateNew = #False` (the default) - the file must exist and be exactly `size` bytes; it is written over in place, never truncated or extended. A missing file or another size is refused and the file is untouched.

Refused also: an empty path, a negative size, no bytes for a size above 0, another system. Written in pieces of 1 MB; on Linux an interrupted write or flush is retried.

## GlMemoryWatch.pbi

### Structure GLMemoryWatch

A watched region: `memory` (the block), `bytes` (its size), `pageBytes` (the page size), `tracked` (the system tracks writes), `pages` (the dirty page addresses of the last collect), `count` (how many), `capacity` (the room in `pages`), and `error` (why the last collect returned -1).

### GL_MemoryWatchCreate

A region of `bytes` zeroed bytes (at least 1); with `watch` (the default) on Windows the system tracks writes to it. Elsewhere, or when tracking cannot be had, it is ordinary memory and `tracked` is 0. Returns the region, or 0.

### GL_MemoryWatchCollect

The pages written since the last collect: their addresses in `pages`, their number returned, and a new observation started. **-1** when tracking is not available or the system's answer is unusable (the reason in `error`): treat the whole region as changed. Every store counts, the same value included. No other thread may write to the region during the call.

### GL_MemoryWatchFree

Frees a region and its page list. Nothing for 0.
