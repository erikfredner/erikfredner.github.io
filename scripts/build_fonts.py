# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "fonttools[woff]",
# ]
# ///
"""Download EB Garamond and subset it for fredner.org.

Upstream ships every script the family covers (Greek, Cyrillic, a full set of
small caps and alternates; the roman alone is 830 KB as TTF), so each face is
cut down to the codepoints and layout features this site actually uses before
being written to fonts/ as a variable WOFF2.

EB Garamond is the site's only webfont: it sets prose, headings, and chrome
alike. Code uses the platform's own monospace (see --font-mono in style.css).

Run via `make fonts`. Output is committed; rerun deliberately, not on every build.
"""

import argparse
import sys
import urllib.request
from pathlib import Path
from tempfile import TemporaryDirectory

from fontTools import subset
from fontTools.ttLib import TTFont

# google/fonts carries Octavio Pardo's variable build (wght 400-800), which is
# the maintained one; Georg Duffner's original static EB Garamond is frozen.
RAW = "https://raw.githubusercontent.com/google/fonts/main/ofl/ebgaramond/{path}"

# (output stem, upstream path)
FACES = [
    ("eb-garamond-roman", "EBGaramond%5Bwght%5D.ttf"),
    ("eb-garamond-italic", "EBGaramond-Italic%5Bwght%5D.ttf"),
]

# Saved under this name in fonts/; the Makefile copies it to docs/fonts/
# because the OFL requires the license to travel with the fonts.
LICENSE = ("OFL.txt", "LICENSE-eb-garamond.txt")

# Every non-ASCII character in src/ and references.bib, plus the symbols the
# template injects, plus headroom in the two Latin blocks. Latin Extended-A
# matters: Č č ļ Š appear in references.bib author names and fall outside the
# usual "latin" webfont subset.
#
# Requesting a codepoint the upstream face lacks is harmless — the subsetter
# skips it — but it is not the same as covering it, so the list below names
# only characters EB Garamond actually has. Three that the site uses and it
# does not, all of which render from a system font: ☰ U+2630 (the nav toggle),
# ↩ U+21A9 (pandoc's footnote back-link, emitted with the text-presentation
# selector U+FE0E), and U+202F narrow no-break space (a handful of
# Zotero-pasted citations in src/, invisible either way). Check the `report()` glyph counts afterward.
# The slide decks under slides/ are self-contained and link none of these
# fonts, so their character coverage is not a constraint here.
TEXT_RANGES = [
    (0x0000, 0x00FF),  # Basic Latin + Latin-1 Supplement (NBSP, á ä é ë í)
    (0x0100, 0x017F),  # Latin Extended-A (Č č ļ Š)
    (0x2013, 0x2014),  # en/em dash
    (0x2018, 0x201D),  # curly quotes
    (0x2020, 0x2021),  # dagger, double dagger
    (0x2026, 0x2026),  # ellipsis
    (0x2191, 0x2191),  # ↑ back-to-top button
    # No ▸ U+25B8 / ▾ U+25BE: the TOC disclosure triangle is drawn with CSS
    # borders, not a glyph in `content`, because NVDA and VoiceOver announce
    # generated text and read the marker out as part of the label. Do not
    # restore them without first re-reading the .toc-label::before rule in
    # css/style.css.
    (0xFB01, 0xFB02),  # fi/fl ligatures
]

# Kept: kerning, ligatures, contextual alternates, mark positioning. Dropped:
# everything else the subsetter would otherwise retain. Two drops are
# deliberate and worth knowing about:
#   * `smcp`. EB Garamond has true small caps, but they cost 17 KB on the roman
#     alone, on every page, for three phrases on avg-syllabus. `.smallcaps` is
#     synthesized instead, as it always was.
#   * `lnum`/`tnum`/`onum`. Upstream's default figures are already lining,
#     which is what the tables and dates want, so no figure feature is needed.
LAYOUT_FEATURES = ["kern", "liga", "clig", "calt", "ccmp", "locl", "mark", "mkmk"]


def expand(ranges):
    return [cp for lo, hi in ranges for cp in range(lo, hi + 1)]


def subset_face(src, dest, unicodes):
    """Subset `src` into a WOFF2 at `dest`.

    Reproducible as long as upstream is unchanged: subset.load_font opens the
    font with recalcTimestamp off (Options.recalc_timestamp defaults to False),
    so `head.modified` keeps upstream's date rather than the build time and
    `git diff fonts/` is signal, not noise.
    """
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = LAYOUT_FEATURES
    options.name_IDs = ["*"]  # keep family/style names so the CSS can match
    options.name_legacy = True
    options.notdef_outline = True
    options.drop_tables += ["DSIG"]
    # Leave the variation tables (fvar/gvar/HVAR) intact — these are variable
    # fonts and the weight axis has to survive.

    font = subset.load_font(str(src), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    subset.save_font(font, str(dest), options)


def report(path):
    """Print the size and variation axes of a finished subset."""
    kb = path.stat().st_size / 1024
    with TTFont(path) as font:
        if "fvar" in font:
            axes = " ".join(
                f"{a.axisTag} {a.minValue:g}-{a.maxValue:g}" for a in font["fvar"].axes
            )
        else:
            axes = "static"
        glyphs = font["maxp"].numGlyphs
    print(f"  {path.name:<32} {kb:6.1f} KB  {glyphs:4d} glyphs  [{axes}]", file=sys.stderr)
    return kb


def main():
    parser = argparse.ArgumentParser(description="Subset EB Garamond for the site.")
    parser.add_argument("--out-dir", required=True, help="Directory to write .woff2 files into")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    unicodes = expand(TEXT_RANGES)

    total = 0.0
    with TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for stem, path in FACES:
            url = RAW.format(path=path)
            src = tmp_path / f"{stem}.ttf"
            print(f"Fetching {url}", file=sys.stderr)
            urllib.request.urlretrieve(url, src)

            dest = out_dir / f"{stem}.woff2"
            subset_face(src, dest, unicodes)
            total += report(dest)

        upstream, local = LICENSE
        urllib.request.urlretrieve(RAW.format(path=upstream), out_dir / local)

    print(f"  {'total':<32} {total:6.1f} KB", file=sys.stderr)


if __name__ == "__main__":
    main()
