package main

import "core:fmt"
import "core:os"
import "core:strings"

/*
The static markup a document is assembled from.

gingerBill's generator #loads these at compile time, which is right for a
generator that builds exactly one site. ostat stopped being that in c33e523:
one binary builds any number of sites. So the files in src/html are compiled in
as defaults, and a site overrides any of them with a file of the same name in
<site-dir>/html, beside content/ and static/.

header-01 and header-02 are the two halves of the document head, sandwiching
the only part of it that varies per page: the title, the description, and the
per-page meta. A site that wants its own favicons, stylesheet or fonts writes
header-02 and never touches the generator.

Supplying none of them is not an error, for the same reason having no site.json
is not: a bare content directory should still build.

What stays in the generator, deliberately: the doctype and the html element.
`lang` comes from the site's locale, which the feed also writes, and a fragment
that could disagree with site.json would be a second place to say one thing.
*/

Fragments :: struct {
	header_01: string,
	header_02: string,
	home:      string,
	not_found: string,
}

FRAGMENT_DIR :: "html"

// Where the home page's list of recent posts goes. That list is the one part
// of that page ostat generates, so it is the one part the fragment cannot
// write for itself. Everything around it, including the heading and the feed
// badge, belongs to the site.
RECENT_MARKER :: "<!--ostat:recent-->"

// A variable rather than a constant, for the reason DEFAULT_SITE gives.
@(rodata)
DEFAULT_FRAGMENTS := Fragments {
	header_01 = #load("html/header-01.html", string),
	header_02 = #load("html/header-02.html", string),
	home      = #load("html/home.html", string),
	not_found = #load("html/not-found-404.html", string),
}

load_fragments :: proc(w: ^Website) -> bool {
	w.fragments = DEFAULT_FRAGMENTS

	dir := fmt.aprintf("%s/%s", w.opts.site_dir, FRAGMENT_DIR, allocator = w.scratch)
	if !os.is_directory(dir) {
		return true
	}

	overrides := [?]struct {
		name: string,
		into: ^string,
	} {
		{"header-01.html", &w.fragments.header_01},
		{"header-02.html", &w.fragments.header_02},
		{"home.html", &w.fragments.home},
		{"not-found-404.html", &w.fragments.not_found},
	}
	for o in overrides {
		path := fmt.aprintf("%s/%s", dir, o.name, allocator = w.scratch)
		if !os.exists(path) {
			continue
		}
		src, err := os.read_entire_file_from_path(path, w.perm)
		if err != nil {
			fmt.eprintfln("ostat: cannot read %s: %v", path, err)
			return false
		}
		o.into^ = string(src)
	}

	// Here rather than at render time. A home page whose recent posts have
	// nowhere to go is a mistake in the file, and the file is what to name.
	if !strings.contains(w.fragments.home, RECENT_MARKER) {
		fmt.eprintfln(
			"ostat: %s/home.html: no %s, so the recent posts have nowhere to go",
			dir,
			RECENT_MARKER,
		)
		return false
	}
	return true
}
