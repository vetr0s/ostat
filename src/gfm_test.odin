package main

import "core:strings"
import "core:testing"

@(private = "file")
tables :: proc(src: string) -> string {
	w := new(Website, context.temp_allocator)
	w.perm = context.temp_allocator
	w.scratch = context.temp_allocator

	lines := split_source_lines(src, context.temp_allocator)
	return build_tables(w, lines, context.temp_allocator)
}

@(test)
test_strikethrough :: proc(t: ^testing.T) {
	out := replace_strikethrough("a ~~struck~~ b", context.temp_allocator)
	testing.expect_value(t, out, "a <del>struck</del> b")
}

@(test)
test_strikethrough_leaves_unpaired_markers :: proc(t: ^testing.T) {
	testing.expect_value(t, replace_strikethrough("a ~~b", context.temp_allocator), "a ~~b")
	testing.expect_value(t, replace_strikethrough("plain", context.temp_allocator), "plain")
}

@(test)
test_table_becomes_html :: proc(t: ^testing.T) {
	out := tables("| a | b |\n|---|---|\n| 1 | 2 |\n")
	testing.expect(t, strings.contains(out, "<table>"))
	testing.expect(t, strings.contains(out, "<th>a</th>"))
	testing.expect(t, strings.contains(out, "<td>1</td>"))
	testing.expect(t, strings.contains(out, "</table>"))
	// A blank line would close the HTML block early.
	testing.expect(t, !strings.contains(out, "\n\n<tr>"), "no blank line inside the block")
}

@(test)
test_table_cells_render_markdown :: proc(t: ^testing.T) {
	out := tables("| Path |\n|---|\n| `src/main.odin` |\n")
	testing.expect(t, strings.contains(out, "<td><code>src/main.odin</code></td>"))
}

@(test)
test_table_alignment :: proc(t: ^testing.T) {
	out := tables("| l | c | r | n |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |\n")
	testing.expect(t, strings.contains(out, `<th align="left">l</th>`))
	testing.expect(t, strings.contains(out, `<th align="center">c</th>`))
	testing.expect(t, strings.contains(out, `<th align="right">r</th>`))
	testing.expect(t, strings.contains(out, "<th>n</th>"), "no attribute for default")
}

@(test)
test_short_and_long_rows :: proc(t: ^testing.T) {
	out := tables("| a | b |\n|---|---|\n| 1 |\n| 1 | 2 | 3 |\n")
	testing.expect(t, strings.contains(out, "<td>1</td>\n<td></td>"), "short row padded")
	testing.expect(t, !strings.contains(out, "<td>3</td>"), "long row truncated")
}

@(test)
test_pipes_without_a_delimiter_row_are_not_a_table :: proc(t: ^testing.T) {
	out := tables("a | b is just prose\n\nmore prose\n")
	testing.expect(t, !strings.contains(out, "<table>"))
}

@(test)
test_mismatched_delimiter_width_is_not_a_table :: proc(t: ^testing.T) {
	out := tables("| a | b |\n|---|\n| 1 | 2 |\n")
	testing.expect(t, !strings.contains(out, "<table>"))
}
