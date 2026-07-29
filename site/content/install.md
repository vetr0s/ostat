---
{
    "title": "Install",
    "description": "What ostat needs, how to build it, and how to build a site with it."
}
---

ostat needs two things on your machine: the
[Odin compiler](https://odin-lang.org/docs/install/) and `libcmark`, which the
`vendor:commonmark` bindings link against.

```bash
brew install cmark          # macOS
sudo apt install libcmark-dev   # Debian, Ubuntu
```

`build.sh` looks for the library in `/opt/homebrew/lib` and `/usr/local/lib`
and passes the path to the linker[^linker]. On Linux it usually finds nothing,
which is correct: the library is already where the linker looks.

[^linker]: If the link fails with `library not found for -lcmark` on macOS, or
    `cannot find -lcmark` on Linux, cmark is not installed. If it is installed
    somewhere else entirely, add the directory to the loop in `build.sh`.

## Building

```bash
./build.sh          # debug build, into build/debug/ostat
./build.sh release  # optimised
./build.sh test     # every @(test) proc
```

`./dev` builds this documentation site and serves it on port 1313. It needs
`python3` for the server; nothing else does.

```bash
./dev               # build with drafts, serve
./dev --build       # build without drafts, no server
./dev --clean       # discard the output tree first, then serve
```

## Building a site

```
ostat build [site-dir]      build a site into an output directory
ostat new <path>            create a page from the archetype
ostat version               print the version
```

Build options:

| Option | Meaning |
|---|---|
| `-o <dir>` | Output directory. Default `public` |
| `-drafts` | Include pages marked draft |
| `-future` | Include pages dated after today |
| `-today <date>` | Treat this `YYYY-MM-DD` as today, rather than reading the clock |
| `-base-url <url>` | Override the configured base URL |

A site directory holds `content/`, and optionally `static/` which is copied
into the output verbatim.

```text
site/
  content/
    install.md         -> /install/
    blog/
      _index.md        -> /blog/          the section page
      0-1-0.md         -> /blog/0-1-0/
  static/
    css/style.css      -> /css/style.css
```

A file named `_index.md` is its directory's section page. Any other `.md` file
is a regular page. The home page has no file at all: it is the configuration
plus the most recent posts.

Alongside the pages a build writes `sitemap.xml` and two identical feeds,
`/index.xml` and `/blog/index.xml`, so either address works in a reader.
