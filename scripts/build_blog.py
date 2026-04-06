# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml",
# ]
# ///

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml


def parse_frontmatter(path):
    """Return (frontmatter_dict, body_str) from a markdown file with YAML frontmatter."""
    content = path.read_text(encoding="utf-8")
    if not content.startswith("---"):
        return {}, content
    end = content.find("\n---", 3)
    if end == -1:
        return {}, content
    fm = yaml.safe_load(content[3:end])
    body = content[end + 4:]
    return fm or {}, body


def build_blog(src_dir, build_dir, site_url):
    src_path = Path(src_dir)
    build_path = Path(build_dir)
    build_path.mkdir(parents=True, exist_ok=True)

    posts = []
    for md_file in sorted(src_path.glob("*.md")):
        fm, _ = parse_frontmatter(md_file)
        if fm.get("draft", False):
            continue
        date = fm.get("date")
        if not date:
            print(f"WARNING: {md_file} has no date field, skipping", file=sys.stderr)
            continue
        posts.append({
            "slug": md_file.stem,
            "title": fm.get("title", md_file.stem),
            "date": str(date),
            "description": fm.get("description", ""),
        })

    posts.sort(key=lambda p: p["date"], reverse=True)

    # Blog index markdown
    lines = ["---", 'title: "Blog"', "---", ""]
    if posts:
        for post in posts:
            link = f"blog/{post['slug']}.html"
            lines.append('<div class="post-card">')
            lines.append("")
            lines.append(f"## [{post['title']}]({link})")
            lines.append("")
            if post.get("description"):
                lines.append(post["description"])
                lines.append("")
            lines.append(f'<span class="post-date">{post["date"]}</span>')
            lines.append("")
            lines.append("</div>")
            lines.append("")
    else:
        lines.append("No posts yet.")
    lines.append("")

    (build_path / "blog-index.md").write_text("\n".join(lines), encoding="utf-8")

    # Atom feed
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    entry_parts = []
    for post in posts:
        date_str = post["date"]
        if len(date_str) == 10:  # YYYY-MM-DD → full datetime
            date_str = f"{date_str}T00:00:00Z"
        url = f"{site_url}/blog/{post['slug']}.html"
        summary = (
            f"    <summary>{post['description']}</summary>\n"
            if post.get("description")
            else ""
        )
        entry_parts.append(
            f"  <entry>\n"
            f"    <title>{post['title']}</title>\n"
            f"    <link href=\"{url}\"/>\n"
            f"    <id>{url}</id>\n"
            f"    <updated>{date_str}</updated>\n"
            f"{summary}"
            f"  </entry>"
        )

    feed_content = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<feed xmlns="http://www.w3.org/2005/Atom">\n'
        f"  <title>Erik Fredner</title>\n"
        f'  <link href="{site_url}/feed.xml" rel="self"/>\n'
        f'  <link href="{site_url}/"/>\n'
        f"  <id>{site_url}/feed.xml</id>\n"
        f"  <updated>{now}</updated>\n"
        + ("\n".join(entry_parts) + "\n" if entry_parts else "")
        + "</feed>\n"
    )

    (build_path / "feed.xml").write_text(feed_content, encoding="utf-8")

    print(
        f"Blog: {len(posts)} published post(s). Wrote blog-index.md and feed.xml.",
        file=sys.stderr,
    )


def main():
    parser = argparse.ArgumentParser(description="Generate blog index and Atom feed.")
    parser.add_argument("--src-dir", required=True, help="Directory containing blog post .md files")
    parser.add_argument("--build-dir", required=True, help="Output directory for generated files")
    parser.add_argument("--site-url", required=True, help="Base URL of the site (no trailing slash)")
    args = parser.parse_args()
    build_blog(args.src_dir, args.build_dir, args.site_url)


if __name__ == "__main__":
    main()
