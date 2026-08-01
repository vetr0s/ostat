package main

import "core:testing"

/*
The fragments are what makes one binary able to build a second site's chrome.
They were #load-ed at compile time, which is correct for a generator that
builds exactly one site and quietly wrong for one that does not.
*/

@(test)
test_a_site_overrides_only_the_fragments_it_supplies :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)
	w.opts.site_dir = "tests/fixture-fragments"

	testing.expect(t, load_fragments(w), "fragments loaded")
	testing.expect_value(t, w.fragments.header_02, "</head>\n<body>\n")

	// The two it does not supply keep the built-in defaults, the same way a
	// site.json that omits a key does.
	testing.expect_value(t, w.fragments.header_01, DEFAULT_FRAGMENTS.header_01)
	testing.expect_value(t, w.fragments.not_found, DEFAULT_FRAGMENTS.not_found)
}

@(test)
test_a_site_without_an_html_directory_still_builds :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)
	w.opts.site_dir = "tests/fixture-config-none"

	testing.expect(t, load_fragments(w), "a missing html directory is not an error")
	testing.expect_value(t, w.fragments.header_01, DEFAULT_FRAGMENTS.header_01)
	testing.expect_value(t, w.fragments.header_02, DEFAULT_FRAGMENTS.header_02)
	testing.expect_value(t, w.fragments.not_found, DEFAULT_FRAGMENTS.not_found)
}
