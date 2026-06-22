# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make               # Build all pages into docs/
make serve         # Build, serve at http://localhost:8000, and live-reload on src/ changes (requires entr)
make clean         # Remove the entire docs/ directory
make prune-images  # Remove src/images/ files not referenced by any .md
```

External tools required: `pandoc`, `pandoc-sidenote` (`brew install jez/formulae/pandoc-sidenote`), `pandoc-crossref` (`brew install pandoc-crossref`), `cwebp` (`brew install webp`), `uv` (for the blog script), and `entr` (only for `make serve`).

To rebuild a single non-blog page:
```bash
pandoc --standalone --defaults=defaults/toc-defaults.yaml --template=templates/tufte-base.html \
  --section-divs \
  --lua-filter=filters/webp.lua \
  --metadata build-date="$(date +%Y-%m-%d)" \
  --metadata email="erik.fredner@oregonstate.edu" \
  --metadata site-url="https://fredner.org" \
  --metadata link-citations=false \
  --lua-filter=filters/og-image.lua \
  --lua-filter=filters/inject-lists.lua \
  --filter pandoc-crossref \
  --lua-filter=filters/wrap-lists.lua \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  --lua-filter=filters/figure-margin.lua \
  --filter pandoc-sidenote \
  -o docs/PAGE.html src/PAGE.md
```

To rebuild a single blog post (note the `pathprefix` so relative asset paths resolve from `docs/blog/`):
```bash
pandoc --standalone --template=templates/tufte-base.html \
  --section-divs \
  --lua-filter=filters/webp.lua \
  --metadata build-date="$(date +%Y-%m-%d)" \
  --metadata email="erik.fredner@oregonstate.edu" \
  --metadata site-url="https://fredner.org" \
  --metadata pathprefix="../" \
  --metadata link-citations=false \
  --lua-filter=filters/og-image.lua \
  --lua-filter=filters/inject-lists.lua \
  --filter pandoc-crossref \
  --lua-filter=filters/wrap-lists.lua \
  --citeproc --bibliography=references.bib --csl=chicago-notes.csl \
  --lua-filter=filters/figure-margin.lua \
  --filter pandoc-sidenote \
  -o docs/blog/POST.html src/blog/POST.md
