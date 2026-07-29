---
{
    "title": "Writing",
    "description": "The content format, demonstrated by the page describing it."
}
---

This page documents everything ostat knows how to render, and is written using
all of it. If the renderer breaks, this page shows it.

## Front matter

Front matter is a `---` fence around literal JSON, which is what
[gingerBill's generator](https://github.com/gingerBill/gingerBill.org) does.
Odin has no YAML or TOML parser in its core library, and `core:encoding/json`
unmarshals straight into a struct, so the format costs almost no parser code.

````text
---
{
    "title": "Writing",
    "date": "2026-01-30",
    "description": "Optional. Falls back to the opening paragraph.",
    "draft": false,
    "slug": "optional-override"
}
---
````

`title` is required. `date` must be `YYYY-MM-DD`. A `slug` may not contain a
path separator, `..`, or whitespace: it becomes a directory name, and a content
file is the least trusted input the generator has.

## Margin notes

An aside is written where the claim is[^why-here], not collected at the foot of
the page.

[^why-here]: This is a margin note. On a wide screen it sits out in the margin;
    below the breakpoint the marker becomes a toggle and the note folds inline.

````text
An aside is written where the claim is[^why-here], not collected.

[^why-here]: This is a margin note, and it may carry *markdown*.
````

Definitions may sit anywhere in the file and continue onto indented lines. The
generator writes no numbers: the count comes from a CSS counter, so a note's
number is the stylesheet's business and the two cannot drift apart.

An unresolved marker is left as prose rather than failing the build, because
`[^` is ordinary text far more often than it is a note[^regex]. A mistyped
label is still caught from the other side: the definition it was meant to reach
goes unreferenced, and that does fail the build.

[^regex]: A POSIX character class like `[^a-z]` is the obvious case, and it used
    to abort the build with an error naming a note nobody had written.

## Prose

Inline: **bold**, *italic*, `inline_code()`, ~~struck through~~, a
[link](https://odin-lang.org/), and a [link back home](/).

> A quote sits on a rule and goes muted. It is not a callout and does not want
> to be one.

Lists nest:

- A first item
- A second item, long enough to wrap onto a second line so the hanging indent
  has a chance to be wrong
  - A nested item
  - Another nested item

Ordered lists may hold code, which stays inside its item:

1. Build the generator.

   ```bash
   ./build.sh
   ```

2. Build a site with it.

   ```bash
   ./build/debug/ostat build site
   ```

3. There is no step three.

## Code

CommonMark has no syntax highlighting and libcmark does none, so ostat
highlights fenced blocks itself, emitting the class names Chroma uses so the
stylesheet needs no special casing.

```odin
package main

import "core:fmt"

main :: proc() {
	// Comments are muted and italic.
	fmt.println("Hellope, world!")
}
```

`odin`, `zig` and `bash` have lexers. Anything else renders escaped and
uncoloured:

```text
this line is deliberately far too long to fit inside the measure and should produce a horizontal scrollbar on the block itself, never on the page
```

A longer fence holds a shorter one, which is how you document Markdown:

`````text
````text
```
An inner fence, kept as content.
```
````
`````

## Tables

Tables are not in CommonMark either, so they are rewritten before cmark sees
them. Alignment comes from the delimiter row.

| Extension | Where it comes from | Aligned |
|---|---|:--:|
| Tables | `gfm.odin`, before cmark | centre |
| `~~strikethrough~~` | the same pass | centre |
| Highlighting | `highlight.odin` | centre |

## Raw HTML

Raw HTML passes through, so a figure renders as one:

<figure>
<img src="/favicon-32x32.png" alt="The ostat favicon, enlarged" width="64" height="64" />
<figcaption>A figure, which is how a captioned image is written.</figcaption>
</figure>

---

That rule is an `<hr>`, and this is the end of the page.
