# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Check the built site in docs/ for errors a reader would hit.

`make check` runs this after a build. The site has no test suite and no CI, so
this is the regression net: everything it reports is something that is broken
on the live site, not a style preference. Stdlib only, and offline — external
links are not fetched.

What it checks, per built HTML page:

- every local href/src resolves to a file in docs/, and every #fragment (on the
  same page or another) names an id that exists there
- no id is used twice on one page (a duplicate breaks fragment links and
  aria references silently: the browser just picks the first)
- every <img> has an alt attribute, and every local <img> has width/height
  (filters/image-size.lua is supposed to reserve every image's box)
- aria-labelledby / aria-describedby / aria-controls / for= point at real ids
- heading levels never skip downward (h2 -> h4), which breaks the outline a
  screen reader navigates by
- one <h1>, a non-empty <title>, <html lang>, and a canonical link (except the
  404 page, which deliberately has none)
- no unresolved citation or cross-reference markers left in the text: pandoc
  -crossref writes "??" for a dangling @fig:/@tbl: reference, and citeproc
  writes "(key?)" for a citation key that is not in references.bib

And for the site as a whole: feed.xml and sitemap.xml parse, and every URL in
the sitemap maps to a built file.

Exit status is 1 if anything is reported, so a failing check fails `make check`.
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

SITE_HOSTS = {"fredner.org", "www.fredner.org"}
# fredner.org/<name>/ paths served by the GitHub Pages sites of *other* repos
# (project sites), so they are not in docs/ and cannot be checked from here.
PROJECT_SITES = {"mapping-canon", "eng108"}
IDREF_ATTRS = ("aria-labelledby", "aria-describedby", "aria-controls", "for")
# Pages GitHub Pages serves under other names, or that are not pandoc output.
NO_CANONICAL = {"404.html"}


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = {}
        self.dup_ids = set()
        self.links = []  # (attr, value)
        self.imgs = []  # attrs dict
        self.idrefs = []  # (attr, id)
        self.headings = []  # (level, line)
        self.title = None
        self._in_title = False
        self._skip_text = 0  # inside <script>/<style>
        self.lang = None
        self.canonical = None
        self.text = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html":
            self.lang = a.get("lang")
        if "id" in a and a["id"] is not None:
            if a["id"] in self.ids:
                self.dup_ids.add(a["id"])
            self.ids[a["id"]] = self.getpos()[0]
        # Pre-HTML5 named anchors still work as fragment targets.
        if tag == "a" and a.get("name"):
            self.ids.setdefault(a["name"], self.getpos()[0])
        for attr in ("href", "src", "poster"):
            if a.get(attr):
                self.links.append((tag, attr, a[attr], self.getpos()[0]))
        if tag == "link" and a.get("rel") == "canonical":
            self.canonical = a.get("href")
        if tag in ("img", "video"):
            self.imgs.append((tag, a, self.getpos()[0]))
        for attr in IDREF_ATTRS:
            if a.get(attr):
                for ref in a[attr].split():
                    self.idrefs.append((attr, ref, self.getpos()[0]))
        if re.fullmatch(r"h[1-6]", tag):
            self.headings.append((int(tag[1]), self.getpos()[0]))
        if tag == "title":
            self._in_title = True
            self.title = ""
        if tag in ("script", "style"):
            self._skip_text += 1

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        if tag in ("script", "style") and self._skip_text:
            self._skip_text -= 1

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if not self._skip_text:
            self.text.append((data, self.getpos()[0]))


def parse(path):
    p = Page()
    p.feed(path.read_text(encoding="utf-8"))
    p.close()
    return p


def resolve(out_dir, page_path, url):
    """Map a link on page_path to (file in out_dir or None, fragment) or None if external."""
    parts = urlsplit(url)
    if parts.scheme in ("mailto", "tel", "data", "javascript"):
        return None
    if parts.scheme in ("http", "https") or url.startswith("//"):
        if parts.netloc not in SITE_HOSTS:
            return None
        if parts.path.strip("/").split("/")[0] in PROJECT_SITES:
            return None
        target = out_dir / unquote(parts.path).lstrip("/")
    elif parts.path == "":
        target = page_path
    elif parts.path.startswith("/"):
        target = out_dir / unquote(parts.path).lstrip("/")
    else:
        target = page_path.parent / unquote(parts.path)
    if target.is_dir() or str(parts.path).endswith("/"):
        target = target / "index.html"
    return target, parts.fragment


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out-dir", default="docs")
    args = ap.parse_args()
    out_dir = Path(args.out_dir).resolve()

    pages = sorted(p for p in out_dir.rglob("*.html") if "slides" not in p.parts)
    parsed = {p: parse(p) for p in pages}
    problems = []

    def report(path, line, msg):
        problems.append(f"{path.relative_to(out_dir)}:{line}: {msg}")

    for path, page in parsed.items():
        # The CV redirect stub is a bare meta-refresh, not a pandoc page.
        is_stub = path.relative_to(out_dir).as_posix() == "cv/index.html"

        for i in sorted(page.dup_ids):
            report(path, page.ids[i], f"duplicate id {i!r}")

        for tag, attr, url, line in page.links:
            r = resolve(out_dir, path, url)
            if r is None:
                continue
            target, frag = r
            target = target.resolve()
            if out_dir != target and out_dir not in target.parents:
                # Browsers clamp ".." at the root, so this may even work on
                # the live site, but only by accident (and image-size.lua,
                # which resolves against src/, cannot find the file).
                report(path, line, f"<{tag} {attr}> {url!r} climbs above the site root")
                continue
            if not target.exists():
                report(path, line, f"<{tag} {attr}> {url!r}: no such file {target.relative_to(out_dir)}")
                continue
            if frag and target.suffix == ".html":
                other = parsed.get(target) or parse(target)
                if unquote(frag) not in other.ids:
                    report(path, line, f"<{tag} {attr}> {url!r}: no id {frag!r} in {target.relative_to(out_dir)}")

        for tag, a, line in page.imgs:
            if tag == "img" and "alt" not in a:
                report(path, line, f"<img src={a.get('src')!r}> has no alt attribute")
            src = a.get("src") or ""
            if src and not urlsplit(src).scheme and not src.startswith("//"):
                if not (a.get("width") and a.get("height")):
                    report(path, line, f"<{tag} src={src!r}> has no width/height (layout shift)")

        for attr, ref, line in page.idrefs:
            if ref not in page.ids:
                report(path, line, f"{attr}={ref!r} names no element on the page")

        if is_stub:
            continue

        prev = None
        for level, line in page.headings:
            if prev is not None and level > prev + 1:
                report(path, line, f"heading skips from h{prev} to h{level}")
            prev = level
        h1s = [h for h in page.headings if h[0] == 1]
        if len(h1s) != 1:
            report(path, 1, f"{len(h1s)} <h1> elements (want exactly 1)")
        if not (page.title or "").strip():
            report(path, 1, "empty <title>")
        if not page.lang:
            report(path, 1, "<html> has no lang")
        if path.name not in NO_CANONICAL and not page.canonical:
            report(path, 1, "no <link rel=canonical>")

        for data, line in page.text:
            if "??" in data and re.search(r"(?<![?\w])\?\?(?![?\w])", data):
                report(path, line, f"unresolved cross-reference marker '??' in {data.strip()[:60]!r}")
            m = re.search(r"\(([\w:-]+)\?\)", data)
            if m:
                report(path, line, f"unresolved citation key {m.group(1)!r}")

    for name in ("feed.xml", "sitemap.xml"):
        f = out_dir / name
        try:
            tree = ET.parse(f)
        except (ET.ParseError, FileNotFoundError) as e:
            problems.append(f"{name}: does not parse: {e}")
            continue
        if name == "sitemap.xml":
            for loc in tree.iter("{http://www.sitemaps.org/schemas/sitemap/0.9}loc"):
                r = resolve(out_dir, out_dir / "index.html", loc.text)
                if r is None or not r[0].exists():
                    problems.append(f"sitemap.xml: {loc.text} has no built page")

    for p in problems:
        print(p)
    print(f"Check: {len(pages)} page(s), {len(problems)} problem(s).", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
