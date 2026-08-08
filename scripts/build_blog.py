# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyyaml",
# ]
# ///
"""Generate the blog index, per-post pandoc metadata, tag pages, and the Atom feed.

Runs in two stages, because the feed embeds each post's rendered HTML and that
HTML does not exist until pandoc has run:

  --stage meta   resolve timestamps, write build/blog-index.md, build/meta/*.yaml,
                 build/tags/*.md, build/tags-index.md, and build/posts.json
  --stage feed   read build/posts.json plus the fragments pandoc produced from it,
                 write build/feed.xml

Publication and modification timestamps are not typed by hand. They live in a
committed manifest (src/blog/timestamps.json) keyed by slug. A post is stamped
`published` the first time it is built without `draft: true`, and `updated`
whenever the SHA-256 of its source changes. A `date:` in frontmatter, when
present, overrides `published` — which is what makes deliberately back-dated and
future-dated posts (an announcement dated to the event it announces) possible.

Deriving these from `git log` instead was tried and does not work: posts get
committed days after they are written, event-dated posts are committed before
their date, and two posts added in one commit collapse to a single timestamp,
which destroys the sort key.
"""

import argparse
import hashlib
import json
import re
import sys
from datetime import date, datetime
from pathlib import Path
from xml.sax.saxutils import escape, quoteattr

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


def write_if_changed(path, text):
    """Write only when the content differs.

    Make decides what to rebuild from mtimes, and this script runs on every
    build (its rule watches src/blog/ itself, so that deleting a post is
    noticed). Rewriting unchanged files would touch their mtimes and cascade a
    full pandoc rebuild every time.
    """
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return
    path.write_text(text, encoding="utf-8")


def slugify(value):
    """Lowercase, non-alphanumeric runs to single hyphens. Used for tag URLs."""
    slug = re.sub(r"[^a-z0-9]+", "-", str(value).strip().lower()).strip("-")
    return slug or "tag"


def local_tz():
    return datetime.now().astimezone().tzinfo


def as_datetime(value, tz):
    """Coerce a frontmatter `date:` to an aware datetime.

    PyYAML already turns `2026-06-19` into a date and `2026-06-19T10:00:00` into
    a datetime; a quoted value arrives as a string. A bare date means midnight
    local.
    """
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=tz)
    if isinstance(value, date):
        return datetime(value.year, value.month, value.day, tzinfo=tz)
    parsed = datetime.fromisoformat(str(value).strip())
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=tz)


def iso(dt):
    return dt.isoformat(timespec="seconds")


def display(dt):
    # Not strftime("%-d"): the no-pad flag is a glibc/BSD extension, not portable.
    return f"{dt:%B} {dt.day}, {dt.year}"


# ---------------------------------------------------------------- stage: meta


def load_manifest(path):
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def save_manifest(path, manifest):
    # Sorted keys and a trailing newline so the file is byte-stable across builds.
    write_if_changed(path, json.dumps(manifest, indent=2, sort_keys=True) + "\n")


def resolve_posts(src_path, manifest, now, tz):
    """Stamp timestamps into `manifest` (mutated) and return the published posts."""
    posts = []
    seen = set()

    for md_file in sorted(src_path.glob("*.md")):
        fm, _ = parse_frontmatter(md_file)
        if fm.get("draft", False):
            continue

        slug = md_file.stem
        seen.add(slug)
        digest = "sha256:" + hashlib.sha256(md_file.read_bytes()).hexdigest()

        entry = manifest.get(slug)
        if entry is None:
            entry = {"published": iso(now), "updated": iso(now), "hash": digest}
        elif entry.get("hash") != digest:
            entry = {**entry, "updated": iso(now), "hash": digest}

        if fm.get("date") is not None:
            entry["published"] = iso(as_datetime(fm["date"], tz))

        published = as_datetime(entry["published"], tz)
        updated = as_datetime(entry["updated"], tz)
        if updated < published:
            # An event-dated post must never advertise a revision predating it.
            updated = published
            entry["updated"] = iso(updated)

        manifest[slug] = entry

        raw_tags = fm.get("tags") or []
        if isinstance(raw_tags, str):
            raw_tags = [raw_tags]

        posts.append({
            "slug": slug,
            "title": fm.get("title", slug),
            "description": fm.get("description", ""),
            "published": iso(published),
            "updated": iso(updated),
            "published_display": display(published),
            "updated_display": display(updated),
            "show_updated": updated.date() > published.date(),
            "tags": [{"name": str(t).strip(), "slug": slugify(t)} for t in raw_tags],
            "_sort": published,
        })

    for stale in set(manifest) - seen:
        del manifest[stale]

    posts.sort(key=lambda p: (p["_sort"], p["slug"]), reverse=True)
    for post in posts:
        del post["_sort"]
    return posts


