package main

import "core:testing"

/*
Argument parsing.

`ostat build p -o -drafts` created a directory named "-drafts", built into it,
and printed "built 3 pages into -drafts". Every flag that takes a value had the
same hole, and none of it was reachable from a test while the two parse
procedures were file-private.
*/

@(test)
test_build_flags_take_their_values :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)

	testing.expect(
		t,
		parse_build_args(w, {"site", "-o", "out", "-base-url", "https://x.test/", "-today", "2026-03-04"}),
		"a well-formed command line parses",
	)
	testing.expect_value(t, w.opts.site_dir, "site")
	testing.expect_value(t, w.opts.out_dir, "out")
	testing.expect_value(t, w.opts.base_url, "https://x.test/")
	testing.expect_value(t, w.today, "2026-03-04")
}

@(test)
test_a_flag_is_not_a_value :: proc(t: ^testing.T) {
	cases := [][]string {
		{"p", "-o", "-drafts"},
		{"p", "-base-url", "-future"},
		{"p", "-today", "-drafts"},
		{"p", "-o"},
		{"p", "-base-url"},
		{"p", "-today"},
	}
	for args in cases {
		w := test_website()
		defer test_website_destroy(w)
		testing.expectf(t, !parse_build_args(w, args), "%v should be rejected", args)
	}
}

@(test)
test_new_path_and_site_dir :: proc(t: ^testing.T) {
	rel, site_dir, ok := parse_new_args({"blog/a-post", "-s", "site"})
	testing.expect(t, ok, "a well-formed command line parses")
	testing.expect_value(t, rel, "blog/a-post")
	testing.expect_value(t, site_dir, "site")

	// The same hole: -s took whatever followed, including another flag.
	_, _, taken := parse_new_args({"a-post", "-s", "-drafts"})
	testing.expect(t, !taken, "-s should not swallow a flag")

	_, _, bare := parse_new_args({"a-post", "-s"})
	testing.expect(t, !bare, "-s needs a value")
}
