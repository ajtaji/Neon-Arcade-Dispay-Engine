#!/usr/bin/env python3
# check_manual.py - is the manual whole, current with the engine, and fit to publish?
#
#   python -I docs/manual/check_manual.py          (after build_manual.py; exit 0: nothing to fix)
#
# It reports:
#   1. every public name of the engine's source (neon_source.py says which are public) that the manual
#      does not document - "in the source, not in the manual" - and every reference entry whose name the
#      source does not have. A procedure, structure or prototype is documented by an entry heading
#      ("### Name", "### Structure Name", "### Prototype Name"); a constant or a global by its name in
#      backticks anywhere in the chapters; any name by an "Internal:" line.
#   2. every program the manual prints (an @include of examples/*.pb, a ```pb block) that is not in
#      docs/manual/examples/compiled.txt with the SHA-256 of its text as it is now: run compile_examples.py.
#   3. every link of the chapters whose target does not exist, and a PDF older than its sources.
#   4. the forbidden-content pass over the manual's sources and the text of the built PDF: no person's or
#      account's name, no attribution of the manual or the engine to a person or a tool, no path of a
#      particular machine, no name of a private project. The two copyright lines of the typefaces' licences
#      are the one exception: the licence page quotes them from the licence files.
#   5. the PDF's metadata: a title and a subject, and no author, creator or producer.
# This file itself holds the forbidden patterns and is left out of pass 4.
import hashlib, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import neon_source                                     # noqa: E402
import build_manual                                    # noqa: E402
import pymupdf                                         # noqa: E402

ROOT = neon_source.ROOT
PDF = build_manual.OUT
RECORD = os.path.join(HERE, "examples", "compiled.txt")

FORBIDDEN = [
    (r"\bRon\b", 0), (r"ajtaji", re.I), (r"rajta", re.I), (r"Dot ?Gobbler", re.I), (r"sparrow", re.I),
    (r"\bowner\b", re.I), (r"\bvault\b", re.I),
    (r"Claude|Anthropic|Codex|OpenAI|ChatGPT|Copilot|Gemini", re.I), (r"\bGPT\b", 0), (r"\bLLM\b", 0),
    (r"language model", re.I), (r"\bAI\b", 0), (r"\bagents?\b", re.I), (r"\bassistants?\b", re.I),
    (r"generated (with|by)|written by|created by|authored by|produced by|co-authored", re.I),
    (r"\b[A-Za-z]:\\", 0), (r"\b[A-Za-z]:/", 0), (r"PMFBuild|neon-tiles|Embedded Compiler|CompilerEmbedded", re.I),
    (r"PureMetal|PureBasicCode|Zentaji|LibPureMetal|GlIdeShell|\bAnvil\b|\bN64\b|Nintendo", re.I),
    (r"Users[\\/]", 0),
]


def sha(text):
    return hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()


def chapters():
    return sorted(f for f in os.listdir(HERE) if re.match(r"^\d\d-.*\.md$", f))


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def coverage(problems):
    texts = {fn: read(os.path.join(HERE, fn)) for fn in chapters()}
    entries, internal, ticked = {}, set(), set()
    for fn, t in texts.items():
        for n, ln in enumerate(t.splitlines(), 1):
            m = build_manual.ENTRY.match(ln.strip())
            if m:
                key = m.group(2)
                if key in entries:
                    problems.append("DOCUMENTED TWICE  %s  (%s:%d and %s:%d)" % ((key,) + entries[key] + (fn, n)))
                entries[key] = (fn, n)
            if ln.strip().startswith("Internal:"):
                internal.update(re.findall(r"`([^`]+)`", ln))
        for ln in t.splitlines():
            if ln.strip().startswith("Internal:"):
                continue
            for code in re.findall(r"`([^`]+)`", ln):
                for name in re.findall(r"#?\*?([A-Za-z_]\w*\$?)", code):
                    ticked.add(name)
    pub = neon_source.public()
    names = neon_source.by_name()
    counted = {"documented": 0, "internal": 0}
    for d in pub:
        bare = d.name.lstrip("#")
        if d.kind in ("procedure", "structure", "prototype", "macro"):
            ok = d.name in entries
        else:
            ok = bare in ticked
        if ok:
            counted["documented"] += 1
        elif d.name in internal or bare in internal:
            counted["internal"] += 1
        else:
            problems.append("IN THE SOURCE, NOT IN THE MANUAL  %s %s  (%s line %d)" % (d.kind, d.name, d.module, d.line))
    for name, (fn, n) in sorted(entries.items()):
        if name not in names:
            problems.append("IN THE MANUAL, NOT IN THE SOURCE  %s  (%s:%d)" % (name, fn, n))
    for name in sorted(internal):
        if name not in names and ("#" + name) not in names:
            problems.append("INTERNAL BUT NOT IN THE SOURCE  %s" % name)
    return len(pub), counted, len(entries)


