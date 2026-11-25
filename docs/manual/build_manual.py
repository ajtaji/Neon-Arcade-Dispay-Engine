#!/usr/bin/env python3
# build_manual.py - builds "docs/Neon Arcade Programmer's Manual.pdf" from its source.
#
#   python -I docs/manual/build_manual.py       (Windows or Linux; needs PyMuPDF 1.24 or later, nothing else)
#
# THE SOURCE. docs/manual/NN-name.md, one file a chapter, taken in file-name order, and the engine's own
# source files: the signature printed at the head of every reference entry and the fields of every
# structure are read from the engine by neon_source.py each time the manual is built, never copied by hand.
# The example programs the manual prints are files in docs/manual/examples/, included by a line
#     @include examples/name.pb
# so what is printed is the file that was compiled (compile_examples.py; check_manual.py checks it).
#
# THE MARKDOWN it reads is a small, fixed subset:
#   @part Title                 a part of the manual starts here (a page of its own)
#   @appendix                   this chapter and the ones after it are appendices, lettered A, B ...
#   @unnumbered                 this chapter has no number (the front matter's "About this manual")
#   @figure name height Caption a figure drawn by this script (FIGURES below), height in points
#   @index                      the index of every reference entry with its page, made here
#   # Chapter   ## Section   ### Sub-section   #### Minor heading      "{#id}" at the end names the heading
#   ### Name                    a reference entry: Name is a procedure of the engine; its signature is
#                               printed from the source (### Structure Name, ### Prototype Name: the same)
#   Internal: `A`, `B`          public-looking names that only the engine itself uses (see neon_source.py)
#   paragraphs, "- " and "1. " lists, "> " notes, | pipe | tables |, ```fenced code``` (```pb is the
#   engine's language and is compiled), `code`, **bold**, [text](#id) links inside a line.
#   A `Name` in code that has a reference entry links to it.
import datetime, html, io, os, re, subprocess, sys
import pymupdf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import neon_source                                          # noqa: E402

ROOT = neon_source.ROOT
FONTS = os.path.join(ROOT, "assets", "fonts")
OUT = os.path.join(ROOT, "docs", "Neon Arcade Programmer's Manual.pdf")
TITLE = "Neon Arcade Display Engine"
SUBTITLE = "Programmer's Manual"
SHORT = "Neon Arcade Programmer's Manual"
MAXCOL = 114                    # a code line longer than this is wrapped (and reported: shorten it)
BODY_FONT = os.path.join(FONTS, "Lato-Regular.ttf")
MONO_FONT = os.path.join(FONTS, "JetBrainsMono-Regular.ttf")

esc = html.escape
ENTRY = re.compile(r"^###\s+(?:(Structure|Prototype)\s+)?([A-Za-z_]\w*\$?)\s*(?:\(\s*\))?\s*$")
WRAPPED, PROBLEMS = [], []

# ------------------------------------------------------------------ the engine's version
def git(*args):
    try:
        r = subprocess.run(["git", "-C", ROOT] + list(args), capture_output=True, text=True, timeout=30)
        return r.stdout.strip() if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def engine_version():
    line = git("log", "-1", "--format=%h %cs", "--", ".", ":(exclude)docs", ":(exclude)README.md")
    if not line:
        return "engine revision unknown", ""
    h, d = line.split()
    dirty = git("status", "--porcelain", "--untracked-files=no", "--", ".", ":(exclude)docs", ":(exclude)README.md")
    return "Engine revision %s%s" % (h, " with changes not yet committed" if dirty else ""), d


# ------------------------------------------------------------------ Markdown subset -> HTML
def inline(s, entries):
    """`code`, **bold** and [text](#id) inside a line."""
    out, bold = [], False
    parts = s.split("`")
    for i, p in enumerate(parts):
        if i % 2:
            m = re.match(r"^#?([A-Za-z_]\w*\$?)", p)
            c = "<code>%s</code>" % esc(p)
            if m and m.group(1) in entries and (p == m.group(1) or p.startswith(m.group(1) + "(")):
                c = '<a href="#e-%s">%s</a>' % (anchor(m.group(1)), c)
            out.append(c)
        else:
            t = esc(p)
            t = re.sub(r"\[([^\]]+)\]\(#([\w-]+)\)", r'<a href="#\2">\1</a>', t)
            for k, piece in enumerate(t.split("**")):
                if k:
                    bold = not bold
                    out.append('<span class="b">' if bold else "</span>")
                out.append(piece)
    if bold:
        out.append("</span>")
    return "".join(out)


def anchor(name):
    return re.sub(r"[^A-Za-z0-9_]", "_", name)


def code_block(lines, src, caption=None):
    h = '<p class="capc">%s</p>' % esc(caption) if caption else ""
    rows = []
    for n, ln in enumerate(lines, 1):
        ln = ln.rstrip().replace("\t", "  ")
        while len(ln) > MAXCOL:
            WRAPPED.append("%s line %d" % (src, n))
            cut = ln.rfind(" ", 40, MAXCOL)
            cut = cut if cut > 0 else MAXCOL
            rows.append(ln[:cut])
            ln = "    " + ln[cut:].lstrip()
        rows.append(ln)
    return h + "<pre>%s</pre>" % esc("\n".join(rows))


class Chapter:
    def __init__(self, path):
        self.path = path
        self.file = os.path.basename(path)
        with open(path, encoding="utf-8") as f:
            self.lines = f.read().splitlines()
        self.part = None
        self.appendix = False
        self.unnumbered = False
        self.index = False
        for ln in self.lines[:6]:
            s = ln.strip()
            if s.startswith("@part "):
                self.part = s[6:].strip()
            elif s == "@appendix":
                self.appendix = True
            elif s == "@unnumbered":
                self.unnumbered = True
            elif s == "@index":
                self.index = True
        self.title = next((l[2:].strip() for l in self.lines if l.startswith("# ")), self.file)
        self.title = re.sub(r"\s*\{#[\w-]+\}\s*$", "", self.title)


def heading_id(text, default):
    m = re.search(r"\s*\{#([\w-]+)\}\s*$", text)
    if m:
        return text[:m.start()].strip(), m.group(1)
    return text.strip(), default


def struct_block(d):
    rows = ["Structure %s" % d.name] + ["  " + f for f in d.extra] + ["EndStructure"]
    return "<pre>%s</pre>" % esc("\n".join(rows))


