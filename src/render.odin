package main

import "core:fmt"
import "core:os"
import "core:strings"

/*
Every layout, as a procedure. There is no template language: gingerBill's
generator writes HTML with io.write_string and fmt.wprintf, and this follows
it. Static chunks that never branch are #load-ed from src/html.

There is no footer. The colophon it linked to is reachable from the home
page's Elsewhere list.
*/

HEAD_STATIC :: #load("html/head.html", string)

render_all :: proc(w: ^Website) -> bool {
	for p in w.pages {
		write_output(w, p.out_path, build_page(w, p)) or_return
	}
	render_feeds(w) or_return
	render_sitemap(w) or_return
	copy_static(w) or_return
	return true
}

// Building a page and writing it are separate so that a layout can be asserted
// on without touching the filesystem. Fused, none of this file was reachable
// from a test.
build_page :: proc(w: ^Website, p: ^Page) -> string {
	b := strings.builder_make(w.scratch)

	fmt.sbprintf(&b, "<!DOCTYPE html>\n<html lang=\"%s\">\n<head>\n", html_lang(w))
	write_head(w, &b, p)
	strings.write_string(&b, "</head>\n<body>\n  <header>")
	write_header(w, &b, p)
	strings.write_string(&b, "</header>\n  <main>\n")

	switch {
	case p.is_home:
		write_home(w, &b)
	case p.is_section:
		write_list(w, &b, p)
	case:
		write_single(w, &b, p)
	}

	strings.write_string(&b, "  </main>\n</body>\n</html>\n")
	return strings.to_string(b)
}

@(private = "file")
write_head :: proc(w: ^Website, b: ^strings.Builder, p: ^Page) {
	title := page_title(w, p, w.scratch)
	desc := page_description(w, p, w.scratch)
	kind := "website" if p.is_home || p.is_section else "article"

	strings.write_string(b, `<meta charset="UTF-8">` + "\n")
	strings.write_string(b, `<meta name="viewport" content="width=device-width, initial-scale=1.0">` + "\n")
	fmt.sbprintfln(b, "<title>%s</title>", html_escape(title, w.scratch))
	fmt.sbprintfln(b, `<meta name="description" content="%s">`, html_escape(desc, w.scratch))
	fmt.sbprintfln(b, `<meta name="author" content="%s">`, html_escape(w.config.author, w.scratch))
	fmt.sbprintfln(b, `<meta property="og:type" content="%s">`, kind)
	fmt.sbprintfln(b, `<meta property="og:title" content="%s">`, html_escape(title, w.scratch))
	fmt.sbprintfln(b, `<meta property="og:description" content="%s">`, html_escape(desc, w.scratch))
	fmt.sbprintfln(b, `<meta property="og:url" content="%s">`, page_permalink(w, p, w.scratch))

	if p.feed_url != "" {
		fmt.sbprintfln(
			b,
			`<link rel="alternate" type="application/rss+xml" href="%s" title="%s">`,
			abs_url(w, p.feed_url, w.scratch),
			html_escape(title, w.scratch),
		)
	}

	strings.write_string(b, HEAD_STATIC)
}

