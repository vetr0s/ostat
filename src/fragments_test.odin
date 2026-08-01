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
	testing.expect_value(t, w.fragments.home, DEFAULT_FRAGMENTS.home)
	testing.expect_value(t, w.fragments.not_found, DEFAULT_FRAGMENTS.not_found)
}

@(test)
test_a_home_fragment_needs_the_recent_marker :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)
	w.opts.site_dir = "tests/fixture-fragments-no-marker"

	// The recent posts are the one part of that page the site cannot write for
	// itself, so a fragment with nowhere to put them is a mistake in the file.
	// Caught here rather than at render time, where the file is harder to name.
	testing.expect(t, !load_fragments(w), "a home page without the marker is rejected")
}