def chapter_html(ch, label, entries, decls, procs, figures):
    """One chapter -> a list of HTML chunks (one a heading, so that no layout is long)."""
    L = ch.lines
    chunks, cur = [], []
    sec, sub = 0, 0
    para, items, kind = [], [], None
    cid = "c-" + anchor(label)

    def flush():
        nonlocal para, items, kind
        if para:
            cur.append("<p>%s</p>" % inline(" ".join(para), entries))
        if items:
            tag = "ol" if kind == "ol" else "ul"
            cur.append("<%s>%s</%s>" % (tag, "".join("<li>%s</li>" % inline(x, entries) for x in items), tag))
        para, items, kind = [], [], None

    def new_chunk():
        flush()
        if cur:
            chunks.append("".join(cur))
            cur.clear()

    i = 0
    while i < len(L):
        ln = L[i]
        s = ln.strip()
        if s.startswith(("@part", "@appendix", "@unnumbered", "@index")):
            i += 1
            continue
        if s.startswith("```"):
            flush()
            j = i + 1
            while j < len(L) and not L[j].strip().startswith("```"):
                j += 1
            cur.append(code_block(L[i + 1:j], ch.file))
            i = j + 1
            continue
        if s.startswith("@include "):
            flush()
            rel = s[9:].strip()
            fp = os.path.join(HERE, *rel.split("/"))
            if not os.path.isfile(fp):
                raise SystemExit("%s line %d: @include %s: no such file" % (ch.file, i + 1, rel))
            with open(fp, encoding="utf-8") as f:
                cur.append(code_block(f.read().rstrip("\n").splitlines(), rel, "docs/manual/" + rel))
            i += 1
            continue
        if s.startswith("@figure "):
            flush()
            m = re.match(r"^@figure\s+(\w+)\s+(\d+)\s*(.*)$", s)
            if not m:
                raise SystemExit("%s line %d: @figure name height caption" % (ch.file, i + 1))
            name, h, cap = m.group(1), int(m.group(2)), m.group(3).strip()
            figures.append((name, cap))
            fno = len(figures)
            new_chunk()                         # a figure is a chunk of its own, never parted from its caption
            cur.append('<div class="fig" id="fig-%s" style="height:%dpt"></div><p class="figcap">Figure %d. %s</p>'
                       % (name, h, fno, inline(cap, entries)))
            new_chunk()
            i += 1
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            new_chunk()
            lvl, text = len(m.group(1)), m.group(2).strip()
            em = ENTRY.match(s) if lvl == 3 else None
            if lvl == 1:
                text, hid = heading_id(text, cid)
                num = "" if ch.unnumbered else (label + " ")
                pre = "Appendix " if ch.appendix else ""
                cur.append('<h1 id="%s">%s%s%s</h1>' % (hid, pre if pre else "", esc(num), inline(text, entries)))
                sec = 0
            elif lvl == 2:
                sec += 1
                sub = 0
                text, hid = heading_id(text, "%s-%d" % (cid, sec))
                num = "" if ch.unnumbered else "%s.%d " % (label, sec)
                cur.append('<h2 id="%s">%s%s</h2>' % (hid, esc(num), inline(text, entries)))
            elif em:
                what, name = em.group(1), em.group(2)
                d = decls.get(name)
                if d is None:
                    PROBLEMS.append("%s line %d: no %s %s in the source" % (ch.file, i + 1, (what or "procedure").lower(), name))
                    sig = name
                elif what == "Structure":
                    sig = "Structure " + name
                elif what == "Prototype":
                    sig = d.sig
                else:
                    sig = d.sig
                procs.append([name, sig, label, None, d.module if d else "", what or "Procedure"])
                cur.append('<h3 id="e-%s" class="entry">%s</h3><p class="src">%s</p>'
                           % (anchor(name), esc(sig), esc(d.module) if d else ""))
                if what == "Structure" and d is not None:
                    cur.append(struct_block(d))
            elif lvl == 3:
                sub += 1
                text, hid = heading_id(text, "%s-%d-%d" % (cid, sec, sub))
                cur.append('<h3 id="%s">%s</h3>' % (hid, inline(text, entries)))
            else:
                text, hid = heading_id(text, "")
                cur.append('<h4%s>%s</h4>' % (' id="%s"' % hid if hid else "", inline(text, entries)))
            i += 1
            continue
        if not s:
            flush()
            i += 1
            continue
        if s.startswith("Internal:"):
            flush()
            names = re.findall(r"`([^`]+)`", s)
            cur.append('<p class="int"><span class="b">Internal.</span> Named like the public interface, but used only '
                       'by the engine itself; a program does not call or set them: %s.</p>'
                       % ", ".join("<code>%s</code>" % esc(n) for n in names))
            i += 1
            continue
        if s.startswith(">"):
            flush()
            box = []
            while i < len(L) and L[i].strip().startswith(">"):
                box.append(L[i].strip()[1:].strip())
                i += 1
            paras = " ".join(x if x else "\n\n" for x in box).split("\n\n")
            cur.append('<div class="box">%s</div>' % "".join("<p>%s</p>" % inline(p.strip(), entries)
                                                           for p in paras if p.strip()))
            continue
        if s.startswith("|"):
            flush()
            rows = []
            while i < len(L) and L[i].strip().startswith("|"):
                cells = [c.strip() for c in re.split(r"(?<!\\)\|", L[i].strip().strip("|"))]
                cells = [c.replace("\\|", "|") for c in cells]
                if not all(re.match(r"^:?-+:?$", c) for c in cells if c):
                    rows.append(cells)
                i += 1
            h = '<table class="t">'
            for r, cells in enumerate(rows):
                tag = "th" if r == 0 else "td"
                h += "<tr>" + "".join("<%s>%s</%s>" % (tag, inline(c, entries), tag) for c in cells) + "</tr>"
            cur.append(h + "</table>")
            continue
        lm = re.match(r"^(-|\d+\.)\s+(.*)$", s)
        if lm:
            k = "ol" if lm.group(1) != "-" else "ul"
            if para or (items and kind != k):
                flush()
            kind = k
            items.append(lm.group(2))
            i += 1
            continue
        if items and ln.startswith("  "):
            items[-1] += " " + s
            i += 1
            continue
        if items:
            flush()
        para.append(s)
        i += 1
    new_chunk()
    return chunks


def index_html(procs, label, title):
    h = ['<h1 id="c-%s">Appendix %s %s</h1><p>Every entry of the reference, in alphabetical order, with the '
         'chapter that documents it and its page. Click a name to go to it.</p>' % (anchor(label), label, esc(title))]
    letter = ""
    for name, sig, chap, page, module, what in sorted(procs, key=lambda x: x[0].lower().lstrip("#")):
        l0 = name.lstrip("#")[:1].upper()
        if l0 != letter:
            letter = l0
            h.append('<h4>%s</h4>' % esc(letter))
        kind = "" if what == "Procedure" else " (%s)" % what.lower()
        h.append('<p class="ix"><a href="#e-%s"><code>%s</code></a>%s <span class="pg">&#160;&#8230; chapter %s, page %s</span></p>'
                 % (anchor(name), esc(name), kind, esc(chap), page if page else "000"))
    return ["".join(h[i:i + 50]) for i in range(0, len(h), 50)]


