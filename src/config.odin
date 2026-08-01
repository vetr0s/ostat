package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

/*
One site's identity, in one struct.

What lives here: the short facts about *which* site is being built — its name,
address, author, locale, brand. Data, and genuinely data.

The struct is filled from DEFAULT_SITE and then from <site-dir>/site.json, so
one binary builds any number of sites. The defaults below name no real site:
they are a placeholder that builds and says plainly that it is unconfigured.
ostat's own identity lives in site/site.json like anyone else's.

What does not, and where to find it instead:

  - The home page, and the markup around every page, in <site-dir>/html. Those
    are documents. They used to be four fields here and three structs, which
    meant the data model had to grow a field for every idea a home page might
    have and render.odin had to grow a branch to draw it.
  - The *shape* of the remaining layouts, in render.odin: the single page, the
    section listing, the breadcrumb. That is the deliberate trade of "layouts
    are procedures, not templates".
  - The CSS class names the generator writes, in notes.odin and highlight.odin.
    They are a contract with static/css/style.css and have to move together.

This comment used to claim nothing outside this file hardcoded a site's title,
URL or navigation. That was false in four files, and a forker who believed it
edited this struct and still shipped someone else's home page.
*/

// The title, split where the accent colour starts. Written out rather than
// derived: the rule used to be "split at the first dot", which lives nowhere
// near this file and renders "Dr. Foo" as "Dr" plus an accented ". Foo".
Brand :: struct {
	head:   string,
	accent: string,
}

Site_Config :: struct {
	base_url:    string,
	title:       string,
	description: string,
	author:      string,
	locale:      string,
	brand:       Brand,
}

// A variable, not a constant. A compile-time constant holding slice fields
// gives those slices no backing storage to point at.
//
// Deliberately nobody's site. These used to be ostat's own identity, which
// meant a site.json that forgot a key silently inherited ostat's headings and
// documentation links, and the forker who hit that had no way to see where the
// strings came from. A placeholder is wrong in a way you notice.
//
// base_url points at the dev server because an unconfigured site is one being
// looked at locally. Every other address a build emits is derived from it.
//
// URLs here are root-relative, so a site is assumed to sit at a domain root
// rather than under a path.
@(rodata)
DEFAULT_SITE := Site_Config {
	base_url    = "http://localhost:1313/",
	title       = "An unconfigured ostat site",
	description = "This site has no site.json. Add one beside content/ to give it a name.",
	author      = "",
	locale      = "en-us",
	brand       = {head = "unconfigured", accent = ""},
}

CONFIG_FILE :: "site.json"

/*
Reads <site-dir>/site.json over the defaults above.

A key the file omits keeps its default, because unmarshalling assigns only
what the document actually contains. A site.json naming nothing but base_url
and title is therefore enough, and does not have to restate the struct.

Having no site.json is not an error. The defaults describe a working site, and
a content directory on its own should still build.

Everything this returns is untrusted in a way a compile-time literal was not.
Strings that reach markup as text are escaped where they land. base_url and
locale are not: they are concatenated into URLs and attributes at eight call
sites, and are checked here instead. That is the right shape for them, because
base_url is supposed to be one URL and locale one language tag, and a value
that cannot be written into an attribute is neither.
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
	return validate_identity(w, path)
}

// The offending rune and false, or true.
//
// base_url reaches og:url, <loc>, <link> and <atom:link> without being escaped
// at any of them, so it may not carry a character that would end an attribute
// or an XML text node. Nor could a real URL.
//
// Not file-private: -base-url replaces this value after the file is read, and
// checking one door and not the other is how the check gets walked around.
check_base_url :: proc(url: string) -> (bad: rune, ok: bool) {
	for c in url {
		switch {
		case c == '"', c == '\'', c == '<', c == '>', c == '&', c <= ' ', c == 0x7f:
			return c, false
		}
	}
	return 0, true
}

// locale reaches the html lang attribute and <language>, unescaped at both.
@(private = "file")
validate_identity :: proc(w: ^Website, path: string) -> bool {
	if c, ok := check_base_url(w.config.base_url); !ok {
		fmt.eprintfln("ostat: %s: base_url cannot contain %q", path, c)
		return false
	}

	for c in w.config.locale {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '-':
		case:
			fmt.eprintfln("ostat: %s: %q is not a language tag", path, w.config.locale)
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
