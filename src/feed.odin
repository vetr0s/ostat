package main

import "core:fmt"
import "core:strings"
import "core:time"

/*
RSS 2.0.

The same document is written to /index.xml and /blog/index.xml, differing only
in the two URLs that point at the feed itself, so either address works in a
reader. Both carry blog posts and nothing else.

An item carries the whole post, not an excerpt. A feed has no margin and no
stylesheet, so each post is rendered a second time with its notes as numbered
endnotes and every anchor absolute.
*/

FEED_ITEM_LIMIT :: 20

@(rodata)
WEEKDAY_ABBR := [7]string{"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}

@(rodata)
MONTH_ABBR := [13]string {
	"",
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec",
}

render_feeds :: proc(w: ^Website) -> bool {
	items := w.articles[:min(FEED_ITEM_LIMIT, len(w.articles))]

	// Rendered once and written twice: the two feeds differ only in the URLs
	// that name the feed itself.
	bodies := make([]string, len(items), w.scratch)
	for p, i in items {
		bodies[i] = feed_item_content(w, p) or_return
	}

	write_output(w, "index.xml", build_feed(w, ROOT_FEED_PATH, "/", items, bodies)) or_return
	write_output(
		w,
		BLOG_SECTION + "/index.xml",
		build_feed(w, "/" + BLOG_SECTION + "/index.xml", "/" + BLOG_SECTION + "/", items, bodies),
	) or_return
	return true
}

// The post as a feed reader should see it: full content, endnotes appended.
feed_item_content :: proc(w: ^Website, p: ^Page) -> (content: string, ok: bool) {
	src := preprocess(w, p, .Endnote) or_return

	b := strings.builder_make(w.scratch)
	strings.write_string(&b, md_block(src, w.scratch))
	write_endnote_list(w, &b, p)
	return absolutize_urls(w, strings.to_string(b), w.scratch), true
}

// Attributes whose value is a URL. srcset holds a comma-separated list of
// them, so it is rewritten entry by entry rather than as one value.
@(rodata)
URL_ATTRS := [?]string{"href", "src", "srcset", "poster", "cite"}

SRCSET_ATTR :: "srcset"

// A feed item is read on someone else's host, where a root-relative link
// resolves against their document rather than this site. Every URL that starts
// at the root is rewritten to an absolute one.
//
// cmark emits only double-quoted href and src, so everything else this handles
// is reachable only through raw HTML written into a post. That is also the only
// way to write a URL the generator then cannot see is broken.
absolutize_urls :: proc(w: ^Website, html: string, allocator := context.allocator) -> string {
	base := strings.trim_suffix(w.config.base_url, "/")

	b := strings.builder_make(allocator)
	i := 0
	for {
		start, end, list, found := find_url_value(html, i)
		if !found {
			break
		}
		strings.write_string(&b, html[i:start])
		if list {
			write_absolute_srcset(&b, html[start:end], base)
		} else {
			write_absolute_url(&b, html[start:end], base)
		}
		i = end
	}

	strings.write_string(&b, html[i:])
	return strings.to_string(b)
}

// Deliberately not an HTML parser. It finds the attribute names that carry a
// URL and the CSS url() an inline style can hold, and takes the quoted or bare
// run that follows each.
@(private = "file")
find_url_value :: proc(html: string, from: int) -> (start, end: int, list, ok: bool) {
	for i := from; i < len(html); i += 1 {
		// A name character before the match means a longer name ending in one
		// of these, like data-href, which is not a URL to the browser.
		if name_byte(html, i - 1) {
			continue
		}
		if strings.has_prefix(html[i:], "url(") {
			start, end = bounded_value(html, i + len("url("), ')')
			return start, end, false, true
		}
		for attr in URL_ATTRS {
			eq := i + len(attr)
			if !strings.has_prefix(html[i:], attr) || eq >= len(html) || html[eq] != '=' {
				continue
			}
			start, end = bounded_value(html, eq + 1, '>')
			return start, end, attr == SRCSET_ATTR, true
		}
	}
	return 0, 0, false, false
}

// The byte range of a value starting at `at`: the run inside the quotes, or the
// bare run up to the first whitespace or `stop`.
@(private = "file")
bounded_value :: proc(html: string, at: int, stop: byte) -> (start, end: int) {
	if at >= len(html) {
		return at, at
	}
	if q := html[at]; q == '"' || q == '\'' {
		start = at + 1
		if i := strings.index_byte(html[start:], q); i >= 0 {
			return start, start + i
		}
		return start, len(html)
	}

	start = at
	for end = at; end < len(html); end += 1 {
		switch html[end] {
		case stop, ' ', '\t', '\n', '\r':
			return start, end
		}
	}
	return start, end
}

@(private = "file")
name_byte :: proc(html: string, i: int) -> bool {
	if i < 0 {
		return false
	}
	switch c := html[i]; {
	case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9', c == '-', c == '_':
		return true
	}
	return false
}

@(private = "file")
write_absolute_url :: proc(b: ^strings.Builder, url, base: string) {
	// A protocol-relative URL is already absolute enough.
	if strings.has_prefix(url, "/") && !strings.has_prefix(url, "//") {
		strings.write_string(b, base)
	}
	strings.write_string(b, url)
}

// "/a.png 1x, /b.png 2x". The descriptor trails its URL, so writing the entry
// whole after the base is enough; only the leading space needs preserving.
@(private = "file")
write_absolute_srcset :: proc(b: ^strings.Builder, value, base: string) {
	rest := value
	for {
		entry, comma := rest, strings.index_byte(rest, ',')
		if comma >= 0 {
			entry = rest[:comma]
		}

		lead := 0
		for lead < len(entry) && (entry[lead] == ' ' || entry[lead] == '\t' || entry[lead] == '\n') {
			lead += 1
		}
		strings.write_string(b, entry[:lead])
		write_absolute_url(b, entry[lead:], base)

		if comma < 0 {
			return
		}
		strings.write_byte(b, ',')
		rest = rest[comma + 1:]
	}
}

build_feed :: proc(
	w: ^Website,
	feed_url, page_url: string,
	items: []^Page,
	bodies: []string,
) -> string {
	b := strings.builder_make(w.scratch)

	strings.write_string(&b, `<?xml version="1.0" encoding="utf-8" standalone="yes"?>` + "\n")
	strings.write_string(&b, `<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">` + "\n")
	strings.write_string(&b, "  <channel>\n")

	fmt.sbprintfln(&b, "    <title>%s</title>", html_escape(w.config.title, w.scratch))
	fmt.sbprintfln(&b, "    <link>%s</link>", abs_url(w, page_url, w.scratch))
	fmt.sbprintfln(&b, "    <description>%s</description>", html_escape(w.config.description, w.scratch))
	strings.write_string(&b, "    <generator>ostat</generator>\n")
	fmt.sbprintfln(&b, "    <language>%s</language>", w.config.locale)

	if len(items) > 0 {
		fmt.sbprintfln(&b, "    <lastBuildDate>%s</lastBuildDate>", rfc822_date(items[0], w.scratch))
	}
	fmt.sbprintfln(
		&b,
		`    <atom:link href="%s" rel="self" type="application/rss+xml" />`,
		abs_url(w, feed_url, w.scratch),
	)

	for p, i in items {
		permalink := page_permalink(w, p, w.scratch)
		strings.write_string(&b, "    <item>\n")
		fmt.sbprintfln(&b, "      <title>%s</title>", html_escape(p.title, w.scratch))
		fmt.sbprintfln(&b, "      <link>%s</link>", permalink)
		fmt.sbprintfln(&b, "      <pubDate>%s</pubDate>", rfc822_date(p, w.scratch))
		fmt.sbprintfln(&b, "      <guid>%s</guid>", permalink)
		fmt.sbprintfln(&b, "      <description>%s</description>", html_escape(bodies[i], w.scratch))
		strings.write_string(&b, "    </item>\n")
	}

	strings.write_string(&b, "  </channel>\n</rss>\n")
	return strings.to_string(b)
}

// RFC 822, which is what RSS wants. Front matter carries a date and no time,
// so every post is stamped at midnight UTC.
rfc822_date :: proc(p: ^Page, allocator := context.allocator) -> string {
	if p.date == "" {
		return ""
	}

	t, ok := time.components_to_time(p.year, p.month, p.day, 0, 0, 0)
	if !ok {
		return ""
	}

	return fmt.aprintf(
		"%s, %02d %s %04d 00:00:00 +0000",
		WEEKDAY_ABBR[int(time.weekday(t))],
		p.day,
		MONTH_ABBR[p.month],
		p.year,
		allocator = allocator,
	)
}
