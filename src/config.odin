package main

/*
Everything hugo.toml used to carry, in one struct.

This is the seam. Nothing outside this file hardcodes a site's title, URL, or
navigation, so making ostat configurable later means writing a loader that
fills a Site_Config instead of rewriting callers.
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

Site_Config :: struct {
	base_url:    string,
	title:       string,
	description: string,
	author:      string,
	locale:      string,

	// The home page. Data, not markup.
	portrait:    Portrait,
	contact:     []Contact,
	elsewhere:   []Link,
}

// A variable, not a constant. A compile-time constant holding slice fields
// gives those slices no backing storage to point at.
@(rodata)
DEFAULT_SITE := Site_Config {
	base_url    = "https://vetr0s.dev/",
	title       = "vetr0s.dev",
	description = "Nathan Tebbs, software engineer. Writing, projects, and a page about who I am.",
	author      = "Nathan Tebbs",
	locale      = "en-us",
	portrait    = {src = "/img/gh_profile.jpg", alt = "Nathan Tebbs", width = 553, height = 553},
	contact     = {
		{"email",    "vetr0s.dev@gmail.com",       "mailto:vetr0s.dev@gmail.com"},
		{"github",   "github.com/vetr0s",          "https://github.com/vetr0s"},
		{"linkedin", "linkedin.com/in/ntebbs",     "https://www.linkedin.com/in/ntebbs"},
		{"resume",   "resume.pdf",                 "/resume.pdf"},
	},
	elsewhere   = {
		{"about",    "/about/"},
		{"blog",     "/blog/"},
		{"projects", "/projects/"},
		{"colophon", "/colophon/"},
	},
}

// The number of recent posts the home page lists.
HOME_RECENT_COUNT :: 5

// The section whose pages are posts: the only one that gets a feed, a date, or
// a place in the recent list.
BLOG_SECTION :: "blog"
