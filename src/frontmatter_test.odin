package main

import "core:testing"

@(test)
test_front_matter_valid :: proc(t: ^testing.T) {
	src := `---
{
    "title": "Kitchen Sink",
    "date": "2026-07-12",
    "draft": true
}
---

Body starts here.
`
	fm, body, err := parse_front_matter(src, context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.None)
	testing.expect_value(t, fm.title, "Kitchen Sink")
	testing.expect_value(t, fm.date, "2026-07-12")
	testing.expect_value(t, fm.draft, true)
	testing.expect_value(t, body, "Body starts here.\n")
}

@(test)
test_front_matter_no_opening_fence :: proc(t: ^testing.T) {
	_, _, err := parse_front_matter("# Just markdown\n", context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.No_Opening_Fence)
}

@(test)
test_front_matter_no_closing_fence :: proc(t: ^testing.T) {
	_, _, err := parse_front_matter("---\n{\"title\": \"x\"}\n", context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.No_Closing_Fence)
}

@(test)
test_front_matter_bad_json :: proc(t: ^testing.T) {
	_, _, err := parse_front_matter("---\n{\"title\": }\n---\n", context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.Bad_Json)
}

@(test)
test_front_matter_requires_title :: proc(t: ^testing.T) {
	_, _, err := parse_front_matter("---\n{\"date\": \"2026-07-12\"}\n---\n", context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.Missing_Title)
}

@(test)
test_front_matter_rejects_bad_date :: proc(t: ^testing.T) {
	src := "---\n{\"title\": \"x\", \"date\": \"2026-02-30\"}\n---\n"
	_, _, err := parse_front_matter(src, context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.Bad_Date)
}

@(test)
test_parse_date :: proc(t: ^testing.T) {
	y, m, d, ok := parse_date("2026-07-12")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, y, 2026)
	testing.expect_value(t, m, 7)
	testing.expect_value(t, d, 12)

	// A leading zero must not be read as octal.
	_, m, d, ok = parse_date("2026-08-09")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, m, 8)
	testing.expect_value(t, d, 9)

	// Leap years decide whether February has a 29th.
	_, _, _, ok = parse_date("2024-02-29")
	testing.expect_value(t, ok, true)
	_, _, _, ok = parse_date("2026-02-29")
	testing.expect_value(t, ok, false)

	for bad in ([]string{"2026-7-12", "2026/07/12", "", "2026-13-01", "2026-07-32"}) {
		_, _, _, ok = parse_date(bad)
		testing.expectf(t, !ok, "%q should not parse", bad)
	}
}

@(test)
test_title_from_slug :: proc(t: ^testing.T) {
	testing.expect_value(t, title_from_slug("a-new-post"), "A New Post")
	testing.expect_value(t, title_from_slug("ostat"), "Ostat")
}

@(test)
test_slug_rejects_traversal_and_separators :: proc(t: ^testing.T) {
	// A slug becomes a directory name. "../../x" used to create a directory
	// outside the output tree before the write failed.
	for bad in ([]string{"../../escaped", "..", "a/b", "a\\b", "a b", "", ".", "a\tb"}) {
		testing.expectf(t, !valid_slug(bad), "%q should be rejected", bad)
	}
	for good in ([]string{"a-post", "v1.2", "under_score", "ünïcode", "2026-07-29"}) {
		testing.expectf(t, valid_slug(good), "%q should be allowed", good)
	}
}

@(test)
test_front_matter_rejects_a_bad_slug :: proc(t: ^testing.T) {
	src := "---\n{\"title\": \"x\", \"slug\": \"../../evil\"}\n---\n"
	_, _, err := parse_front_matter(src, context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.Bad_Slug)
}
