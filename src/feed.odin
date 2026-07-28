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

	write_feed(w, "/index.xml", "/", items, bodies) or_return
	write_feed(w, "/" + BLOG_SECTION + "/index.xml", "/" + BLOG_SECTION + "/", items, bodies) or_return
	return true
}

// The post as a feed reader should see it: full content, endnotes appended.
@(private = "file")
feed_item_content :: proc(w: ^Website, p: ^Page) -> (content: string, ok: bool) {
	src := preprocess(w, p, .Endnote) or_return

	b := strings.builder_make(w.scratch)
	strings.write_string(&b, md_block(src, w.scratch))
	write_endnote_list(w, &b, p)
	return absolutize_urls(w, strings.to_string(b), w.scratch), true
}

// A feed item is read on someone else's host, where a root-relative link
// resolves against their document rather than this site. Every href and src
// that starts at the root is rewritten to an absolute URL.
absolutize_urls :: proc(w: ^Website, html: string, allocator := context.allocator) -> string {
	base := strings.trim_suffix(w.config.base_url, "/")

	b := strings.builder_make(allocator)
	rest := html

	for {
		i := next_root_relative(rest)
		if i < 0 {
			break
		}
		strings.write_string(&b, rest[:i])
		strings.write_string(&b, base)
		rest = rest[i:]
	}

	strings.write_string(&b, rest)
	return strings.to_string(b)
}

// The offset of the `/` opening a root-relative href or src value, or -1.
@(private = "file")
next_root_relative :: proc(html: string) -> int {
	offset := 0
	for {
		rest := html[offset:]

		href := strings.index(rest, `href="/`)
		src := strings.index(rest, `src="/`)

		i, width: int
		switch {
		case href < 0 && src < 0:
			return -1
		case src < 0 || (href >= 0 && href < src):
			i, width = href, len(`href="`)
		case:
			i, width = src, len(`src="`)
		}

		slash := offset + i + width
		// A protocol-relative URL is already absolute enough.
		if slash + 1 >= len(html) || html[slash + 1] != '/' {
			return slash
		}
		offset = slash + 1
	}
}

@(private = "file")
write_feed :: proc(w: ^Website, feed_url, page_url: string, items: []^Page, bodies: []string) -> bool {
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
	return write_output(w, feed_url[1:], strings.to_string(b))
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
