---
{
    "title": "Configuring",
    "description": "What lives in config.odin, and what deliberately does not."
}
---

ostat is a site-specific generator, not a themeable one. There is no config
file and no template language: a site's identity is one struct, and its layouts
are procedures.

## What is configuration

`src/config.odin` holds `Site_Config`. Replacing the `DEFAULT_SITE` literal
gives you a different site:

```odin
DEFAULT_SITE := Site_Config {
	base_url    = "https://example.com/",
	title       = "Example",
	description = "…",
	author      = "A Name",
	locale      = "en-us",
	brand       = {head = "exam", accent = "ple"},
	contact     = {{"email", "a@example.com", "mailto:a@example.com"}},
	elsewhere   = {{"about", "/about/"}},
	home        = {contact_heading = "Find Me", …},
}
```

`brand` is the site name split where the accent colour starts, written out
rather than derived[^brand]. `portrait` may be left zeroed if there is no
author photo; the home page then omits the image entirely.

[^brand]: It used to be derived, by splitting the title at its first dot. That
    is a rule about one particular domain, and it renders a title like
    "Dr. Foo" as "Dr" plus an accented ". Foo".

URLs are root-relative, so a site is assumed to sit at a domain root rather
than under a path.

## What is code

Three things stay in the source, deliberately.

**The shape of the layouts**, in `render.odin`. The home page has three
sections in a fixed order; a site wanting a fourth edits `write_home`. This is
the trade "layouts are procedures" makes: no template language to learn, no
partials to thread, and a compiler that checks the whole thing — at the cost of
recompiling to move a heading.

**The assets each page links**, in `src/html/head.html`. Favicons, the
manifest, the stylesheet and the font preload are markup, and the file is
`#load`-ed whole into the binary.

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
