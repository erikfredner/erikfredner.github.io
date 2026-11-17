# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Write BibTeX and RIS files for a page whose frontmatter has `article:`.

    build_citations.py SRC.md OUT_DIR    writes OUT_DIR/<stem>.bib and .ris

The page links both from its article box (templates/base.html). The fields
are the ones filters/article.lua reads for the on-page citation and the
Google Scholar tags; see that filter's header for the frontmatter schema, and
keep the two in step.

Titles are markdown in the frontmatter. `*x*` / `_x_` becomes \\emph{x} in
BibTeX, with every capitalized word braced so a sentence-case style cannot
lowercase it (BibTeX's convention for preserving case); RIS takes plain text.
"""

import re
import sys
from pathlib import Path

import yaml

EMPH = re.compile(r"(\*|_)(.+?)\1")


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    return yaml.safe_load(m.group(1)) if m else {}


def plain(s):
    return EMPH.sub(r"\2", str(s))


def bib_escape(s):
    return re.sub(r"([&%$#_])", r"\\\1", s)


def bib_title(s):
    s = bib_escape_markdown(str(s))
    # Brace words that start with a capital, outside \emph{...} commands.
    return re.sub(r"(?<![\\\w])([A-Z][\w'’.-]*)", r"{\1}", s)


def bib_escape_markdown(s):
    out, pos = [], 0
    for m in EMPH.finditer(s):
        out.append(bib_escape(s[pos:m.start()]))
        out.append(r"\emph{" + bib_escape(m.group(2)) + "}")
        pos = m.end()
    out.append(bib_escape(s[pos:]))
    return "".join(out)


def split_name(name):
    given, _, family = name.rpartition(" ")
    return given, family


def full_title(meta):
    t = str(meta["title"])
    if meta.get("subtitle"):
        t += ": " + str(meta["subtitle"])
    return t


def bibtex(stem, meta, a):
    authors = " and ".join(
        f"{fam}, {giv}" if giv else fam for giv, fam in map(split_name, (x["name"] for x in a["authors"]))
    )
    first_family = split_name(a["authors"][0]["name"])[1].lower()
    key = re.sub(r"\W", "", first_family + re.sub(r"\W", "", plain(meta["title"]).split()[0]).title() + str(a["year"]))
    fields = [
        ("author", authors),
        ("title", bib_title(full_title(meta))),
        ("journal", bib_escape(str(a["journal"]))),
        ("volume", a.get("volume")),
        ("number", a.get("issue")),
        ("pages", str(a["pages"]).replace("–", "--") if a.get("pages") else None),
        ("year", a.get("year")),
        ("doi", a.get("doi")),
        ("url", f"https://fredner.org/{stem}.html"),
        ("note", "Forthcoming" if a.get("status") == "forthcoming" else None),
    ]
    body = ",\n".join(f"  {k} = {{{v}}}" for k, v in fields if v not in (None, ""))
    return f"@article{{{key},\n{body}\n}}\n"


def ris(stem, meta, a):
    lines = [("TY", "JOUR")]
    for x in a["authors"]:
        giv, fam = split_name(x["name"])
        lines.append(("AU", f"{fam}, {giv}" if giv else fam))
    lines += [
        ("TI", plain(full_title(meta))),
        ("T2", plain(a["journal"])),
        ("VL", a.get("volume")),
        ("IS", a.get("issue")),
        ("PY", a.get("year")),
    ]
    if a.get("pages"):
        sp, _, ep = str(a["pages"]).partition("–")
        lines += [("SP", sp), ("EP", ep or None)]
    lines += [
        ("DO", a.get("doi")),
        ("UR", f"https://fredner.org/{stem}.html"),
        ("N1", "Forthcoming" if a.get("status") == "forthcoming" else None),
        ("ER", ""),
    ]
    return "".join(f"{k}  - {v}\r\n" for k, v in lines if v is not None)


def main():
    src, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    meta = frontmatter(src)
    a = meta.get("article")
    if not a:
        sys.exit(f"{src}: no article: frontmatter")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{src.stem}.bib").write_text(bibtex(src.stem, meta, a), encoding="utf-8")
    (out_dir / f"{src.stem}.ris").write_bytes(ris(src.stem, meta, a).encode("utf-8"))


if __name__ == "__main__":
    main()
