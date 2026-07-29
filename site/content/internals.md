---
{
    "title": "Internals",
    "description": "The pipeline, and why the interesting part is what happens before cmark."
}
---

A build is four passes over one arena pair: discover, preprocess, render,
write.

| File | Does |
|---|---|
| `content.odin` | Walks `content/`, parses front matter, builds the page list |
| `markdown.odin` | The pass that runs before cmark, then cmark |
| `notes.odin` | Margin notes |
| `gfm.odin` | Tables and strikethrough |
| `highlight.odin` | Syntax highlighting |
| `render.odin` | Every layout, as a procedure |
| `feed.odin`, `sitemap.odin` | RSS and the sitemap |

## Two arenas

Everything a `Page` points at is allocated from the permanent arena;
everything else from scratch. There is no manual `free` anywhere in the
program, and one `arena_destroy` at the end returns all of it.

The discipline has one rule worth stating: **nothing retained on a `Page` may
point into scratch**[^lifetime]. Directory listings, file contents and every
intermediate string live there.

[^lifetime]: Two fields broke this rule and were safe only because nothing ever
    reset the scratch arena. There is now a test that frees it and writes over
    it, so a pointer left behind reads as garbage.

## The preprocessing pass

libcmark implements CommonMark and nothing else, so tables, strikethrough,
margin notes and highlighting do not exist as far as it is concerned. Rather
than post-process its output, ostat rewrites the source into raw HTML first and
lets cmark pass it through — the same shape as gingerBill's
`preprocessor_pass_over_article`.

That means the pass has to agree with cmark about **where code is**, and
getting that wrong is where every interesting bug in this program has lived:

- A line scanner that knew about fenced blocks but not inline code spans
  rewrote `` `a ~~ b` `` and corrupted the sample.
- Matching fences by prefix closed a ```` ```` ```` block at the ```` ``` ````
  example inside it.
- A fence indented under a list item ended the list and hoisted the block out.

Each is fixed by making the scanner more nearly a CommonMark parser, which is
the direction this design pulls in. The alternative is walking cmark's AST and
transforming only text nodes, which is correct by construction and a
considerably larger rewrite.

## Output

`build_page`, `build_sitemap` and `build_feed` return strings; their callers
write them. Fused, none of the layout code was reachable from a test.

The whole program is a pure function from content, configuration and today's
date to a file tree. Directory walks are sorted explicitly and `-today`
overrides the only clock read, which is what makes the golden tests in
`tests/` possible.
