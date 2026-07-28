---
{
    "title": "Colophon"
}
---

The tools and influences behind this site.

## Built with

- [ostat](https://github.com/vetr0s/ostat): a static site generator written in
  [Odin](https://odin-lang.org/)
- [cmark](https://github.com/commonmark/cmark) for Markdown, through Odin's
  `vendor:commonmark` bindings
- Layouts are Odin procedures, not templates. There is no theme and no
  framework, and no JavaScript beyond a theme toggle
- An [RSS feed](/index.xml) of the posts

## Typography

The site is set in [ET Book](https://github.com/edwardtufte/et-book), the
digital Bembo cut for Edward Tufte's books and the face
[Tufte CSS](https://edwardtufte.github.io/tufte-css/) ships. It is served from
this domain in three weights: roman, italic, and bold.

- Body and headings: `ET Book`, then `Palatino`, `Book Antiqua`, `Georgia`
- Code: `ui-monospace`, then `Hack`, `DejaVu Sans Mono`

It used to load no web fonts at all, on the grounds that nothing should
download and nothing should swap under you mid-sentence. The second half of
that still holds; it is the reason the face is declared `font-display:
optional` rather than the `swap` that Tufte CSS and most of the web use. Under
`optional` a browser uses the face if it has it by the first paint and ignores
it for that page otherwise. It never trades one typeface for another while you
are reading. The roman cut is preloaded, so having it in time is the ordinary
case, and after one visit it is cached. Arrive cold on a slow line and you read
in Palatino, which is a decent thing to be mistaken for.

Headings are set semibold on a 1.2 modular scale. That is one step down from the
sizes a browser picks on its own.

The root is left at whatever size your browser is set to. Nothing here scales
past that. If you want the text larger you have a zoom control, and overriding
the size you already chose is not the site's business.

There is no step up on large screens either. The page should read like a
document, not a poster.

Every length here is font-relative: the measure in `ch`, the spacing in `rem`.
One number scales the whole layout the way your browser's zoom does.

Body text runs a step above what a UI face would need. ET Book has a small
x-height and sets optically smaller than a sans at the same size, so the same
number tuned for one is too little for the other. The leading is kept tight:
spread the same ink over more page and a paragraph turns into a grey field
instead of a block of white.

## Layout

The page hugs the left margin and stops at its measure. Nothing is centered. A
centered column asks your eye to find the text. A left-aligned one puts it where
the eye already is.

An aside is a margin note. A small marker sits where the claim is, and the note
itself sits out beside it. The line you are reading runs its full width from the
first word to the last. Below the breakpoint the margin has nowhere to go, so
the marker becomes a toggle and the note folds inline.

Photographs sit in the flow. Each one is capped well short of the measure and
placed after the passage it illustrates. A picture interrupts the prose without
becoming the page.

## Colors

The light and dark color schemes are based on the [Modus
themes](https://protesilaos.com/emacs/modus-themes-colors) by Protesilaos
Stavrou:

- `modus-operandi`: light
- `modus-vivendi`: dark

Headings use the `yellow-warmer`, `magenta`, and `cyan` accents from the same
palettes. Syntax highlighting is drawn from the same set. A code block is tinted
like the rest of the page instead of carrying a theme of its own.

Both schemes follow your system preference by default. The toggle overrides it.
The choice persists in `localStorage`.

## Design influence

- [gingerBill.org](https://www.gingerbill.org/): the generator. Two files of
  Odin, no template language, HTML written by procedures
- [Tufte CSS](https://edwardtufte.github.io/tufte-css/): the aside written where
  the claim is, set in the margin rather than collected at the end
- [andrewkelley.me](https://andrewkelley.me/): the plainness. Left-aligned,
  underlined links, a document rather than a layout
- [protesilaos.com](https://protesilaos.com/): system-font text on a modular
  scale, no web fonts, and the Modus palettes above

## Navigation

Every page opens the same way. One line says where you are and links back out of
it. There is no menu and no banner. A menu on every page is furniture standing
in front of the thing you came to read. A banner on the home page is the same
furniture in a bigger typeface.

That makes the home page the way in. It carries where to find me, a short list
of everywhere else, and the most recent posts. It is one click from anywhere. A
post climbs to its section. A section climbs home. Home has the rest.

## The feed

[`/index.xml`](/index.xml) carries the posts. [`/blog/index.xml`](/blog/index.xml)
carries the same ones, so either address works in a reader.

An item carries the whole post rather than an excerpt. A feed has no margin, so
the margin notes collapse into numbered endnotes with absolute anchors, because
a feed item is read a long way from the page it came from. Nothing here asks you
to click through to finish reading.
