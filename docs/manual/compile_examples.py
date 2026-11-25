#!/usr/bin/env python3
# compile_examples.py - compiles every program the manual prints, and records it.
#
#   python -I docs/manual/compile_examples.py [--run]
#
# What is compiled:
#   - every file docs/manual/examples/*.pb, as printed: a console program when its "; Build:" line says
#     /CONSOLE, else a windowed one (/THREAD /DPIAWARE). Windowed programs are compiled, never run.
#   - every ```pb fenced block of docs/manual/NN-*.md, as a fragment: after every engine module is
#     included (the PRELUDE below), at the top level of a program of its own.
# With --run, the console examples that open no window are also run once, and what they print is kept in
# docs/manual/examples/output/<name>.txt (the manual quotes it).
#
# The record, docs/manual/examples/compiled.txt, is one line a program: its SHA-256, its kind, where it is,
# the compiler's version, and OK. check_manual.py compares it with the files: a program changed since it
# was compiled, or never compiled, is reported.
#
# The compiler: PMF_PBC_ASM when set (as tools/*.py use it), else the default the engine's check tools use.
import hashlib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
EX = os.path.join(HERE, "examples")
OUTDIR = os.path.join(EX, "output")
WORK = os.path.join(ROOT, "build", "manual")
RECORD = os.path.join(EX, "compiled.txt")

PRELUDE_MODULES = ["GlTypes.pbi", "GlUtilities.pbi", "GlMath.pbi", "GlFile.pbi", "GlClock.pbi", "GlMemoryWatch.pbi",
                   "GlSpriteFunctions.pbi", "GlTiles.pbi", "GlLayers.pbi", "GlUI.pbi", "GlUIChrome.pbi", "Gl3D.pbi",
                   "GlNet.pbi"]


def compiler():
    c = os.environ.get("PMF_PBC_ASM")
    if not c and os.name == "nt":
        c = os.path.join(os.environ["LOCALAPPDATA"], "Programs", "PureBasic", "Compilers", "pbcompiler.exe")
    if not c or not os.path.isfile(c):
        raise SystemExit("Set PMF_PBC_ASM to the PureBasic compiler (pbcompiler).")
    return c


def sha(text):
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def fragments():
    """(chapter file, line, code) of every ```pb block."""
    out = []
    for fn in sorted(f for f in os.listdir(HERE) if re.match(r"^\d\d-.*\.md$", f)):
        with open(os.path.join(HERE, fn), encoding="utf-8") as f:
            L = f.read().splitlines()
        i = 0
        while i < len(L):
            if L[i].strip() == "```pb":
                j = i + 1
                while j < len(L) and not L[j].strip().startswith("```"):
                    j += 1
                out.append((fn, i + 1, "\n".join(L[i + 1:j]) + "\n"))
                i = j
            i += 1
    return out


def build(pbc, src, exe, console):
    if os.name == "nt":
        args = [pbc, src, "/EXE", exe] + (["/CONSOLE"] if console else ["/THREAD", "/DPIAWARE"])
    else:
        args = [pbc, src, "-o", exe] + (["-cl"] if console else ["-t"])
    r = subprocess.run(args, capture_output=True, text=True, timeout=180)
    ok = r.returncode == 0 and os.path.isfile(exe)
    return ok, (r.stdout + r.stderr).strip()


def version(pbc):
    r = subprocess.run([pbc, "/VERSION" if os.name == "nt" else "--version"], capture_output=True, text=True, timeout=30)
    return (r.stdout + r.stderr).strip().splitlines()[0].replace(" - (c) 2026 Fantaisie Software", "")


def main():
    run = "--run" in sys.argv[1:]
    pbc = compiler()
    ver = version(pbc)
    os.makedirs(WORK, exist_ok=True)
    rows, fails = [], 0
    for fn in sorted(f for f in os.listdir(EX) if f.endswith(".pb")):
        path = os.path.join(EX, fn)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        console = bool(re.search(r"^; Build:.*/CONSOLE", text, re.M))
        exe = os.path.join(WORK, fn[:-3] + (".exe" if os.name == "nt" else ""))
        ok, msg = build(pbc, path, exe, console)
        print("%-22s %-8s %s" % (fn, "console" if console else "window", "OK" if ok else "FAILED\n" + msg))
        if not ok:
            fails += 1
            continue
        rows.append("%s  %s  examples/%s  %s  OK" % (sha(text), "console" if console else "window", fn, ver))
        if run and console and "OpenGLWindow(" not in text:
            r = subprocess.run([exe], capture_output=True, text=True, timeout=60, cwd=WORK)
            os.makedirs(OUTDIR, exist_ok=True)
            with open(os.path.join(OUTDIR, fn[:-3] + ".txt"), "w", encoding="utf-8", newline="\n") as f:
                f.write(r.stdout.replace("\r\n", "\n"))
            print("   ran: exit %d, %d lines" % (r.returncode, len(r.stdout.splitlines())))
    root = ROOT.replace("\\", "/") + "/"
    prelude = "".join('XIncludeFile "%s%s"\n' % (root, m) for m in PRELUDE_MODULES)
    for n, (fn, line, code) in enumerate(fragments()):
        src = os.path.join(WORK, "fragment_%03d.pb" % n)
        with open(src, "w", encoding="utf-8") as f:
            f.write("; %s line %d\n" % (fn, line) + prelude + code)
        exe = os.path.join(WORK, "fragment_%03d" % n + (".exe" if os.name == "nt" else ""))
        ok, msg = build(pbc, src, exe, True)
        if not ok:
            fails += 1
            print("FRAGMENT FAILED %s line %d\n%s" % (fn, line, msg))
            continue
        rows.append("%s  fragment  %s:%d  %s  OK" % (sha(code), fn, line, ver))
    with open(RECORD, "w", encoding="utf-8", newline="\n") as f:
        f.write("# compiled by docs/manual/compile_examples.py: sha256, kind, where, compiler, result\n")
        f.write("\n".join(rows) + "\n")
    print("%d compiled, %d failed; record in %s" % (len(rows), fails, os.path.relpath(RECORD, ROOT)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
