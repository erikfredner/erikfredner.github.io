# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make          # Build all HTML pages into docs/
make serve    # Build and serve locally at http://localhost:8000
make clean    # Remove the entire docs/ directory
```

To rebuild a single page (also copies CSS and fonts if not present):
```bash
pandoc --standalone --template=templates/base.html \
  --metadata date="$(date +%Y)" \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
cp style.css docs/style.css
cp -r fonts docs/fonts
```

Pages that need a TOC use `toc: true` and `toc-depth: 2` directly in YAML frontmatter — no `--defaults` flag needed.

## Architecture

This is a static academic website built with **Pandoc** and deployed to GitHub Pages from the `docs/` directory (domain: fredner.org).

**Build pipeline:** `src/*.md` → pandoc → `docs/*.html`

- `templates/base.html` — single HTML template for all pages; includes GoatCounter analytics, navigation, and back-to-top button
- `style.css` — self-contained stylesheet with EB Garamond variable fonts, light/dark mode, and all layout styles; copied to `docs/style.css` by the Makefile
- `fonts/` — EB Garamond variable font files (regular + italic); copied to `docs/fonts/` by the Makefile
- `references.bib` — Zotero/Better BibTeX bibliography; all citations across the site draw from this file
- `chicago-notes.csl` — citation style applied by pandoc's `--citeproc`
- `defaults/` — pandoc defaults YAML files; currently unused (TOC is controlled via frontmatter)

**Source pages** (`src/`): Markdown with YAML frontmatter. The `title` field becomes the `<title>` and `<h1>`. Use `toc: true` and `toc-depth: 2` for pages that need a table of contents.

**Assets:** `src/images/` → `docs/images/`, `slides/*.html` → `docs/slides/`, `style.css` → `docs/style.css`, and `fonts/` → `docs/fonts/` are all copied by the Makefile.

**No Jekyll:** `.nojekyll` disables GitHub Pages' Jekyll processing; the `docs/` folder is served as plain static files.
