---
{
    "title": "Kitchen Sink",
    "date": "2026-07-12",
    "description": "Every content feature the site knows how to render, on one page."
}
---

This post exists to be looked at, not read. It uses every feature the renderer
and stylesheet support, so that changing either has somewhere to fail loudly.

## Prose, and what it can carry

Body text runs at full width from the first line to the last. An aside is a
margin note[^aside], set beside the claim rather than collected at the end of
the page.

[^aside]: A margin note. The marker is set where the claim is, and the note
    itself sits out in the margin. On a narrow screen the margin disappears and
    the marker becomes a toggle.

Numbering runs down the page in order[^numbering], and it is the stylesheet
that counts, not the generator.

[^numbering]: Notes carry [links](/colophon/), `code`, and *emphasis* like any
    other prose.

Inline, prose can carry **bold**, *italic*, `inline_code()`, a
[link to another site](https://andrewkelley.me/), a [link back
home](/colophon/), and ~~text struck through~~. Links are underlined, because
that is what a link looks like when nobody has styled it.

### A third-level heading

Headings run `h1` warm-yellow, `h2` magenta, `h3` cyan, on a 1.2 scale. Only the
`h1` carries a rule under it.

#### And a fourth

Which is plain, and the smallest heading the scale defines.

## Lists

Unordered, with nesting:

- A first item
- A second item, which is long enough to wrap onto a second line so that the
  hanging indent has a chance to be wrong
  - A nested item
  - Another nested item
- A third item

Ordered:

1. Install cmark
2. Run `./dev`
3. There is no step three

## Code

Inline code like `ostat build site` sits in a bordered box. A fenced block does
not repeat that border on every token. The surface belongs to the block:

```odin
package main

import "core:fmt"

main :: proc() {
	// Comments are muted and italic.
	fmt.println("Hellope, world!")
}
```

```bash
./dev            # serve locally, drafts included
./dev --build    # production build into public/
```

A block wide enough to overflow the measure scrolls inside its own box rather
than pushing the page sideways:

```text
this line is deliberately far too long to fit inside the measure and should produce a horizontal scrollbar on the block itself, never on the page
```

## Quotes

> A quote sits on a rule and goes muted. It is not a callout and does not want
> to be one.

## Tables

| Path | What lives there |
|---|---|
| `src/render.odin` | Every layout, as a proc |
| `src/notes.odin` | Margin notes, before cmark sees them |
| `site/static/css/style.css` | The whole stylesheet |

## Images

A picture sits in the flow, capped well short of the measure, with its caption
under it:

<figure>
<img src="/img/huston_pit.webp" alt="Our team's pit at the FRC World Championships in Houston" />
<figcaption>A figure, which is how every picture on the site is set.</figcaption>
</figure>

A bare markdown image gets the same cap and no caption.

![Our team's pit at the FRC World Championships in Houston](/img/huston_pit.webp)

---

That rule above is an `<hr>`. Above it is the same breadcrumb every page
carries: this is a post, so it climbs to `blog`, and `blog` climbs home.
