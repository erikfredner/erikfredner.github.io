# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make               # Build all pages into docs/
make serve         # Build, serve at http://localhost:8000, rebuild on changes to src/, css/, templates/, filters/ (requires entr)
make clean         # Remove the entire docs/ directory
make prune-images  # Remove src/images/ files not referenced by any .md
make update-csl    # Re-pull the vendored chicago-notes.csl from upstream (review with git diff)
make fonts         # Re-download and re-subset the Source webfonts into fonts/ (review with git diff)
```

`make update-csl` refreshes `vendor/csl/chicago-notes.csl` from [citation-style-language/styles](https://github.com/citation-style-language/styles). `vendor/csl/modern-language-association.csl` also lives there but is not wired into any build target and is never overwritten.

This refresh also runs **automatically** as part of `make`, but at most once every 30 days: the `csl-autoupdate` prerequisite of `all` checks a gitignored stamp file (`vendor/csl/.csl-updated`) via `find -mtime -30` and only re-pulls when the stamp is missing or older than 30 days, touching it on success. The auto-update is non-fatal — if the fetch fails (e.g. offline) the build continues with the existing vendored copy. So a routine `make` will occasionally pull a newer CSL; check `git diff vendor/csl` after a build that prints the refresh message.

External tools required: `pandoc`, `pandoc-crossref` (`brew install pandoc-crossref`), `cwebp` (`brew install webp`), `uv` (for the blog and font scripts), and `entr` (only for `make serve`).

## Verifying changes

There is no test suite, no linter, and no CI (`.github/` does not exist — GitHub Pages serves the committed `docs/` directly from `main`). **`make` is the only check**, so run it after any edit and read the output; then inspect the regenerated `docs/` HTML for what you actually changed.

- **A full rebuild takes ~7 seconds.** When in doubt, `touch src/*.md src/blog/*.md templates/base.html css/style.css && make` (or `make clean && make`) — it is cheap enough that there is never a reason to reason about stale targets.
- **The build is byte-reproducible except for `docs/feed.xml`.** Its top-level `<updated>` element is stamped with the wall-clock build time (`scripts/build_blog.py:81`), so *every* build dirties that one file even when nothing else changed. A lone `M docs/feed.xml` in `git status` after a rebuild is expected — commit it or `git checkout` it, but do not go looking for a nondeterminism bug. Correspondingly, a clean `git status` after `make` means the committed `docs/` genuinely matches the sources.
- **`make serve` watches only `src/`, `css/`, `templates/`, and `filters/`.** Edits to `scripts/*.py`, `references.bib`, `defaults/`, or `favicon.svg` will not trigger a rebuild; touch a watched file or re-run `make` by hand.
- **Hand-running pandoc on a single page skips things `make` does for you.** The recipes below omit `--toc`, which the Makefile adds by grepping the source for `^toc: true` — 13 of the pages in `src/` set it (all the syllabi, `cv.md`, `reading-lms.md`, `the-ends-of-reading.md`, `ur-reading.md`), and rebuilding one of those by hand without `--toc` silently drops its table of contents. Likewise, rebuilding a single blog post does **not** regenerate `docs/blog.html` or `docs/feed.xml`; run `make blog` for those. Prefer plain `make`.

To rebuild a single non-blog page (add `--toc` if the source has `toc: true`):
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

To rebuild a single blog post (note the `pathprefix` so relative asset paths resolve from `docs/blog/`):
```bash
pandoc --standalone --template=templates/base.html \
  --section-divs \
  --lua-filter=filters/webp.lua \
  --metadata email="erik.fredner@oregonstate.edu" \
  --metadata site-url="https://fredner.org" \
  --metadata pathprefix="../" \
  --metadata link-citations=false \
  --metadata nav-blog=true \
  --lua-filter=filters/og-image.lua \
  --lua-filter=filters/inject-lists.lua \
  --filter pandoc-crossref \
  --lua-filter=filters/wrap-lists.lua \
  --lua-filter=filters/wrap-tables.lua \
  --citeproc --bibliography=references.bib --csl=vendor/csl/chicago-notes.csl \
  -o docs/blog/POST.html src/blog/POST.md
```

## Architecture

This is a static academic website built with **Pandoc** and a single local stylesheet, deployed to GitHub Pages from the `docs/` directory (domain: fredner.org).

**`docs/` is committed to git.** It is the deploy target — GitHub Pages serves the checked-in build output, so any change to `src/`, `css/`, `templates/`, or `filters/` must be followed by `make` and the regenerated `docs/` files committed alongside the source change, or the live site will not reflect it. `build/` is gitignored.

**Build pipeline:** `src/*.md` → pandoc (with Lua filters) → `docs/*.html`

- `templates/base.html` — single HTML template for all pages (nav, skip-link, back-to-top, GoatCounter analytics; no footer). `<main>` carries `tabindex="-1"` so the skip link actually moves focus rather than only scrolling; `style.css` suppresses the focus ring on it, since it is a skip target and not a control. The narrow-screen nav collapse is **progressive enhancement, deliberately inverted**: the links are visible by default and the `.nav-toggle` is hidden, and the inline script adds `js-nav` to the `<nav>` only once it has bound the button — the `@media (max-width: 500px)` rules that hide the links are all scoped to that class. Building it the other way round (links hidden in CSS, revealed by JS) meant that a blocked or failed script left Blog/CV/Research unreachable on a phone. Blog posts pass `--metadata pathprefix="../"` so relative asset paths resolve from `docs/blog/`. The template links `style.css`.
- `css/style.css` — the site's only stylesheet: minimalist black-on-white design with a `prefers-color-scheme: dark` variant (colors are CSS custom properties on `:root`), a centered ~65ch column of left-aligned text, and the three self-hosted Source families (see **Fonts** below) exposed as `--font-serif` / `--font-sans` / `--font-mono`. It styles all site chrome (`.skip-link`, nav, `.toc-box`, `.back-to-top`, `.post-card`) and content elements (figures/figcaptions, tables, blockquotes, code, and pandoc's end-of-document footnotes section). Copied to `docs/style.css` by the Makefile. All font sizes are relative (rem/em); keep it that way for accessibility.
- `vendor/csl/` — vendored citation styles from [citation-style-language/styles](https://github.com/citation-style-language/styles). `chicago-notes.csl` (Chicago 18th ed., notes without bibliography) is the only CSL the build uses; refreshed by `make update-csl` / the 30-day `csl-autoupdate` stamp.
- **Footnotes and citations** render as pandoc's standard end-of-document footnotes section (`<section id="footnotes" role="doc-endnotes">`), styled by `style.css` with `:target` highlighting for the in-page note links. Chicago-notes citations become footnotes via `--citeproc`.
- `--section-divs` — wraps each heading section in `<section>`; kept for semantic structure and anchor targets.
- `references.bib` — Zotero/Better BibTeX bibliography; all citations across the site draw from this file.
- `--metadata link-citations=false` — chicago-notes is a notes-only style with no bibliography section, so the default citeproc behavior of wrapping each citation in `<a href="#ref-...">` produces dead links and also swallows DOIs / JSTOR URLs that would otherwise render as clickable external links. Setting `link-citations` to `false` suppresses the wrapper entirely, leaving bare URLs in the citation content to be rendered as ordinary external links.
- **Figures** are pandoc's default `<figure><img><figcaption>` output, numbered by `pandoc-crossref` (`![caption](src){#fig:foo}`). Captions render below the image, styled by `style.css`.
- `filters/og-image.lua` — runs right after `filters/webp.lua` so it sees the `.webp`-rewritten src. Captures the first `Image` element on the page, resolves it against the `site-url` metadata (set in the Makefile to `https://fredner.org`), and exposes the absolute URL as `og-image` metadata. The template renders `<meta property="og:image">` (plus `twitter:card` / `twitter:image`) when that value is set, so iMessage / Slack / Twitter link previews show the page's first image. Pages with no images emit no `og:image` tag.
- `filters/wrap-tables.lua` — runs last, after `pandoc-crossref` and `filters/wrap-lists.lua` (so both still see real `Table` elements). Wraps every table in `<div class="table-scroll">`, which is what keeps a table wider than the 65ch column from pushing the whole document sideways on a phone. `style.css` draws CSS-only edge shadows on it that appear only when the table actually overflows.
  - `role="region" tabindex="0" aria-label="..."` — what makes the scroll box reachable by keyboard — is added **only to tables that can actually overflow**, currently 2 of the site's 24. A tab stop on a box with nothing to scroll is a dead stop, and 20-odd regions all named "Table" is noise in a screen reader's landmark list.
  - Overflow is estimated as the sum of each column's **longest word** (plus ~2ch of padding per column) against a 55ch threshold — prose cells wrap, so only unbreakable tokens set the floor. `overflow-wrap: break-word` on `th`/`td` lets an over-wide word break visually but, unlike `anywhere`, does not reduce min-content, so the longest word still governs.
  - **The measurement runs before `--citeproc`**, so it normalizes first: `Cite` and `Note` become a 2-character stand-in (chicago-notes renders them as footnote markers, not as the raw `[@key]` that `stringify` would return), and `LineBreak`/`SoftBreak` become spaces (they stringify to nothing, welding the words on either side into one long token). Skipping either correction marks comfortably-fitting tables as scrollable.
  - The accessible name comes from the table's caption when it has one, else the nearest preceding heading (tracked by a `traverse = "topdown"` filter), else `"Table"`. Second and later unnamed tables under one heading get a `, table N` suffix so the names stay distinct. Only 2 tables sitewide carry captions, so the heading is what usually does the work.
- **Nav wayfinding:** the Makefile passes `--metadata nav-$*=true` (the source file's stem) on every page rule, and `--metadata nav-blog=true` explicitly for the blog index and posts. `templates/base.html` turns `nav-index` / `nav-blog` / `nav-cv` / `nav-research` into `aria-current="page"` on the matching nav link; stems that match no nav item just set a variable nobody reads. Adding a nav item means adding both the link and its `$if(nav-…)$` guard.
- `--metadata email=...` is passed by every Makefile pandoc rule but the template no longer references `$email$`; it is vestigial. Contact addresses live in page content (`src/index.md`), not in the chrome.
- `defaults/toc-defaults.yaml` — sets `toc-depth: 2`; always passed via `--defaults` by the Makefile for non-blog pages.
- **Syntax highlighting:** no page currently contains fenced code blocks, so pandoc emits no `highlighting-css`. If highlighted code is ever added, pass `--highlight-style=monochrome` (weight/italic-based) rather than writing per-token color overrides — pandoc's default token colors are not tuned for the dark theme.

**Source pages** (`src/`): Markdown with YAML frontmatter. The `title` field becomes both the `<title>` and `<h1>`. `subtitle` (optional) renders as a `<p class="subtitle">` directly under the `<h1>` — lighter, smaller, muted sans — and deliberately does *not* appear in `<title>` or `og:title`, which stay short. `description` (optional) becomes the `<meta name="description">` and `og:description`. `date` (optional; set on blog posts) renders a `<time>` byline under the title. Add `toc: true` to frontmatter for pages that need a table of contents (the Makefile greps for this line and passes `--toc` to pandoc). Add `lof: true` / `lot: true` to generate a list of figures / list of tables (driven by `filters/inject-lists.lua`, which prepends a `\listoffigures` / `\listoftables` raw block; pandoc-crossref then renders the list, and `filters/wrap-lists.lua` wraps it in a `<details class="toc-box list-of-figures-box">` styled to match the TOC).

**Blog pipeline:** `src/blog/*.md` → `scripts/build_blog.py` → `build/` intermediary → `docs/blog/*.html` + `docs/blog.html` index + `docs/feed.xml` Atom feed.

- `scripts/build_blog.py` — run via `uv run` (inline script metadata declares the `pyyaml` dependency); reads frontmatter, filters out drafts, generates `build/blog-index.md` and `build/feed.xml`.
- The Makefile also filters drafts at the Make level (via a `grep '^draft: true'` shell loop) so `make` never builds an HTML page for a draft post. A post with no `date` is skipped with a warning by the script (so it vanishes from the index and feed) but the Makefile still builds its HTML page — always set `date`.
- Required blog frontmatter: `title`, `date` (YYYY-MM-DD). Optional: `description`, `draft`.
- `docs/blog.html` (the index) is built from the generated `build/blog-index.md` with a deliberately minimal pandoc call — no `--section-divs`, no crossref, no citeproc, no `site-url`. The index markup (`.post-card`, `.post-date`) is emitted as raw HTML by `build_blog.py`, so changing the index layout means editing that script, not a template.

**Fonts:** self-hosted subsets of three Adobe families (all SIL OFL 1.1) — **Source Serif 4** for body prose, **Source Sans 3** for headings and site chrome (nav, TOC label, back-to-top, skip link, figcaptions, table headers), **Source Code Pro** for `code`/`pre`.

- `scripts/build_fonts.py` (`make fonts`) downloads the variable TTFs from the `release` branch of `adobe-fonts/source-serif`, `source-sans`, and `source-code-pro`, subsets them with fontTools, and writes `fonts/*.woff2` plus each repo's `LICENSE-*.md`. `make` copies both into `docs/fonts/`.
- **`make fonts` is deliberately *not* a prerequisite of `all`** — unlike the CSL auto-update there is no 30-day stamp, because silently changing the site's typography mid-build is undesirable. Run it on purpose and review the diff.
- **The subset ranges are load-bearing, not decorative.** `references.bib` contains `Č č ļ Š` (Latin Extended-A) in author names, which fall *outside* the usual "latin" webfont subset that Google Fonts and Fontsource ship — a `latin`-only build drops to a fallback face mid-name on `reading-lms.html` and `the-ends-of-reading.html`. The text ranges in `build_fonts.py` also cover the `↑`, `▸`, `▾` symbols the template and stylesheet inject. Source Code Pro is ASCII-only (the site has no `<pre>` blocks; mono is inline-only).
- **`PIN_OPSZ` in `build_fonts.py` matters a lot for size.** Source Serif 4 ships a second variation axis (`opsz 8–60`) whose `gvar` deltas more than double the file — 124 KB vs 51 KB for the roman. Since the serif is only ever set at 16–18px here, the axis is pinned to its default of 20. All four faces total ~141 KB.
- The `@font-face` blocks use `font-weight: 200 900` (one variable file per face covers every weight) and **`font-display: optional`**. This is a CLS fix, not a preference: under `swap` the page repainted in the webfont whenever it arrived, and Source Serif is ~15% narrower than the generic serifs, so every paragraph rewrapped mid-load (PageSpeed measured 0.46 CLS). `optional` gives a short block period and *no* swap period — a face that isn't ready at first paint is simply not used for that pageview, which makes the shift structurally impossible. The tradeoff is that a cold first visit over a slow link renders in the fallback.
- **Under `optional`, each face is dropped independently**, so `templates/base.html` preloads all three faces that set running prose: serif roman, serif italic, and sans upright. Dropping the italic from that list is a real bug, not an optimization — the roman lands, the italic doesn't, and a sentence containing a book title renders half in Source Serif and half in Georgia. Mono is left to CSS discovery (inline-only, few pages). The `crossorigin` attribute is required even though the fonts are same-origin: fonts are fetched in CORS mode, and without it the preload lands in a separate cache entry and the font downloads twice.
- **Metric-matched fallback faces: one `@font-face` per set of system metrics, and never two non-metric-compatible families in one `src`.** An `@font-face` whose every `local()` fails to resolve is unusable and the stack falls through it *silently*. A single face declaring `local("Georgia"), local("Times New Roman")` therefore looked correct on macOS and did nothing whatsoever on Linux, Android, or PageSpeed's own runner — which is how the 0.46 CLS went unnoticed locally. There are now four: `Source Serif Fallback Georgia`, `Source Serif Fallback Times` (plus its metric clones Liberation Serif / Tinos / Nimbus Roman), `Source Sans Fallback Helvetica`, and `Source Sans Fallback Arial` (plus Liberation Sans / Arimo). **The `size-adjust`/`ascent-override`/`descent-override` values are derived from the fonts' `OS/2` and `hhea` tables — recompute them if `make fonts` pulls an upstream release with different metrics.**
- **The reading column is `max-width: 36.5625rem`, deliberately not `65ch`.** That rem value *is* 65ch of Source Serif at the body's `1.125rem` (its `0` advance is exactly 0.5em), but `ch` resolves against each element's own computed font, which made the shared `header > nav, main` rule mean two different widths (the nav is sans, `0` = 0.497em) and made the column itself resize when a fallback stood in — generic serifs run up to 27% wider at `0`. Keep it in rem; `line-height` here is unitless, so horizontal advance is the *only* font-dependent geometry on the site.

**Assets:** `src/images/` → `docs/images/`. JPG/JPEG/PNG are converted to WebP via `cwebp`; existing `.webp` and `.svg` files are copied through unchanged. In markdown, reference images by their original `.jpg`/`.jpeg`/`.png` filename — `filters/webp.lua` rewrites image `src` attributes to `.webp` during the pandoc run so the HTML matches the converted asset.

**Slides:** `slides/*.html` is copied verbatim to `docs/slides/` (no pandoc processing).

**GitHub Pages config:** `CNAME` (custom domain) and `.nojekyll` (disables Jekyll) are recreated in `docs/` by `make`, so they survive `make clean`.

**Favicon:** `favicon.svg` is an asterisk on a transparent ground, set in the site's own Source Serif 4 at weight 600 (the heading/wordmark weight). It lives at the repo root, not in `src/images/` — `make prune-images` deletes anything under `src/images/` that no `.md` references, and the file needs to land at the site root rather than under `/images/`. `make` copies it to `docs/favicon.svg`.

Two things about it are load-bearing:

- **The glyph is a baked path, not a `<text>` element.** A favicon renders outside the page's font context, so `<text>` would fall back to whatever serif the viewer's system has, and the asterisk's shape varies a lot between faces. The outline was extracted from `fonts/source-serif-4-roman.woff2` with fontTools — `instancer.instantiateVariableFont` to pin the `wght` axis, then `SVGPathPen` — and the transform's negative y scale converts the font's y-up coordinates to SVG's y-down. Regenerate it that way rather than hand-editing the path data.
- **An XML comment may not contain a double hyphen.** The comment inside the file therefore spells the CSS custom properties without their leading dashes. Writing `--text` there makes the file fail to parse, and browsers render a broken-image icon instead of the favicon.

Light/dark is handled by a `prefers-color-scheme` block *inside* the SVG, using the site's own text colors, so the mark stays legible against both a light and a dark tab strip.
