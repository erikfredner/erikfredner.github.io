# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Write docs/sitemap.xml by walking the built HTML.

Runs last in the build, once every page exists. `<lastmod>` is emitted only for
blog posts, where src/blog/timestamps.json gives a real modification date; for
the static pages there is no honest source for it (the whole site is regenerated
on nearly every commit, so file and git dates both mean "last rebuild"), and an
absent lastmod is better than a misleading one.
"""

import argparse
import json
from pathlib import Path
from xml.sax.saxutils import escape

# GitHub Pages serves 404.html for any unmatched path; it is not a real page.
EXCLUDE = {"404.html"}


def collect(out_dir, site_url, manifest):
    urls = []

    for path in sorted(out_dir.glob("*.html")):
        if path.name in EXCLUDE:
            continue
        loc = f"{site_url}/" if path.name == "index.html" else f"{site_url}/{path.name}"
        urls.append((loc, None))

    for path in sorted((out_dir / "blog").glob("*.html")):
        entry = manifest.get(path.stem, {})
        urls.append((f"{site_url}/blog/{path.name}", entry.get("updated")))

    for path in sorted((out_dir / "tags").glob("*.html")):
        urls.append((f"{site_url}/tags/{path.name}", None))

    return urls


def main():
    parser = argparse.ArgumentParser(description="Generate sitemap.xml from built HTML.")
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--site-url", required=True)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    site_url = args.site_url.rstrip("/")

    manifest_path = Path(args.manifest)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}

    urls = collect(out_dir, site_url, manifest)

    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for loc, lastmod in urls:
        lines.append("  <url>")
        lines.append(f"    <loc>{escape(loc)}</loc>")
        if lastmod:
            lines.append(f"    <lastmod>{escape(lastmod)}</lastmod>")
        lines.append("  </url>")
    lines.append("</urlset>")

    (out_dir / "sitemap.xml").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Sitemap: {len(urls)} URL(s).")


if __name__ == "__main__":
    main()
