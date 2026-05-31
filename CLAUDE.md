# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make          # Build all HTML pages into docs/
make serve    # Build, serve at http://localhost:8000, and live-reload on src/ changes (requires entr)
make clean    # Remove the entire docs/ directory
make prune-images  # Remove src/images/ files not referenced in any .md
```

External tools required: `pandoc`, `cwebp` (`brew install webp`), `uv` (for the blog script), and `entr` (only for `make serve`).

To rebuild a single non-blog page:
```bash
pandoc --standalone --defaults=defaults/toc-defaults.yaml --template=templates/base.html \
  --lua-filter=filters/webp.lua \
  --metadata build-date="$(date +%Y-%m-%d)" \
  --metadata email="erik.fredner@oregonstate.edu" \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
cp style.css docs/style.css
```

To rebuild a single blog post:
```bash
pandoc --standalone --template=templates/base.html \
  --lua-filter=filters/webp.lua \
  --metadata build-date="$(date +%Y-%m-%d)" \
  --metadata email="erik.fredner@oregonstate.edu" \
  --metadata pathprefix="../" \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  -o docs/blog/POST.html src/blog/POST.md
```

## Architecture

This is a static academic website built with **Pandoc** and deployed to GitHub Pages from the `docs/` directory (domain: fredner.org).

**Build pipeline:** `src/*.md` → pandoc → `docs/*.html`

- `templates/base.html` — single HTML template for all pages; includes GoatCounter analytics, navigation, and back-to-top button. Blog posts require `--metadata pathprefix="../"` so relative asset paths resolve correctly from `docs/blog/`.
- `style.css` — stylesheet using system fonts, light/dark mode, and all layout styles; copied to `docs/style.css` by the Makefile
- `references.bib` — Zotero/Better BibTeX bibliography; all citations across the site draw from this file
- `chicago-notes.csl` — citation style applied by pandoc's `--citeproc`
- `defaults/toc-defaults.yaml` — sets `toc-depth: 2`; always passed via `--defaults` by the Makefile for non-blog pages

**Source pages** (`src/`): Markdown with YAML frontmatter. The `title` field becomes the `<title>` and `<h1>`. Use `toc: true` in frontmatter for pages that need a table of contents (the Makefile detects this and passes `--toc` to pandoc).

**Blog pipeline:** `src/blog/*.md` → `scripts/build_blog.py` → `build/` intermediary → `docs/blog/*.html` + `docs/blog.html` index + `docs/feed.xml` Atom feed.

- `scripts/build_blog.py` — run via `uv run` (inline script metadata declares `pyyaml` dependency); reads frontmatter, filters out drafts, generates `build/blog-index.md` and `build/feed.xml`
- Blog posts with `draft: true` in frontmatter are excluded from the index and feed, and not built to HTML
- Required blog frontmatter: `title`, `date` (YYYY-MM-DD); optional: `description`, `draft`

**Assets:** `src/images/` → `docs/images/` (JPG/PNG converted to WebP via `cwebp`; `.webp` copied directly). In markdown, reference images by their original `.jpg`/`.png` filename — `filters/webp.lua` rewrites image `src` attributes to `.webp` during the pandoc run so the HTML matches the converted asset.

**Slides:** `slides/*.html` is copied verbatim to `docs/slides/` (no pandoc processing).

**No Jekyll:** `.nojekyll` disables GitHub Pages' Jekyll processing; the `docs/` folder is served as plain static files.
