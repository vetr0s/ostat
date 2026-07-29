package main

import "core:testing"

@(test)
test_html_escape :: proc(t: ^testing.T) {
	out := html_escape(`a & b < c > d " e ' f`, context.temp_allocator)
	testing.expect_value(t, out, "a &amp; b &lt; c &gt; d &quot; e &#39; f")
	// Untouched input is returned as-is rather than copied.
	testing.expect_value(t, html_escape("plain", context.temp_allocator), "plain")
}

@(test)
test_strip_tags :: proc(t: ^testing.T) {
	out := strip_tags("<p>A <a href=\"/x\">link</a> and <code>a &amp; b</code>.</p>", context.temp_allocator)
	testing.expect_value(t, out, "A link and a & b.")
}

@(test)
test_truncate_words :: proc(t: ^testing.T) {
	testing.expect_value(t, truncate_words("short", 160, context.temp_allocator), "short")
	// Cuts on a word boundary, not mid-word.
	testing.expect_value(t, truncate_words("one two three four", 12, context.temp_allocator), "one two…")
}

@(test)
test_first_paragraph :: proc(t: ^testing.T) {
	html := "<h1>T</h1>\n<p>The opening\nline.</p>\n<p>Second.</p>"
	testing.expect_value(t, first_paragraph(html, context.temp_allocator), "The opening line.")
	testing.expect_value(t, first_paragraph("<h1>only a heading</h1>", context.temp_allocator), "")
}

@(test)
test_page_description_falls_back :: proc(t: ^testing.T) {
	w := test_website()

	explicit := new(Page, w.perm)
	explicit.description = "Set by hand."
	explicit.content = "<p>Ignored.</p>"
	testing.expect_value(t, page_description(w, explicit, w.scratch), "Set by hand.")

	summarised := new(Page, w.perm)
	summarised.content = "<p>The opening prose.</p>"
	testing.expect_value(t, page_description(w, summarised, w.scratch), "The opening prose.")

	bare := new(Page, w.perm)
	testing.expect_value(t, page_description(w, bare, w.scratch), w.config.description)
}

@(test)
test_page_title :: proc(t: ^testing.T) {
	// The site's own title is set here rather than read from DEFAULT_SITE, so
	// this asserts how a title is composed instead of what one site is called.
	w := test_website()
	w.config.title = "Example"

	home := new(Page, w.perm)
	home.is_home = true
	testing.expect_value(t, page_title(w, home, w.scratch), "Example")

	page := new(Page, w.perm)
	page.title = "About"
	testing.expect_value(t, page_title(w, page, w.scratch), "About · Example")
}

@(test)
test_site_brand :: proc(t: ^testing.T) {
	w := test_website()

	w.config.brand = {head = "exam", accent = "ple"}
	testing.expect_value(t, site_brand(w, w.scratch), `exam<span class="accent">ple</span>`)

	// No accent: no span, rather than an empty one.
	w.config.brand = {head = "plain", accent = ""}
	testing.expect_value(t, site_brand(w, w.scratch), "plain")

	// Both halves are escaped.
	w.config.brand = {head = "a&b", accent = "<c>"}
	testing.expect_value(t, site_brand(w, w.scratch), `a&amp;b<span class="accent">&lt;c&gt;</span>`)
}

@(test)
test_html_lang :: proc(t: ^testing.T) {
	w := test_website()
	w.config.locale = "en-us"
	testing.expect_value(t, html_lang(w), "en")
	w.config.locale = "fr"
	testing.expect_value(t, html_lang(w), "fr")
}

@(test)
test_long_date :: proc(t: ^testing.T) {
	p := new(Page, context.temp_allocator)
	p.date, p.year, p.month, p.day = "2026-07-12", 2026, 7, 12
	testing.expect_value(t, long_date(p, context.temp_allocator), "July 12, 2026")

	// An undated page has nothing to format.
	undated := new(Page, context.temp_allocator)
	testing.expect_value(t, long_date(undated, context.temp_allocator), "")
}

@(test)
test_abs_url :: proc(t: ^testing.T) {
	w := test_website()
	w.config.base_url = "https://example.test/"
	// The trailing slash on the base must not double up.
	testing.expect_value(t, abs_url(w, "/blog/", w.scratch), "https://example.test/blog/")
	testing.expect_value(t, abs_url(w, "/", w.scratch), "https://example.test/")

	w.config.base_url = "https://example.test"
	testing.expect_value(t, abs_url(w, "/blog/", w.scratch), "https://example.test/blog/")
}