# ------------------------------------------------------------------ page layout
CSS = """
@font-face { font-family: Body; src: url(Lato-Regular.ttf); }
@font-face { font-family: Body; font-weight: bold; src: url(Lato-Regular.ttf); }
@font-face { font-family: Body; font-style: italic; src: url(Lato-Regular.ttf); }
@font-face { font-family: Body; font-weight: bold; font-style: italic; src: url(Lato-Regular.ttf); }
@font-face { font-family: Mono; src: url(JetBrainsMono-Regular.ttf); }
@font-face { font-family: Mono; font-weight: bold; src: url(JetBrainsMono-Regular.ttf); }
@font-face { font-family: Mono; font-style: italic; src: url(JetBrainsMono-Regular.ttf); }
body { font-family: Body; font-size: 10pt; line-height: 1.38; color: #1c1c1c; }
h1 { font-family: Body; font-weight: normal; font-size: 21pt; color: #0d3a52; margin-top: 0; margin-bottom: 10pt;
     padding-bottom: 4pt; border-bottom: 1.4pt solid #0d7a8c; }
h2 { font-family: Body; font-weight: normal; font-size: 14pt; color: #0d3a52; margin-top: 14pt; margin-bottom: 4pt; }
h3 { font-family: Body; font-weight: normal; font-size: 11.5pt; color: #0d3a52; margin-top: 10pt; margin-bottom: 3pt; }
h3.entry { font-family: Mono; font-size: 8.6pt; color: #0d3a52; background-color: #e9f3f5; border-top: 0.8pt solid #0d7a8c;
           padding: 3pt 4pt 3pt 4pt; margin-top: 12pt; margin-bottom: 0pt; }
p.src { font-size: 7.5pt; color: #5a6a72; margin-top: 1pt; margin-bottom: 3pt; text-align: right; }
h4 { font-family: Body; font-weight: normal; font-size: 10pt; color: #0d7a8c; margin-top: 8pt; margin-bottom: 2pt; }
p { margin-top: 2pt; margin-bottom: 5pt; text-align: left; }
ul, ol { margin-top: 1pt; margin-bottom: 5pt; }
li { margin-bottom: 2pt; }
a { color: #0b6e80; text-decoration: none; }
code { font-family: Mono; font-size: 8.6pt; color: #20323a; }
pre { font-family: Mono; font-size: 6.8pt; line-height: 1.28; background-color: #f4f6f7; padding: 5pt;
      border-left: 2pt solid #0d7a8c; margin-top: 3pt; margin-bottom: 7pt; }
.b { color: #0d3a52; }
.capc { font-family: Mono; font-size: 7pt; color: #5a6a72; margin-bottom: 0; }
table.t { width: 100%; margin-top: 3pt; margin-bottom: 8pt; border-collapse: collapse; }
table.t td { border: 0.5pt solid #b7c4ca; padding: 2pt 4pt; vertical-align: top; font-size: 8.8pt; }
.box { border-left: 2.5pt solid #d08a1e; background-color: #fbf5ea; padding: 5pt 8pt; margin-top: 5pt; margin-bottom: 7pt; }
.int { font-size: 8.4pt; color: #4a5a62; }
.ix { font-size: 8.6pt; margin-top: 0; margin-bottom: 1pt; }
.pg { color: #5a6a72; }
.fig { margin-top: 4pt; margin-bottom: 2pt; }
.figcap { font-size: 8.6pt; color: #3a4a52; text-align: center; margin-top: 2pt; margin-bottom: 9pt; }
table.toc { width: 100%; border-collapse: collapse; }
td.toc0 { font-size: 11pt; color: #0d3a52; padding-top: 9pt; padding-bottom: 2pt; }
td.toc1 { font-size: 10pt; padding-top: 3pt; }
td.toc2 { font-size: 8.8pt; padding-left: 16pt; color: #2a3a42; }
td.tp { text-align: right; padding-left: 0; width: 40pt; }
span, a span, a code, td a, p a { text-decoration: none; }
td.th { color: #0d7a8c; font-size: 8.4pt; border-bottom: 1pt solid #0d7a8c; }
.title { margin-top: 150pt; }
.t1 { font-size: 34pt; color: #0d3a52; margin-bottom: 4pt; }
.t2 { font-size: 20pt; color: #0d7a8c; margin-bottom: 60pt; }
.t3 { font-size: 11pt; margin-bottom: 4pt; color: #2a3a42; }
.t4 { font-size: 9pt; color: #4a5a62; margin-top: 40pt; }
.part { margin-top: 220pt; }
.p1 { font-size: 13pt; color: #0d7a8c; margin-bottom: 4pt; }
.p2 { font-size: 28pt; color: #0d3a52; }
.legal p { font-size: 8.6pt; }
.legal pre { font-size: 7.4pt; }
"""

PAGE = pymupdf.paper_rect("letter")
MARGIN_L, MARGIN_R, MARGIN_T, MARGIN_B = 66, 66, 64, 62
WHERE = PAGE + (MARGIN_L, MARGIN_T, -MARGIN_R, -MARGIN_B)
ARCHIVE = pymupdf.Archive(FONTS)


def th_cells(s):
    return re.sub(r"<th>", '<td class="th">', s).replace("</th>", "</td>")


FTAG = re.compile(r"(f(?=[A-Za-z])|t(?=[fit]))")

SPLIT = re.compile(r"(<[^>]*>)")


def no_ligatures(h):
    """The PDF's text layer must read back as the text: searchable, and what the forbidden-content pass reads.
    Both faces join some characters into one glyph that the text layer then holds as a wrong character: Lato
    joins f with any letter after it and t with f, i or t (measured: its only ligatures of two letters), and
    JetBrains Mono joins and alternates punctuation in code ("..", "::", "->", ">>", "1:1" ...). A character in
    an element of its own is shaped alone: it looks the same and reads back as itself. So in code (pre, code)
    every punctuation character, and elsewhere every f before a letter and every t before f, i or t, is put
    in a span of its own, and so is the text between them."""
    out, code = [], 0
    for part in SPLIT.split(h):
        if part.startswith("<"):
            m = re.match(r"<(/?)(pre|code)(?=[\s>])", part)
            if m:
                code += -1 if m.group(1) else 1
            out.append(part)
        elif part:
            # every piece a span of its own, siblings: a bare text node beside a span sits on another
            # baseline in a table cell (measured), so no piece is left bare
            pieces = re.split(r"(&[#\w]+;|[^\w\s])", part) if code > 0 else FTAG.split(part)
            out.append("".join("<span>%s</span>" % x for x in pieces if x))
    return "".join(out)


