# Website

[fredner.org](https://fredner.org)

## Dependencies

- [`make`](https://www.gnu.org/software/make/)
- [Pandoc](https://pandoc.org)
- [Pico's Classless CSS](https://picocss.com/docs/classless)
- [Zotero](https://www.zotero.org)
  - [Better BibTeX](https://retorque.re/zotero-better-bibtex/)

## How to create

```zsh
make
```

This will:

1. Take all of the `.md` files in `src`
2. Use `pandoc` to convert them to HTML pages, respecting certain `pandoc` YAML options like `toc`
3. Copy HTML, images, and slides to `docs`

## Why do it this way?

- WordPress is slow.
- I already write everything in Pandoc markdown.
- Pandoc handles citations.
- Easier to use GitHub Pages subdomains for projects.
