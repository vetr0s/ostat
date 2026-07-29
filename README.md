# ostat

A static site generator written in [Odin](https://odin-lang.org/), modeled
after the generator behind
[gingerBill.org](https://github.com/gingerBill/gingerBill.org).

There is no template language. Every layout is a procedure that writes HTML.
There is no config file, no theme system, and no plugin API. It builds one
site's shape, and that shape lives in `src/render.odin`.

The site in `site/` is ostat's own documentation, and building it is how the
generator proves it works.

## Requirements

- [Odin](https://odin-lang.org/docs/install/) on your `PATH`
- `libcmark`, which `vendor:commonmark` links against
- `python3`, only for `./dev`'s local server

```sh
brew install cmark              # macOS
sudo apt install libcmark-dev   # Debian, Ubuntu
```

`build.sh` looks for the library in `/opt/homebrew/lib` and `/usr/local/lib`
and passes the path to the linker. On Linux it usually finds nothing, which is
correct: the library is already somewhere the linker looks. If the link fails —
`library not found for -lcmark` on macOS, `cannot find -lcmark` on Linux —
cmark is not installed, or is somewhere neither of those paths covers.

## Quick start

```sh
./build.sh            # debug build, into build/debug/ostat
./build.sh release    # optimised, into build/release/ostat
./build.sh test       # every @(test) proc

./dev                 # build the docs with drafts, serve on :1313
./dev --build         # release build, no drafts, no server
```

## Usage

```
ostat build [site-dir]      build a site into an output directory
ostat new <path> [-s dir]   create a page from the archetype
ostat version               print the version
```

Build options:

| Option | Meaning |
| --- | --- |
| `-o <dir>` | Output directory. Default `public` |
| `-drafts` | Include pages marked draft |
| `-future` | Include pages dated after today |
| `-today <date>` | Treat this `YYYY-MM-DD` as today, rather than reading the clock |
| `-base-url <url>` | Override the configured base URL |

A site directory holds `content/`, and optionally `static/`, which is copied
into the output verbatim.

```
site/
  content/
    install.md        -> /install/
    blog/
      _index.md       -> /blog/         the section page
      0-1-0.md        -> /blog/0-1-0/
  static/
    css/style.css     -> /css/style.css
```

A file named `_index.md` is its directory's section page. Any other `.md` file
is a regular page. The home page has no file: it is the configuration plus the
most recent posts.

A build also writes `sitemap.xml` and two feeds, `/index.xml` and
`/blog/index.xml`, which carry the same items and differ only in the two URLs
naming the feed itself, so either address works in a reader.

## Content format

Front matter is a `---` fence around JSON. `core:encoding/json` parses it in
JSON5 mode, so comments, trailing commas and unquoted keys are all accepted,
though the documentation site sticks to plain JSON.

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

`title` is required. `date` must be `YYYY-MM-DD`, and is required for any page
in the posts section. A `slug` may not contain a path separator, `..`, or
whitespace, because it becomes a directory name.

### Margin notes

An aside is a margin note, written where the claim is:

```markdown
Prose making a claim[^why] that wants qualifying.

[^why]: The qualification, which may carry *markdown* and [links](/x/).
```

Definitions may sit anywhere in the file and continue onto indented lines. The
generator writes no numbers: the count comes from a CSS counter, so a note's
number is the stylesheet's business.

An unresolved marker is left as prose, because `[^` is ordinary text far more
often than it is a note — a POSIX class like `[^a-z]` should not be one. A
mistyped label is caught from the other side: the definition it was meant to
reach goes unreferenced, and that fails the build.

The feed has no margin, so each post is rendered a second time there with its
notes as numbered endnotes and every anchor absolute.

### Markdown

CommonMark, via cmark, plus three things cmark does not do:

| Feature | Where it comes from |
| --- | --- |
| Tables | `src/gfm.odin`, rewritten before cmark runs |
| `~~strikethrough~~` | The same pass |
| Syntax highlighting | `src/highlight.odin`, emitting Chroma class names |

Raw HTML passes through, so a `<figure>` in a post renders as one.

Highlighting covers `odin`, `zig`, and `bash` (also `sh`, `shell`, `zsh`).
Anything else renders escaped and uncoloured. It is a keyword table and a
scanner, not a parser, and produces only the seven token groups the stylesheet
distinguishes.

## Configuring it

`src/config.odin` holds `Site_Config`: title, base URL, author, the brand
split, and the home page's links and headings. Replacing the `DEFAULT_SITE`
literal gives a different site.

Three things stay in the source deliberately: the shape of the layouts, in
`render.odin`; the assets each page links, in `src/html/head.html`; and the CSS
class names the generator writes, which pair with `site/static/css/style.css`.
The comment at the top of `config.odin` is the authoritative map.

## Layout

```
build.sh              build, test, and the cmark linker flag
dev                   build the documentation site and serve it
src/
  main.odin           CLI, arenas, the Website struct
  config.odin         Site_Config
  content.odin        discovery and the page model
  frontmatter.odin    the --- fenced JSON block
  archetype.odin      ostat new
  markdown.odin       cmark, and the pass that runs before it
  notes.odin          margin notes
  gfm.odin            tables and strikethrough
  highlight.odin      syntax highlighting
  render.odin         every layout, as a procedure
  feed.odin           RSS
  sitemap.odin        sitemap.xml
  text.odin           escaping, dates, truncation
  html/               static chunks, pulled in with #load
  *_test.odin         unit tests, beside what they test
site/                 ostat's documentation, and the demo site
tests/
  fixture-site/       a site exercising every path
  golden/             its expected output, committed
docs/                 audit reports
```

## Tests

```sh
./build.sh test
```

Unit tests live beside the code they test, because Odin scopes `@(private)` to
a package and a package is a directory: tests in a separate directory could
only reach the exported API.

`tests/` holds a fixture site and a committed tree of its expected output. The
generator is a pure function from content, configuration and today's date to a
file tree, so the whole program can be pinned by comparing documents. After an
intended change, regenerate and read the diff before committing it:

```sh
./build.sh && rm -rf tests/golden && \
  ./build/debug/ostat build tests/fixture-site -o tests/golden \
    -today 2026-01-01 -base-url https://example.test/
```

## Versions

Built and verified against:

| | |
| --- | --- |
| Odin | `dev-2026-07:301c287de` |
| cmark | 0.31.2 on macOS, 0.30.x on Ubuntu |

The `vendor:commonmark` bindings declare 0.30.2. Only four entry points are
used and they are unchanged across that range; CI builds on both.

## License

Unlicense. See `LICENSE`.