def collect_tags(posts):
    """Map tag slug -> {name, posts}. First spelling seen wins the display name."""
    tags = {}
    for post in posts:
        for tag in post["tags"]:
            bucket = tags.setdefault(tag["slug"], {"name": tag["name"], "posts": []})
            bucket["posts"].append(post)
    return dict(sorted(tags.items(), key=lambda kv: kv[1]["name"].lower()))


def post_card(post, post_prefix, tag_prefix):
    """Emit one .post-card as raw HTML with markdown inside, blank-line separated
    so pandoc still parses the heading and description as markdown."""
    lines = [
        '<div class="post-card">',
        "",
        # The date reads as a label above the title rather than a trailing
        # footnote. Emitted as its own <p> (not a <span> inside one) so the
        # .post-date margin rule in style.css applies to the block itself.
        f'<p class="post-date">{post["published_display"]}</p>',
        "",
        f'## [{post["title"]}]({post_prefix}{post["slug"]}.html)',
        "",
    ]
    if post["description"]:
        lines += [post["description"], ""]
    if post["tags"]:
        links = " ".join(
            f'<a href="{tag_prefix}{t["slug"]}.html">{escape(t["name"])}</a>'
            for t in post["tags"]
        )
        lines += [f'<p class="tag-list">{links}</p>', ""]
    lines += ["</div>", ""]
    return lines


def write_page(path, title, body):
    """Write a generated markdown page: YAML frontmatter carrying `title`, then
    `body` lines.

    The title goes through json.dumps rather than being interpolated into a
    quoted literal. A JSON string is also a valid YAML double-quoted scalar, so
    this costs nothing and closes an injection hole: tag names come from post
    frontmatter, and one containing a double quote would otherwise produce a
    file pandoc cannot parse.
    """
    write_if_changed(path, "\n".join(["---", f"title: {json.dumps(title)}", "---", ""] + body))


def write_index(build_path, posts, has_tags):
    body = []
    if posts:
        for post in posts:
            body += post_card(post, "blog/", "tags/")
    else:
        body.append("No posts yet.")
    body.append("")
    # The feed is otherwise discoverable only via <link rel="alternate">.
    subscribe = '<a href="feed.xml">Subscribe via Atom</a>'
    browse = ' &middot; <a href="tags.html">Browse by tag</a>' if has_tags else ""
    body.append(f'<p class="feed-link">{subscribe}{browse}</p>')
    body.append("")
    write_page(build_path / "blog-index.md", "Blog", body)


def write_meta(build_path, posts, site_url):
    """One pandoc --metadata-file per post.

    Keys are deliberately named `published` / `tag-links` rather than `date` /
    `tags`: pandoc ranks document frontmatter above --metadata-file, so reusing
    the frontmatter's own key names would let the post shadow these values.
    """
    meta_dir = build_path / "meta"
    meta_dir.mkdir(parents=True, exist_ok=True)
    keep = {f"{post['slug']}.yaml" for post in posts}
    for stale in meta_dir.glob("*.yaml"):
        if stale.name not in keep:
            stale.unlink()

    for i, post in enumerate(posts):
        meta = {
            "published": post["published"],
            "published-display": post["published_display"],
            "updated": post["updated"],
            "updated-display": post["updated_display"],
            "canonical": f"{site_url}/blog/{post['slug']}.html",
        }
        if post["show_updated"]:
            meta["show-updated"] = True
        if post["tags"]:
            meta["tag-links"] = [
                {"name": t["name"], "url": f"../tags/{t['slug']}.html"} for t in post["tags"]
            ]
        # Posts are newest-first, so the preceding entry is the newer one.
        if i > 0:
            meta["next-url"] = f"{posts[i - 1]['slug']}.html"
            meta["next-title"] = posts[i - 1]["title"]
        if i + 1 < len(posts):
            meta["prev-url"] = f"{posts[i + 1]['slug']}.html"
            meta["prev-title"] = posts[i + 1]["title"]
        # Pandoc templates have no `or`, so the presence test is precomputed.
        if len(posts) > 1:
            meta["has-post-nav"] = True

        write_if_changed(
            meta_dir / f"{post['slug']}.yaml",
            yaml.safe_dump(meta, allow_unicode=True, sort_keys=True),
        )


def write_tag_pages(build_path, tags):
    tags_dir = build_path / "tags"
    keep = {f"{slug}.md" for slug in tags}
    if tags_dir.exists():
        for stale in tags_dir.glob("*.md"):
            if stale.name not in keep:
                stale.unlink()
    if not tags:
        (build_path / "tags-index.md").unlink(missing_ok=True)
        return

    tags_dir.mkdir(parents=True, exist_ok=True)
    for slug, bucket in tags.items():
        body = []
        for post in bucket["posts"]:
            body += post_card(post, "../blog/", "")
        body += ["", '<p class="feed-link"><a href="../blog.html">All posts</a></p>', ""]
        write_page(tags_dir / f"{slug}.md", f"Tagged: {bucket['name']}", body)

    body = ['<ul class="tag-index">']
    for slug, bucket in tags.items():
        count = len(bucket["posts"])
        body.append(
            f'<li><a href="tags/{slug}.html">{escape(bucket["name"])}</a> '
            f'<span class="tag-count">{count}</span></li>'
        )
    body += ["</ul>", "", '<p class="feed-link"><a href="blog.html">All posts</a></p>', ""]
    write_page(build_path / "tags-index.md", "Tags", body)