// One bar on every page: where you are, and the way back out. It is a trail,
// not a menu, so the current page is never a link and never links deeper.
@(private = "file")
write_header :: proc(w: ^Website, b: ^strings.Builder, p: ^Page) {
	strings.write_string(b, "\n<nav class=\"crumbs\" aria-label=\"Breadcrumb\">\n  <p class=\"trail\">\n")

	brand := site_brand(w, w.scratch)
	switch {
	case p.is_home:
		fmt.sbprintfln(b, `    <span class="here" aria-current="page">%s</span>`, brand)
	case p.is_section:
		section := html_escape(p.section, w.scratch)
		fmt.sbprintfln(b, `    <a href="/">%s</a>`, brand)
		strings.write_string(b, "    <span class=\"sep\">/</span>\n")
		fmt.sbprintfln(b, `    <span class="here" aria-current="page">%s</span>`, section)
	case p.section != "":
		section := html_escape(p.section, w.scratch)
		fmt.sbprintfln(b, `    <a href="/">%s</a>`, brand)
		strings.write_string(b, "    <span class=\"sep\">/</span>\n")
		fmt.sbprintfln(b, `    <a href="/%s/">%s</a>`, section, section)
	case:
		// A page at the content root, like the colophon: no section to climb.
		fmt.sbprintfln(b, `    <a href="/">%s</a>`, brand)
		strings.write_string(b, "    <span class=\"sep\">/</span>\n")
		fmt.sbprintfln(
			b,
			`    <span class="here" aria-current="page">%s</span>`,
			html_escape(strings.to_lower(p.title, w.scratch), w.scratch),
		)
	}

	strings.write_string(b, "  </p>\n")
	strings.write_string(b, `  <button id="theme-toggle" type="button" aria-label="Toggle color theme"></button>` + "\n")
	strings.write_string(b, "</nav>\n  ")
}

@(private = "file")
write_home :: proc(w: ^Website, b: ^strings.Builder) {
	fmt.sbprintfln(b, `<section id="find-me">`+"\n"+`  <h1>%s</h1>`, html_escape(w.config.home.contact_heading, w.scratch))

	// Optional: a site without an author photo should not emit a broken image.
	if p := w.config.portrait; p.src != "" {
		fmt.sbprintfln(
			b,
			`  <div class="portrait">`+"\n"+`    <img src="%s" alt="%s" width="%d" height="%d" />`+"\n"+`  </div>`,
			html_escape(p.src, w.scratch),
			html_escape(p.alt, w.scratch),
			p.width,
			p.height,
		)
	}
	strings.write_string(b, "  <dl class=\"contact-list\">\n")
	for c in w.config.contact {
		fmt.sbprintfln(b, "    <dt>%s</dt>", html_escape(c.label, w.scratch))
		fmt.sbprintfln(
			b,
			`    <dd><a href="%s">%s</a></dd>`,
			html_escape(c.url, w.scratch),
			html_escape(c.text, w.scratch),
		)
	}
	strings.write_string(b, "  </dl>\n</section>\n\n")

	fmt.sbprintfln(b, `<section id="elsewhere">`+"\n"+`  <h1>%s</h1>`+"\n"+`  <ul>`, html_escape(w.config.home.elsewhere_heading, w.scratch))
	for link in w.config.elsewhere {
		fmt.sbprintfln(
			b,
			`    <li><a href="%s">%s</a></li>`,
			html_escape(link.url, w.scratch),
			html_escape(link.label, w.scratch),
		)
	}
	strings.write_string(b, "  </ul>\n</section>\n\n")

	// Rendered even with nothing to list. The badge is the only way to the
	// feed from this page, and an empty blog is when subscribing matters.
	strings.write_string(b, "<section id=\"recent\">\n")
	write_section_head(w, b, w.config.home.recent_heading, ROOT_FEED_PATH)
	recent := w.articles[:min(HOME_RECENT_COUNT, len(w.articles))]
	write_post_entries(w, b, recent, w.config.home.nothing_published)
	strings.write_string(b, "</section>\n")
}

@(private = "file")
write_list :: proc(w: ^Website, b: ^strings.Builder, p: ^Page) {
	write_section_head(w, b, p.title, p.feed_url)
	strings.write_string(b, p.content)

	pages := section_pages(w, p)
	write_post_entries(w, b, pages, "Nothing published here yet.")
}

@(private = "file")
write_single :: proc(w: ^Website, b: ^strings.Builder, p: ^Page) {
	strings.write_string(b, "<article>\n")
	fmt.sbprintfln(b, "  <h1>%s</h1>", html_escape(p.title, w.scratch))
	if p.date != "" {
		fmt.sbprintfln(b, `  <time datetime="%s">%s</time>`, p.date, long_date(p, w.scratch))
	}
	strings.write_string(b, p.content)
	strings.write_string(b, "</article>\n")
}

