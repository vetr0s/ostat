package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

/*
Discovery and the page model.

A file named _index.md is its directory's section page. Anything else ending
in .md is a regular page. Everything else in content/ is ignored.

Page pointers are handed out and kept, so pages are allocated individually
from the permanent arena rather than living inside a [dynamic]Page that would
invalidate them as it grows.
*/

Note :: struct {
	label:  string,
	desc:   string, // markdown source
	html:   string, // rendered inline html
	used:   int,    // marker count, so an unreferenced definition can be caught
	number: int,    // assigned at first use, so ordering follows the markers
}

// How a note is written into the page. The margin form is the site's; a feed
// has no margin and no stylesheet, so it gets numbered endnotes instead.
Note_Style :: enum {
	Margin,
	Endnote,
}

Page :: struct {
	title:       string,
	description: string,
	slug:        string,
	section:     string, // "" for a page at the content root
	date:        string, // "2026-07-12", or "" when undated
	year:        int,
	month:       int,
	day:         int,
	draft:       bool,
	is_section:  bool,
	is_home:     bool,
	feed_url:    string, // "" when the page advertises no feed

	body:        string, // markdown, front matter stripped
	content:     string, // rendered html
	notes:       [dynamic]Note,

	url:         string, // "/blog/kitchen-sink/"
	out_path:    string, // "blog/kitchen-sink/index.html"
	source:      string, // path on disk, for error messages
}

collect_content :: proc(w: ^Website) -> bool {
	root := fmt.aprintf("%s/content", w.opts.site_dir, allocator = w.perm)
	if !os.is_directory(root) {
		fmt.eprintfln("ostat: no content directory at %s", root)
		return false
	}

	walk_content(w, root, "") or_return

	// Newest first. Dates are YYYY-MM-DD, so string order is date order.
	slice.sort_by(w.articles[:], proc(a, b: ^Page) -> bool {
		return a.date > b.date
	})

	// The home page has no content file. It is the config plus the recent
	// posts, so it is synthesised here and rendered like any other page.
	home := new(Page, w.perm)
	home.title = w.config.title
	home.description = w.config.description
	home.is_home = true
	home.url = "/"
	home.out_path = "index.html"
	home.feed_url = "/index.xml"
	home.notes = make([dynamic]Note, w.perm)
	append(&w.pages, home)

	// Both feeds carry the same posts, so either address works in a reader.
	if blog, found := w.sections[BLOG_SECTION]; found {
		blog.feed_url = "/" + BLOG_SECTION + "/index.xml"
	}
	return true
}

@(private = "file")
walk_content :: proc(w: ^Website, dir: string, section: string) -> bool {
	entries, err := os.read_all_directory_by_path(dir, w.scratch)
	if err != nil {
		fmt.eprintfln("ostat: cannot read %s: %v", dir, err)
		return false
	}

	// Sorted so a build is reproducible; readdir order is not.
	slice.sort_by(entries, proc(a, b: os.File_Info) -> bool {
		return a.name < b.name
	})

	for entry in entries {
		if entry.type == .Directory {
			sub := section == "" ? entry.name : fmt.tprintf("%s/%s", section, entry.name)
			walk_content(w, entry.fullpath, sub) or_return
			continue
		}
		if !strings.has_suffix(entry.name, ".md") {
			continue
		}
		load_page(w, entry.fullpath, entry.name, section) or_return
	}
	return true
}

@(private = "file")
load_page :: proc(w: ^Website, path, name, section: string) -> bool {
	src, read_err := os.read_entire_file_from_path(path, w.scratch)
	if read_err != nil {
		fmt.eprintfln("ostat: cannot read %s: %v", path, read_err)
		return false
	}

	fm, body, fm_err := parse_front_matter(string(src), w.perm)
	if fm_err != .None {
		fmt.eprintfln("ostat: %s: %v", path, fm_err)
		return false
	}

	if fm.draft && !w.opts.drafts {
		return true
	}

	p := new(Page, w.perm)
	p.title       = fm.title
	p.description = fm.description
	p.draft       = fm.draft
	// Cloned, not aliased. A nested section name is a tprintf result and a
	// derived slug points into the directory listing, both of which live in
	// scratch — and a Page outlives scratch. Nothing here may point into it.
	p.section     = strings.clone(section, w.perm)
	p.source      = strings.clone(path, w.perm)
	p.body        = strings.clone(body, w.perm)
	p.is_section  = name == "_index.md"
	p.notes       = make([dynamic]Note, w.perm)

	if fm.date != "" {
		p.date = fm.date
		p.year, p.month, p.day, _ = parse_date(fm.date)
	}

	if !w.opts.future && is_future(w, p) {
		return true
	}

	if p.is_section {
		p.slug = ""
		p.url = section == "" ? "/" : fmt.aprintf("/%s/", section, allocator = w.perm)
	} else {
		p.slug = strings.clone(
			fm.slug != "" ? fm.slug : name[:len(name) - len(".md")],
			w.perm,
		)
		if section == "" {
			p.url = fmt.aprintf("/%s/", p.slug, allocator = w.perm)
		} else {
			p.url = fmt.aprintf("/%s/%s/", section, p.slug, allocator = w.perm)
		}
	}
	p.out_path = fmt.aprintf("%sindex.html", p.url[1:], allocator = w.perm)

	append(&w.pages, p)
	if p.is_section {
		if section in w.sections {
			fmt.eprintfln("ostat: %s: two _index.md files for section %q", path, section)
			return false
		}
		w.sections[strings.clone(section, w.perm)] = p
	} else if section == BLOG_SECTION {
		append(&w.articles, p)
	}
	return true
}

@(private = "file")
is_future :: proc(w: ^Website, p: ^Page) -> bool {
	if p.date == "" {
		return false
	}
	return p.date > w.today
}

// The absolute URL for a page, for feeds and og:url.
page_permalink :: proc(w: ^Website, p: ^Page, allocator := context.allocator) -> string {
	return abs_url(w, p.url, allocator)
}

abs_url :: proc(w: ^Website, rel: string, allocator := context.allocator) -> string {
	base := strings.trim_suffix(w.config.base_url, "/")
	return fmt.aprintf("%s%s", base, rel, allocator = allocator)
}