def layout(chunks):
    """Lays every chunk out one after another (a chapter or a part starts a page).
    Returns (pdf bytes, ids {id: (page, rect)}, hrefs, heads [(level, page, y, id)])."""
    buf = io.BytesIO()
    writer = pymupdf.DocumentWriter(buf)
    ids, hrefs, heads = {}, [], []
    state = {"page": -1}
    dev = None
    y = WHERE.y1

    def cb(pos):
        pg = state["page"]
        if getattr(pos, "id", None) and (pos.open_close & 1):
            ids.setdefault(pos.id, (pg, pymupdf.Rect(pos.rect)))
            if pos.heading and pos.heading <= 2:
                heads.append((pos.heading, pg, pos.rect[1], pos.id))
        if getattr(pos, "href", None) and (pos.open_close & 1):
            hrefs.append((pg, pymupdf.Rect(pos.rect), pos.href))

    for ch in chunks:
        story = pymupdf.Story("<html><body>" + no_ligatures(th_cells(ch)) + "</body></html>", user_css=CSS, em=10,
                              archive=ARCHIVE)
        brk = ch.startswith(("<h1", '<div class="title"', '<div class="part"', '<div class="legal"'))
        need = 110 if ch.startswith(("<h2", "<h3")) else 40
        if ch.startswith('<h3 id="e-'):
            need = 70                            # a reference entry: its heading and a few lines
        fm = re.match(r'<div class="fig"[^>]*height:(\d+)pt', ch)
        if fm:
            need = int(fm.group(1)) + 40         # the figure and its caption on one page
        more, tries = 1, 0
        while more:
            tries += 1
            if tries > 400:
                raise SystemExit("layout did not end in the chunk: " + re.sub("<[^>]+>", " ", ch)[:120])
            if dev is None or brk or WHERE.y1 - y < need:
                if dev is not None:
                    writer.end_page()
                dev = writer.begin_page(PAGE)
                state["page"] += 1
                y = WHERE.y0
                brk = False
            more, filled = story.place(pymupdf.Rect(WHERE.x0, y, WHERE.x1, WHERE.y1))
            story.element_positions(cb)
            story.draw(dev)
            y = pymupdf.Rect(filled).y1 + 2
            if more:
                brk = True
        if ch.startswith(('<div class="part"', '<div class="title"', '<div class="legal"')):
            y = WHERE.y1            # nothing else on a part's, the title's or the licence's page
        del story
    writer.end_page()
    writer.close()
    return buf.getvalue(), ids, hrefs, heads


# ------------------------------------------------------------------ the figures, drawn as vectors
INK = (0.11, 0.15, 0.18)
TEAL = (0.05, 0.48, 0.55)
NAVY = (0.05, 0.23, 0.32)
AMBER = (0.82, 0.54, 0.12)
GREY = (0.55, 0.60, 0.63)
PALE = (0.91, 0.95, 0.96)
PALE2 = (0.98, 0.96, 0.92)
WHITE = (1, 1, 1)
FONT_BODY = pymupdf.Font(fontfile=BODY_FONT)
FONT_MONO = pymupdf.Font(fontfile=MONO_FONT)


class Fig:
    """Drawing in a figure's box: x, y in points from the box's top-left."""
    def __init__(self, page, rect):
        self.page, self.r = page, rect
        self.tw = pymupdf.TextWriter(page.rect)
        self.twc = {}

    def P(self, x, y):
        return pymupdf.Point(self.r.x0 + x, self.r.y0 + y)

    def box(self, x, y, w, h, fill=None, stroke=INK, width=0.7, dashes=None):
        self.page.draw_rect(pymupdf.Rect(self.P(x, y), self.P(x + w, y + h)), color=stroke, fill=fill,
                            width=width, dashes=dashes)

    def line(self, x0, y0, x1, y1, color=INK, width=0.7, dashes=None):
        self.page.draw_line(self.P(x0, y0), self.P(x1, y1), color=color, width=width, dashes=dashes)

    def arrow(self, x0, y0, x1, y1, color=INK, width=0.8, head=5):
        import math
        self.line(x0, y0, x1, y1, color, width)
        a = math.atan2(y1 - y0, x1 - x0)
        for s in (-1, 1):
            hx = x1 - head * math.cos(a + s * 0.45)
            hy = y1 - head * math.sin(a + s * 0.45)
            self.line(x1, y1, hx, hy, color, width)

    def poly(self, pts, color=INK, fill=None, width=0.7, closed=True):
        sh = self.page.new_shape()
        sh.draw_polyline([self.P(x, y) for x, y in pts] + ([self.P(*pts[0])] if closed else []))
        sh.finish(color=color, fill=fill, width=width, closePath=closed)
        sh.commit()

    def text(self, x, y, s, size=7.5, color=INK, mono=False, align="left"):
        f = FONT_MONO if mono else FONT_BODY
        w = f.text_length(s, fontsize=size)
        if align == "center":
            x -= w / 2
        elif align == "right":
            x -= w
        tw = self.twc.get(color)
        if tw is None:
            tw = self.twc[color] = pymupdf.TextWriter(self.page.rect, color=color)
        tw.append(self.P(x, y), s, font=f, fontsize=size)

    def done(self):
        for tw in self.twc.values():
            tw.write_text(self.page)


