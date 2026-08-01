---
{
    "title": "Configuring",
    "description": "What lives in site.json, what lives in html/, and what deliberately lives in neither."
}
---

ostat has no template language: a site's layouts are procedures. A site is
configured by two things beside `content/` — a `site.json` holding its
identity, and an `html/` directory holding its documents. One binary builds any
number of sites.

## Identity, in site.json

```json
{
    "base_url": "https://example.com/",
    "title": "Example",
    "description": "…",
    "author": "A Name",
    "locale": "en-us",
    "brand": { "head": "exam", "accent": "ple" }
}
```

Every key is optional. What the file omits keeps its default, at every level,
so a `site.json` naming nothing but `base_url` and `title` is a complete one.
A site with no `site.json` at all still builds, and says in its title that it
is unconfigured.

The defaults live in `DEFAULT_SITE` in `src/config.odin` and describe nobody's
site. They used to be ostat's own, which meant a forgotten key silently
inherited ostat's headings and documentation links.

`brand` is the site name split where the accent colour starts, written out
rather than derived[^brand].

`-base-url` overrides whatever the file says, which is how a staging build gets
a different address without editing the site.

[^brand]: It used to be derived, by splitting the title at its first dot. That
    is a rule about one particular domain, and it renders a title like
    "Dr. Foo" as "Dr" plus an accented ". Foo".

URLs are root-relative, so a site is assumed to sit at a domain root rather
than under a path.

## Documents, in html/

```
html/
  header-01.html      <head>, up to the per-page title
  header-02.html      the rest of it, </head>, <body>
  home.html           the front page
  not-found-404.html  the 404
```

Each is optional and falls back to a built-in default, so a bare content
directory still builds. A site owning `header-02.html` owns its favicons,
stylesheet, fonts and scripts without touching the generator.

The two numbered headers are the two halves of the document head, sandwiching
the only part that varies per page: the title, the description, and the
per-page meta. The doctype and the `<html>` element stay in the generator,
because `lang` comes from `locale` and a fragment able to disagree with
`site.json` would be a second place to say one thing.

`home.html` is written out whole, with one exception. The list of recent posts
is generated, so the fragment says where it goes:

```html
<section id="recent">
  <div class="section-head">
    <h1>Recent</h1>
    <a class="rss-badge" href="/index.xml" title="RSS feed">RSS</a>
  </div>
  <!--ostat:recent-->
</section>
```

A `home.html` without that marker is an error, named at load. The marker owns
its line, so indenting it the way the surrounding markup is indented is fine.

These were four `site.json` fields and three structs, and `write_home` existed
to turn them back into the markup they started as. Adding a fourth section to
the home page meant editing that procedure and recompiling; a paragraph, a
table, or a captioned image had no representation at all. A document is stored
as a document now, so there is no schema to extend.

A fragment is written verbatim, which makes it trusted by construction. That is
a real difference from `site.json`, whose strings are escaped or validated
because a config file is untrusted input. The site author owns the fragment
in a way they do not own an arbitrary config value.

## What is code

Two things stay in the source, deliberately.

**The shape of the remaining layouts**, in `render.odin`: the single page, the
section listing, the breadcrumb. This is the trade "layouts are procedures"
makes: no template language to learn, no partials to thread, and a compiler
that checks the whole thing — at the cost of recompiling to move a heading.

**The class names the generator writes**, in `notes.odin` and
`highlight.odin`. They are a contract with `static/css/style.css` and have to
change together.

## Adding a language

`highlight.odin` holds a table. A lexer is a keyword list and a few
delimiters — it produces only the seven token groups the stylesheet
distinguishes, and is deliberately approximate:

```odin
{
	names = {"python", "py"},
	keywords = {"def", "class", "return", "if", "else"},
	types = {"int", "str", "bytes"},
	builtins = {"len", "print", "range"},
	line_comment = "#",
	quotes = "\"'",
},
```

## Sections

One section is special: the one named by `BLOG_SECTION`, `blog` by default. Its
pages are the only ones that carry a date, appear in the feed, or reach the
home page's recent list. Everything else is a plain section whose pages are
listed alphabetically.
