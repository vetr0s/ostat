package main

import "core:fmt"
import "core:strings"

// Escaping, truncation, and the date and title shapes the layouts need.
//
// Nothing here reaches into the renderer. The description limit used to live
// in render.odin and be read from down here, which made the dependency run
// backwards and the layering unreadable.

// Hugo truncated the meta description at this many characters.
DESCRIPTION_LIMIT :: 160

@(rodata)
MONTHS := [13]string {
	"",
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

html_escape :: proc(s: string, allocator := context.allocator) -> string {
	if !strings.contains_any(s, `&<>"'`) {
		return s
	}

	b := strings.builder_make(allocator)
	for c in s {
		switch c {
		case '&':
			strings.write_string(&b, "&amp;")
		case '<':
			strings.write_string(&b, "&lt;")
		case '>':
			strings.write_string(&b, "&gt;")
		case '"':
			strings.write_string(&b, "&quot;")
		case '\'':
			strings.write_string(&b, "&#39;")
		case:
			strings.write_rune(&b, c)
		}
	}
	return strings.to_string(b)
}

// Drops every tag and decodes the handful of entities cmark emits, so that
// rendered HTML can stand in as a plain-text summary.
strip_tags :: proc(html: string, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)

	in_tag := false
	for i := 0; i < len(html); i += 1 {
		switch {
		case html[i] == '<':
			in_tag = true
		case html[i] == '>':
			in_tag = false
		case in_tag:
		// skipped
		case html[i] == '&':
			end := entity_end(html[i:])
			if end < 0 {
				strings.write_byte(&b, html[i])
				continue
			}
			strings.write_string(&b, decode_entity(html[i:i + end + 1]))
			i += end
		case:
			strings.write_byte(&b, html[i])
		}
	}
	return strings.to_string(b)
}

// The offset of the ';' closing an entity at the start of s, or -1.
//
// Bounded and shape-checked: a bare '&' used to search the whole remaining
// document for a ';' and swallow everything in between as one entity. cmark
// escapes a bare '&' before this ever sees one, so it took raw HTML to reach.
@(private = "file")
entity_end :: proc(s: string) -> int {
	// "&#x201C;" is the longest shape worth recognising; decode_entity knows
	// far fewer than that.
	for i := 1; i < len(s) && i <= 8; i += 1 {
		switch c := s[i]; {
		case c == ';':
			return i > 1 ? i : -1
		case c == '#' && i == 1:
		case c >= '0' && c <= '9', c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z':
		case:
			return -1
		}
	}
	return -1
}

@(private = "file")
decode_entity :: proc(e: string) -> string {
	switch e {
	case "&amp;":
		return "&"
	case "&lt;":
		return "<"
	case "&gt;":
		return ">"
	case "&quot;":
		return `"`
	case "&#39;", "&apos;":
		return "'"
	}
	return e
}

// Cuts at the last word boundary inside the limit and marks the cut, which is
// what Hugo's truncate did.
//
// The limit counts runes. It counted bytes and sliced at one, so a description
// with no ASCII space inside the limit was cut at an arbitrary byte offset and
// put a dangling continuation byte in a meta tag.
truncate_words :: proc(s: string, limit: int, allocator := context.allocator) -> string {
	// Both offsets are rune boundaries by construction, which is the whole
	// point of walking the string rather than indexing into it.
	cut, last_space := -1, -1

	count := 0
	for r, i in s {
		if count == limit {
			cut = i
			break
		}
		if r == ' ' {
			last_space = i
		}
		count += 1
	}
	if cut < 0 {
		return s
	}
	// A leading space is not a word boundary worth cutting at; fall back to the
	// limit rather than returning nothing but an ellipsis.
	if last_space > 0 {
		cut = last_space
	}
	return fmt.aprintf("%s…", strings.trim_right_space(s[:cut]), allocator = allocator)
}

page_title :: proc(w: ^Website, p: ^Page, allocator := context.allocator) -> string {
	if p.is_home {
		return w.config.title
	}
	return fmt.aprintf("%s · %s", p.title, w.config.title, allocator = allocator)
}

// Page description, then the opening prose, then the site's own. Whatever it
// lands on gets stripped of markup and cut to the meta description limit.
page_description :: proc(w: ^Website, p: ^Page, allocator := context.allocator) -> string {
	if p.description != "" {
		return truncate_words(p.description, DESCRIPTION_LIMIT, allocator)
	}
	if summary := first_paragraph(p.content, allocator); summary != "" {
		return truncate_words(summary, DESCRIPTION_LIMIT, allocator)
	}
	return truncate_words(w.config.description, DESCRIPTION_LIMIT, allocator)
}

// cmark has no equivalent of Hugo's .Summary, so the opening paragraph stands
// in for it.
first_paragraph :: proc(html: string, allocator := context.allocator) -> string {
	open := strings.index(html, "<p>")
	if open < 0 {
		return ""
	}
	rest := html[open + len("<p>"):]

	close := strings.index(rest, "</p>")
	if close < 0 {
		return ""
	}

	// Soft line breaks inside the paragraph are newlines in the HTML, and a
	// meta description is one line.
	text := strip_tags(rest[:close], allocator)
	flat, _ := strings.replace_all(text, "\n", " ", allocator)
	return strings.trim_space(flat)
}

// "2026-07-12" -> "July 12, 2026"
long_date :: proc(p: ^Page, allocator := context.allocator) -> string {
	if p.month < 1 || p.month > 12 {
		return p.date
	}
	return fmt.aprintf("%s %d, %d", MONTHS[p.month], p.day, p.year, allocator = allocator)
}

// The brand, with its accented tail wrapped. Both halves come from config;
// this used to split the title at its first dot, which is a rule about one
// domain living two files from anything that mentions it.
site_brand :: proc(w: ^Website, allocator := context.allocator) -> string {
	head := html_escape(w.config.brand.head, allocator)
	if w.config.brand.accent == "" {
		return head
	}
	return fmt.aprintf(
		`%s<span class="accent">%s</span>`,
		head,
		html_escape(w.config.brand.accent, allocator),
		allocator = allocator,
	)
}

// "en-us" -> "en", for the html lang attribute.
html_lang :: proc(w: ^Website) -> string {
	locale := w.config.locale
	if dash := strings.index_byte(locale, '-'); dash > 0 {
		return locale[:dash]
	}
	return locale
}
