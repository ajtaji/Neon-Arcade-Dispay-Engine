#!/usr/bin/env python3
# neon_source.py - reads the engine's source files and lists what they declare.
#
# Used by build_manual.py (the exact signature printed at the head of every reference entry, the
# fields of every structure) and by check_manual.py (every public name in the source is in the
# reference). Nothing here is copied by hand from the source: it is read from it each time.
#
#   python -I docs/manual/neon_source.py            lists every public name, module by module
#   python -I docs/manual/neon_source.py --missing  only the public names the manual does not document
#
# WHAT IS PUBLIC. The engine marks its own helpers by name, and those names are left out:
#   - a name that starts with a lower-case letter (g3dMul, g3dReadNodes ...), except the OpenGL
#     function pointers (glBindFramebuffer ...), which are documented with the bindings;
#   - a name with one of the module prefixes the engine keeps for itself: GLF_, GLTile_, GLPal_,
#     GLLayer_, Internal_, and the operating-system bindings GLFile_, GLClock_, GLMemory_, GLNet
#     (no underscore), GLPa, GLWave, GLJs, GL_Proto, GL_Pa, GL_Js, GL_Ff, GL_X, GL_gtk, GL_gdk,
#     GL_snd, GL_wave, GL_glX, GL_open, GL_read ... (the imported system calls);
#   - the names a reference chapter lists on an "Internal:" line (public-looking names that only
#     the engine itself calls).
# Everything else declared at the top level of an engine module - a procedure, a macro, a
# structure, a prototype, a constant, a global - is public and has to be in the reference.
# The OpenGL binding files (opengl_*.pbi) are the OpenGL API itself, generated from the Khronos
# registry; their thousands of names are described as a group, not one by one.
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MODULES = ["GlTypes.pbi", "GlUtilities.pbi", "GlSpriteFunctions.pbi", "GlMath.pbi", "GlFile.pbi",
           "GlClock.pbi", "GlMemoryWatch.pbi", "GlTiles.pbi", "GlPalette.pbi", "GlLayers.pbi",
           "GlUI.pbi", "GlUIChrome.pbi", "Gl3D.pbi", "Gl3DMath.pbi", "Gl3DMesh.pbi",
           "Gl3DLoader.pbi", "Gl3DRender.pbi", "Gl3DAnimation.pbi", "GlNet.pbi"]

INTERNAL_PREFIXES = ("GLF_", "GLTile_", "GLPal_", "GLLayer_", "Internal_", "GLFile_", "GLClock_",
                     "GLMemory_", "GLNet", "GL_NET_AF6", "GL_NET_SOL", "GL_NET_SOERR", "GL_NET_AIADDR", "GLPaS", "GLPaB", "GLWave", "GLJs", "GLXError", "GL_Proto", "GL_Js", "GL_Joy",
                     "GL_Ff", "GL_X", "GL_gtk", "GL_gdk", "GL_snd", "GL_wave", "GL_glX", "GL_open",
                     "GL_read", "GL_close", "GL_ioctl", "GL_errno", "GL_write", "GL_clock_gettime",
                     "GL_mmap", "GL_munmap", "GL_sched_", "GL_dl_", "GL_ProgramBase", "GL_Full",
                     "GL_Micros", "GL_Cursor", "GL_KeyDisplay", "GL_Audio", "GL_Pad", "GL_Net", "GL_LogClip",
                     "GL_DrawLogOn")
# Names above that ARE public (the prefix rule catches families with public members)
PUBLIC_EXCEPTIONS = {
    "GL_ProgramBase", "GL_FullscreenEnter", "GL_FullscreenLeave", "GL_FullscreenIsOn", "GL_FullscreenRect",
    "GL_Micros", "GL_CursorShow", "GL_KeyHeld", "GL_KeyName", "GL_KeysSnapshot", "GL_KeySnap",
    "GL_KeyEventCode", "GL_KeySnapState", "GL_AudioOpen", "GL_AudioNext", "GL_AudioPlay", "GL_AudioQueued",
    "GL_AudioClose", "GL_AudioDriver", "GL_JoyRead", "GL_PadRead", "GL_PadRumble", "GL_DrawLogOn",
    "GL_NetInit", "GL_NetOpen", "GL_NetBind", "GL_NetListen", "GL_NetAccept", "GL_NetConnect", "GL_NetError",
    "GL_NetSend", "GL_NetSendTo", "GL_NetRecv", "GL_NetRecvFrom", "GL_NetPoll", "GL_NetWaitBegin",
    "GL_NetWaitAdd", "GL_NetWait", "GL_NetShutdown", "GL_NetClose", "GL_NetLocalPort", "GL_NetResolve",
    "GL_NetFromAddr$", "GL_NetFromPort", "GL_NetOsError",
    "GLF_EMPTY", "GLF_RESIDENT", "GLF_BLANK", "GLF_TOFU",
}
OPENGL_POINTER = re.compile(r"^(gl[A-Z]|wgl)")

PROC = re.compile(r"^\s*Procedure(C|DLL|CDLL)?(\.\w+)?\s+(\w+)\s*\(")
MACRO = re.compile(r"^\s*Macro\s+(\w+)\s*\((.*)\)")
STRUCT = re.compile(r"^\s*Structure\s+(\w+)")
PROTO = re.compile(r"^\s*Prototype(C)?(\.\w+)?\s+(\w+)\s*\((.*)\)")
ENUM = re.compile(r"^\s*Enumeration\b\s*(\w*)")
CONST = re.compile(r"#(\w+\$?)\s*=")
GLOBAL = re.compile(r"^\s*Global\s+(.*)$")


