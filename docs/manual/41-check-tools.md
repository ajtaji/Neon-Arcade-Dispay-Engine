# The check tools

The engine's `tools` folder holds check programs, each paired with a Python script that builds it and runs it. Each proves one module's behaviour against values worked out independently, prints `PASS` and the number of checks, and ends with exit code 0; the first failure prints `FAIL` and what was expected, and ends with 1. None shows anything on the screen: the ones that need OpenGL make an invisible window.

## Running them

From the engine's folder:

```
python tools/tiles_check.py
```

and the same for the others. Each script builds its program with the PureBasic compiler named by the environment variable `PMF_PBC_ASM` or, on Windows when it is not set, the one at `%LOCALAPPDATA%\Programs\PureBasic\Compilers\pbcompiler.exe`; on Linux set the variable. The programs are built in the repository's `build` folder (ignored by version control), or a temporary folder.

| Script | Proves | Window |
|---|---|---|
| `tools/tiles_check.py` | the cut of a sheet; cells and orientations; that the cells a map submits are exactly those a pass over every cell finds visible, at 400 camera positions; the quads written (place, picture, the eight orientations, shared edges with no gap, the camera ignored); animated tiles by the clock; the map file round trip, and a damaged file refused | none |
| `tools/layers_check.py` | the draw order; the parallax arithmetic at 300 camera positions; what a sprite layer writes; 600 boxes, 600 circles and 600 lines against a slow reference that visits every cell by other means; one-way tiles; the layer forms; the collision table in the file | none |
| `tools/palette_check.py` | cycling and cycling by the clock; 2000 fades to a colour and 300 to a palette against arithmetic in floating point; their order within a frame; the slots and which palette a draw uses; the CPU look-up; an image made from a picture; the `.nti` file, 8 and 4 bits a pixel; a damaged file; an indexed set's slots in the map file | none |
| `tools/draw_check.py` | maps drawn through the camera into a render target, every pixel against a CPU reference; tint; a zoomed-out view over several batches; three layers (parallax, a half-transparent turned sprite, a fixed layer); indexed maps with two palettes, after a cycle and a fade, a layer's swap, two sprites with their own palettes in one call, the CPU recolour; the draw calls counted | invisible |
| `tools/ui_check.py` | the draw log; the typefaces; `Neon_FitText` at every width from 0 to 360 for six texts against a reference; the arcade kit's sizing rules; the widget gallery's script played with the mouse and keys and with a pad, every step's state, log and primitives checked, the two runs compared, and the record compared line by line with `tools/ui_check_expected.txt` (`--write` writes that file instead) | invisible |
| `tools/file_store_check.py` | `GL_FileStore`: a new file made and refused when it exists, an existing file updated only at its size, a missing file not made, pieces of 1 MB and a tail, every byte, nothing changed by a refusal | none |
| `tools/memory_watch_check.py` | `GL_MemoryWatch`: plain memory zeroed and reported as not tracked; tracked writes by the program and by native code, writes of the value already there, a write across two pages, bulk writes, the partial last page, and a clean region after a collect | none |

`tests/GlNetTest.pb` (31 checks: loopback TCP and UDP, the peer's close, a refused connection, name resolution, the result codes of bad calls) and `tests/GlIdleTest.pb` (the idle wait and socket waits) are console programs built and run directly:

```
pbcompiler tests/GlNetTest.pb /CONSOLE /EXE GlNetTest.exe
```

## The manual's own checks

`docs/manual/compile_examples.py` compiles every program this manual prints and records each with its SHA-256 in `docs/manual/examples/compiled.txt`; with `--run` it also runs the console examples that open no window and keeps what they print in `docs/manual/examples/output/`. `docs/manual/check_manual.py` reports any public name of the engine's source that the reference does not document, any reference entry the source does not have, any printed program not compiled as printed, any link that does not resolve in the built PDF, and any text that must not be in a public manual; it ends with 0 when there is nothing to fix. `docs/manual/build_manual.py` builds the PDF.