def stage_meta(src_path, build_path, manifest_path, site_url):
    tz = local_tz()
    now = datetime.now(tz).replace(microsecond=0)

    manifest = load_manifest(manifest_path)
    posts = resolve_posts(src_path, manifest, now, tz)
    save_manifest(manifest_path, manifest)

    tags = collect_tags(posts)
    write_index(build_path, posts, bool(tags))
    write_meta(build_path, posts, site_url)
    write_tag_pages(build_path, tags)

    write_if_changed(build_path / "posts.json", json.dumps(posts, indent=2) + "\n")

    print(
        f"Blog: {len(posts)} published post(s), {len(tags)} tag(s). "
        f"Wrote blog-index.md, meta/, tags/, posts.json.",
        file=sys.stderr,
    )


# ---------------------------------------------------------------- stage: feed


def stage_feed(build_path, site_url, author):
    posts = json.loads((build_path / "posts.json").read_text(encoding="utf-8"))
    fragment_dir = build_path / "feed"

    entries = []
    for post in posts:
        url = f"{site_url}/blog/{post['slug']}.html"
        parts = [
            "  <entry>",
            f"    <title>{escape(post['title'])}</title>",
            f"    <link href={quoteattr(url)}/>",
            f"    <id>{escape(url)}</id>",
            f"    <published>{escape(post['published'])}</published>",
            f"    <updated>{escape(post['updated'])}</updated>",
        ]
        for tag in post["tags"]:
            parts.append(f"    <category term={quoteattr(tag['name'])}/>")
        if post["description"]:
            parts.append(f"    <summary>{escape(post['description'])}</summary>")
        fragment = fragment_dir / f"{post['slug']}.html"
        if fragment.exists():
            body = fragment.read_text(encoding="utf-8").strip()
            if body:
                # filters/absolutize.lua handles authored links and images, but
                # footnote back-references are synthesized by pandoc's HTML
                # writer after every filter has run, so `#fn1` survives it and
                # would resolve against whatever page the reader is on.
                body = re.sub(r'(href=")#', rf'\g<1>{url}#', body)
                parts.append(f'    <content type="html">{escape(body)}</content>')
        parts.append("  </entry>")
        entries.append("\n".join(parts))

    # Newest entry timestamp, not wall-clock time: stamping the build time here
    # made docs/feed.xml dirty after every `make` even with no content change.
    updated = max((p["updated"] for p in posts), default=None)
    if updated is None:
        updated = iso(datetime.now(local_tz()).replace(microsecond=0))

    feed = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<feed xmlns="http://www.w3.org/2005/Atom">\n'
        f"  <title>{escape(author)}</title>\n"
        f'  <link href={quoteattr(f"{site_url}/feed.xml")} rel="self"/>\n'
        f'  <link href={quoteattr(f"{site_url}/")}/>\n'
        f"  <id>{escape(site_url)}/feed.xml</id>\n"
        f"  <updated>{escape(updated)}</updated>\n"
        f"  <author>\n    <name>{escape(author)}</name>\n  </author>\n"
        + ("\n".join(entries) + "\n" if entries else "")
        + "</feed>\n"
    )

    write_if_changed(build_path / "feed.xml", feed)
    print(f"Blog: wrote feed.xml with {len(entries)} entr(ies).", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Generate blog index, metadata, and Atom feed.")
    parser.add_argument("--stage", choices=["meta", "feed"], required=True)
    parser.add_argument("--src-dir", help="Directory containing blog post .md files")
    parser.add_argument("--build-dir", required=True, help="Output directory for generated files")
    parser.add_argument("--site-url", required=True, help="Base URL of the site (no trailing slash)")
    parser.add_argument("--manifest", help="Path to the committed timestamps.json")
    parser.add_argument("--author", default="Erik Fredner", help="Feed author name")
    args = parser.parse_args()

    build_path = Path(args.build_dir)
    build_path.mkdir(parents=True, exist_ok=True)

    if args.stage == "meta":
        if not args.src_dir or not args.manifest:
            parser.error("--stage meta requires --src-dir and --manifest")
        stage_meta(Path(args.src_dir), build_path, Path(args.manifest), args.site_url)
    else:
        stage_feed(build_path, args.site_url, args.author)


if __name__ == "__main__":
    main()
