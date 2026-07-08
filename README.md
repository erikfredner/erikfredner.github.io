# fredner.org

Source for [fredner.org](https://fredner.org) — a static academic website built with Pandoc and hosted on GitHub Pages.

## Dependencies

- [`make`](https://www.gnu.org/software/make/)
- [Pandoc](https://pandoc.org)
- [`pandoc-crossref`](https://github.com/lierdakil/pandoc-crossref) — `brew install pandoc-crossref` (figure/table numbering and cross-references)
- [`cwebp`](https://developers.google.com/speed/webp/docs/cwebp) — `brew install webp` (for image conversion)
- [`uv`](https://docs.astral.sh/uv/) (for the blog build script)
- [`entr`](https://eradman.com/entrproject/) — `brew install entr` (only required by `make serve` for live reload)
- [Zotero](https://www.zotero.org) + [Better BibTeX](https://retorque.re/zotero-better-bibtex/) (for `references.bib`)

## Commands

```bash
make              # Build all pages into docs/
make serve        # Build, serve at http://localhost:8000, and live-reload on src/ changes
make clean        # Remove the entire docs/ directory
make prune-images # Delete images in src/images/ not referenced by any src/*.md
make update-csl   # Re-pull the vendored CSL from upstream (review with git diff)
```

`make` also refreshes the vendored CSL from upstream automatically, at most once every 30 days (tracked by a gitignored stamp file, `vendor/csl/.csl-updated`). The refresh is non-fatal if offline. After a build that prints the refresh message, review with `git diff vendor/csl`.

To rebuild a single page:

```bash
pandoc --standalone --defaults=defaults/toc-defaults.yaml --template=templates/base.html \
  --section-divs \
  --lua-filter=filters/webp.lua \
  --metadata email="erik.fredner@oregonstate.edu" \
  --metadata site-url="https://fredner.org" \
  --metadata link-citations=false \
  --lua-filter=filters/og-image.lua \
  --lua-filter=filters/inject-lists.lua \
  --filter pandoc-crossref \
  --lua-filter=filters/wrap-lists.lua \
  --citeproc --bibliography=references.bib --csl=vendor/csl/chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
```

Blog posts use the same command minus the `--defaults` flag, plus `--metadata pathprefix="../"` so relative asset paths resolve from `docs/blog/`.

## Architecture

**Build pipeline:** `src/*.md` → Pandoc (with Lua filters) → `docs/*.html`

| File/Directory | Purpose |
|---|---|
| `src/*.md` | Source pages (Markdown + YAML frontmatter) |
| `src/blog/*.md` | Blog posts (built by the blog pipeline below) |
| `templates/base.html` | Single HTML template for all pages (nav, skip-link, back-to-top, GoatCounter analytics) |
| `css/style.css` | The site's single stylesheet: minimalist centered column, system serif type, light + dark themes — copied to `docs/style.css` by `make` |
| `defaults/toc-defaults.yaml` | Pandoc defaults for non-blog pages (`toc-depth: 2`) |
| `filters/webp.lua` | Rewrites image `src` attributes to `.webp` so HTML matches converted assets |
| `filters/og-image.lua` | Captures each page's first image as an absolute `og:image` URL for link previews |
| `filters/inject-lists.lua` | Prepends list-of-figures/tables blocks for pages with `lof: true` / `lot: true` |
| `filters/wrap-lists.lua` | Wraps those lists in collapsible boxes styled to match the TOC |
| `src/images/` | Source images; JPG/JPEG/PNG are auto-converted to WebP on build, `.webp`/`.svg` copied through |
| `slides/*.html` | Slide decks, copied verbatim to `docs/slides/` |
| `references.bib` | Shared bibliography for all citations (exported from Zotero via Better BibTeX) |
| `vendor/csl/chicago-notes.csl` | Citation style (Chicago notes); citations render as end-of-page footnotes |
| `scripts/build_blog.py` | Blog index + Atom feed generator (run via `uv run`) |
| `CNAME` | Custom domain (`fredner.org`) — recreated in `docs/` by `make` |
| `.nojekyll` | Disables Jekyll processing on GitHub Pages — recreated in `docs/` by `make` |

**Source pages:** Each `src/*.md` file has a YAML frontmatter `title` field that becomes both the `<title>` and `<h1>`. Optional frontmatter: `toc: true` for a table of contents, `lof: true` / `lot: true` for lists of figures/tables, `description` for the meta description.

**Blog:** `src/blog/*.md` → `scripts/build_blog.py` → `build/` intermediary → `docs/blog/*.html`, plus the `docs/blog.html` index and `docs/feed.xml` Atom feed. Posts require `title` and `date` (YYYY-MM-DD) frontmatter; optional `description` and `draft`. Posts marked `draft: true` are excluded from the index, the feed, and the build.

**`docs/` is the deploy target:** GitHub Pages serves from `docs/`. Running `make clean && make` fully regenerates it. `CNAME` and `.nojekyll` are recreated by `make` so they survive `make clean`.
