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

all: $(HTML_OUT) $(IMAGES_OUT) $(SLIDES_OUT)

$(OUT_DIR)/%.html: $(SRC_DIR)/%.md $(TEMPLATE) $(BIBLIOGRAPHY) $(CSL) | $(OUT_DIR)
	TOC_FLAG=$$(awk 'NR==1 && $$0=="---" {in_yaml=1; next} in_yaml && $$0=="---" {exit} in_yaml && $$0 ~ /^toc:[[:space:]]*true([[:space:]]|$$)/ {print "--toc"; exit}' $<); \
	$(PANDOC) --standalone $$TOC_FLAG --template=$(TEMPLATE) \
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

.PHONY: clean serve
clean: ; rm -rf $(OUT_DIR)
serve: all ; cd $(OUT_DIR) && python3 -m http.server 8000