@(private = "file")
write_section_head :: proc(w: ^Website, b: ^strings.Builder, title, feed_url: string) {
	strings.write_string(b, "  <div class=\"section-head\">\n")
	fmt.sbprintfln(b, "    <h1>%s</h1>", html_escape(title, w.scratch))
	// Only a section that publishes a feed gets the badge.
	if feed_url != "" {
		fmt.sbprintfln(b, `    <a class="rss-badge" href="%s" title="RSS feed">RSS</a>`, feed_url)
	}
	strings.write_string(b, "  </div>\n")
}

@(private = "file")
write_post_entries :: proc(w: ^Website, b: ^strings.Builder, pages: []^Page, empty: string) {
	if len(pages) == 0 {
		fmt.sbprintfln(b, `  <p class="empty">%s</p>`, empty)
		return
	}
	for p in pages {
		strings.write_string(b, "  <article class=\"post-entry\">\n")
		fmt.sbprintfln(b, `    <a href="%s">%s</a>`, p.url, html_escape(p.title, w.scratch))
		fmt.sbprintfln(b, `    <time datetime="%s">%s</time>`, p.date, p.date)
		strings.write_string(b, "  </article>\n")
	}
}

// The pages a section lists, newest first. Only the blog is dated, so anything
// else keeps its discovery order, which is alphabetical.
@(private = "file")
section_pages :: proc(w: ^Website, section: ^Page) -> []^Page {
	if section.section == BLOG_SECTION {
		return w.articles[:]
	}

	out := make([dynamic]^Page, w.scratch)
	for p in w.pages {
		if !p.is_section && !p.is_home && p.section == section.section {
			append(&out, p)
		}
	}
	return out[:]
}

write_output :: proc(w: ^Website, rel, body: string) -> bool {
	path := fmt.aprintf("%s/%s", w.opts.out_dir, rel, allocator = w.scratch)

	dir := path
	if i := strings.last_index_byte(path, '/'); i >= 0 {
		dir = path[:i]
	}
	ensure_directory(dir) or_return
	if err := os.write_entire_file(path, body); err != nil {
		fmt.eprintfln("ostat: cannot write %s: %v", path, err)
		return false
	}
	return true
}

// make_directory_all reports .Exist rather than succeeding when the path is
// already there, and a rebuild into an existing public/ hits that constantly.
@(private = "file")
ensure_directory :: proc(path: string) -> bool {
	err := os.make_directory_all(path)
	if err == nil || err == .Exist {
		return true
	}
	fmt.eprintfln("ostat: cannot create %s: %v", path, err)
	return false
}

@(private = "file")
copy_static :: proc(w: ^Website) -> bool {
	root := fmt.aprintf("%s/static", w.opts.site_dir, allocator = w.scratch)
	if !os.is_directory(root) {
		return true
	}
	return copy_tree(w, root, w.opts.out_dir)
}

@(private = "file")
copy_tree :: proc(w: ^Website, src, dst: string) -> bool {
	entries, err := os.read_all_directory_by_path(src, w.scratch)
	if err != nil {
		fmt.eprintfln("ostat: cannot read %s: %v", src, err)
		return false
	}

	ensure_directory(dst) or_return

	for entry in entries {
		out := fmt.aprintf("%s/%s", dst, entry.name, allocator = w.scratch)
		if entry.type == .Directory {
			copy_tree(w, entry.fullpath, out) or_return
			continue
		}

		data, read_err := os.read_entire_file_from_path(entry.fullpath, w.scratch)
		if read_err != nil {
			fmt.eprintfln("ostat: cannot read %s: %v", entry.fullpath, read_err)
			return false
		}
		if write_err := os.write_entire_file(out, data); write_err != nil {
			fmt.eprintfln("ostat: cannot write %s: %v", out, write_err)
			return false
		}
	}
	return true
}
