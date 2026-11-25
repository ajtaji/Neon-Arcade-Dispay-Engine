@unnumbered
# About this manual

This manual describes the Neon Arcade Display Engine as its source stands at the revision named on the title page. It is in three parts and a set of appendices.

- **Part I, Getting started**, says what the engine is, what it needs, how a program is built on it, and the conventions every later chapter assumes: coordinates and units, the canvas and the window, colours, and how a call reports that it could not do what was asked.
- **Part II, Guides**, takes one subject a chapter - sprites, text, tile maps, layers, palettes, collision, the two user-interface kits, the 3D renderer, time and files, the host services, networking, performance and testing - and shows it at work in an example program.
- **Part III, Reference**, documents every public procedure, structure, constant and global of the engine, module by module.
- **The appendices** give the engine's file formats byte by byte, the check tools, the known limits, a glossary and an index of every reference entry with its page.

## Conventions

- `Monospaced text` is code: a name from the engine, a value, a line of a program. A name that has a reference entry is a link to it.
- Every program printed with a file name above it (for example `docs/manual/examples/first_program.pb`) is a file of the engine's repository, and was compiled as printed. Shorter fragments, printed without a file name, were compiled too, each with every engine module included before it.
- A reference entry starts with the procedure's declaration exactly as the source declares it: its return type (`.i` an integer the size of a pointer, `.l` 32 bits, `.q` 64 bits, `.f` a 32-bit float, `.b` a byte, `.s` a string; none means an integer), each parameter's name and type, and any default value. The file that declares it is given at the right.
- A **canvas unit** is one pixel of the engine's canvas (chapter 3); a **physical pixel** is one pixel of the screen. Times are in seconds unless a name or the text says milliseconds (`Ms`) or microseconds (`Micros`). Angles are in radians.
- Notes in a box with a coloured edge mark behaviour that is easy to get wrong or that surprises.

## What "public" means here

The engine marks its own helpers by name. A procedure, structure or global whose name starts with a lower-case letter (`g3dMul`), or with one of the prefixes `GLF_`, `GLTile_`, `GLPal_`, `GLLayer_` or `Internal_`, or that is one of the operating-system bindings the engine imports, is the engine's own and is left out. A few names look public but are used only by the engine itself; each reference chapter lists them on a line marked **Internal**. Everything else that a module declares at its top level is public and has an entry. The rule is written into `docs/manual/neon_source.py`, which `docs/manual/check_manual.py` uses to report any public name the reference leaves out.

The OpenGL binding files (`opengl_constants.pbi`, `opengl_extensions.pbi`, `opengl_features.pbi`, `opengl_prototypes.pbi`) are the OpenGL interface itself, about nine thousand names generated from the OpenGL registry; [chapter 33](#c-33) describes them as a group.