def fig_coords(F, W, H):
    F.box(20, 14, 300, 200, fill=PALE, stroke=NAVY, width=1)
    F.text(20, 10, "the canvas: Util_BaseWidth x Util_BaseHeight canvas units", 7.5, NAVY)
    F.arrow(20, 14, 340, 14, TEAL, 1)
    F.text(344, 17, "x", 9, TEAL)
    F.arrow(20, 14, 20, 232, TEAL, 1)
    F.text(16, 242, "y", 9, TEAL)
    F.text(24, 26, "(0, 0)", 7, TEAL, mono=True)
    F.text(316, 224, "(W, H)", 7, TEAL, mono=True, align="right")
    # a sprite at X, Y and the same turned about its centre
    F.box(90, 70, 70, 50, fill=WHITE, stroke=INK)
    F.line(90, 70, 90, 60, GREY, 0.5)
    F.text(90, 57, "X, Y: the top-left corner", 7, INK)
    F.text(125, 99, "w x h", 7, GREY, align="center")
    import math
    cx, cy, a = 230, 120, 0.5
    pts = []
    for lx, ly in ((-35, -25), (35, -25), (35, 25), (-35, 25)):
        pts.append((cx + lx * math.cos(a) - ly * math.sin(a), cy + lx * math.sin(a) + ly * math.cos(a)))
    F.box(195, 95, 70, 50, stroke=GREY, dashes="[2] 0")
    F.poly(pts, INK, WHITE)
    F.line(cx - 3, cy, cx + 3, cy, AMBER, 1)
    F.line(cx, cy - 3, cx, cy + 3, AMBER, 1)
    F.text(cx - 40, cy + 62, "Angle (radians, clockwise on screen)", 7, INK)
    F.text(cx - 40, cy + 71, "turns it about its centre X + w/2, Y + h/2", 7, INK)
    F.text(360, 60, "One canvas unit is one pixel of the", 7.5, INK)
    F.text(360, 70, "canvas framebuffer. y grows downwards.", 7.5, INK)
    F.text(360, 88, "Angles are radians; a positive angle", 7.5, INK)
    F.text(360, 98, "turns clockwise as seen on the screen.", 7.5, INK)
    F.text(360, 116, "Colours are R, G, B, A from 0.0 to 1.0.", 7.5, INK)


def fig_letterbox(F, W, H):
    F.box(10, 10, 230, 170, fill=PALE, stroke=NAVY, width=1)
    F.text(10, 6, "the canvas framebuffer (Util_FBO)", 7.5, NAVY)
    F.text(125, 95, "320 x 240", 9, NAVY, align="center")
    F.text(125, 108, "Util_BaseWidth x Util_BaseHeight", 7, NAVY, mono=True, align="center")
    F.arrow(250, 95, 285, 95, TEAL, 1.2)
    F.text(267, 86, "DrawPassthrough", 5.6, TEAL, mono=True, align="center")
    F.text(267, 108, "DrawRetroCRT", 5.6, TEAL, mono=True, align="center")
    F.box(295, 10, 180, 200, fill=(0.12, 0.12, 0.12), stroke=INK, width=1)
    F.text(295, 6, "the window's client area (physical pixels)", 7.5, INK)
    F.box(295, 42.5, 180, 135, fill=PALE, stroke=TEAL, width=1)
    F.text(385, 112, "GL_ViewportX, Y, W, H", 7, NAVY, mono=True, align="center")
    F.text(385, 30, "bar", 7, WHITE, align="center")
    F.text(385, 196, "bar", 7, WHITE, align="center")
    F.text(10, 196, "GL_HandleResize keeps the canvas's aspect: the largest rectangle of", 7.5, INK)
    F.text(10, 206, "that shape that fits the client area, centred; the rest is bars.", 7.5, INK)
    F.text(10, 222, "MapPhysicalToVirtual takes a pointer position back from the window to", 7.5, INK)
    F.text(10, 232, "the canvas: (P - GL_Viewport) / (GL_ViewportW / Util_BaseWidth).", 7.5, INK)


def fig_frame(F, W, H):
    steps = [("events", "WindowEvent until 0;\nresize: GL_HandleResize"),
             ("update", "move things by the\ntime since last frame"),
             ("draw", "bind Util_FBO;\ndraw in canvas units"),
             ("present", "framebuffer 0, viewport;\nDrawPassthrough"),
             ("flip", "FlipBuffers;\nDelay(1)")]
    x = 6
    for k, (t, d) in enumerate(steps):
        F.box(x, 22, 82, 64, fill=PALE if k != 2 else PALE2, stroke=NAVY)
        F.text(x + 41, 36, t, 9, NAVY, align="center")
        for n, part in enumerate(d.split("\n")):
            F.text(x + 41, 52 + n * 10, part, 6.0, INK, align="center")
        if k < len(steps) - 1:
            F.arrow(x + 82, 54, x + 94, 54, TEAL, 1)
        x += 94
    F.line(441, 90, 441, 104, TEAL, 1)
    F.line(441, 104, 47, 104, TEAL, 1)
    F.arrow(47, 104, 47, 88, TEAL, 1)
    F.text(244, 116, "one turn of the loop is one frame", 7.5, TEAL, align="center")


def fig_cell(F, W, H):
    bits = ["FLIPY", "FLIPX", "-", "DIAG"] + ["tile number + 1"] * 12
    x0, y0, bw = 20, 30, 27
    for i in range(16):
        b = 15 - i
        F.box(x0 + i * bw, y0, bw, 26, fill=PALE if b < 12 else PALE2, stroke=NAVY)
        F.text(x0 + i * bw + bw / 2, y0 - 4, str(b), 7, GREY, align="center")
    for name, b in (("FLIPY", 15), ("FLIPX", 14), ("0", 13), ("DIAG", 12)):
        F.text(x0 + (15 - b) * bw + bw / 2, y0 + 16, name, 6.2 if len(name) > 1 else 7, NAVY, align="center")
    F.text(x0 + 4 * bw + 6 * bw, y0 + 16, "tile number + 1   (0 = empty cell, 1 .. 4095 = tiles 0 .. 4094)", 7.5, NAVY,
           align="center")
    F.text(x0, y0 + 46, "#GL_TILE_FLIPY $8000    #GL_TILE_FLIPX $4000    bit 13 reserved (0)    #GL_TILE_DIAG $1000"
           "    #GL_TILE_NUMBER $0FFF", 6.8, INK, mono=True)
    F.text(x0, y0 + 60, "A cell is 16 bits, stored big-endian in the map file. The orientation is applied as DIAG, then FLIPX, "
           "then FLIPY.", 7.5, INK)


def fig_orient(F, W, H):
    import math
    names = [("0", 0), ("FLIPX", 1), ("FLIPY", 2), ("ROT180", 3), ("DIAG", 4), ("ROT90", 5), ("ROT270", 6), ("DIAG+X+Y", 7)]
    # an "F" in the unit square, T down
    shape = [(0.2, 0.1), (0.8, 0.1), (0.8, 0.28), (0.4, 0.28), (0.4, 0.45), (0.7, 0.45), (0.7, 0.62), (0.4, 0.62),
             (0.4, 0.9), (0.2, 0.9)]
    for k, (nm, o) in enumerate(names):
        x, y, s = 14 + (k % 8) * 60, 20, 44
        F.box(x, y, s, s, fill=PALE, stroke=NAVY)
        pts = []
        for px, py in shape:
            u, v = px, py
            if o & 4:
                u, v = v, u
            if o & 1:
                u = 1 - u
            if o & 2:
                v = 1 - v
            pts.append((x + u * s, y + v * s))
        F.poly(pts, NAVY, TEAL, 0.5)
        F.text(x + s / 2, y + s + 11, nm, 6.6, INK, mono=True, align="center")
    F.text(14, 92, "The picture of a tile, turned by its cell's orientation bits: DIAG swaps x and y first, then FLIPX "
           "mirrors left-right, then FLIPY top-bottom.", 7.2, INK)
    F.text(14, 102, "ROT90 = DIAG | FLIPX turns a quarter clockwise; ROT270 = DIAG | FLIPY; ROT180 = FLIPX | FLIPY.",
           7.2, INK)


