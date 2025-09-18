# Website

<fredner.org>

## How to create

```zsh
make
```

This will:

1. Grab all of the `.md` files in `src`
2. Use `pandoc` to convert them to HTML pages, respecting certain `pandoc` YAML options like `toc`
3. Copy HTML, images, and slides to `docs`

## Why do it this way?

- WordPress is slow.
- I already write everything in Pandoc markdown.
- Pandoc handles citations.
- Easier to use GitHub Pages subdomains for projects.
- Pico looks nice.

## Not possible without

- [Pandoc](https://pandoc.org)
- [Pico's Classless CSS](https://picocss.com/docs/classless)