def compiled(problems):
    done = {}
    if os.path.isfile(RECORD):
        for ln in read(RECORD).splitlines():
            if ln and not ln.startswith("#"):
                parts = ln.split()
                done[parts[0]] = parts
    n_ex = n_fr = 0
    for fn in chapters():
        L = read(os.path.join(HERE, fn)).splitlines()
        i = 0
        while i < len(L):
            s = L[i].strip()
            if s.startswith("@include ") and s.endswith(".pb"):
                rel = s[9:].strip()
                p = os.path.join(HERE, *rel.split("/"))
                n_ex += 1
                if not os.path.isfile(p):
                    problems.append("NO SUCH EXAMPLE  %s  (%s:%d)" % (rel, fn, i + 1))
                elif sha(read(p)) not in done:
                    problems.append("NOT COMPILED AS PRINTED  %s  (%s:%d): run compile_examples.py" % (rel, fn, i + 1))
            elif s.startswith("@include "):
                rel = s[9:].strip()
                if not os.path.isfile(os.path.join(HERE, *rel.split("/"))):
                    problems.append("NO SUCH FILE  %s  (%s:%d)" % (rel, fn, i + 1))
            elif s == "```pb":
                j = i + 1
                while j < len(L) and not L[j].strip().startswith("```"):
                    j += 1
                n_fr += 1
                if sha("\n".join(L[i + 1:j]) + "\n") not in done:
                    problems.append("FRAGMENT NOT COMPILED  %s:%d: run compile_examples.py" % (fn, i + 1))
                i = j
            i += 1
    return n_ex, n_fr


def links(problems):
    chs = build_manual.chapter_files()
    decls = neon_source.by_name()
    entries = set()
    for ch in chs:
        for ln in ch.lines:
            m = build_manual.ENTRY.match(ln.strip())
            if m:
                entries.add(m.group(2))
    html, figs, procs = [], [], []
    labels, nch, napp, app = [], 0, 0, False
    for ch in chs:
        if ch.appendix:
            app = True
        if ch.unnumbered:
            label = ch.file[:2]
        elif app:
            label = chr(ord("A") + napp)
            napp += 1
        else:
            nch += 1
            label = str(nch)
        ch.appendix = app and not ch.unnumbered
        if not ch.index:
            html += build_manual.chapter_html(ch, label, entries, decls, procs, figs)
    blob = "".join(html)
    ids = set(re.findall(r'id="([^"]+)"', blob)) | {"toc"} | {"part-" + r for r in ("I", "II", "III", "IV")}
    ids |= {"c-" + chr(ord("A") + k) for k in range(napp)}
    bad = sorted(set(h for h in re.findall(r'href="#([^"]+)"', blob) if h not in ids))
    for h in bad:
        problems.append("LINK TO NOTHING  #%s" % h)
    return len(re.findall(r'href="#', blob))


def forbidden(problems, pdf_text):
    allow = [build_manual.first_copyright(os.path.join(build_manual.FONTS, f)) for f in ("Lato-OFL.txt", "JetBrainsMono-OFL.txt")]
    files = [os.path.join(HERE, f) for f in sorted(os.listdir(HERE))
             if f.endswith((".md", ".py")) and f != "check_manual.py"]
    for sub in ("examples", os.path.join("examples", "output")):
        d = os.path.join(HERE, sub)
        files += [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith((".pb", ".txt")) and f != "compiled.txt"]
    texts = [(os.path.relpath(p, ROOT), read(p)) for p in files] + [("the built PDF", pdf_text)]
    hits = 0
    for where, text in texts:
        for a in allow:
            text = text.replace(a, "")
        for n, ln in enumerate(text.splitlines(), 1):
            for pat, flags in FORBIDDEN:
                m = re.search(pat, ln, flags)
                if m:
                    hits += 1
                    problems.append("FORBIDDEN  %r in %s line %d: %s" % (m.group(0), where, n, ln.strip()[:90]))
    return len(texts), hits


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    problems = []
    npub, counted, nentries = coverage(problems)
    n_ex, n_fr = compiled(problems)
    nlinks = links(problems)
    pdf_text, meta, pages = "", {}, 0
    if not os.path.isfile(PDF):
        problems.append("NO PDF: run build_manual.py")
    else:
        doc = pymupdf.open(PDF)
        pages = doc.page_count
        pdf_text = "\n".join(p.get_text() for p in doc)
        meta = doc.metadata
        newest = max(os.path.getmtime(os.path.join(HERE, f)) for f in chapters())
        if os.path.getmtime(PDF) < newest:
            problems.append("THE PDF IS OLDER THAN ITS SOURCES: run build_manual.py")
        for p in doc:
            for l in p.get_links():
                if l.get("kind") == pymupdf.LINK_GOTO and not (0 <= l.get("page", -1) < doc.page_count):
                    problems.append("PDF LINK TO A PAGE THAT IS NOT THERE  page %d" % (p.number + 1))
        if not meta.get("title") or not meta.get("subject"):
            problems.append("PDF METADATA: no title or no subject")
        for k in ("author", "creator", "producer"):
            if meta.get(k):
                problems.append("PDF METADATA: %s is %r" % (k, meta.get(k)))
    nfiles, nforbidden = forbidden(problems, pdf_text)

    print("public names in the source: %d; documented %d, internal %d; reference entries %d"
          % (npub, counted["documented"], counted["internal"], nentries))
    print("printed programs: %d examples, %d fragments; links in the chapters: %d" % (n_ex, n_fr, nlinks))
    print("forbidden-content pass: %d texts (the sources and the PDF's %d pages), %d hits" % (nfiles, pages, nforbidden))
    print("PDF metadata: title %r, subject %r, author %r, creator %r, producer %r"
          % (meta.get("title"), meta.get("subject"), meta.get("author"), meta.get("creator"), meta.get("producer")))
    for p in problems:
        print(p)
    print("%d problem(s)" % len(problems) if problems else "OK: nothing to fix")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
