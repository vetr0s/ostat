package main

import "core:strings"
import "core:testing"

/*
`ostat new` and `ostat build` have to agree about the file between them.

They did not: the archetype's front matter was written through fmt with a lone
`{`, which fmt read as a formatting directive, so every new page opened with
`%!(MISSING CLOSE BRACE)` and failed to parse the moment it was built. The
command reported success, and the error arrived later and somewhere else.
*/

@(test)
test_archetype_round_trips_through_the_parser :: proc(t: ^testing.T) {
	body := archetype_body("A New Post", 2026, 7, 12, context.temp_allocator)

	fm, rest, err := parse_front_matter(body, context.temp_allocator)
	testing.expectf(t, err == .None, "the archetype should parse, got %v", err)
	testing.expect_value(t, fm.title, "A New Post")
	testing.expect_value(t, fm.date, "2026-07-12")
	testing.expect(t, fm.draft, "a new page starts as a draft")

	// The body is empty on purpose: the command creates a page to write, not a
	// page with placeholder prose in it.
	testing.expect_value(t, strings.trim_space(rest), "")
}

@(test)
test_archetype_pads_single_digit_dates :: proc(t: ^testing.T) {
	// Zero padding is what makes the date parse. "2026-7-2" is rejected, and
	// the failure would only show on nine days of the month.
	body := archetype_body("X", 2026, 7, 2, context.temp_allocator)
	testing.expect(t, strings.contains(body, `"date": "2026-07-02"`), body)

	fm, _, err := parse_front_matter(body, context.temp_allocator)
	testing.expect_value(t, err, Front_Matter_Error.None)
	testing.expect_value(t, fm.date, "2026-07-02")
}

@(test)
test_archetype_escapes_a_quoted_title :: proc(t: ^testing.T) {
	// %q quotes and escapes, so a title carrying a quote stays valid JSON
	// rather than closing the string early.
	body := archetype_body(`A "Quoted" Title`, 2026, 1, 1, context.temp_allocator)

	fm, _, err := parse_front_matter(body, context.temp_allocator)
	testing.expectf(t, err == .None, "a quoted title should still parse, got %v", err)
	testing.expect_value(t, fm.title, `A "Quoted" Title`)
}
