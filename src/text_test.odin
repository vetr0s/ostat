package main

import "core:testing"

@(private = "file")
config_website :: proc() -> ^Website {
	w := new(Website, context.temp_allocator)
	w.perm = context.temp_allocator
	w.scratch = context.temp_allocator
	w.config = DEFAULT_SITE
	return w
}

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
	w := config_website()

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
	w := config_website()

	home := new(Page, w.perm)
	home.is_home = true
	testing.expect_value(t, page_title(w, home, w.scratch), "vetr0s.dev")

	page := new(Page, w.perm)
	page.title = "About"
	testing.expect_value(t, page_title(w, page, w.scratch), "About · vetr0s.dev")
}

@(test)
test_site_brand_and_lang :: proc(t: ^testing.T) {
	w := config_website()
	testing.expect_value(t, site_brand(w, w.scratch), `vetr0s<span class="accent">.dev</span>`)
	testing.expect_value(t, html_lang(w), "en")
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
	w := config_website()
	testing.expect_value(t, abs_url(w, "/blog/", w.scratch), "https://vetr0s.dev/blog/")
	testing.expect_value(t, abs_url(w, "/", w.scratch), "https://vetr0s.dev/")
}
