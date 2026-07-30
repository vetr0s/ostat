package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

/*
One site's identity, in one struct.

What lives here: everything about *which* site is being built — its name,
address, author, the home page's copy and links, the section that holds posts.
Change these and you get a different site.

The struct is filled from DEFAULT_SITE and then from <site-dir>/site.json, so
one binary builds any number of sites. The defaults below are ostat's own
documentation site, and they are what a site with no site.json gets.

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
// generator builds to prove it works. A site.json overrides any of it;
// portrait may be left zeroed if there is no author photo.
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

CONFIG_FILE :: "site.json"

/*
Reads <site-dir>/site.json over the defaults above.

A key the file omits keeps its default, because unmarshalling assigns only
what the document actually contains. A site.json naming nothing but base_url
and title is therefore enough, and does not have to restate the struct.

Having no site.json is not an error. The defaults describe a working site, and
a content directory on its own should still build.

Everything this returns is untrusted in a way a compile-time literal was not,
so config strings are escaped where they reach markup rather than here. The
one exception is base_url, which is checked below because it is concatenated
into every absolute URL the build emits.
*/
load_site_config :: proc(w: ^Website) -> bool {
	path := fmt.aprintf("%s/%s", w.opts.site_dir, CONFIG_FILE, allocator = w.scratch)
	if !os.exists(path) {
		return true
	}

	src, read_err := os.read_entire_file_from_path(path, w.scratch)
	if read_err != nil {
		fmt.eprintfln("ostat: cannot read %s: %v", path, read_err)
		return false
	}

	// Into w.config, which already holds the defaults, so this is a merge.
	if err := json.unmarshal(src, &w.config, .JSON5, w.perm); err != nil {
		fmt.eprintfln("ostat: %s: %v", path, err)
		return false
	}

	required := [?]struct {
		value, name: string,
	} {
		{w.config.base_url, "base_url"},
		{w.config.title, "title"},
		{w.config.locale, "locale"},
	}
	for f in required {
		if f.value == "" {
			fmt.eprintfln("ostat: %s: %q cannot be empty", path, f.name)
			return false
		}
	}
	return true
}

// The number of recent posts the home page lists.
HOME_RECENT_COUNT :: 5

// The section whose pages are posts: the only one that gets a feed, a date, or
// a place in the recent list.
BLOG_SECTION :: "blog"

// The root feed. Named once because content.odin advertises it, render.odin
// links it and feed.odin writes it, and they have to agree.
ROOT_FEED_PATH :: "/index.xml"
