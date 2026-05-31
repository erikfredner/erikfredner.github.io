# fredner.org

Source for [fredner.org](https://fredner.org) — a static academic website built with Pandoc and hosted on GitHub Pages.

## Dependencies

- [`make`](https://www.gnu.org/software/make/)
- [Pandoc](https://pandoc.org)
- [`pandoc-sidenote`](https://github.com/jez/pandoc-sidenote) — `brew install jez/formulae/pandoc-sidenote` (renders footnotes and Chicago-notes citations as Tufte sidenotes)
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
```

To rebuild a single page:

```bash
pandoc --standalone --defaults=defaults/toc-defaults.yaml --template=templates/tufte-base.html \
  --section-divs \
  --lua-filter=filters/webp.lua \
  --metadata build-date="$(date +%Y-%m-%d)" \
  --metadata email="erik.fredner@oregonstate.edu" \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  --filter pandoc-sidenote \
  -o docs/PAGE.html src/PAGE.md
```

## Architecture

**Build pipeline:** `src/*.md` → Pandoc → `docs/*.html`

| File/Directory | Purpose |
|---|---|
| `src/*.md` | Source pages (Markdown + YAML frontmatter) |
| `templates/tufte-base.html` | Single HTML template for all pages; adapts the upstream `tufte.html5` template to preserve site chrome (nav, skip-link, back-to-top, footer) |
| `vendor/tufte/` | Vendored [tufte-css](https://edwardtufte.github.io/tufte-css/) (`tufte.css`, `et-book/` fonts) and [jez/tufte-pandoc-css](https://github.com/jez/tufte-pandoc-css) (`pandoc.css`, `tufte-extra.css`); copied to `docs/` by `make` |
| `vendor/tufte/site-extra.css` | Site-specific overrides for chrome and width rules that Tufte's CSS doesn't cover |
| `filters/webp.lua` | Pandoc Lua filter that rewrites image `src` attributes to `.webp` so HTML matches converted assets |
| `src/images/` | Source images (JPG, JPEG, PNG, WebP); JPG/JPEG/PNG are auto-converted to WebP on build |
| `references.bib` | Shared bibliography for all citations |
| `chicago-notes.csl` | Citation style (Chicago notes); rendered as Tufte sidenotes via `pandoc-sidenote` |
| `CNAME` | Custom domain (`fredner.org`) — copied to `docs/` by `make` |
| `.nojekyll` | Disables Jekyll processing on GitHub Pages — copied to `docs/` by `make` |

**Source pages:** Each `src/*.md` file has a YAML frontmatter `title` field that becomes both the `<title>` and `<h1>`. Add `toc: true` and `toc-depth: 2` to frontmatter for pages that need a table of contents.

**`docs/` is the deploy target:** GitHub Pages serves from `docs/`. Running `make clean && make` fully regenerates it. `CNAME` and `.nojekyll` are recreated by `make` so they survive `make clean`.
