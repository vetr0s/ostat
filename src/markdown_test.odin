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
test_undefined_note_is_an_error :: proc(t: ^testing.T) {
	_, _, ok := run("A claim[^missing] stands.\n")
	testing.expect_value(t, ok, false)
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
