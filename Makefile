PANDOC := pandoc
SRC_DIR := src
OUT_DIR := docs
TEMPLATE := templates/tufte-base.html
BIBLIOGRAPHY := references.bib
CSL := chicago-notes.csl
LUA_FILTER := filters/webp.lua
OG_IMAGE_FILTER := filters/og-image.lua
LISTS_FILTER := filters/inject-lists.lua
WRAP_LISTS_FILTER := filters/wrap-lists.lua
FIG_MARGIN_FILTER := filters/figure-margin.lua
CURRENT_YEAR := $(shell date +%Y)
BUILD_DATE := $(shell date +%Y-%m-%d)
EMAIL := erik.fredner@oregonstate.edu

# Per-page footer dates come from `git log` of each source file, but Make's
# rebuild check is mtime-based and a commit does not change the source file's
# mtime. Depending on the reflog (touched by every commit) forces pages to
# rebuild after a commit so the footer date reflects the latest content change.
# (wildcard => degrades gracefully to current behavior if the reflog is absent.)
GIT_HEAD := $(wildcard .git/logs/HEAD)

SRC_MD := $(wildcard $(SRC_DIR)/*.md)
HTML_OUT := $(patsubst $(SRC_DIR)/%.md,$(OUT_DIR)/%.html,$(SRC_MD))

# Blog
POST_TEMPLATE   := templates/post.html
BUILD_DIR       := build
BLOG_SCRIPT     := scripts/build_blog.py
BLOG_SRC_DIR    := $(SRC_DIR)/blog
BLOG_OUT_DIR    := $(OUT_DIR)/blog
SITE_URL        := https://fredner.org
BLOG_INDEX_MD   := $(BUILD_DIR)/blog-index.md
BLOG_FEED_XML   := $(BUILD_DIR)/feed.xml
BLOG_INDEX_HTML := $(OUT_DIR)/blog.html
FEED_OUT        := $(OUT_DIR)/feed.xml

BLOG_SRC_MD := $(wildcard $(BLOG_SRC_DIR)/*.md)
# Filter drafts at eval time: include only files that do NOT contain 'draft: true'
BLOG_PUBLISHED_SRC := $(shell for f in $(BLOG_SRC_MD); do \
  grep -q '^draft: true' "$$f" 2>/dev/null || echo "$$f"; \
done)
BLOG_HTML_OUT := $(patsubst $(BLOG_SRC_DIR)/%.md,$(BLOG_OUT_DIR)/%.html,$(BLOG_PUBLISHED_SRC))

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

# Tufte CSS bundle (vendored stylesheets + et-book fonts)
TUFTE_SRC_DIR  := vendor/tufte
TUFTE_CSS_NAMES := tufte.css pandoc.css tufte-extra.css site-extra.css
TUFTE_CSS_OUT  := $(patsubst %,$(OUT_DIR)/%,$(TUFTE_CSS_NAMES))
TUFTE_FONT_SRC := $(shell find $(TUFTE_SRC_DIR)/et-book -type f 2>/dev/null)
TUFTE_FONT_OUT := $(patsubst $(TUFTE_SRC_DIR)/%,$(OUT_DIR)/%,$(TUFTE_FONT_SRC))
TUFTE_OUT      := $(TUFTE_CSS_OUT) $(TUFTE_FONT_OUT)

# Upstream sources for the vendored Tufte CSS (used only by `make update-tufte`).
# tufte.css comes from edwardtufte/tufte-css; pandoc.css and tufte-extra.css from
# jez/tufte-pandoc-css. site-extra.css is local and is never overwritten.
TUFTE_CSS_UPSTREAM_URL  := https://raw.githubusercontent.com/edwardtufte/tufte-css/gh-pages/tufte.css
PANDOC_CSS_UPSTREAM_URL := https://raw.githubusercontent.com/jez/tufte-pandoc-css/master/pandoc.css
EXTRA_CSS_UPSTREAM_URL  := https://raw.githubusercontent.com/jez/tufte-pandoc-css/master/tufte-extra.css
# Local-only stamp (gitignored) recording the last successful upstream refresh.
TUFTE_STAMP := $(TUFTE_SRC_DIR)/.tufte-updated

# GitHub Pages config files
CNAME_SRC := CNAME
CNAME_OUT := $(OUT_DIR)/CNAME
NOJEKYLL_OUT := $(OUT_DIR)/.nojekyll

all: tufte-autoupdate $(HTML_OUT) $(IMAGES_OUT) $(SLIDES_OUT) $(TUFTE_OUT) $(CNAME_OUT) $(NOJEKYLL_OUT) blog

# Refresh the vendored Tufte CSS from upstream if it hasn't been pulled in the
# last 30 days. Runs automatically as part of `make`. Failures (e.g. offline)
# are non-fatal: the build continues with the existing vendored copies.
.PHONY: tufte-autoupdate
tufte-autoupdate:
	@if [ -z "$$(find $(TUFTE_STAMP) -mtime -30 2>/dev/null)" ]; then \
	  echo "Tufte CSS not refreshed in 30+ days; checking upstream..."; \
	  if $(MAKE) --no-print-directory update-tufte; then touch $(TUFTE_STAMP); \
	  else echo "warning: tufte auto-update failed (offline?); using existing vendored copies."; fi; \
	fi

$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) $(LUA_FILTER) $(OG_IMAGE_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) $(FIG_MARGIN_FILTER) $(GIT_HEAD) | $(OUT_DIR)
	TOC_ARG=$$(grep -m1 '^toc: true' $< > /dev/null 2>&1 && echo '--toc' || echo ''); \
	PAGE_DATE=$$(git log -1 --format=%cs -- $< 2>/dev/null); \
	[ -n "$$PAGE_DATE" ] || PAGE_DATE=$(BUILD_DATE); \
	$(PANDOC) --standalone $$TOC_ARG --defaults=defaults/toc-defaults.yaml --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata build-date="$$PAGE_DATE" \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata link-citations=false \
	  --lua-filter=$(OG_IMAGE_FILTER) \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  --lua-filter=$(FIG_MARGIN_FILTER) \
	  --filter pandoc-sidenote \
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

# Copy Tufte CSS files
$(OUT_DIR)/%.css: $(TUFTE_SRC_DIR)/%.css | $(OUT_DIR)
	cp $< $@

# Copy et-book font files (preserve subdirectory structure)
$(OUT_DIR)/et-book/%: $(TUFTE_SRC_DIR)/et-book/% | $(OUT_DIR)
	@mkdir -p $(dir $@)
	cp $< $@

# Copy CNAME for GitHub Pages custom domain
$(CNAME_OUT): $(CNAME_SRC) | $(OUT_DIR)
	cp $< $@

# Create .nojekyll to disable Jekyll processing
$(NOJEKYLL_OUT): | $(OUT_DIR)
	touch $@

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
blog: $(BLOG_INDEX_HTML) $(FEED_OUT) $(BLOG_HTML_OUT)

$(BLOG_INDEX_MD): $(BLOG_SRC_MD) $(BLOG_SCRIPT) | $(BUILD_DIR)
	uv run $(BLOG_SCRIPT) --src-dir $(BLOG_SRC_DIR) --build-dir $(BUILD_DIR) --site-url $(SITE_URL)

$(BLOG_INDEX_HTML): $(BLOG_INDEX_MD) $(TEMPLATE) $(LUA_FILTER) | $(OUT_DIR)
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata build-date="$(BUILD_DATE)" \
	  --metadata email="$(EMAIL)" \
	  -o $@ $<

$(FEED_OUT): $(BLOG_INDEX_MD) | $(OUT_DIR)
	cp $(BLOG_FEED_XML) $@

$(BLOG_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(BLOG_OUT_DIR)

# Static pattern rule: explicit targets prevent ambiguity with the generic docs/%.html rule
$(BLOG_HTML_OUT): $(BLOG_OUT_DIR)/%.html: $(BLOG_SRC_DIR)/%.md $(TEMPLATE) $(LUA_FILTER) $(OG_IMAGE_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) $(FIG_MARGIN_FILTER) $(GIT_HEAD) | $(BLOG_OUT_DIR)
	PAGE_DATE=$$(git log -1 --format=%cs -- $< 2>/dev/null); \
	[ -n "$$PAGE_DATE" ] || PAGE_DATE=$(BUILD_DATE); \
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata build-date="$$PAGE_DATE" \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata pathprefix="../" \
	  --metadata link-citations=false \
	  --lua-filter=$(OG_IMAGE_FILTER) \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  --lua-filter=$(FIG_MARGIN_FILTER) \
	  --filter pandoc-sidenote \
	  -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Re-pull the vendored Tufte CSS from upstream (leaves site-extra.css alone).
# Run `git diff vendor/tufte` afterward to review any incoming changes.
update-tufte:
	curl -fsSL $(TUFTE_CSS_UPSTREAM_URL)  -o $(TUFTE_SRC_DIR)/tufte.css
	curl -fsSL $(PANDOC_CSS_UPSTREAM_URL) -o $(TUFTE_SRC_DIR)/pandoc.css
	curl -fsSL $(EXTRA_CSS_UPSTREAM_URL)  -o $(TUFTE_SRC_DIR)/tufte-extra.css
	@echo "Tufte CSS refreshed from upstream. Review with: git diff $(TUFTE_SRC_DIR)"

.PHONY: clean serve prune-images update-tufte tufte-autoupdate blog
clean: ; rm -rf $(OUT_DIR)
serve: all
	python3 -m http.server 8000 --bind localhost --directory $(OUT_DIR) & \
	SERVER_PID=$$!; \
	trap "kill $$SERVER_PID 2>/dev/null" EXIT INT TERM; \
	{ find $(SRC_DIR) -name '*.md'; find $(TUFTE_SRC_DIR) -name '*.css'; find templates/ -name '*.html'; find filters/ -name '*.lua'; } | entr $(MAKE) all; \
	kill $$SERVER_PID 2>/dev/null
