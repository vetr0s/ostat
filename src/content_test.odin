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
