# ostat

**Archived.** ostat built [vetr0s.dev](https://vetr0s.dev/) until August 2026.
That site now uses pandoc. Nothing runs ostat and I do not maintain it.

I retired it because every layout was compiled into the program. Moving a
heading required a rebuild of the generator. That trade stopped making sense
once the generator had more code than the site it built.

The final version remains here. I would not choose it for a new site.

## What it is

ostat is a static site generator written in [Odin](https://odin-lang.org/). It
was modeled after the generator behind
[gingerBill.org](https://github.com/gingerBill/gingerBill.org).

There is no template language, theme system, or plugin API. Layouts are Odin
procedures that write HTML. A site can set its identity in `site.json`, but its
page shapes live in `src/render.odin`.

The `site/` directory contains ostat's documentation and demo site. Its former
documentation domain no longer resolves. Build it locally to read it.

## Requirements

- [Odin](https://odin-lang.org/docs/install/) on your `PATH`
- `libcmark`
- `python3` for the local development server

```sh
brew install cmark              # macOS
sudo apt install libcmark-dev   # Debian or Ubuntu
```

## Build and use

```sh
./build.sh            # debug build
./build.sh release    # release build
./build.sh test       # run every @(test) proc
./dev.sh              # build and serve the documentation on port 1313

ostat build [site-dir]
ostat new <path> [-s dir]
ostat version
```

A site directory contains `content/` and may contain `static/`, `html/`, and
`site.json`. Builds also write `sitemap.xml` and RSS feeds.

Front matter is JSON inside a `---` fence. The parser accepts JSON5 syntax.
Markdown is CommonMark with tables, strikethrough, and syntax highlighting.

## Versions

| Dependency | Version |
| --- | --- |
| Odin | `dev-2026-07:301c287de` |
| cmark | 0.31.2 on macOS and 0.30.x on Ubuntu |

## License

Unlicense. See `LICENSE`.
