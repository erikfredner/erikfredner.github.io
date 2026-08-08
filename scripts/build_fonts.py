# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "fonttools[woff]",
# ]
# ///
"""Download Adobe's Source variable fonts and subset them for fredner.org.

Upstream ships every script the families cover (the Source Serif roman alone is
417 KB as WOFF2), so each face is cut down to the codepoints this site actually
uses before being written to fonts/ as a variable WOFF2.

Run via `make fonts`. Output is committed; rerun deliberately, not on every build.
"""

import argparse
import sys
import urllib.request
from pathlib import Path
from tempfile import TemporaryDirectory

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

RAW = "https://raw.githubusercontent.com/adobe-fonts/{repo}/release/{path}"

# Source Serif 4 carries a second variation axis, opsz 8-60, whose gvar deltas
# more than double the file (124 KB vs 51 KB for the roman). The serif is only
# ever set at 16-18px here — body prose, blockquotes, footnotes — so the axis is
# pinned to its default of 20 ("Text", Adobe's continuous-reading instance)
# rather than shipped. Set to None to keep an axis live.
PIN_OPSZ = 20

# (output stem, repo, upstream path, unicode set)
FACES = [
    ("source-serif-4-roman", "source-serif", "VAR/SourceSerif4Variable-Roman.ttf", "text"),
    ("source-serif-4-italic", "source-serif", "VAR/SourceSerif4Variable-Italic.ttf", "text"),
    ("source-sans-3-upright", "source-sans", "VF/SourceSans3VF-Upright.ttf", "text"),
    ("source-code-pro-upright", "source-code-pro", "VF/SourceCodeVF-Upright.ttf", "mono"),
]

LICENSES = ["source-serif", "source-sans", "source-code-pro"]

# Every non-ASCII character in src/ and references.bib, plus the symbols the
# template and stylesheet inject, plus headroom in the two Latin blocks.
# Latin Extended-A matters: Č č ļ Š appear in references.bib author names and
# fall outside the usual "latin" webfont subset.
#
# Requesting a codepoint no upstream face contains is harmless — the subsetter
# skips it — but it is not the same as covering it. ☰ U+2630 is the live case:
# the nav toggle emits it and .nav-toggle sets --font-sans, yet no Source face
# ships the glyph, so it renders from a system font today. The range is kept
# because the site genuinely uses the character and would want it the moment
# Adobe adds it; the `report()` glyph counts are what to check afterward.
# The slide decks under slides/ are self-contained and link none of these
# fonts, so their character coverage is not a constraint here.
TEXT_RANGES = [
    (0x0000, 0x00FF),  # Basic Latin + Latin-1 Supplement (NBSP, á ä é ë í)
    (0x0100, 0x017F),  # Latin Extended-A (Č č ļ Š)
    (0x2013, 0x2014),  # en/em dash
    (0x2018, 0x201D),  # curly quotes
    (0x2020, 0x2021),  # dagger, double dagger
    (0x2026, 0x2026),  # ellipsis
    (0x202F, 0x202F),  # narrow no-break space
    (0x2191, 0x2191),  # ↑ back-to-top button
    # No ▸ U+25B8 / ▾ U+25BE: the TOC disclosure triangle is drawn with CSS
    # borders, not a glyph in `content`, because NVDA and VoiceOver announce
    # generated text and read the marker out as part of the label. Only Source
    # Sans ever carried these two — the serif faces do not contain them — so
    # dropping them shrinks the sans subset alone. Do not restore them without
    # first re-reading the .toc-label::before rule in css/style.css.
    (0x2630, 0x2630),  # ☰ mobile nav toggle — see note below
    (0xFB01, 0xFB02),  # fi/fl ligatures
]

MONO_RANGES = [
    (0x0000, 0x007F),  # inline <code> only; the site has no <pre> blocks
]

# Kept: kerning, ligatures, contextual alternates, mark positioning. Dropped:
# everything else pyftsubset would otherwise retain (small caps, alt figures,
# swashes) since no page calls for them.
LAYOUT_FEATURES = ["kern", "liga", "clig", "calt", "ccmp", "locl", "mark", "mkmk"]


def expand(ranges):
    return [cp for lo, hi in ranges for cp in range(lo, hi + 1)]


def pin_optical_size(src, dest):
    """Freeze the opsz axis at PIN_OPSZ, leaving wght variable. No-op if absent.

    recalcTimestamp=False keeps upstream's `head.modified` instead of stamping
    the build time, which is what makes this script reproducible. fontTools
    restamps on save by default, and the subsetter downstream preserves whatever
    it is handed — so without this, the two Source Serif faces (the only ones
    with an opsz axis, hence the only ones saved here) came out with different
    bytes on every run while Source Sans and Code Pro stayed identical. That
    made `git diff fonts/` noise rather than signal, and defeated the point of
    reviewing it. Upstream's own date still moves when Adobe cuts a release.
    """
    with TTFont(src, recalcTimestamp=False) as font:
        tags = {a.axisTag for a in font["fvar"].axes}
        if PIN_OPSZ is None or "opsz" not in tags:
            return src
        instantiateVariableFont(font, {"opsz": PIN_OPSZ}, inplace=True)
        font.save(dest)
    return dest


def subset_face(src, dest, unicodes):
    options = subset.Options()
    options.flavor = "woff2"
    options.layout_features = LAYOUT_FEATURES
    options.name_IDs = ["*"]  # keep family/style names so the CSS can match
    options.name_legacy = True
    options.notdef_outline = True
    options.drop_tables += ["DSIG"]
    # Leave desubroutinize off and the variation tables (fvar/gvar/HVAR) intact —
    # these are variable fonts and the weight axis has to survive.

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
    parser = argparse.ArgumentParser(description="Subset the Source fonts for the site.")
    parser.add_argument("--out-dir", required=True, help="Directory to write .woff2 files into")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    text_unicodes = expand(TEXT_RANGES)
    mono_unicodes = expand(MONO_RANGES)

    total = 0.0
    with TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for stem, repo, path, kind in FACES:
            url = RAW.format(repo=repo, path=path)
            src = tmp_path / f"{stem}.ttf"
            print(f"Fetching {repo}/{path}", file=sys.stderr)
            urllib.request.urlretrieve(url, src)

            pinned = pin_optical_size(src, tmp_path / f"{stem}-pinned.ttf")
            dest = out_dir / f"{stem}.woff2"
            subset_face(pinned, dest, text_unicodes if kind == "text" else mono_unicodes)
            total += report(dest)

        for repo in LICENSES:
            url = RAW.format(repo=repo, path="LICENSE.md")
            urllib.request.urlretrieve(url, out_dir / f"LICENSE-{repo}.md")

    print(f"  {'total':<32} {total:6.1f} KB", file=sys.stderr)


if __name__ == "__main__":
    main()
