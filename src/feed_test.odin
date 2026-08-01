package main

import "core:strings"
import "core:testing"

@(private = "file")
endnote_html :: proc(body: string) -> (string, ^Page) {
	w := test_website()
	w.config.base_url = "https://example.test/"
	p := test_page(w, body)

	src, ok := preprocess(w, p, .Endnote)
	if !ok {
		return "", p
	}

	b := strings.builder_make(w.scratch)
	strings.write_string(&b, md_block(src, w.scratch))
	write_endnote_list(w, &b, p)
	return strings.to_string(b), p
}

@(test)
test_rfc822_date :: proc(t: ^testing.T) {
	p := new(Page, context.temp_allocator)
	p.date, p.stamp = "2026-07-12", {year = 2026, month = 7, day = 12}
	testing.expect_value(t, rfc822_date(p, context.temp_allocator), "Sun, 12 Jul 2026 00:00:00 +0000")

	p.date, p.stamp = "2026-07-27", {year = 2026, month = 7, day = 27}
	testing.expect_value(t, rfc822_date(p, context.temp_allocator), "Mon, 27 Jul 2026 00:00:00 +0000")

	// A stamp carrying a time reaches the feed as that time. Every post used
	// to be published at midnight because that was the only thing it could say.
	p.date, p.stamp = "2026-07-27T14:30:05", {2026, 7, 27, 14, 30, 5}
	testing.expect_value(t, rfc822_date(p, context.temp_allocator), "Mon, 27 Jul 2026 14:30:05 +0000")

	undated := new(Page, context.temp_allocator)
	testing.expect_value(t, rfc822_date(undated, context.temp_allocator), "")
}

@(test)
test_feed_collapses_notes_to_endnotes :: proc(t: ^testing.T) {
	out, _ := endnote_html("A claim[^why].\n\n[^why]: Because.\n")

	testing.expect(t, !strings.contains(out, "sidenote"), "no margin markup in a feed")
	testing.expect(t, !strings.contains(out, "margin-toggle"), "no toggle in a feed")
	testing.expect(t, strings.contains(out, `id="fnref-1"`), "marker is anchorable")
	testing.expect(t, strings.contains(out, `<li id="fn-1">Because.`), "note is listed")
}

@(test)
test_feed_anchors_are_absolute :: proc(t: ^testing.T) {
	out, _ := endnote_html("A claim[^why].\n\n[^why]: Because.\n")

	testing.expect(
		t,
		strings.contains(out, `href="https://example.test/blog/test/#fn-1"`),
		"marker points at the post, not the reader's document",
	)
	testing.expect(
		t,
		strings.contains(out, `href="https://example.test/blog/test/#fnref-1"`),
		"back-link points at the post",
	)
}

@(test)
test_endnotes_number_by_marker_order :: proc(t: ^testing.T) {
	// Definitions written in the opposite order to their markers.
	out, p := endnote_html("First[^b] then second[^a].\n\n[^a]: A.\n\n[^b]: B.\n")

	testing.expect_value(t, len(p.notes), 2)
	for note in p.notes {
		expected := 1 if note.label == "b" else 2
		testing.expectf(t, note.number == expected, "note %q got number %d", note.label, note.number)
	}
	testing.expect(t, strings.contains(out, `<li id="fn-1">B.`), "the first marker is note 1")
	testing.expect(t, strings.contains(out, `<li id="fn-2">A.`), "the second marker is note 2")
}

@(test)
test_a_second_render_does_not_duplicate_notes :: proc(t: ^testing.T) {
	// The page is rendered once for HTML and again for the feed.
	w := test_website()
	p := test_page(w, "A claim[^why].\n\n[^why]: Because.\n")

	_, ok := preprocess(w, p, .Margin)
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(p.notes), 1)

	_, ok = preprocess(w, p, .Endnote)
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(p.notes), 1)
	testing.expect_value(t, p.notes[0].number, 1)
}

@(test)
test_page_without_notes_gets_no_endnote_list :: proc(t: ^testing.T) {
	out, _ := endnote_html("Nothing to annotate.\n")
	testing.expect(t, !strings.contains(out, "footnotes"), "no empty list")
}

@(test)
test_feed_urls_are_absolute :: proc(t: ^testing.T) {
	w := test_website()
	w.config.base_url = "https://example.test/"
	in_ := `<a href="/colophon/">c</a> <img src="/img/a.png"> <a href="https://x.dev/">x</a>`
	out := absolutize_urls(w, in_, w.scratch)

	testing.expect(t, strings.contains(out, `href="https://example.test/colophon/"`), "href absolute")
	testing.expect(t, strings.contains(out, `src="https://example.test/img/a.png"`), "src absolute")
	testing.expect(t, strings.contains(out, `href="https://x.dev/"`), "external link untouched")
}

@(test)
test_protocol_relative_urls_are_left_alone :: proc(t: ^testing.T) {
	w := test_website()
	out := absolutize_urls(w, `<img src="//cdn.example/a.png">`, w.scratch)
	testing.expect_value(t, out, `<img src="//cdn.example/a.png">`)
}

// cmark writes double-quoted href and src and nothing else, so every shape
// below arrives only through raw HTML written into a post. A feed item that
// keeps a root-relative URL resolves it against the reader's host, and the
// generator cannot see that it happened.
@(test)
test_feed_absolutises_every_url_shape :: proc(t: ^testing.T) {
	w := test_website()
	w.config.base_url = "https://example.test/"

	cases := [][2]string {
		{`<a href='/x/'>x</a>`, `<a href='https://example.test/x/'>x</a>`},
		{`<img src=/a.png>`, `<img src=https://example.test/a.png>`},
		{`<video poster="/p.jpg"></video>`, `<video poster="https://example.test/p.jpg"></video>`},
		{`<blockquote cite="/src/">q</blockquote>`, `<blockquote cite="https://example.test/src/">q</blockquote>`},
		{
			`<img srcset="/a.png 1x, /b.png 2x">`,
			`<img srcset="https://example.test/a.png 1x, https://example.test/b.png 2x">`,
		},
		{`<div style="background: url(/bg.png)"></div>`, `<div style="background: url(https://example.test/bg.png)"></div>`},
		{`<div style="background: url('/bg.png')"></div>`, `<div style="background: url('https://example.test/bg.png')"></div>`},
		// A longer name that merely ends in one of the attributes is not a URL
		// to the browser and must not be rewritten.
		{`<a data-href="/x/">x</a>`, `<a data-href="/x/">x</a>`},
	}
	for c in cases {
		testing.expect_value(t, absolutize_urls(w, c[0], w.scratch), c[1])
	}
}
