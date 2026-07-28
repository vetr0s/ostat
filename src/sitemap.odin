package main

import "core:fmt"
import "core:strings"

/*
sitemap.xml.

Hugo wrote one by default, so leaving it out would quietly drop something the
live site already has. Every rendered page gets an entry, dated when the page
carries a date.
*/

render_sitemap :: proc(w: ^Website) -> bool {
	b := strings.builder_make(w.scratch)

	strings.write_string(&b, `<?xml version="1.0" encoding="utf-8" standalone="yes"?>` + "\n")
	strings.write_string(&b, `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` + "\n")

	for p in w.pages {
		strings.write_string(&b, "  <url>\n")
		fmt.sbprintfln(&b, "    <loc>%s</loc>", page_permalink(w, p, w.scratch))
		if p.date != "" {
			fmt.sbprintfln(&b, "    <lastmod>%s</lastmod>", p.date)
		}
		strings.write_string(&b, "  </url>\n")
	}

	strings.write_string(&b, "</urlset>\n")
	return write_output(w, "sitemap.xml", strings.to_string(b))
}
