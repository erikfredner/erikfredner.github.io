# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make               # Build all pages into docs/
make serve         # Build, serve at http://localhost:8000, and live-reload on src/ changes (requires entr)
make clean         # Remove the entire docs/ directory
make prune-images  # Remove src/images/ files not referenced by any .md
make update-csl    # Re-pull the vendored chicago-notes.csl from upstream (review with git diff)
```

`make update-csl` refreshes `vendor/csl/chicago-notes.csl` from [citation-style-language/styles](https://github.com/citation-style-language/styles). `vendor/csl/modern-language-association.csl` also lives there but is not wired into any build target and is never overwritten.

This refresh also runs **automatically** as part of `make`, but at most once every 30 days: the `csl-autoupdate` prerequisite of `all` checks a gitignored stamp file (`vendor/csl/.csl-updated`) via `find -mtime -30` and only re-pulls when the stamp is missing or older than 30 days, touching it on success. The auto-update is non-fatal — if the fetch fails (e.g. offline) the build continues with the existing vendored copy. So a routine `make` will occasionally pull a newer CSL; check `git diff vendor/csl` after a build that prints the refresh message.

External tools required: `pandoc`, `pandoc-crossref` (`brew install pandoc-crossref`), `cwebp` (`brew install webp`), `uv` (for the blog script), and `entr` (only for `make serve`).

To rebuild a single non-blog page:
```bash
pandoc --standalone --defaults=defaults/toc-defaults.yaml --template=templates/base.html \
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
  --citeproc --bibliography=references.bib --csl=vendor/csl/chicago-notes.csl \
  -o docs/PAGE.html src/PAGE.md
```

To rebuild a single blog post (note the `pathprefix` so relative asset paths resolve from `docs/blog/`):
```bash
pandoc --standalone --template=templates/base.html \
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
  --citeproc --bibliography=references.bib --csl=vendor/csl/chicago-notes.csl \
  -o docs/blog/POST.html src/blog/POST.md
