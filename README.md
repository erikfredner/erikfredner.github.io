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

To rebuild a single page:

```bash
pandoc --standalone --defaults=defaults/toc-defaults.yaml --template=templates/base.html \
  --section-divs \
  --lua-filter=filters/webp.lua \
  --metadata email="erik.fredner@oregonstate.edu" \
  --citeproc --bibliography=references.bib --csl=vendor/csl/chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
```

## Architecture

**Build pipeline:** `src/*.md` → Pandoc → `docs/*.html`

| File/Directory | Purpose |
|---|---|
| `src/*.md` | Source pages (Markdown + YAML frontmatter) |
| `templates/base.html` | Single HTML template for all pages (nav, skip-link, back-to-top) |
| `css/style.css` | The site's single stylesheet: minimalist centered column, EB Garamond, light + dark themes |
| `vendor/fonts/ebgaramond/` | Vendored [EB Garamond](https://github.com/octaviopardo/EBGaramond12) variable webfonts (OFL-1.1); copied to `docs/fonts/` by `make` |
| `vendor/csl/` | Vendored citation styles from [citation-style-language/styles](https://github.com/citation-style-language/styles) |
| `filters/webp.lua` | Pandoc Lua filter that rewrites image `src` attributes to `.webp` so HTML matches converted assets |
| `src/images/` | Source images (JPG, JPEG, PNG, WebP); JPG/JPEG/PNG are auto-converted to WebP on build |
| `references.bib` | Shared bibliography for all citations |
| `vendor/csl/chicago-notes.csl` | Citation style (Chicago notes); citations render as standard end-of-page footnotes |
| `CNAME` | Custom domain (`fredner.org`) — copied to `docs/` by `make` |
| `.nojekyll` | Disables Jekyll processing on GitHub Pages — copied to `docs/` by `make` |

**Source pages:** Each `src/*.md` file has a YAML frontmatter `title` field that becomes both the `<title>` and `<h1>`. Add `toc: true` to frontmatter for pages that need a table of contents.

**`docs/` is the deploy target:** GitHub Pages serves from `docs/`. Running `make clean && make` fully regenerates it. `CNAME` and `.nojekyll` are recreated by `make` so they survive `make clean`.
