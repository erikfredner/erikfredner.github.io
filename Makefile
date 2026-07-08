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
EMAIL := erik.fredner@oregonstate.edu

SRC_MD := $(wildcard $(SRC_DIR)/*.md)
HTML_OUT := $(patsubst $(SRC_DIR)/%.md,$(OUT_DIR)/%.html,$(SRC_MD))

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

# Stylesheet
STYLE_SRC := css/style.css
STYLE_OUT := $(OUT_DIR)/style.css

# Vendored CSL from citation-style-language/styles (used by `make update-csl`).
CSL_DIR          := vendor/csl
CSL_UPSTREAM_URL := https://raw.githubusercontent.com/citation-style-language/styles/master/chicago-notes.csl
# Local-only stamp (gitignored) recording the last successful upstream refresh.
CSL_STAMP := $(CSL_DIR)/.csl-updated

# GitHub Pages config files
CNAME_SRC := CNAME
CNAME_OUT := $(OUT_DIR)/CNAME
NOJEKYLL_OUT := $(OUT_DIR)/.nojekyll

all: csl-autoupdate $(HTML_OUT) $(IMAGES_OUT) $(SLIDES_OUT) $(STYLE_OUT) $(CNAME_OUT) $(NOJEKYLL_OUT) blog

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

$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) $(LUA_FILTER) $(OG_IMAGE_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) | $(OUT_DIR)
	TOC_ARG=$$(grep -m1 '^toc: true' $< > /dev/null 2>&1 && echo '--toc' || echo ''); \
	$(PANDOC) --standalone $$TOC_ARG --defaults=defaults/toc-defaults.yaml --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata link-citations=false \
	  --lua-filter=$(OG_IMAGE_FILTER) \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
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
	  --metadata email="$(EMAIL)" \
	  -o $@ $<

$(FEED_OUT): $(BLOG_INDEX_MD) | $(OUT_DIR)
	cp $(BLOG_FEED_XML) $@

$(BLOG_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(BLOG_OUT_DIR)

# Static pattern rule: explicit targets prevent ambiguity with the generic docs/%.html rule
$(BLOG_HTML_OUT): $(BLOG_OUT_DIR)/%.html: $(BLOG_SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) $(LUA_FILTER) $(OG_IMAGE_FILTER) $(LISTS_FILTER) $(WRAP_LISTS_FILTER) | $(BLOG_OUT_DIR)
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --section-divs \
	  --lua-filter=$(LUA_FILTER) \
	  --metadata email="$(EMAIL)" \
	  --metadata site-url="$(SITE_URL)" \
	  --metadata pathprefix="../" \
	  --metadata link-citations=false \
	  --lua-filter=$(OG_IMAGE_FILTER) \
	  --lua-filter=$(LISTS_FILTER) \
	  --filter pandoc-crossref \
	  --lua-filter=$(WRAP_LISTS_FILTER) \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Re-pull the vendored CSL from upstream.
# Run `git diff vendor/csl` afterward to review any incoming changes.
update-csl:
	curl -fsSL $(CSL_UPSTREAM_URL) -o $(CSL_DIR)/chicago-notes.csl
	@echo "CSL refreshed from upstream. Review with: git diff $(CSL_DIR)"

.PHONY: clean serve prune-images update-csl csl-autoupdate blog
clean: ; rm -rf $(OUT_DIR)
serve: all
	python3 -m http.server 8000 --bind localhost --directory $(OUT_DIR) & \
	SERVER_PID=$$!; \
	trap "kill $$SERVER_PID 2>/dev/null" EXIT INT TERM; \
	{ find $(SRC_DIR) -name '*.md'; find css -name '*.css'; find templates/ -name '*.html'; find filters/ -name '*.lua'; } | entr $(MAKE) all; \
	kill $$SERVER_PID 2>/dev/null
