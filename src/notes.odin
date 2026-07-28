package main

import "core:fmt"
import "core:slice"
import "core:strings"

/*
Margin notes, in the Tufte CSS shape gingerBill's site uses.

Authoring is standard Markdown footnote syntax: a `[^label]` marker where the
claim is, and a `[^label]: text` definition anywhere in the file. Definitions
continue onto following indented lines.

The generator emits no numbers. The visible number comes from a CSS counter,
so numbering is a stylesheet concern and there is nothing here to keep in
sync. The checkbox is the narrow-screen toggle, not a control: below the
breakpoint the margin has nowhere to go and the note folds inline.
*/

MARKER_OPEN :: "[^"

// Namespaces the id. Labels are author-written words, and a note labelled
// "recent" would otherwise collide with the home page's section id.
NOTE_ID_PREFIX :: "sn-"

// Pulls every definition out of the line list and renders its body, returning
// the lines that remain.
collect_notes :: proc(w: ^Website, p: ^Page, lines: []Line) -> (kept: []Line, ok: bool) {
	out := make([dynamic]Line, 0, len(lines), w.scratch)

	// The feed renders each post a second time, so this starts from empty
	// rather than appending to what the first pass found.
	clear(&p.notes)

	i := 0
	for i < len(lines) {
		line := lines[i]
		label, first, is_def := parse_note_definition(line.text)
		if line.fence || !is_def {
			append(&out, line)
			i += 1
			continue
		}

		desc := strings.builder_make(w.scratch)
		strings.write_string(&desc, first)

		// Continuation lines are indented and non-blank, as in Markdown.
		for i + 1 < len(lines) {
			next := lines[i + 1]
			if next.fence || !is_indented(next.text) {
				break
			}
			strings.write_byte(&desc, ' ')
			strings.write_string(&desc, strings.trim_space(next.text))
			i += 1
		}
		i += 1

		validate_note_label(p, label) or_return
		append(
			&p.notes,
			Note {
				label = strings.clone(label, w.perm),
				desc = strings.clone(strings.to_string(desc), w.perm),
				html = md_inline(strings.to_string(desc), w.perm),
			},
		)
	}

	return out[:], true
}

@(private = "file")
parse_note_definition :: proc(text: string) -> (label, first: string, ok: bool) {
	if !strings.has_prefix(text, MARKER_OPEN) {
		return
	}
	rest := text[len(MARKER_OPEN):]

	close := strings.index_byte(rest, ']')
	if close < 0 || close + 1 >= len(rest) || rest[close + 1] != ':' {
		return
	}

	label = rest[:close]
	first = strings.trim_space(rest[close + 2:])
	ok = true
	return
}

@(private = "file")
is_indented :: proc(text: string) -> bool {
	return len(text) > 0 && (text[0] == ' ' || text[0] == '\t') && strings.trim_space(text) != ""
}

@(private = "file")
validate_note_label :: proc(p: ^Page, label: string) -> bool {
	if label == "" {
		fmt.eprintfln("ostat: %s: a note definition has an empty label", p.source)
		return false
	}
	for c in label {
		if c == ' ' || c == '\t' {
			fmt.eprintfln("ostat: %s: note label %q contains whitespace", p.source, label)
			return false
		}
	}
	for note in p.notes {
		if note.label == label {
			fmt.eprintfln("ostat: %s: note %q is defined twice", p.source, label)
			return false
		}
	}
	return true
}

// Replaces every `[^label]` in a line. Emitted on one line so that a marker
// inside a table cell stays inside its cell.
replace_note_markers :: proc(
	w: ^Website,
	p: ^Page,
	text: string,
	style: Note_Style,
) -> (
	string,
	bool,
) {
	if !strings.contains(text, MARKER_OPEN) {
		return text, true
	}

	b := strings.builder_make(w.scratch)
	rest := text

	for {
		start := strings.index(rest, MARKER_OPEN)
		if start < 0 {
			break
		}
		after := rest[start + len(MARKER_OPEN):]
		close := strings.index_byte(after, ']')
		if close < 0 {
			break
		}

		label := after[:close]
		note := find_note(p, label)
		if note == nil {
			fmt.eprintfln("ostat: %s: note %q is used but never defined", p.source, label)
			return "", false
		}

		// Numbering follows the markers, not the order the definitions were
		// written, which is what the CSS counter does on the page.
		note.used += 1
		if note.number == 0 {
			note.number = next_note_number(p)
		}

		strings.write_string(&b, rest[:start])
		switch style {
		case .Margin:
			write_margin_note(&b, note^)
		case .Endnote:
			write_endnote_marker(w, &b, p, note^)
		}
		rest = after[close + 1:]
	}

	strings.write_string(&b, rest)
	return strings.to_string(b), true
}

@(private = "file")
next_note_number :: proc(p: ^Page) -> int {
	highest := 0
	for note in p.notes {
		highest = max(highest, note.number)
	}
	return highest + 1
}

@(private = "file")
write_margin_note :: proc(b: ^strings.Builder, note: Note) {
	// <input> is a void element, so it is written self-closing rather than
	// with the closing tag gingerBill's generator emits.
	fmt.sbprintf(
		b,
		`&nbsp;<label for="%s%s" class="margin-toggle sidenote-number"></label>` +
		`<input type="checkbox" id="%s%s" class="margin-toggle">` +
		`<span class="sidenote">%s</span>`,
		NOTE_ID_PREFIX,
		note.label,
		NOTE_ID_PREFIX,
		note.label,
		note.html,
	)
}

// Anchors are absolute: a feed item is read a long way from the page it came
// from, so a bare fragment would resolve against the reader's own document.
@(private = "file")
write_endnote_marker :: proc(w: ^Website, b: ^strings.Builder, p: ^Page, note: Note) {
	fmt.sbprintf(
		b,
		`<sup class="fn-ref" id="fnref-%d"><a href="%s#fn-%d" role="doc-noteref">%d</a></sup>`,
		note.number,
		page_permalink(w, p, w.scratch),
		note.number,
		note.number,
	)
}

// The endnote list a feed item carries after its content.
write_endnote_list :: proc(w: ^Website, b: ^strings.Builder, p: ^Page) {
	if len(p.notes) == 0 {
		return
	}

	permalink := page_permalink(w, p, w.scratch)
	ordered := slice.clone(p.notes[:], w.scratch)
	slice.sort_by(ordered, proc(a, b: Note) -> bool {
		return a.number < b.number
	})

	strings.write_string(b, "\n<div class=\"footnotes\" role=\"doc-endnotes\">\n<ol>\n")
	for note in ordered {
		fmt.sbprintfln(
			b,
			`<li id="fn-%d">%s <a href="%s#fnref-%d">&#8617;</a></li>`,
			note.number,
			note.html,
			permalink,
			note.number,
		)
	}
	strings.write_string(b, "</ol>\n</div>\n")
}

@(private = "file")
find_note :: proc(p: ^Page, label: string) -> ^Note {
	for &note in p.notes {
		if note.label == label {
			return &note
		}
	}
	return nil
}

// A definition nobody references is a mistake, not a comment.
check_notes_used :: proc(p: ^Page) -> bool {
	ok := true
	for note in p.notes {
		if note.used == 0 {
			fmt.eprintfln("ostat: %s: note %q is defined but never used", p.source, note.label)
			ok = false
		}
	}
	return ok
}
