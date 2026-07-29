package main

import "core:strings"
import "core:testing"

@(private = "file")
run :: proc(body: string) -> (out: string, notes: []Note, ok: bool) {
	w := test_website()
	p := test_page(w, body)
	out, ok = preprocess(w, p)
	return out, p.notes[:], ok
}

@(test)
test_note_marker_and_definition_pair_up :: proc(t: ^testing.T) {
	out, notes, ok := run("A claim[^why] stands.\n\n[^why]: Because.\n")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(notes), 1)
	testing.expect_value(t, notes[0].label, "why")
	testing.expect_value(t, notes[0].html, "Because.")

	testing.expect(t, strings.contains(out, `for="sn-why"`), "label targets the input")
	testing.expect(t, strings.contains(out, `id="sn-why"`), "input carries the id")
	testing.expect(t, strings.contains(out, `<span class="sidenote">Because.</span>`))
	// The definition line itself must not survive into the output.
	testing.expect(t, !strings.contains(out, "[^why]:"), "definition was removed")
}

@(test)
test_note_definition_continuation_lines :: proc(t: ^testing.T) {
	_, notes, ok := run("A claim[^why].\n\n[^why]: First line\n    and its continuation.\n")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(notes), 1)
	testing.expect_value(t, notes[0].desc, "First line and its continuation.")
}

@(test)
test_note_body_renders_markdown :: proc(t: ^testing.T) {
	_, notes, ok := run("A claim[^why].\n\n[^why]: With a [link](/x/) and `code`.\n")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, notes[0].html, `With a <a href="/x/">link</a> and <code>code</code>.`)
}

@(test)
test_note_marker_before_definition :: proc(t: ^testing.T) {
	// The definition may sit anywhere in the file, including after the marker.
	out, _, ok := run("Claim[^a] here.\n\n[^a]: Defined later.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "Defined later."))
}

@(test)
test_unmatched_marker_is_prose :: proc(t: ^testing.T) {
	// This used to fail the build. `[^` is ordinary text far more often than
	// it is a note, so an unresolved one is left alone.
	out, notes, ok := run("A claim[^missing] stands.\n")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(notes), 0)
	testing.expect(t, strings.contains(out, "[^missing]"), "left as written")
}

@(test)
test_regex_in_a_code_span_builds :: proc(t: ^testing.T) {
	// The reported bug: a POSIX character class aborted the build with an
	// error naming a note nobody wrote.
	out, _, ok := run("Match a non-letter with `[^a-z]+` in your pattern.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "[^a-z]+"), "the class survives intact")
}

@(test)
test_a_mistyped_label_is_still_caught :: proc(t: ^testing.T) {
	// Nothing resolves the marker, so it stays prose — but the definition it
	// was meant to reach goes unused, and that fails the build.
	_, _, ok := run("A claim[^tpyo].\n\n[^typo]: The note.\n")
	testing.expect_value(t, ok, false)
}

@(test)
test_a_real_marker_after_an_unmatched_one_still_resolves :: proc(t: ^testing.T) {
	out, _, ok := run("A `[^set]` then a claim[^real].\n\n[^real]: Note.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "[^set]"), "the first is prose")
	testing.expect(t, strings.contains(out, `class="sidenote"`), "the second is a note")
}

@(test)
test_unused_note_is_an_error :: proc(t: ^testing.T) {
	_, _, ok := run("Nothing refers to it.\n\n[^orphan]: Alone.\n")
	testing.expect_value(t, ok, false)
}

@(test)
test_duplicate_note_label_is_an_error :: proc(t: ^testing.T) {
	_, _, ok := run("Claim[^a].\n\n[^a]: One.\n\n[^a]: Two.\n")
	testing.expect_value(t, ok, false)
}

@(test)
test_fenced_code_is_left_alone :: proc(t: ^testing.T) {
	body := "```text\nnot a note[^x] and not ~~struck~~\n```\n"
	out, notes, ok := run(body)
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(notes), 0)
	testing.expect(t, strings.contains(out, "not a note[^x]"), "marker untouched in a fence")
	testing.expect(t, strings.contains(out, "~~struck~~"), "strikethrough untouched in a fence")
}

@(test)
test_raw_html_survives :: proc(t: ^testing.T) {
	w := test_website()
	p := test_page(w, "<figure>\n<img src=\"/a.png\" />\n<figcaption>Cap.</figcaption>\n</figure>\n")
	src, ok := preprocess(w, p)
	testing.expect_value(t, ok, true)

	html := md_block(src, context.temp_allocator)
	testing.expect(t, strings.contains(html, "<figure>"), "figure survives cmark")
	testing.expect(t, strings.contains(html, "<figcaption>Cap.</figcaption>"))
}

@(test)
test_inline_code_spans_are_left_alone :: proc(t: ^testing.T) {
	out, notes, ok := run("Match `[^a-z]+` and write `a ~~ b` in prose.\n")
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(notes), 0)
	testing.expect(t, strings.contains(out, "`[^a-z]+`"), "marker untouched in a span")
	testing.expect(t, strings.contains(out, "`a ~~ b`"), "tildes untouched in a span")
	testing.expect(t, !strings.contains(out, "<del>"), "no strikethrough injected")
}

