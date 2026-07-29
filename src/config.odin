package main

/*
One site's identity, in one struct.

What lives here: everything about *which* site is being built — its name,
address, author, the home page's copy and links, the section that holds posts.
Change these and you get a different site.

What does not, and where to find it instead:

  - The *shape* of the layouts, in render.odin. The home page has three
    sections in a fixed order; a site wanting a fourth edits write_home. That
    is the deliberate trade of "layouts are procedures, not templates".
  - The assets each page links, in html/head.html. Favicons, the manifest, the
    stylesheet and the font preload are markup, and they are #load-ed whole.
  - The CSS class names the generator writes, in notes.odin and highlight.odin.
    They are a contract with static/css/style.css and have to move together.

This comment used to claim nothing outside this file hardcoded a site's title,
URL or navigation. That was false in four files, and a forker who believed it
edited this struct and still shipped someone else's home page.
*/

// A definition list entry: the label names the kind of address, the text is
// what a reader sees, and they differ often enough to be separate fields.
Contact :: struct {
	label: string,
	text:  string,
	url:   string,
}

Link :: struct {
	label: string,
	url:   string,
}

Portrait :: struct {
	src:    string,
	alt:    string,
	width:  int,
	height: int,
}

// The title, split where the accent colour starts. Written out rather than
// derived: the rule used to be "split at the first dot", which lives nowhere
// near this file and renders "Dr. Foo" as "Dr" plus an accented ". Foo".
Brand :: struct {
	head:   string,
	accent: string,
}

// The three headings on the home page. Copy, not structure — the sections
// themselves are written in render.odin.
Home_Copy :: struct {
	contact_heading:   string,
	elsewhere_heading: string,
	recent_heading:    string,
	nothing_published: string,
}

Site_Config :: struct {
	base_url:    string,
	title:       string,
	description: string,
	author:      string,
	locale:      string,
	brand:       Brand,

	// The home page. Data, not markup.
	portrait:    Portrait,
	contact:     []Contact,
	elsewhere:   []Link,
	home:        Home_Copy,
}

// A variable, not a constant. A compile-time constant holding slice fields
// gives those slices no backing storage to point at.
// ostat's own documentation, which is the site in site/ and the thing this
// generator builds to prove it works. Replace the whole literal to build a
// different site; portrait may be left zeroed if there is no author photo.
//
// URLs here are root-relative, so a site is assumed to sit at a domain root
// rather than under a path.
@(rodata)
DEFAULT_SITE := Site_Config {
	base_url    = "https://ostat.example/",
	title       = "ostat",
	description = "A static site generator written in Odin. Layouts are procedures, not templates.",
	author      = "ostat",
	locale      = "en-us",
	brand       = {head = "ostat", accent = ""},
	contact     = {
		{"source",  "github.com/vetr0s/ostat",         "https://github.com/vetr0s/ostat"},
		{"issues",  "github.com/vetr0s/ostat/issues",  "https://github.com/vetr0s/ostat/issues"},
		{"licence", "Unlicense",                       "https://unlicense.org/"},
	},
	elsewhere   = {
		{"install",     "/install/"},
		{"writing",     "/writing/"},
		{"configuring", "/configuring/"},
		{"internals",   "/internals/"},
		{"notes",       "/blog/"},
	},
	home        = {
		contact_heading   = "ostat",
		elsewhere_heading = "Documentation",
		recent_heading    = "Release Notes",
		nothing_published = "No releases yet.",
	},
}

// The number of recent posts the home page lists.
HOME_RECENT_COUNT :: 5

// The section whose pages are posts: the only one that gets a feed, a date, or
// a place in the recent list.
BLOG_SECTION :: "blog"

// The root feed. Named once because content.odin advertises it, render.odin
// links it and feed.odin writes it, and they have to agree.
ROOT_FEED_PATH :: "/index.xml"
