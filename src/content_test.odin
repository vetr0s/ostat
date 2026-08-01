package main

import "core:testing"

/*
Discovery, and the shapes it refuses.

Everything here was once a build that exited 0 and wrote a site that was wrong
in a way nothing on the site revealed. A generator this small has no reason to
guess: the only useful thing it can do with an ambiguous content tree is name
the files and stop.
*/

@(private = "file")
discover :: proc(fixture: string) -> bool {
	w := test_website()
	defer test_website_destroy(w)
	w.opts.site_dir = fixture
	return collect_content(w)
}

@(test)
test_two_pages_may_not_claim_one_path :: proc(t: ^testing.T) {
	// Both pages stayed in w.pages, so both were listed and both reached the
	// sitemap, while the later write took the path they shared.
	testing.expect(t, !discover("tests/fixture-duplicate-slug"), "a duplicate slug is rejected")
}

@(test)
test_sections_do_not_nest :: proc(t: ^testing.T) {
	// blog/2024/nested.md got section "blog/2024", which matches neither
	// BLOG_SECTION nor the blog section page, so it was built and crawlable
	// and reachable from nowhere on the site.
	testing.expect(t, !discover("tests/fixture-nested-section"), "a nested section is rejected")
}

@(test)
test_a_section_needs_an_index :: proc(t: ^testing.T) {
	// Every page in notes/ linked a breadcrumb to /notes/, which was never
	// written because the directory had no _index.md.
	testing.expect(t, !discover("tests/fixture-sectionless"), "a section without an index is rejected")
}

@(test)
test_a_section_name_has_to_survive_being_a_path :: proc(t: ^testing.T) {
	// A directory name becomes a URL path segment, an output directory, and an
	// href in every breadcrumb inside it. A slug is checked for exactly that,
	// and a directory name had never been checked at all.
	testing.expect(t, !discover("tests/fixture-bad-section"), "a section name with a space is rejected")
}

@(test)
test_the_home_page_is_not_authored_in_content :: proc(t: ^testing.T) {
	// It was loaded, written, and then overwritten by the synthesised home
	// page, which is appended after the walk. Both carried url "/", so the
	// sitemap listed the front page twice and the authored file was gone.
	testing.expect(t, !discover("tests/fixture-root-index"), "a root _index.md is rejected")
}