```

The full `make` build sets `build-date` per page from `git log -1 --format=%cs -- <file>` (falling back to today's date if the file has no git history). The ad-hoc commands above just use today's date.

Because this date comes from git history but Make's rebuild check is mtime-based — and a commit does not change the source file's mtime — every HTML rule also depends on `.git/logs/HEAD` (the `GIT_HEAD` variable, the reflog, which every commit touches). Without this, a page committed *after* it was last built would keep stamping the previous commit's date in its footer forever, since Make would consider the page up-to-date. The dependency is wrapped in `$(wildcard ...)` so the build degrades gracefully if no reflog exists. A consequence is that the first `make` after any commit rebuilds all pages, but each is restamped with its own source's git date, so unchanged pages keep their original (older) footer date.

## Architecture

This is a static academic website built with **Pandoc** and a single local stylesheet, deployed to GitHub Pages from the `docs/` directory (domain: fredner.org).

**Build pipeline:** `src/*.md` → pandoc (with Lua filters) → `docs/*.html`

- `templates/base.html` — single HTML template for all pages (nav, skip-link, back-to-top, footer, GoatCounter analytics). Blog posts pass `--metadata pathprefix="../"` so relative asset paths resolve from `docs/blog/`. The template preloads the roman EB Garamond variable font and links `style.css`.
- `css/style.css` — the site's only stylesheet: minimalist black-on-white design with a `prefers-color-scheme: dark` variant (colors are CSS custom properties on `:root`), a centered ~65ch column of left-aligned text, and EB Garamond type. It styles all site chrome (`.skip-link`, nav, `.toc-box`, `.back-to-top`, `.post-card`, footer) and content elements (figures/figcaptions, tables, blockquotes, code, and pandoc's end-of-document footnotes section). Copied to `docs/style.css` by the Makefile. All font sizes are relative (rem/em); keep it that way for accessibility.
- `vendor/fonts/ebgaramond/` — vendored [EB Garamond](https://github.com/octaviopardo/EBGaramond12) variable webfonts (OFL-1.1: `EBGaramond-VF.woff2` roman + `EBGaramond-Italic-VF.woff2`, weight axis 400–800) plus `OFL.txt`. Copied to `docs/fonts/` by the Makefile (the license must ship with the fonts). Loaded via two `@font-face` rules in `style.css` with `font-display: swap`. These files were renamed from upstream's bracketed names (`EBGaramond[wght].woff2`) for URL safety and are not expected to change; there is no auto-update for fonts.
- `vendor/csl/` — vendored citation styles from [citation-style-language/styles](https://github.com/citation-style-language/styles). `chicago-notes.csl` (Chicago 18th ed., notes without bibliography) is the only CSL the build uses; refreshed by `make update-csl` / the 30-day `csl-autoupdate` stamp.
- **Footnotes and citations** render as pandoc's standard end-of-document footnotes section (`<section id="footnotes" role="doc-endnotes">`), styled by `style.css` with `:target` highlighting for the in-page note links. Chicago-notes citations become footnotes via `--citeproc`.
- `--section-divs` — wraps each heading section in `<section>`; kept for semantic structure and anchor targets.
- `references.bib` — Zotero/Better BibTeX bibliography; all citations across the site draw from this file.
- `--metadata link-citations=false` — chicago-notes is a notes-only style with no bibliography section, so the default citeproc behavior of wrapping each citation in `<a href="#ref-...">` produces dead links and also swallows DOIs / JSTOR URLs that would otherwise render as clickable external links. Setting `link-citations` to `false` suppresses the wrapper entirely, leaving bare URLs in the citation content to be rendered as ordinary external links.
- **Figures** are pandoc's default `<figure><img><figcaption>` output, numbered by `pandoc-crossref` (`![caption](src){#fig:foo}`). Captions render below the image, styled by `style.css`.
- `filters/og-image.lua` — runs right after `filters/webp.lua` so it sees the `.webp`-rewritten src. Captures the first `Image` element on the page, resolves it against the `site-url` metadata (set in the Makefile to `https://fredner.org`), and exposes the absolute URL as `og-image` metadata. The template renders `<meta property="og:image">` (plus `twitter:card` / `twitter:image`) when that value is set, so iMessage / Slack / Twitter link previews show the page's first image. Pages with no images emit no `og:image` tag.
- `defaults/toc-defaults.yaml` — sets `toc-depth: 2`; always passed via `--defaults` by the Makefile for non-blog pages.
- **Syntax highlighting:** no page currently contains fenced code blocks, so pandoc emits no `highlighting-css`. If highlighted code is ever added, pass `--highlight-style=monochrome` (weight/italic-based) rather than writing per-token color overrides — pandoc's default token colors are not tuned for the dark theme.

**Source pages** (`src/`): Markdown with YAML frontmatter. The `title` field becomes both the `<title>` and `<h1>`. Add `toc: true` to frontmatter for pages that need a table of contents (the Makefile greps for this line and passes `--toc` to pandoc). Add `lof: true` / `lot: true` to generate a list of figures / list of tables (driven by `filters/inject-lists.lua`, which prepends a `\listoffigures` / `\listoftables` raw block; pandoc-crossref then renders the list, and `filters/wrap-lists.lua` wraps it in a `<details class="toc-box list-of-figures-box">` styled to match the TOC).

**Blog pipeline:** `src/blog/*.md` → `scripts/build_blog.py` → `build/` intermediary → `docs/blog/*.html` + `docs/blog.html` index + `docs/feed.xml` Atom feed.

- `scripts/build_blog.py` — run via `uv run` (inline script metadata declares the `pyyaml` dependency); reads frontmatter, filters out drafts, generates `build/blog-index.md` and `build/feed.xml`.
- The Makefile also filters drafts at the Make level (via a `grep '^draft: true'` shell loop) so `make` never builds an HTML page for a draft post.
- Required blog frontmatter: `title`, `date` (YYYY-MM-DD). Optional: `description`, `draft`.

**Assets:** `src/images/` → `docs/images/`. JPG/JPEG/PNG are converted to WebP via `cwebp`; existing `.webp` and `.svg` files are copied through unchanged. In markdown, reference images by their original `.jpg`/`.jpeg`/`.png` filename — `filters/webp.lua` rewrites image `src` attributes to `.webp` during the pandoc run so the HTML matches the converted asset.

**Slides:** `slides/*.html` is copied verbatim to `docs/slides/` (no pandoc processing).

**GitHub Pages config:** `CNAME` (custom domain) and `.nojekyll` (disables Jekyll) are recreated in `docs/` by `make`, so they survive `make clean`.
