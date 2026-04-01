# fredner.org

Source for [fredner.org](https://fredner.org) — a static academic website built with Pandoc and hosted on GitHub Pages.

## Dependencies

- [`make`](https://www.gnu.org/software/make/)
- [Pandoc](https://pandoc.org)
- [Zotero](https://www.zotero.org) + [Better BibTeX](https://retorque.re/zotero-better-bibtex/) (for `references.bib`)

## Commands

```bash
make              # Build all pages into docs/
make serve        # Build and serve locally at http://localhost:8000
make clean        # Remove the entire docs/ directory
make prune-images # Delete images in src/images/ not referenced by any src/*.md
```

To rebuild a single page:

```bash
pandoc --standalone --template=templates/base.html \
  --metadata date="$(date +%Y)" \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
cp style.css docs/style.css
cp -r fonts docs/fonts
rm -f docs/fonts/*.ttf docs/fonts/*.py
```

## Architecture

**Build pipeline:** `src/*.md` → Pandoc → `docs/*.html`

| File/Directory | Purpose |
|---|---|
| `src/*.md` | Source pages (Markdown + YAML frontmatter) |
| `templates/base.html` | Single HTML template for all pages |
| `style.css` | Stylesheet with EB Garamond variable fonts and light/dark mode |
| `fonts/` | EB Garamond source TTFs + optimized WOFF2 files; only `.woff2` is copied to `docs/fonts/` |
| `references.bib` | Shared bibliography for all citations |
| `chicago-notes.csl` | Citation style (Chicago notes) |
| `CNAME` | Custom domain (`fredner.org`) — copied to `docs/` by `make` |
| `.nojekyll` | Disables Jekyll processing on GitHub Pages — copied to `docs/` by `make` |

**Source pages:** Each `src/*.md` file has a YAML frontmatter `title` field that becomes both the `<title>` and `<h1>`. Add `toc: true` and `toc-depth: 2` to frontmatter for pages that need a table of contents.

**`docs/` is the deploy target:** GitHub Pages serves from `docs/`. Running `make clean && make` fully regenerates it. `CNAME` and `.nojekyll` are recreated by `make` so they survive `make clean`.