@(test)
test_strikethrough_still_works_outside_a_span :: proc(t: ^testing.T) {
	out, _, ok := run("A ~~struck~~ word beside `code`.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "<del>struck</del>"), "prose still rewritten")
	testing.expect(t, strings.contains(out, "`code`"), "the span reaches cmark intact")
}

@(test)
test_double_backtick_span_holds_a_single_backtick :: proc(t: ^testing.T) {
	// A run only closes on a run of its own length.
	out, _, ok := run("Write ``a ` b ~~c~~`` here.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, !strings.contains(out, "<del>"), "the whole span is code")
}

@(test)
test_a_code_span_may_cross_a_line :: proc(t: ^testing.T) {
	out, _, ok := run("Start `a\n~~b~~ c` end.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, !strings.contains(out, "<del>"), "span continues onto the next line")
}

@(test)
test_a_span_does_not_leak_past_a_paragraph :: proc(t: ^testing.T) {
	// An unclosed backtick must not silence the rest of the document.
	out, _, ok := run("An unclosed ` tick.\n\nA ~~struck~~ word after it.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "<del>struck</del>"), "next paragraph is prose again")
}

@(test)
test_a_longer_fence_holds_a_shorter_one :: proc(t: ^testing.T) {
	// How you document Markdown. The inner run must not close the outer block.
	body := "````text\n```\nnot ~~struck~~ and not a note[^x]\n```\n````\n"
	out, notes, ok := run(body)
	testing.expect_value(t, ok, true)
	testing.expect_value(t, len(notes), 0)
	testing.expect(t, strings.contains(out, "~~struck~~"), "inner content untouched")
	testing.expect(t, strings.contains(out, "[^x]"), "marker untouched")
}

@(test)
test_a_fence_closes_only_on_its_own_character :: proc(t: ^testing.T) {
	// A ~~~ line inside a ``` block is content, not a closing fence.
	out, _, ok := run("```\n~~~\n~~struck~~\n```\n\nA ~~real~~ one after.\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "~~struck~~"), "inside the block, untouched")
	testing.expect(t, strings.contains(out, "<del>real</del>"), "outside it, rewritten")
}

@(test)
test_a_closing_fence_takes_no_info_string :: proc(t: ^testing.T) {
	// text, so the highlighter does not wrap tokens and the assertion can be
	// on the literal content.
	out, _, ok := run("```text\ninside\n```text\nstill inside\n```\n")
	testing.expect_value(t, ok, true)
	testing.expect(t, strings.contains(out, "still inside"), "the middle line did not close it")
	testing.expect(t, strings.contains(out, "```text"), "it is content, not markup")
}

@(test)
test_a_fence_inside_a_list_stays_in_the_list :: proc(t: ^testing.T) {
	// It used to end the list and hoist the block to the top level.
	w := test_website()
	p := test_page(w, "- item\n\n  ```odin\n  x := 1\n  y := 2\n  ```\n\n- second\n")
	src, ok := preprocess(w, p)
	testing.expect_value(t, ok, true)

	html := md_block(src, w.scratch)
	testing.expect(t, strings.count(html, "<ul>") == 1, "one list, not two")
	testing.expect(t, strings.contains(html, "</code></pre>\n</li>"), "the block is inside the item")
	// The list's indentation belongs to the item, not to the code.
	testing.expect(t, !strings.contains(html, ">  x := "), "code is dedented")
	testing.expect(t, strings.contains(html, "&#10;"), "newlines ride as entities")
}

@(test)
test_a_top_level_fence_is_written_plainly :: proc(t: ^testing.T) {
	// No entity newlines when there is no list item to stay inside.
	w := test_website()
	p := test_page(w, "```text\na\nb\n```\n")
	src, _ := preprocess(w, p)

	html := md_block(src, w.scratch)
	testing.expect(t, strings.contains(html, "a\nb"), "real newlines")
	testing.expect(t, !strings.contains(html, "&#10;"))
}