def fig_parallax(F, W, H):
    rows = [("sky   ParallaxX 0.1", 0.1, (0.80, 0.88, 0.95)), ("hills  ParallaxX 0.45", 0.45, (0.80, 0.85, 0.80)),
            ("ground  ParallaxX 1", 1.0, (0.86, 0.80, 0.70)), ("status strip  Fixed", None, PALE2)]
    for k, (nm, p, col) in enumerate(rows):
        y = 16 + k * 42
        F.box(150, y, 300, 30, fill=col, stroke=NAVY)
        F.text(144, y + 18, nm, 7.5, NAVY, align="right")
        if p is None:
            F.text(300, y + 18, "drawn in canvas units; the camera does not move it", 7, INK, align="center")
        else:
            F.arrow(300, y + 15, 300 - 120 * p, y + 15, TEAL, 1.2)
            F.text(304, y + 18, "moves %s times as fast as the camera" % ("%g" % p), 7, INK)
    F.text(150, 190, "content point P is drawn at world  X - ScrollX + P + GL_CameraX * (1 - ParallaxX)", 7.5, NAVY)
    F.text(150, 202, "layers are drawn back to front: lowest Order first; equal Order in the order added", 7.5, NAVY)


def fig_camera(F, W, H):
    F.box(20, 20, 200, 150, stroke=GREY, dashes="[3] 0")
    F.text(20, 16, "the world", 7.5, GREY)
    F.box(70, 55, 100, 75, fill=PALE, stroke=TEAL, width=1)
    F.text(120, 95, "what the canvas shows", 7, NAVY, align="center")
    F.text(70, 140, "GL_CameraX, GL_CameraY: the world point at the canvas's top-left (zoom 1)", 7, INK)
    F.text(250, 50, "screen = C + (world - camera - C) * GL_CameraZoom", 8, NAVY, mono=True)
    F.text(250, 64, "C = the canvas centre (W / 2, H / 2)", 7.5, INK)
    F.text(250, 84, "Zoom > 1 magnifies about the canvas centre;", 7.5, INK)
    F.text(250, 94, "zoom < 1 shows more of the world.", 7.5, INK)
    F.text(250, 114, "IgnoreCamera = #True: the numbers are canvas units", 7.5, INK)
    F.text(250, 124, "and the camera is not applied (a HUD, the UI).", 7.5, INK)


def fig_tab(F, W, H):
    # one tab with its metrics
    x, y, h = 30, 40, 34
    F.box(x, y, 340, h, fill=PALE, stroke=NAVY)
    F.box(x, y, 340, 2.5, fill=TEAL, stroke=None)
    F.text(x + 30, y + 21, "main.pb", 9, NAVY)
    F.box(x + 340 - 26, y + 6, 22, 22, fill=WHITE, stroke=GREY)
    F.text(x + 340 - 15, y + 21, "x", 8, GREY, align="center")
    for a, b, lab in ((x, x + 12, "PADL 12"), (x + 300, x + 314, "GAPX 6"), (x + 314, x + 336, "close side")):
        F.line(a, y + h + 8, b, y + h + 8, AMBER, 0.8)
        F.line(a, y + h + 4, a, y + h + 12, AMBER, 0.8)
        F.line(b, y + h + 4, b, y + h + 12, AMBER, 0.8)
        F.text((a + b) / 2, y + h + 22, lab, 6.5, AMBER, align="center")
    F.text(x + 160, y + h + 22, "label room = TabW - PADL - GAPX - side - 1 (x Neon_UIScale)", 6.5, INK, align="center")
    F.text(x, 20, "a tab of a strip with close boxes: the active one carries the accent bar along its top", 7.5, NAVY)
    F.text(x, y + h + 44, "TabW = label width + 26 (+ side with a close box), at most Neon_TabMaxWidth: 26 line heights of the "
           "UI face, at least 300.", 7.2, INK)
    F.text(x, y + h + 55, "A label longer than its room is cut with an ellipsis by Neon_FitText; side = max(18, small face's "
           "line height + 2).", 7.2, INK)


def fig_menu(F, W, H):
    F.box(20, 14, 440, 24, fill=(0.17, 0.17, 0.18), stroke=None)
    for k, t in enumerate(["File", "View", "Long", "Help"]):
        x = 28 + k * 60
        if k == 1:
            F.box(x, 14, 52, 24, fill=(0.11, 0.22, 0.25), stroke=None)
            F.box(x, 36, 52, 2, fill=TEAL, stroke=None)
        F.text(x + 26, 30, t, 8, WHITE if k != 1 else TEAL, align="center")
    F.box(88, 38, 190, 120, fill=(0.17, 0.17, 0.18), stroke=TEAL)
    rows = [("Status line", True, ""), ("Pointer mark", False, ""), (None, None, None), ("Faces", None, ">")]
    y = 44
    for lab, chk, sc in rows:
        if lab is None:
            F.line(98, y + 4, 268, y + 4, GREY, 0.5)
            y += 9
            continue
        F.text(108, y + 15, lab, 8, WHITE)
        if chk:
            F.text(94, y + 15, "v", 7, (0.36, 0.75, 0.6))
        if sc:
            F.text(270, y + 15, sc, 8, GREY, align="right")
        y += 24
    F.text(300, 60, "row height 24, separator 9 (x Neon_UIScale)", 7, INK)
    F.text(300, 72, "width: the widest row of the frame before", 7, INK)
    F.text(300, 84, "a drop-down taller than the canvas scrolls,", 7, INK)
    F.text(300, 96, "with 16-unit arrow strips at both ends", 7, INK)
    F.text(300, 112, "Neon_MenuBlocksMouse: the bar and an open", 7, INK)
    F.text(300, 124, "drop-down own the pointer", 7, INK)


