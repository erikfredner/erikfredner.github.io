PANDOC := pandoc
SRC_DIR := src
OUT_DIR := docs
TEMPLATE := templates/base.html
BIBLIOGRAPHY := references.bib
CSL := chicago-notes.csl
CURRENT_YEAR := $(shell date +%Y)
BUILD_DATE := $(shell date +%Y-%m-%d)
EMAIL := erik.fredner@oregonstate.edu

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
IMG_SRC := $(wildcard $(IMG_SRC_DIR)/*)
IMAGES_OUT := $(patsubst $(IMG_SRC_DIR)/%,$(IMG_OUT_DIR)/%,$(IMG_SRC))

# Slide decks
SLIDES_SRC_DIR := slides
SLIDES_OUT_DIR := $(OUT_DIR)/slides
SLIDES_SRC := $(wildcard $(SLIDES_SRC_DIR)/*.html)
SLIDES_OUT := $(patsubst $(SLIDES_SRC_DIR)/%,$(SLIDES_OUT_DIR)/%,$(SLIDES_SRC))

# CSS
CSS_SRC := style.css
CSS_OUT := $(OUT_DIR)/style.css

# Fonts
FONTS_SRC_DIR := fonts
FONTS_OUT_DIR := $(OUT_DIR)/fonts
FONTS_SRC := $(wildcard $(FONTS_SRC_DIR)/*)
FONTS_OUT := $(patsubst $(FONTS_SRC_DIR)/%,$(FONTS_OUT_DIR)/%,$(FONTS_SRC))

# GitHub Pages config files
CNAME_SRC := CNAME
CNAME_OUT := $(OUT_DIR)/CNAME
NOJEKYLL_OUT := $(OUT_DIR)/.nojekyll

all: $(HTML_OUT) $(IMAGES_OUT) $(SLIDES_OUT) $(CSS_OUT) $(FONTS_OUT) $(CNAME_OUT) $(NOJEKYLL_OUT) blog
	rm -f $(FONTS_OUT_DIR)/*.ttf $(FONTS_OUT_DIR)/*.py

$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) | $(OUT_DIR)
	TOC_ARG=$$(grep -m1 '^toc: true' $< > /dev/null 2>&1 && echo '--toc' || echo ''); \
	$(PANDOC) --standalone $$TOC_ARG --defaults=defaults/toc-defaults.yaml --template=$(TEMPLATE) \
	  --metadata date="$(CURRENT_YEAR)" \
	  --metadata build-date="$(BUILD_DATE)" \
	  --metadata email="$(EMAIL)" \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  -o $@ $<

# Ensure base output dir exists
$(OUT_DIR):
	mkdir -p $(OUT_DIR)

# Image output dir
$(IMG_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(IMG_OUT_DIR)

# Copy each image (pattern rule)
$(IMG_OUT_DIR)/%: $(IMG_SRC_DIR)/% | $(IMG_OUT_DIR)
	cp $< $@

# Slide output dir
$(SLIDES_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(SLIDES_OUT_DIR)

# Copy each slide deck
$(SLIDES_OUT_DIR)/%: $(SLIDES_SRC_DIR)/% | $(SLIDES_OUT_DIR)
	cp $< $@

# Copy CSS
$(CSS_OUT): $(CSS_SRC) | $(OUT_DIR)
	cp $< $@

# Font output dir
$(FONTS_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(FONTS_OUT_DIR)

# Copy each font
$(FONTS_OUT_DIR)/%: $(FONTS_SRC_DIR)/% | $(FONTS_OUT_DIR)
	cp $< $@

# Copy CNAME for GitHub Pages custom domain
$(CNAME_OUT): $(CNAME_SRC) | $(OUT_DIR)
	cp $< $@

# Create .nojekyll to disable Jekyll processing
$(NOJEKYLL_OUT): | $(OUT_DIR)
	touch $@

# Delete images in src/images/ that are not referenced in any src/*.md
prune-images:
	@for img in $(IMG_SRC_DIR)/*; do \
	  name=$$(basename $$img); \
	  if ! grep -qr "images/$$name" $(SRC_DIR)/*.md; then \
	    echo "Removing unused image: $$img"; \
	    rm "$$img"; \
	  fi; \
	done

# Blog targets
blog: $(BLOG_INDEX_HTML) $(FEED_OUT) $(BLOG_HTML_OUT)

$(BLOG_INDEX_MD): $(BLOG_SRC_MD) $(BLOG_SCRIPT) | $(BUILD_DIR)
	uv run $(BLOG_SCRIPT) --src-dir $(BLOG_SRC_DIR) --build-dir $(BUILD_DIR) --site-url $(SITE_URL)

$(BLOG_INDEX_HTML): $(BLOG_INDEX_MD) $(TEMPLATE) | $(OUT_DIR)
	$(PANDOC) --standalone --template=$(TEMPLATE) \
	  --metadata build-date="$(BUILD_DATE)" \
	  --metadata email="$(EMAIL)" \
	  -o $@ $<

$(FEED_OUT): $(BLOG_INDEX_MD) | $(OUT_DIR)
	cp $(BLOG_FEED_XML) $@

$(BLOG_OUT_DIR): | $(OUT_DIR)
	mkdir -p $(BLOG_OUT_DIR)

# Static pattern rule: explicit targets prevent ambiguity with the generic docs/%.html rule
$(BLOG_HTML_OUT): $(BLOG_OUT_DIR)/%.html: $(BLOG_SRC_DIR)/%.md $(POST_TEMPLATE) | $(BLOG_OUT_DIR)
	$(PANDOC) --standalone --template=$(POST_TEMPLATE) \
	  --metadata build-date="$(BUILD_DATE)" \
	  --metadata email="$(EMAIL)" \
	  --citeproc --bibliography=$(BIBLIOGRAPHY) --csl=$(CSL) \
	  -o $@ $<

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

.PHONY: clean serve prune-images blog
clean: ; rm -rf $(OUT_DIR)
serve: all ; cd $(OUT_DIR) && python3 -m http.server 8000
