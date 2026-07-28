package main

import "core:fmt"
import "core:strings"

/*
The two GFM extensions the content needs and libcmark does not have: pipe
tables and strikethrough. Both are rewritten to raw HTML before cmark runs.

A table becomes an HTML block, and cmark does not parse markdown inside one,
so each cell is rendered on its own first. The block carries no blank line,
because a blank line is what ends an HTML block.

Escaped pipes (`\|`) inside a cell are not supported. Nothing in the content
needs one.
*/

Align :: enum {
	None,
	Left,
	Center,
	Right,
}

// `~~text~~` -> `<del>text</del>`. The inner text stays markdown; whatever
// renders the surrounding line handles it.
replace_strikethrough :: proc(text: string, allocator := context.allocator) -> string {
	if !strings.contains(text, "~~") {
		return text
	}

	b := strings.builder_make(allocator)
	rest := text

	for {
		open := strings.index(rest, "~~")
		if open < 0 {
			break
		}
		after := rest[open + 2:]
		close := strings.index(after, "~~")
		if close < 0 {
			break
		}

		strings.write_string(&b, rest[:open])
		fmt.sbprintf(&b, "<del>%s</del>", after[:close])
		rest = after[close + 2:]
	}

	strings.write_string(&b, rest)
	return strings.to_string(b)
}

// A table is a header row, a delimiter row with the same cell count, and any
// number of body rows after it.
scan_table :: proc(
	lines: []Line,
	start: int,
) -> (
	aligns: []Align,
	rows: int,
	width: int,
	ok: bool,
) {
	if start + 1 >= len(lines) {
		return
	}
	if !strings.contains(lines[start].text, "|") {
		return
	}

	aligns, ok = parse_delimiter_row(lines[start + 1].text)
	if !ok {
		return
	}

	header := split_row(lines[start].text)
	if len(header) != len(aligns) {
		return nil, 0, 0, false
	}
	width = len(aligns)

	rows = 2
	for start + rows < len(lines) {
		line := lines[start + rows]
		if line.fence || !strings.contains(line.text, "|") {
			break
		}
		rows += 1
	}
	return
}

@(private = "file")
parse_delimiter_row :: proc(text: string) -> (aligns: []Align, ok: bool) {
	cells := split_row(text)
	if len(cells) == 0 {
		return
	}

	aligns = make([]Align, len(cells), context.temp_allocator)
	for cell, i in cells {
		left := strings.has_prefix(cell, ":")
		right := strings.has_suffix(cell, ":")

		bar := cell
		if left {bar = bar[1:]}
		if right && len(bar) > 0 {bar = bar[:len(bar) - 1]}
		if len(bar) == 0 {
			return nil, false
		}
		for c in bar {
			if c != '-' {
				return nil, false
			}
		}

		switch {
		case left && right:
			aligns[i] = .Center
		case left:
			aligns[i] = .Left
		case right:
			aligns[i] = .Right
		case:
			aligns[i] = .None
		}
	}
	return aligns, true
}

// Strips the optional outer pipes, splits on the rest, trims each cell.
@(private = "file")
split_row :: proc(text: string) -> []string {
	t := strings.trim_space(text)
	t = strings.trim_prefix(t, "|")
	t = strings.trim_suffix(t, "|")

	cells := strings.split(t, "|", context.temp_allocator)
	for &cell in cells {
		cell = strings.trim_space(cell)
	}
	return cells
}

write_table :: proc(w: ^Website, b: ^strings.Builder, rows: []Line, aligns: []Align) {
	strings.write_string(b, "<table>\n<thead>\n")
	write_row(w, b, rows[0].text, aligns, "th")
	strings.write_string(b, "</thead>\n<tbody>\n")
	for row in rows[2:] {
		write_row(w, b, row.text, aligns, "td")
	}
	strings.write_string(b, "</tbody>\n</table>\n")
}

@(private = "file")
write_row :: proc(w: ^Website, b: ^strings.Builder, text: string, aligns: []Align, tag: string) {
	cells := split_row(text)

	strings.write_string(b, "<tr>\n")
	for align, i in aligns {
		// Short rows are padded and long ones truncated, as GFM does.
		cell := i < len(cells) ? cells[i] : ""
		fmt.sbprintf(b, "<%s%s>%s</%s>\n", tag, align_attr(align), md_inline(cell, w.scratch), tag)
	}
	strings.write_string(b, "</tr>\n")
}

@(private = "file")
align_attr :: proc(align: Align) -> string {
	switch align {
	case .Left:
		return ` align="left"`
	case .Center:
		return ` align="center"`
	case .Right:
		return ` align="right"`
	case .None:
		return ""
	}
	return ""
}
