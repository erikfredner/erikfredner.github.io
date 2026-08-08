PANDOC := pandoc
SRC_DIR := src
OUT_DIR := docs
TEMPLATE := templates/base.html
BIBLIOGRAPHY := references.bib
CSL := vendor/csl/chicago-notes.csl
LUA_FILTER := filters/webp.lua
OG_IMAGE_FILTER := filters/og-image.lua
LISTS_FILTER := filters/inject-lists.lua
WRAP_LISTS_FILTER := filters/wrap-lists.lua
WRAP_TABLES_FILTER := filters/wrap-tables.lua
ABSOLUTIZE_FILTER := filters/absolutize.lua
EMAIL := erik.fredner@oregonstate.edu
AUTHOR := Erik Fredner

# 404.md is excluded from the generic rule: GitHub Pages serves docs/404.html in
# place of any unmatched path, at any depth, so it needs root-absolute asset
# paths rather than the relative ones every other top-level page gets.
SRC_MD := $(filter-out $(SRC_DIR)/404.md,$(wildcard $(SRC_DIR)/*.md))
HTML_OUT := $(patsubst $(SRC_DIR)/%.md,$(OUT_DIR)/%.html,$(SRC_MD))
NOTFOUND_SRC := $(SRC_DIR)/404.md
NOTFOUND_OUT := $(OUT_DIR)/404.html

# Blog
BUILD_DIR       := build
BLOG_SCRIPT     := scripts/build_blog.py
BLOG_SRC_DIR    := $(SRC_DIR)/blog
BLOG_OUT_DIR    := $(OUT_DIR)/blog
SITE_URL        := https://fredner.org
BLOG_INDEX_MD   := $(BUILD_DIR)/blog-index.md
BLOG_FEED_XML   := $(BUILD_DIR)/feed.xml
BLOG_INDEX_HTML := $(OUT_DIR)/blog.html
FEED_OUT        := $(OUT_DIR)/feed.xml
# Committed manifest of per-post publication/modification timestamps. This is
# the source of truth for post dates; frontmatter `date:` is an optional
# override. Deleting it re-stamps every published post to "now".
BLOG_MANIFEST   := $(BLOG_SRC_DIR)/timestamps.json
BLOG_META_DIR   := $(BUILD_DIR)/meta
BLOG_FRAG_DIR   := $(BUILD_DIR)/feed
BLOG_TAGS_MD    := $(BUILD_DIR)/tags-index.md
TAGS_OUT_DIR    := $(OUT_DIR)/tags
TAGS_INDEX_HTML := $(OUT_DIR)/tags.html
SITEMAP_SCRIPT  := scripts/build_sitemap.py
SITEMAP_OUT     := $(OUT_DIR)/sitemap.xml
ROBOTS_SRC      := robots.txt
ROBOTS_OUT      := $(OUT_DIR)/robots.txt

BLOG_SRC_MD := $(wildcard $(BLOG_SRC_DIR)/*.md)
# Filter drafts at eval time: include only files that do NOT contain 'draft: true'
BLOG_PUBLISHED_SRC := $(shell for f in $(BLOG_SRC_MD); do \
  grep -q '^draft: true' "$$f" 2>/dev/null || echo "$$f"; \
done)
BLOG_HTML_OUT := $(patsubst $(BLOG_SRC_DIR)/%.md,$(BLOG_OUT_DIR)/%.html,$(BLOG_PUBLISHED_SRC))
BLOG_META_OUT := $(patsubst $(BLOG_SRC_DIR)/%.md,$(BLOG_META_DIR)/%.yaml,$(BLOG_PUBLISHED_SRC))
BLOG_FRAG_OUT := $(patsubst $(BLOG_SRC_DIR)/%.md,$(BLOG_FRAG_DIR)/%.html,$(BLOG_PUBLISHED_SRC))

# Image assets
IMG_SRC_DIR := $(SRC_DIR)/images
IMG_OUT_DIR := $(OUT_DIR)/images

IMG_JPG_SRC  := $(wildcard $(IMG_SRC_DIR)/*.jpg)
IMG_JPEG_SRC := $(wildcard $(IMG_SRC_DIR)/*.jpeg)
IMG_PNG_SRC  := $(wildcard $(IMG_SRC_DIR)/*.png)
IMG_WEBP_SRC := $(wildcard $(IMG_SRC_DIR)/*.webp)
IMG_SVG_SRC  := $(wildcard $(IMG_SRC_DIR)/*.svg)

IMG_JPG_OUT  := $(patsubst $(IMG_SRC_DIR)/%.jpg,$(IMG_OUT_DIR)/%.webp,$(IMG_JPG_SRC))
IMG_JPEG_OUT := $(patsubst $(IMG_SRC_DIR)/%.jpeg,$(IMG_OUT_DIR)/%.webp,$(IMG_JPEG_SRC))
IMG_PNG_OUT  := $(patsubst $(IMG_SRC_DIR)/%.png,$(IMG_OUT_DIR)/%.webp,$(IMG_PNG_SRC))
IMG_WEBP_OUT := $(patsubst $(IMG_SRC_DIR)/%,$(IMG_OUT_DIR)/%,$(IMG_WEBP_SRC))
IMG_SVG_OUT  := $(patsubst $(IMG_SRC_DIR)/%,$(IMG_OUT_DIR)/%,$(IMG_SVG_SRC))

IMAGES_OUT := $(IMG_JPG_OUT) $(IMG_JPEG_OUT) $(IMG_PNG_OUT) $(IMG_WEBP_OUT) $(IMG_SVG_OUT)

# Slide decks
SLIDES_SRC_DIR := slides
SLIDES_OUT_DIR := $(OUT_DIR)/slides
SLIDES_SRC := $(wildcard $(SLIDES_SRC_DIR)/*.html)
SLIDES_OUT := $(patsubst $(SLIDES_SRC_DIR)/%,$(SLIDES_OUT_DIR)/%,$(SLIDES_SRC))

# Stylesheet
STYLE_SRC := css/style.css
STYLE_OUT := $(OUT_DIR)/style.css

# Subset webfonts (built by `make fonts`, committed to the repo)
FONT_SCRIPT  := scripts/build_fonts.py
FONT_SRC_DIR := fonts
FONT_OUT_DIR := $(OUT_DIR)/fonts
# The OFL requires the license to travel with the fonts, so the LICENSE-*.md
# files that build_fonts.py pulls down are served alongside them.
FONT_SRC     := $(wildcard $(FONT_SRC_DIR)/*.woff2) $(wildcard $(FONT_SRC_DIR)/*.md)
FONT_OUT     := $(patsubst $(FONT_SRC_DIR)/%,$(FONT_OUT_DIR)/%,$(FONT_SRC))

# Vendored CSL from citation-style-language/styles (used by `make update-csl`).
CSL_DIR          := vendor/csl
CSL_UPSTREAM_URL := https://raw.githubusercontent.com/citation-style-language/styles/master/chicago-notes.csl
# Local-only stamp (gitignored) recording the last successful upstream refresh.
CSL_STAMP := $(CSL_DIR)/.csl-updated

# GitHub Pages config files
CNAME_SRC := CNAME
CNAME_OUT := $(OUT_DIR)/CNAME
NOJEKYLL_OUT := $(OUT_DIR)/.nojekyll

# Favicon. Lives at the repo root rather than src/images/ so that `prune-images`
# (which deletes anything no .md references) leaves it alone and it lands at the
# site root instead of under /images/.
FAVICON_SRC := favicon.svg
FAVICON_OUT := $(OUT_DIR)/favicon.svg

all: csl-autoupdate $(HTML_OUT) $(NOTFOUND_OUT) $(IMAGES_OUT) $(SLIDES_OUT) $(STYLE_OUT) $(FONT_OUT) $(CNAME_OUT) $(NOJEKYLL_OUT) $(FAVICON_OUT) $(ROBOTS_OUT) blog tags sitemap

# Refresh the vendored CSL from upstream if it hasn't been pulled in the
# last 30 days. Runs automatically as part of `make`. Failures (e.g. offline)
# are non-fatal: the build continues with the existing vendored copy.
.PHONY: csl-autoupdate
csl-autoupdate:
	@if [ -z "$$(find $(CSL_STAMP) -mtime -30 2>/dev/null)" ]; then \
	  echo "CSL not refreshed in 30+ days; checking upstream..."; \
	  if $(MAKE) --no-print-directory update-csl; then touch $(CSL_STAMP); \
	  else echo "warning: CSL auto-update failed (offline?); using existing vendored copy."; fi; \
	fi

$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) $(LUA_FILTER) $(OG_IMAGE_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) $(WRAP_TABLES_FILTER) | $(OUT_DIR)
	TOC_ARG=$$(grep -m1 '^toc: true' $< > /dev/null 2>&1 && echo '--toc' || echo ''); \
	$(PANDOC) --standalone $$TOC_ARG --defaults=defaults/toc-defaults.yaml --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata link-citations=false \
	  --metadata nav-$*=true \
	  --metadata canonical="$(SITE_URL)/$(if $(filter index,$*),,$*.html)" \
	  --lua-filter=$(OG_IMAGE_FILTER) \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --lua-filter=$(WRAP_TABLES_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  -o $@ $<

# The 404 page. `pathprefix=/` because GitHub Pages serves this file for an
# unmatched path at any depth (/a/b/c), where relative asset and nav links would
# resolve against /a/b/ and break. No canonical: it is not a real page.
$(NOTFOUND_OUT): $(NOTFOUND_SRC) $(TEMPLATE) $(LUA_FILTER) | $(OUT_DIR)
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata pathprefix="/" \
	  -o $@ $<

# Ensure base output dir exists
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Image output dir
$(IMG_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(IMG_OUT_DIR)

# Convert JPG/JPEG/PNG to WebP
$(IMG_OUT_DIR)/%.webp: $(IMG_SRC_DIR)/%.jpg | $(IMG_OUT_DIR)
	cwebp -quiet $< -o $@

$(IMG_OUT_DIR)/%.webp: $(IMG_SRC_DIR)/%.jpeg | $(IMG_OUT_DIR)
	cwebp -quiet $< -o $@

$(IMG_OUT_DIR)/%.webp: $(IMG_SRC_DIR)/%.png | $(IMG_OUT_DIR)
	cwebp -quiet $< -o $@

# Copy existing WebP files unchanged
$(IMG_OUT_DIR)/%.webp: $(IMG_SRC_DIR)/%.webp | $(IMG_OUT_DIR)
	cp $< $@

# Copy SVG files unchanged
$(IMG_OUT_DIR)/%.svg: $(IMG_SRC_DIR)/%.svg | $(IMG_OUT_DIR)
	cp $< $@

# Slide output dir
$(SLIDES_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(SLIDES_OUT_DIR)

# Copy each slide deck
$(SLIDES_OUT_DIR)/%: $(SLIDES_SRC_DIR)/% | $(SLIDES_OUT_DIR)
	cp $< $@

# Copy the stylesheet
$(STYLE_OUT): $(STYLE_SRC) | $(OUT_DIR)
	cp $< $@

# Font output dir
$(FONT_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(FONT_OUT_DIR)

# Copy each subset webfont and its license
$(FONT_OUT_DIR)/%: $(FONT_SRC_DIR)/% | $(FONT_OUT_DIR)
	cp $< $@

# Re-download and re-subset the Source families from adobe-fonts/*.
# Deliberately NOT a prerequisite of `all`: it needs network access and its
# output is committed, so run it on purpose and review the diff. If the upstream
# metrics change, re-derive the fallback overrides in css/style.css.
fonts:
	uv run $(FONT_SCRIPT) --out-dir $(FONT_SRC_DIR)
	@echo "Fonts rebuilt. Review with: git diff --stat $(FONT_SRC_DIR)"

# Copy CNAME for GitHub Pages custom domain
$(CNAME_OUT): $(CNAME_SRC) | $(OUT_DIR)
	cp $< $@

# Create .nojekyll to disable Jekyll processing
$(NOJEKYLL_OUT): | $(OUT_DIR)
	touch $@

# Copy the favicon to the site root
$(FAVICON_OUT): $(FAVICON_SRC) | $(OUT_DIR)
	cp $< $@

# Delete images in src/images/ that are not referenced in any src/*.md
prune-images:
	@for img in $(IMG_SRC_DIR)/*.jpg $(IMG_SRC_DIR)/*.jpeg $(IMG_SRC_DIR)/*.png $(IMG_SRC_DIR)/*.webp $(IMG_SRC_DIR)/*.svg; do \
	  [ -e "$$img" ] || continue; \
	  base=$$(basename "$$img"); \
	  stem=$$(basename "$$img" | sed 's/\.[^.]*$$//'); \
	  if ! grep -qr "images/$$base\|images/$$stem\." $(SRC_DIR)/*.md $(SRC_DIR)/blog/*.md 2>/dev/null; then \
	    echo "Removing unused image: $$img"; \
	    rm "$$img"; \
	  fi; \
	done

# Blog targets
blog: $(BLOG_INDEX_HTML) $(FEED_OUT) $(BLOG_HTML_OUT) blog-prune

# Delete built pages for posts that no longer exist or have become drafts.
# Without this a deleted or newly-drafted post keeps serving from docs/ (this
# has happened before: docs/blog/chronicling-freqs.html had to be removed by
# hand) and sitemap.xml, which enumerates docs/blog/*.html, would still list it.
blog-prune: | $(BLOG_OUT_DIR)
	@keep=" $(notdir $(BLOG_HTML_OUT)) "; \
	for f in $(BLOG_OUT_DIR)/*.html; do \
	  [ -e "$$f" ] || continue; \
	  case "$$keep" in \
	    *" $$(basename "$$f") "*) ;; \
	    *) echo "Blog: pruning stale $$f"; rm -f "$$f";; \
	  esac; \
	done

# One script run produces blog-index.md, meta/*.yaml, tags/*.md, tags-index.md,
# posts.json, and (re)writes the committed timestamps.json.
#
# $(BLOG_SRC_DIR) is a prerequisite alongside the file list because *deleting* a
# post changes only the directory's mtime — the wildcard simply stops mentioning
# it, and blog-index.md still looks newer than every remaining source, so the
# stale entry would survive in timestamps.json and the feed. The script writes
# only files whose content actually changed, so watching the directory does not
# cascade a full rebuild on every run.
#
# $(BLOG_MANIFEST) is a prerequisite too: it is the source of truth for post
# dates and is meant to be correctable by hand (e.g. to undo an `updated` bump
# caused by a metadata-only edit). Without it, a hand-edited date is silently
# ignored until something else forces a rerun. The script writes the manifest
# only when its content changes, so this converges rather than looping.
$(BLOG_INDEX_MD): $(BLOG_SRC_MD) $(BLOG_SRC_DIR) $(BLOG_MANIFEST) $(BLOG_SCRIPT) | $(BUILD_DIR)
	uv run $(BLOG_SCRIPT) --stage meta \
	  --src-dir $(BLOG_SRC_DIR) --build-dir $(BUILD_DIR) \
	  --site-url $(SITE_URL) --manifest $(BLOG_MANIFEST)

# The per-post metadata files are co-products of the rule above, not separately
# buildable. The empty recipe tells Make they are up to date once it has run.
$(BLOG_META_OUT): $(BLOG_META_DIR)/%.yaml: $(BLOG_INDEX_MD) ;

$(BLOG_INDEX_HTML): $(BLOG_INDEX_MD) $(TEMPLATE) $(LUA_FILTER) | $(OUT_DIR)
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata email="$(EMAIL)" \
	  --metadata nav-blog=true \
	  --metadata canonical="$(SITE_URL)/blog.html" \
	  -o $@ $<

$(FEED_OUT): $(BLOG_FEED_XML) | $(OUT_DIR)
	cp $< $@

# The feed embeds each post's rendered HTML, so it must run after the fragments.
$(BLOG_FEED_XML): $(BLOG_INDEX_MD) $(BLOG_FRAG_OUT) $(BLOG_SCRIPT)
	uv run $(BLOG_SCRIPT) --stage feed \
	  --build-dir $(BUILD_DIR) --site-url $(SITE_URL) --author "$(AUTHOR)"

$(BLOG_FRAG_DIR): | $(BUILD_DIR)
	mkdir -p $(BLOG_FRAG_DIR)

# Template-less HTML fragments for the Atom <content> element. absolutize.lua
# rewrites relative links and images against the post's own URL, since a feed
# entry is read outside the page it came from.
$(BLOG_FRAG_OUT): $(BLOG_FRAG_DIR)/%.html: $(BLOG_SRC_DIR)/%.md $(BIBLIOGRAPHY) $(CSL) $(LUA_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) $(WRAP_TABLES_FILTER) $(ABSOLUTIZE_FILTER) | $(BLOG_FRAG_DIR)
	$(PANDOC) --to html5 --id-prefix="$*-" \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata post-url="$(SITE_URL)/blog/$*.html" \
	  --metadata link-citations=false \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --lua-filter=$(WRAP_TABLES_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  --lua-filter=$(ABSOLUTIZE_FILTER) \
	  -o $@ $<

$(BLOG_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(BLOG_OUT_DIR)

# Static pattern rule: explicit targets prevent ambiguity with the generic docs/%.html rule
$(BLOG_HTML_OUT): $(BLOG_OUT_DIR)/%.html: $(BLOG_SRC_DIR)/%.md $(BLOG_META_DIR)/%.yaml $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) $(LUA_FILTER) $(OG_IMAGE_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) $(WRAP_TABLES_FILTER) | $(BLOG_OUT_DIR)
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata pathprefix="../" \
	  --metadata link-citations=false \
	  --metadata nav-blog=true \
	  --metadata-file=$(BLOG_META_DIR)/$*.yaml \
	  --lua-filter=$(OG_IMAGE_FILTER) \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --lua-filter=$(WRAP_TABLES_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  -o $@ $<

# Tag pages. The tag set is not knowable at Make parse time, so this is phony
# and wipes docs/tags/ first — that is what removes pages for tags no longer in
# use. Pandoc is deterministic, so unconditional regeneration still leaves
# `git status` clean. Skipped entirely when no post carries a tag.
tags: $(BLOG_INDEX_MD) $(TEMPLATE) $(LUA_FILTER) | $(OUT_DIR)
	@rm -rf $(TAGS_OUT_DIR) $(TAGS_INDEX_HTML)
	@if [ -f $(BLOG_TAGS_MD) ]; then \
	  mkdir -p $(TAGS_OUT_DIR); \
	  for f in $(BUILD_DIR)/tags/*.md; do \
	    slug=$$(basename "$$f" .md); \
	    $(PANDOC) --standalone --template=$(TEMPLATE) \
	      --lua-filter=$(LUA_FILTER) \
	      --metadata email="$(EMAIL)" \
	      --metadata pathprefix="../" \
	      --metadata nav-blog=true \
	      --metadata canonical="$(SITE_URL)/tags/$$slug.html" \
	      -o $(TAGS_OUT_DIR)/$$slug.html "$$f"; \
	  done; \
	  $(PANDOC) --standalone --template=$(TEMPLATE) \
	    --lua-filter=$(LUA_FILTER) \
	    --metadata email="$(EMAIL)" \
	    --metadata nav-blog=true \
	    --metadata canonical="$(SITE_URL)/tags.html" \
	    -o $(TAGS_INDEX_HTML) $(BLOG_TAGS_MD); \
	  echo "Tags: wrote $(TAGS_INDEX_HTML) and $(TAGS_OUT_DIR)/"; \
	fi

# Runs last, once every page exists, so it can enumerate the built HTML.
sitemap: $(HTML_OUT) $(NOTFOUND_OUT) $(SITEMAP_SCRIPT) blog tags | $(OUT_DIR)
	@uv run $(SITEMAP_SCRIPT) --out-dir $(OUT_DIR) --site-url $(SITE_URL) --manifest $(BLOG_MANIFEST)

$(ROBOTS_OUT): $(ROBOTS_SRC) | $(OUT_DIR)
	cp $< $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Re-pull the vendored CSL from upstream.
# Run `git diff vendor/csl` afterward to review any incoming changes.
update-csl:
	curl -fsSL $(CSL_UPSTREAM_URL) -o $(CSL_DIR)/chicago-notes.csl
	@echo "CSL refreshed from upstream. Review with: git diff $(CSL_DIR)"

.PHONY: clean serve prune-images update-csl csl-autoupdate blog blog-prune tags sitemap fonts
clean: ; rm -rf $(OUT_DIR)
serve: all
	python3 -m http.server 8000 --bind localhost --directory $(OUT_DIR) & \
	SERVER_PID=$$!; \
	trap "kill $$SERVER_PID 2>/dev/null" EXIT INT TERM; \
	{ find $(SRC_DIR) -name '*.md'; find css -name '*.css'; find templates/ -name '*.html'; find filters/ -name '*.lua'; } | entr $(MAKE) all; \
	kill $$SERVER_PID 2>/dev/null