def fig_camera3d(F, W, H):
    ex, ey = 40, 110
    F.poly([(ex, ey), (300, 30), (300, 190)], NAVY, PALE, 0.8)
    F.line(ex, ey, 330, ey, GREY, 0.5, "[3] 0")
    F.line(150, 30 + (ey - 30) * (1 - 110 / 260.0), 150, 190 - (190 - ey) * (1 - 110 / 260.0), TEAL, 1)
    F.text(150, 72, "near", 7, TEAL, align="center")
    F.text(300, 26, "far", 7, NAVY, align="center")
    F.box(ex - 3, ey - 3, 6, 6, fill=AMBER, stroke=None)
    F.text(ex - 4, ey + 16, "eye x, y, z", 7.5, INK)
    F.box(330 - 3, ey - 3, 6, 6, fill=TEAL, stroke=None)
    F.text(336, ey + 3, "target tx, ty, tz", 7.5, INK)
    F.arrow(ex, ey, ex, ey - 40, AMBER, 1)
    F.text(ex + 4, ey - 34, "up (0, 1, 0)", 7, AMBER)
    F.text(90, 120, "fov", 7.5, NAVY)
    F.text(20, 210, "G3D_LookAt builds viewProjection = P x V: a right-handed view (the eye looks down -z of its space) and "
           "an OpenGL", 7.2, INK)
    F.text(20, 220, "perspective with fov the full vertical angle in radians, aspect = width / height, near > 0, far > near.",
           7.2, INK)


FIGURES = {"coords": fig_coords, "letterbox": fig_letterbox, "frame": fig_frame, "cell": fig_cell,
           "orient": fig_orient, "parallax": fig_parallax, "camera": fig_camera, "tab": fig_tab, "menu": fig_menu,
           "camera3d": fig_camera3d}


# ------------------------------------------------------------------ front matter
def title_html(version, date, counts):
    return ('<div class="title"><p class="t1">%s</p><p class="t2">%s</p>'
            '<p class="t3">%s</p><p class="t3">%s</p><p class="t3">MIT License</p>'
            '<p class="t4">%s</p></div>'
            % (esc(TITLE), esc(SUBTITLE), esc(version), esc("Documents the engine as of " + date) if date else "",
               esc(counts)))


def first_copyright(path):
    with open(path, encoding="utf-8") as f:
        for ln in f:
            if ln.startswith("Copyright"):
                return ln.strip()
    return ""


def legal_html():
    with open(os.path.join(ROOT, "LICENSE"), encoding="utf-8") as f:
        lic = f.read().rstrip()
    lato = first_copyright(os.path.join(FONTS, "Lato-OFL.txt"))
    jbm = first_copyright(os.path.join(FONTS, "JetBrainsMono-OFL.txt"))
    return ('<div class="legal"><h4>Licence</h4><p>The engine and this manual are distributed under the MIT License, '
            'the text of the file LICENSE at the root of the engine\'s repository:</p><pre>%s</pre>'
            '<h4>Typefaces</h4><p>This manual is set in Lato and JetBrains Mono, the two typefaces in the engine\'s '
            '<code>assets/fonts</code> folder, and embeds them. Both are licensed under the SIL Open Font License, '
            'Version 1.1, whose text is in that folder beside each font (<code>Lato-OFL.txt</code>, '
            '<code>JetBrainsMono-OFL.txt</code>).</p><p>Lato: %s</p><p>JetBrains Mono: %s</p>'
            '<h4>Building this manual</h4><p>This PDF is made from the Markdown files in <code>docs/manual</code> and the '
            'engine\'s source files by <code>docs/manual/build_manual.py</code>. <code>docs/manual/check_manual.py</code> '
            'reports any public name of the source the reference does not document, any example that was not '
            'compiled as printed, and any link that does not resolve.</p></div>'
            % (esc(lic), esc(lato), esc(jbm)))


def part_html(pid, num, title):
    return '<div class="part"><p class="p1">Part %s</p><h1 id="%s" class="ph">%s</h1></div>' % (esc(num), pid, esc(title))


def toc_html(entries):
    h = '<h1 id="toc">Contents</h1><table class="toc">'
    for kind, pg, hid, text in entries:
        cls = {"part": "toc0", "ch": "toc1", "sec": "toc2"}[kind]
        h += ('<tr><td class="%s"><a href="#%s">%s</a></td><td class="%s tp">%s</td></tr>'
              % (cls, hid, esc(text), cls, pg + 1 if pg >= 0 else "000"))
    return h + "</table>"


def decorate(doc, running, version):
    """Running header (the manual's name, the chapter's) and the page number."""
    n = doc.page_count
    for pno, page in enumerate(doc):
        if pno == 0 or running.get(pno) is None:
            continue
        r = page.rect
        page.wrap_contents()
        tw = pymupdf.TextWriter(r, color=NAVY)
        chap = running[pno]
        tw.append((MARGIN_L, 40), SHORT, font=FONT_BODY, fontsize=7.6)
        if chap:
            w = FONT_BODY.text_length(chap, fontsize=7.6)
            tw.append((r.width - MARGIN_R - w, 40), chap, font=FONT_BODY, fontsize=7.6)
        num = str(pno + 1)
        w = FONT_BODY.text_length(num, fontsize=8.5)
        tw.append(((r.width - w) / 2, r.height - 34), num, font=FONT_BODY, fontsize=8.5)
        tw.write_text(page)
        page.draw_line((MARGIN_L, 45), (r.width - MARGIN_R, 45), color=TEAL, width=0.5)


# ------------------------------------------------------------------ main
def chapter_files():
    files = sorted(f for f in os.listdir(HERE) if re.match(r"^\d\d-.*\.md$", f))
    if not files:
        raise SystemExit("no chapters (NN-name.md) in " + HERE)
    return [Chapter(os.path.join(HERE, f)) for f in files]