```

The full `make` build sets `build-date` per page from `git log -1 --format=%cs -- <file>` (falling back to today's date if the file has no git history). The ad-hoc commands above just use today's date.

Because this date comes from git history but Make's rebuild check is mtime-based — and a commit does not change the source file's mtime — every HTML rule also depends on `.git/logs/HEAD` (the `GIT_HEAD` variable, the reflog, which every commit touches). Without this, a page committed *after* it was last built would keep stamping the previous commit's date in its footer forever, since Make would consider the page up-to-date. The dependency is wrapped in `$(wildcard ...)` so the build degrades gracefully if no reflog exists. A consequence is that the first `make` after any commit rebuilds all pages, but each is restamped with its own source's git date, so unchanged pages keep their original (older) footer date.

## Architecture

This is a static academic website built with **Pandoc + Tufte CSS** and deployed to GitHub Pages from the `docs/` directory (domain: fredner.org).

**Build pipeline:** `src/*.md` → pandoc (with `pandoc-sidenote` + Lua filter) → `docs/*.html`

- `templates/tufte-base.html` — single HTML template for all pages; adapts the upstream `tufte.html5` template to preserve site chrome (nav, skip-link, back-to-top, footer). Blog posts pass `--metadata pathprefix="../"` so relative asset paths resolve from `docs/blog/`. `templates/base.html` (which links the root `style.css`) and the Makefile's `POST_TEMPLATE := templates/post.html` variable are both vestigial — `base.html` is never invoked, `post.html` does not exist, and nothing references `style.css`. Only `tufte-base.html` is used.
- `vendor/tufte/` — vendored [tufte-css](https://edwardtufte.github.io/tufte-css/) (`tufte.css`, `et-book/` fonts) plus [jez/tufte-pandoc-css](https://github.com/jez/tufte-pandoc-css) (`pandoc.css`, `tufte-extra.css`), and site-specific overrides in `site-extra.css`. All four CSS files plus the `et-book/` font tree are copied to `docs/` by the Makefile.
- `--filter pandoc-sidenote` — converts pandoc footnotes (including Chicago-notes citations from `--citeproc`) into Tufte-style sidenotes. Citation/footnote rendering depends on this filter; do not remove it.
- `--section-divs` — wraps each heading section in `<section>` so Tufte CSS layout rules apply correctly.
- `references.bib` — Zotero/Better BibTeX bibliography; all citations across the site draw from this file.
- `chicago-notes.csl` — Chicago notes citation style applied by pandoc's `--citeproc`; this is the only CSL the build uses. `modern-language-association.csl` also lives in the repo root but is not wired into any build target.
- `--metadata link-citations=false` — chicago-notes is a notes-only style with no bibliography section, so the default citeproc behavior of wrapping each citation in `<a href="#ref-...">` produces dead links and also swallows DOIs / JSTOR URLs that would otherwise render as clickable external links. Setting `link-citations` to `false` suppresses the wrapper entirely, leaving bare URLs in the citation content to be rendered as ordinary external links.
- `filters/figure-margin.lua` — runs after citeproc, before `pandoc-sidenote`. Rewrites every pandoc Figure block as a Tufte-style margin figure by default: the image stays in the main column and the caption is moved into a `<span class="marginnote">` so it floats into the right sidenote column. To opt a figure out of margin treatment and render it as a normal full-width figure instead, tag the image with `.fullwidth` (markdown: `![caption](src){#fig:foo .fullwidth}`); the filter then leaves the Figure alone and pandoc's default `<figure>` output is picked up by the existing `figure.fullwidth` rules in `vendor/tufte/tufte.css`. Must run after `pandoc-crossref` so the caption already carries its `Figure N:` prefix, and after citeproc so caption citations are resolved.
- `filters/og-image.lua` — runs right after `filters/webp.lua` so it sees the `.webp`-rewritten src. Captures the first `Image` element on the page, resolves it against the `site-url` metadata (set in the Makefile to `https://fredner.org`), and exposes the absolute URL as `og-image` metadata. The template renders `<meta property="og:image">` (plus `twitter:card` / `twitter:image`) when that value is set, so iMessage / Slack / Twitter link previews show the page's first image. Pages with no images emit no `og:image` tag.
- `defaults/toc-defaults.yaml` — sets `toc-depth: 2`; always passed via `--defaults` by the Makefile for non-blog pages.

**Source pages** (`src/`): Markdown with YAML frontmatter. The `title` field becomes both the `<title>` and `<h1>`. Add `toc: true` to frontmatter for pages that need a table of contents (the Makefile greps for this line and passes `--toc` to pandoc). Add `lof: true` / `lot: true` to generate a list of figures / list of tables (driven by `filters/inject-lists.lua`, which prepends a `\listoffigures` / `\listoftables` raw block; pandoc-crossref then renders the list, and `filters/wrap-lists.lua` wraps it in a `<div class="list-of-figures-box">` styled to match the TOC).

**Blog pipeline:** `src/blog/*.md` → `scripts/build_blog.py` → `build/` intermediary → `docs/blog/*.html` + `docs/blog.html` index + `docs/feed.xml` Atom feed.

- `scripts/build_blog.py` — run via `uv run` (inline script metadata declares the `pyyaml` dependency); reads frontmatter, filters out drafts, generates `build/blog-index.md` and `build/feed.xml`.
- The Makefile also filters drafts at the Make level (via a `grep '^draft: true'` shell loop) so `make` never builds an HTML page for a draft post.
- Required blog frontmatter: `title`, `date` (YYYY-MM-DD). Optional: `description`, `draft`.

**Assets:** `src/images/` → `docs/images/`. JPG/JPEG/PNG are converted to WebP via `cwebp`; existing `.webp` and `.svg` files are copied through unchanged. In markdown, reference images by their original `.jpg`/`.jpeg`/`.png` filename — `filters/webp.lua` rewrites image `src` attributes to `.webp` during the pandoc run so the HTML matches the converted asset.

**Slides:** `slides/*.html` is copied verbatim to `docs/slides/` (no pandoc processing).

**GitHub Pages config:** `CNAME` (custom domain) and `.nojekyll` (disables Jekyll) are recreated in `docs/` by `make`, so they survive `make clean`.
