# fredner.org

Source for [fredner.org](https://fredner.org) — a static academic website built with Pandoc and hosted on GitHub Pages.

## Dependencies

- [`make`](https://www.gnu.org/software/make/)
- [Pandoc](https://pandoc.org)
- [`pandoc-crossref`](https://github.com/lierdakil/pandoc-crossref) — `brew install pandoc-crossref` (figure/table numbering and cross-references)
- [`cwebp`](https://developers.google.com/speed/webp/docs/cwebp) — `brew install webp` (for image conversion)
- [`uv`](https://docs.astral.sh/uv/) (for the blog and font build scripts)
- [`entr`](https://eradman.com/entrproject/) — `brew install entr` (only required by `make serve` for live reload)
- [Zotero](https://www.zotero.org) + [Better BibTeX](https://retorque.re/zotero-better-bibtex/) (for `references.bib`)

## Commands

```bash
make              # Build all pages into docs/
make serve        # Build, serve at http://localhost:8000, rebuild on changes to src/, css/, templates/, filters/
make clean        # Remove the entire docs/ directory
make blog         # Just the blog: posts, index, feed, timestamps
make tags         # Just the tag pages
make sitemap      # Just docs/sitemap.xml
make prune-images # Delete images in src/images/ not referenced by any post or page
make update-csl   # Re-pull the vendored CSL from upstream (review with git diff)
make fonts        # Re-download and re-subset the Source webfonts (review with git diff)
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
  --metadata nav-PAGE=true \
  --lua-filter=filters/og-image.lua \
  --lua-filter=filters/inject-lists.lua \
  --filter pandoc-crossref \
  --lua-filter=filters/wrap-lists.lua \
  --lua-filter=filters/wrap-tables.lua \
  --citeproc --bibliography=references.bib --csl=vendor/csl/chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
```

Blog posts use the same command minus the `--defaults` flag, with `--metadata nav-blog=true` and `--metadata pathprefix="../"` so relative asset paths resolve from `docs/blog/`.

Filter order matters: `webp.lua` runs before `og-image.lua` (so the OG tag points at the converted asset), and the two wrappers run after `pandoc-crossref` (so it still sees real list and `Table` elements).

## Architecture

**Build pipeline:** `src/*.md` → Pandoc (with Lua filters) → `docs/*.html`

| File/Directory | Purpose |
|---|---|
| `src/*.md` | Source pages (Markdown + YAML frontmatter) |
| `src/blog/*.md` | Blog posts (built by the blog pipeline below) |
| `templates/base.html` | Single HTML template for all pages (nav, skip-link, back-to-top, GoatCounter analytics) |
| `favicon.svg` | Asterisk mark, set in the site's own Source Serif as a baked path; copied to the site root by `make` |
| `css/style.css` | The site's single stylesheet: minimalist centered column, the Source type system, light + dark themes — copied to `docs/style.css` by `make` |
| `fonts/*.woff2` | Self-hosted subset webfonts (Source Serif 4, Source Sans 3, Source Code Pro), built by `make fonts` and copied to `docs/fonts/` |
| `scripts/build_fonts.py` | Downloads the Adobe variable fonts and subsets them (run via `uv run`, invoked by `make fonts`) |
| `defaults/toc-defaults.yaml` | Pandoc defaults for non-blog pages (`toc-depth: 2`) |
| `filters/webp.lua` | Rewrites image `src` attributes to `.webp` so HTML matches converted assets |
| `filters/og-image.lua` | Captures each page's first image as an absolute `og:image` URL for link previews |
| `filters/inject-lists.lua` | Prepends list-of-figures/tables blocks for pages with `lof: true` / `lot: true` |
| `filters/wrap-lists.lua` | Wraps those lists in collapsible boxes styled to match the TOC |
| `filters/wrap-tables.lua` | Wraps tables in a horizontal scroll box so a wide table can't push the page sideways on a phone |
| `filters/absolutize.lua` | Makes links and images absolute in the Atom feed's full-content fragments |
| `src/images/` | Source images; JPG/JPEG/PNG are auto-converted to WebP on build, `.webp`/`.svg` copied through |
| `slides/*.html` | Slide decks, copied verbatim to `docs/slides/` |
| `references.bib` | Shared bibliography for all citations (exported from Zotero via Better BibTeX) |
| `vendor/csl/chicago-notes.csl` | Citation style (Chicago notes); citations render as end-of-page footnotes |
| `scripts/build_blog.py` | Blog index, tag pages, per-post metadata, and Atom feed generator (run via `uv run`) |
| `src/blog/timestamps.json` | Generated + committed manifest of post publication/modification datetimes |
| `scripts/build_sitemap.py` | Writes `docs/sitemap.xml` from the built HTML (run via `uv run`) |
| `src/404.md` | Not-found page; built with root-absolute asset paths so it works at any depth |
| `robots.txt` | Points crawlers at the sitemap — copied to `docs/` by `make` |
| `CNAME` | Custom domain (`fredner.org`) — recreated in `docs/` by `make` |
| `.nojekyll` | Disables Jekyll processing on GitHub Pages — recreated in `docs/` by `make` |

**Source pages:** Each `src/*.md` file has a YAML frontmatter `title` field that becomes both the `<title>` and `<h1>`. Optional frontmatter: `subtitle` (a muted line under the `<h1>`; deliberately kept out of `<title>` and `og:title`), `description` (the meta description and `og:description`), `toc: true` for a table of contents, and `lof: true` / `lot: true` for lists of figures/tables. Blog posts also get a `<time>` byline, driven by the timestamp manifest described below rather than by frontmatter.

**Navigation:** `make` passes `--metadata nav-<stem>=true` for each page, and the template turns `nav-index` / `nav-blog` / `nav-cv` / `nav-research` into `aria-current="page"` on the matching link. Adding a nav item means adding both the link and its `$if(nav-…)$` guard. On narrow screens the nav collapses behind a toggle button, but only once the inline script has bound it — the links are visible by default so a failed script can't hide them.

**Citations:** all citations draw from `references.bib` and render as end-of-document footnotes via `--citeproc` and the Chicago notes style. The build passes `--metadata link-citations=false`: notes-only styles have no bibliography to link to, so citeproc's default anchors would be dead links and would swallow the DOIs and JSTOR URLs that should render as ordinary external links.

**Fonts:** the site sets [Source Serif 4](https://github.com/adobe-fonts/source-serif) for prose, [Source Sans 3](https://github.com/adobe-fonts/source-sans) for headings and chrome, and [Source Code Pro](https://github.com/adobe-fonts/source-code-pro) for code — all SIL OFL 1.1, all self-hosted rather than loaded from a font CDN. Browsers have partitioned the HTTP cache by site since 2020, so a third-party font host buys no cache sharing while costing two extra origin connections on the critical path; serving the fonts from `fonts/` puts them on the already-warm connection and lets them be preloaded.

`make fonts` downloads the upstream variable fonts and subsets them to the codepoints the site actually uses (~141 KB for all four faces, down from ~1 MB unsubsetted). It is not part of `make` — run it deliberately and review the diff. See `scripts/build_fonts.py` for the ranges, and note that the site's bibliography needs Latin Extended-A, which the usual "latin" webfont subset omits.

**Blog:** `src/blog/*.md` → `scripts/build_blog.py` → `build/` intermediary → `docs/blog/*.html`, plus the `docs/blog.html` index, the `docs/tags/` pages, and the `docs/feed.xml` Atom feed. `title` is the only required frontmatter; `description`, `draft`, `tags`, and `date` are optional. Posts marked `draft: true` are excluded from the index, the feed, and the build. The index layout is emitted as raw HTML by `build_blog.py` rather than by a template, so changing it means editing that script.

**Post dates are automatic.** `src/blog/timestamps.json` is generated and committed: a post is stamped `published` the first time it builds without `draft: true`, and `updated` whenever its source file's hash changes, so neither has to be typed. A frontmatter `date:` overrides `published` — the escape hatch for a post whose date is an editorial fact rather than a build artifact, like an announcement dated to the event it announces. (Deriving dates from `git log` instead was tried and abandoned: posts get committed days after they are written, event-dated posts are committed before their date, and two posts added in one commit collapse to one timestamp.)

**Tags:** `tags: [foo, "Bar Baz"]` generates a page per tag under `docs/tags/` plus a `docs/tags.html` index, all static — no JavaScript, no client-side filtering.

**Feed:** the Atom feed carries full post content with absolute links, distinct `<published>` and `<updated>` timestamps, and `<category>` elements for tags.

**Discovery:** `docs/sitemap.xml` is generated from the built HTML on every run, `robots.txt` points at it, and `docs/404.html` is served by GitHub Pages for unmatched paths (it uses root-absolute asset paths, since it can be served from any depth). Every page carries a canonical URL; blog posts declare `og:type=article`.

**`docs/` is the deploy target, and it is committed to git.** GitHub Pages serves the checked-in build output, so any change to `src/`, `css/`, `templates/`, or `filters/` has to be followed by `make` and the regenerated `docs/` files committed alongside it, or the live site won't reflect it. Running `make clean && make` fully regenerates the directory; `CNAME` and `.nojekyll` are recreated by `make` so they survive `make clean`. `build/` is gitignored.