def build():
    chapters = chapter_files()
    decls = neon_source.by_name()
    entries = set()
    for ch in chapters:
        for ln in ch.lines:
            m = ENTRY.match(ln.strip())
            if m:
                entries.add(m.group(2))
    # labels: parts in order I, II ...; chapters numbered 1 ..; appendices lettered A ..
    roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
    nparts, nch, napp, appendix = 0, 0, 0, False
    plan = []                        # (chapter, label, part or None)
    for ch in chapters:
        part = None
        if ch.part:
            part = (roman[nparts], ch.part)
            nparts += 1
        if ch.appendix:
            appendix = True
        ch.appendix = appendix and not ch.unnumbered
        if ch.unnumbered:
            label = ""
        elif appendix:
            label = chr(ord("A") + napp)
            napp += 1
        else:
            nch += 1
            label = str(nch)
        plan.append((ch, label, part))

    procs, figures, body = [], [], []
    starts = []                      # (first chunk index, chapter label, chapter title) for the running heads
    index_slot = None
    for ch, label, part in plan:
        if part:
            body.append(part_html("part-" + part[0], part[0], part[1]))
        starts.append((len(body), label, ch.title, ch.appendix))
        if ch.index:
            index_slot = (len(body), label, ch.title)
            body.append("%INDEX%")
            continue
        body += chapter_html(ch, label or ch.file[:2], entries, decls, procs, figures)

    version, date = engine_version()
    pub = neon_source.public()
    counts = ("%d chapters and %d appendices; %d reference entries. Built from the engine's source by "
              "docs/manual/build_manual.py." % (nch, napp, len(procs)))

    def assemble(toc, idx):
        out = [title_html(version, date, counts), legal_html(), toc]
        for c in body:
            if c == "%INDEX%":
                out += idx
            else:
                out.append(c)
        return out

    def toc_entries(ids):
        res = []
        for ch, label, part in plan:
            if part:
                pid = "part-" + part[0]
                res.append(("part", ids.get(pid, (-1,))[0], pid, "Part %s  %s" % part))
            cid = "c-" + anchor(label or ch.file[:2])
            pre = ("Appendix %s  " % label) if ch.appendix else ("%s  " % label if label else "")
            res.append(("ch", ids.get(cid, (-1,))[0], cid, pre + ch.title))
            if not ch.index and not ch.unnumbered:
                sec = 0
                for ln in ch.lines:
                    m = re.match(r"^##\s+(.*)$", ln.strip())
                    if m and not ln.strip().startswith("###"):
                        sec += 1
                        t, hid = heading_id(m.group(1), "%s-%d" % (cid, sec))
                        if not ch.appendix or True:
                            res.append(("sec", ids.get(hid, (-1,))[0], hid, "%s.%d  %s" % (label, sec, re.sub(r"`", "", t))))
        return res

    def idx_chunks():
        if not index_slot:
            return []
        return index_html(procs, index_slot[1], index_slot[2])

    # pass 1 with placeholders, then again until the page numbers stop moving
    toc = toc_html([(k, -1, h, t) for k, _, h, t in toc_entries({})])
    pdf, ids, hrefs, heads = layout(assemble(toc, idx_chunks()))
    for _ in range(5):
        for p in procs:
            p[3] = ids.get("e-" + anchor(p[0]), (-1,))[0] + 1
        old = dict((k, v[0]) for k, v in ids.items())
        toc = toc_html(toc_entries(ids))
        pdf, ids, hrefs, heads = layout(assemble(toc, idx_chunks()))
        if all(ids.get(k, (None,))[0] == v for k, v in old.items()):
            break
    for p in procs:
        p[3] = ids.get("e-" + anchor(p[0]), (-1,))[0] + 1

    doc = pymupdf.open("pdf", pdf)
    # links
    missing = set()
    for pg, rect, href in hrefs:
        if href.startswith("#"):
            t = ids.get(href[1:])
            if t is None:
                missing.add(href)
                continue
            doc[pg].insert_link({"kind": pymupdf.LINK_GOTO, "from": rect, "page": t[0],
                                 "to": pymupdf.Point(0, max(0, t[1].y0 - 10)), "zoom": 0})
        else:
            doc[pg].insert_link({"kind": pymupdf.LINK_URI, "from": rect, "uri": href})
    # figures
    for name, cap in figures:
        t = ids.get("fig-" + name)
        if not t:
            PROBLEMS.append("figure %s was not laid out" % name)
            continue
        page = doc[t[0]]
        page.wrap_contents()
        F = Fig(page, t[1])
        FIGURES[name](F, t[1].width, t[1].height)
        F.done()
    # outline: parts, chapters, sections
    outline = []
    for kind, pg, hid, text in toc_entries(ids):
        if pg < 0:
            continue
        lvl = {"part": 1, "ch": 2, "sec": 3}[kind]
        if not outline:
            lvl = 1
        lvl = min(lvl, (outline[-1][0] + 1) if outline else 1)
        y = ids[hid][1].y0
        outline.append([lvl, text, pg + 1, {"kind": pymupdf.LINK_GOTO, "page": pg, "to": pymupdf.Point(0, max(0, y - 10))}])
    outline.insert(0, [1, "Contents", ids["toc"][0] + 1, {"kind": pymupdf.LINK_GOTO, "page": ids["toc"][0],
                                                          "to": pymupdf.Point(0, 0)}])
    doc.set_toc(outline)
    # running heads: the chapter that a page belongs to
    chstarts = []
    for ch, label, part in plan:
        cid = "c-" + anchor(label or ch.file[:2])
        if cid in ids:
            name = ("Appendix %s  %s" % (label, ch.title)) if ch.appendix else (("%s  %s" % (label, ch.title)) if label else ch.title)
            chstarts.append((ids[cid][0], name))
        if part:
            pid = "part-" + part[0]
            if pid in ids:
                chstarts.append((ids[pid][0], None))
    chstarts.sort()
    running = {}
    tocpage = ids["toc"][0]
    for pno in range(doc.page_count):
        cur = None
        for start, name in chstarts:
            if start <= pno:
                cur = (start, name)
        if pno <= 1:
            running[pno] = None
        elif cur is None:
            running[pno] = "Contents" if pno >= tocpage else None
        elif cur[0] == pno and cur[1] is None:
            running[pno] = None          # a part's own page
        else:
            running[pno] = cur[1] if cur[1] else ""
    decorate(doc, running, version)
    now = pymupdf.get_pdf_now()
    doc.set_metadata({"title": "%s - %s" % (TITLE, SUBTITLE), "subject": "Programming with the Neon Arcade Display "
                      "Engine: guides and reference. " + version + (", " + date if date else ""),
                      "keywords": "Neon Arcade, display engine, OpenGL, tile maps, palettes, user interface",
                      "author": "", "creator": "", "producer": "", "creationDate": now, "modDate": now})
    doc.del_xml_metadata()
    doc.subset_fonts()                       # only the glyphs used, of Lato and JetBrains Mono
    doc.save(OUT, garbage=4, deflate=True, clean=True)
    for p in PROBLEMS:
        print("problem:", p)
    if missing:
        print("unresolved links:", " ".join(sorted(missing)))
    if WRAPPED:
        print("code lines longer than %d characters, wrapped:" % MAXCOL, "; ".join(WRAPPED))
    print("written %s: %d pages, %d chapters, %d appendices, %d reference entries, %d figures, %d links"
          % (os.path.relpath(OUT, ROOT), doc.page_count, nch, napp, len(procs), len(figures), len(hrefs)))
    return 1 if (missing or PROBLEMS) else 0


if __name__ == "__main__":
    sys.exit(build())
