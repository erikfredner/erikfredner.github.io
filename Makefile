PANDOC := pandoc
SRC_DIR := src
OUT_DIR := docs
TEMPLATE := templates/base.html
BIBLIOGRAPHY := references.bib
CSL := chicago-notes.csl
CURRENT_YEAR := $(shell date +%Y)

SRC_MD := $(wildcard $(SRC_DIR)/*.md)
HTML_OUT := $(patsubst $(SRC_DIR)/%.md,$(OUT_DIR)/%.html,$(SRC_MD))

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

all: $(HTML_OUT) $(IMAGES_OUT) $(SLIDES_OUT) $(CSS_OUT) $(FONTS_OUT) $(CNAME_OUT) $(NOJEKYLL_OUT)

$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) $(CSS_OUT) | $(OUT_DIR)
	TOC_ARG=$$(grep -m1 '^toc: true' $< > /dev/null 2>&1 && echo '--toc --toc-depth=2' || echo ''); \
	$(PANDOC) --standalone $$TOC_ARG --template=$(TEMPLATE) \
	  --metadata date="$(CURRENT_YEAR)" \
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

.PHONY: clean serve prune-images
clean: ; rm -rf $(OUT_DIR)
serve: all ; cd $(OUT_DIR) && python3 -m http.server 8000