def is_public(name):
    name = name.lstrip("#")
    if name in PUBLIC_EXCEPTIONS:
        return True
    if OPENGL_POINTER.match(name):
        return False                      # documented as a group with the bindings
    if name[:1].islower():
        return False
    if re.match(r"^GL_Pa(?!lette|d|rticle)", name):
        return False                      # the sound server's bindings (GL_PaLib, GL_PaQueued ...)
    for p in INTERNAL_PREFIXES:
        if name.startswith(p):
            return False
    return True


def strip_comment(line):
    """The code part of a line: what precedes a ';' that is not inside a string."""
    out, q = [], False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == ";" and not q:
            break
        out.append(ch)
    return "".join(out)


def split_top(text, sep=","):
    parts, depth, cur, q = [], 0, [], False
    for ch in text:
        if ch == '"':
            q = not q
        if not q:
            if ch in "([":
                depth += 1
            elif ch in ")]":
                depth -= 1
            elif ch == sep and depth == 0:
                parts.append("".join(cur))
                cur = []
                continue
        cur.append(ch)
    parts.append("".join(cur))
    return [p.strip() for p in parts if p.strip()]


class Decl:
    def __init__(self, kind, name, sig, module, line, extra=None):
        self.kind, self.name, self.sig, self.module, self.line = kind, name, sig, module, line
        self.extra = extra or []          # structure: its field lines; constants: the value

    def __repr__(self):
        return "%s %s (%s:%d)" % (self.kind, self.name, self.module, self.line)


def read_module(fn):
    path = os.path.join(ROOT, fn)
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    decls, i, depth_proc, in_struct, enum_name = [], 0, 0, None, None
    while i < len(lines):
        raw = lines[i]
        code = strip_comment(raw).rstrip()
        s = code.strip()
        n = i + 1
        if in_struct is not None:
            if re.match(r"^EndStructure\b", s, re.I):
                decls.append(in_struct)
                in_struct = None
            elif s:
                for part in s.split(" : "):
                    in_struct.extra.append(part.strip())
            i += 1
            continue
        m = PROC.match(code)
        if m:
            text, j = code, i
            while text.count("(") > text.count(")") and j + 1 < len(lines):
                j += 1
                text += " " + strip_comment(lines[j]).strip()
            name = m.group(3)
            sig = re.sub(r"\s+", " ", text.strip())
            sig = re.sub(r"\(\s+", "(", sig)
            decls.append(Decl("procedure", name, sig, fn, n))
            depth_proc = 1
            i = j + 1
            continue
        if re.match(r"^\s*EndProcedure\b", code):
            depth_proc = 0
            i += 1
            continue
        if depth_proc:
            i += 1
            continue
        m = MACRO.match(code)
        if m:
            decls.append(Decl("macro", m.group(1), s, fn, n))
            while i < len(lines) and not re.match(r"^\s*EndMacro\b", lines[i]):
                i += 1
            i += 1
            continue
        m = STRUCT.match(code)
        if m:
            in_struct = Decl("structure", m.group(1), s, fn, n)
            parts = [p.strip() for p in s.split(" : ")]
            if len(parts) > 1 and re.match(r"^EndStructure\b", parts[-1], re.I):   # a structure on one line
                in_struct.extra = parts[1:-1]
                in_struct.sig = parts[0]
                decls.append(in_struct)
                in_struct = None
            i += 1
            continue
        m = PROTO.match(code)
        if m:
            decls.append(Decl("prototype", m.group(3), s, fn, n))
            i += 1
            continue
        m = ENUM.match(code)
        if m:
            enum_name = m.group(1) or "(unnamed)"
            i += 1
            while i < len(lines) and not re.match(r"^\s*EndEnumeration\b", lines[i]):
                c = strip_comment(lines[i]).strip()
                mm = re.match(r"^#(\w+)", c)
                if mm:
                    decls.append(Decl("constant", "#" + mm.group(1), c, fn, i + 1, ["enumeration " + enum_name]))
                i += 1
            i += 1
            continue
        if s.startswith("#") or " : #" in s:
            for part in s.split(":"):
                part = part.strip()
                mm = re.match(r"^#(\w+\$?)\s*=\s*(.*)$", part)
                if mm:
                    decls.append(Decl("constant", "#" + mm.group(1), part, fn, n, [mm.group(2).strip()]))
            i += 1
            continue
        m = GLOBAL.match(code)
        if m:
            for item in split_top(m.group(1)):
                item = re.sub(r"^(NewList|NewMap|Dim)\s+", "", item.strip())
                mm = re.match(r"^\*?(\w+\$?)", item)
                if mm:
                    decls.append(Decl("global", mm.group(1), item, fn, n))
            i += 1
            continue
        i += 1
    return decls


def engine():
    """Every declaration of every engine module, in module order."""
    out = []
    for fn in MODULES:
        out += read_module(fn)
    return out


def public(decls=None):
    decls = engine() if decls is None else decls
    seen, out = set(), []
    for d in decls:
        key = (d.kind, d.name)
        if is_public(d.name) and key not in seen:
            seen.add(key)
            out.append(d)
    return out


def by_name(decls=None):
    """name -> the first declaration of that name (a procedure defined in two OS branches is one)."""
    m = {}
    for d in (engine() if decls is None else decls):
        m.setdefault(d.name, d)
    return m


if __name__ == "__main__":
    pub = public()
    counts = {}
    for d in pub:
        counts[d.kind] = counts.get(d.kind, 0) + 1
    if "--missing" not in sys.argv:
        cur = None
        for d in pub:
            if d.module != cur:
                cur = d.module
                print("\n" + cur)
            print("  %-10s %s" % (d.kind, d.sig if d.kind == "procedure" else d.name))
    print("\npublic names:", ", ".join("%d %s" % (v, k) for k, v in sorted(counts.items())), "- total", len(pub))
