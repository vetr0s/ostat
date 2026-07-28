# ostat

A static site generator written in [Odin](https://odin-lang.org/), built for
[vetr0s.dev](https://vetr0s.dev) and modeled after the generator behind
[gingerBill.org](https://github.com/gingerBill/gingerBill.org).

There is no template language. Every layout is a procedure that writes HTML.
There is no theme system, no config file, and no plugin API. It renders one
site's shape, and that shape lives in `src/render.odin`.

## Requirements

- [Odin](https://odin-lang.org/docs/install/) on your `PATH`
- `libcmark`, which `vendor:commonmark` links against

```sh
brew install cmark          # macOS
apt install libcmark-dev    # Debian, Ubuntu
```

`build.sh` finds the library in `/opt/homebrew/lib` or `/usr/local/lib` and
passes the path to the linker. If you see `library not found for -lcmark`,
cmark is not installed.

## Quick start

```sh
./build.sh          # debug build
./dev               # build the example site with drafts, serve on :1313
./dev --build       # production build into public/
./build.sh test     # run every @(test) proc
```

## Usage

```
ostat build [site-dir]      build a site into an output directory
ostat new <path>            create a page from the archetype
ostat version               print the version

build options:
    -o <dir>          output directory (default: public)
    -drafts           include pages marked draft
    -future           include pages dated after today
    -base-url <url>   override the configured base URL
```

A site directory holds `content/` and, optionally, `static/`. Everything in
`static/` is copied into the output verbatim.

```
site/
  content/
    about.md            -> /about/
    colophon.md         -> /colophon/
    blog/
      _index.md         -> /blog/         the section page
      kitchen-sink.md   -> /blog/kitchen-sink/
  static/
    css/style.css       -> /css/style.css
```

A file named `_index.md` is its directory's section page. Any other `.md` file
is a regular page. The home page has no file: it is the config plus the most
recent posts.

Alongside the pages, a build writes `sitemap.xml` and two identical feeds,
`/index.xml` and `/blog/index.xml`, so either address works in a reader.

## Content format

Front matter is a `---` fence around literal JSON.

```markdown
---
{
    "title": "Kitchen Sink",
    "date": "2026-07-12",
    "description": "Optional. Falls back to the opening paragraph.",
    "draft": false,
    "slug": "optional-override"
}
---

The post starts here.
```

`title` is required. `date` must be `YYYY-MM-DD` and is required for anything
that should appear in the feed.

### Margin notes

An aside is a margin note, written where the claim is:

```markdown
Prose making a claim[^why] that wants qualifying.

[^why]: The qualification, which may carry *markdown* and [links](/x/).
```

Definitions may sit anywhere in the file and continue onto indented lines. The
generator writes no numbers: the count comes from a CSS counter, so a note's
number is the stylesheet's business. A marker with no definition, or a
definition nobody references, fails the build.

The feed has no margin, so each post is rendered a second time there with its
notes as numbered endnotes and every anchor absolute.

### Markdown

CommonMark, via cmark, plus three things cmark does not do:

| Feature | Where it comes from |
|---|---|
| Tables | Rewritten to HTML before cmark runs |
| `~~strikethrough~~` | The same pass |
| Syntax highlighting | `src/highlight.odin`, emitting Chroma class names |

Raw HTML passes through, so a `<figure>` in a post renders as one.

Highlighting covers `odin`, `zig`, and `bash`. Anything else renders escaped
and uncoloured. It is a keyword table and a scanner, not a parser, and it
produces only the seven token groups the stylesheet distinguishes.

## Configuring it

`src/config.odin` holds everything `hugo.toml` used to: the title, base URL,
author, and the two lists the home page renders. It is one struct. Making ostat
configurable would mean writing a loader that fills a `Site_Config`, not
rewriting its callers.

## Layout

```
build.sh              build, test, and the cmark linker flag
dev                   build the example site and serve it
src/
  main.odin           CLI, arenas, the Website struct
  config.odin         Site_Config
  content.odin        discovery and the page model
  frontmatter.odin    the --- fenced JSON block
  markdown.odin       cmark, and the pass that runs before it
  notes.odin          margin notes
  gfm.odin            tables and strikethrough
  highlight.odin      syntax highlighting
  render.odin         every layout, as a procedure
  feed.odin           RSS
  sitemap.odin        sitemap.xml
  text.odin           escaping, dates, truncation
  html/               static chunks, pulled in with #load
site/                 the example site
```

## Versions

Built and verified against:

| | |
| --- | --- |
| Odin | `dev-2026-07:301c287de` |
| cmark | 0.31.2 |

The `vendor:commonmark` bindings declare 0.30.2. Only the four entry points
used here are touched, and they have not changed across that range.

## License

Unlicense. See `LICENSE`.
