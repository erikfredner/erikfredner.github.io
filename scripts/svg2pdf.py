# /// script
# requires-python = ">=3.11"
# dependencies = ["cairosvg"]
# ///
"""Convert one SVG figure to PDF for the article PDFs (pdfLaTeX cannot read SVG).

    svg2pdf.py IN.svg OUT.pdf

cairosvg needs the cairo C library (`brew install cairo`). On macOS, Homebrew's
lib directory is not on the default dlopen path, so the Makefile sets
DYLD_FALLBACK_LIBRARY_PATH for this script. Output is deterministic for a
given input, and pdfTeX copies only the page, not the file's own dates, into
the article PDF.
"""

import sys

import cairosvg

cairosvg.svg2pdf(url=sys.argv[1], write_to=sys.argv[2])
