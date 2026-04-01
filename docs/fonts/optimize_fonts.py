# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools[woff]", "brotli"]
# ///

from pathlib import Path
from fontTools import subset as ft_subset

FONTS_DIR = Path(__file__).parent

# Broad Latin coverage for an academic English site
UNICODES = (
    list(range(0x0020, 0x007F))    # Basic Latin
    + list(range(0x00A0, 0x0180))  # Latin-1 Supplement + Latin Extended-A
    + list(range(0x0180, 0x0250))  # Latin Extended-B
    + list(range(0x0250, 0x02B0))  # IPA Extensions
    + list(range(0x02B0, 0x0300))  # Spacing Modifiers
    + list(range(0x0300, 0x0370))  # Combining Diacritical Marks
    + list(range(0x2000, 0x206F))  # General Punctuation
    + list(range(0xFB00, 0xFB07))  # Alphabetic Presentation Forms (ligatures)
)

FILES = [
    ("EBGaramond-VariableFont_wght.ttf",        "EBGaramond-Regular.woff2"),
    ("EBGaramond-Italic-VariableFont_wght.ttf", "EBGaramond-Italic.woff2"),
]

for ttf_name, woff2_name in FILES:
    ttf_path = FONTS_DIR / ttf_name
    woff2_path = FONTS_DIR / woff2_name

    before = ttf_path.stat().st_size

    options = ft_subset.Options()
    options.flavor = "woff2"
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.retain_gids = False

    font = ft_subset.load_font(str(ttf_path), options)
    subsetter = ft_subset.Subsetter(options=options)
    subsetter.populate(unicodes=UNICODES)
    subsetter.subset(font)
    ft_subset.save_font(font, str(woff2_path), options)

    after = woff2_path.stat().st_size
    pct = (1 - after / before) * 100
    print(f"{ttf_name}")
    print(f"  {before / 1024:.1f} KB  →  {after / 1024:.1f} KB  ({pct:.1f}% smaller)")
    print(f"  → {woff2_path.name}")
    print()
