package main

import "core:strings"

import cm "vendor:commonmark"

/*
cmark, and the pass that runs over the source before cmark sees it.

libcmark is CommonMark only. Tables, strikethrough, and margin notes are not
in that spec, so they are rewritten into raw HTML here and passed through by
the .Unsafe option. This is the same shape as gingerBill's
preprocessor_pass_over_article: fix the source up first, then hand it to the
parser once.

The pass is line-oriented and tracks fenced code blocks, because nothing
inside a fence may be rewritten.
*/

// .Unsafe passes raw HTML through, which the content needs for its <figure>
// blocks and for everything this pass emits. .Smart gives curly quotes and
// proper dashes, matching the typographer Goldmark was running.
CMARK_OPTIONS :: cm.Options{.Unsafe, .Smart}

Line :: struct {
	text:   string,
	fence:  bool, // inside a fenced code block, or the fence line itself
	marker: bool, // the ``` line that opens or closes one
}

md_block :: proc(src: string, allocator := context.allocator) -> string {
	html := cm.markdown_to_html_from_string(src, CMARK_OPTIONS)
	defer cm.free_string(html)
	return strings.clone(html, allocator)
}

// For markdown that has to sit inside a <span> or a <td>, so the paragraph
// cmark wraps it in is stripped back off.
md_inline :: proc(src: string, allocator := context.allocator) -> string {
	html := cm.markdown_to_html_from_string(src, CMARK_OPTIONS)
	defer cm.free_string(html)

	body := strings.trim_space(html)
	if strings.has_prefix(body, "<p>") && strings.has_suffix(body, "</p>") {
		body = body[len("<p>"):len(body) - len("</p>")]
	}
	return strings.clone(body, allocator)
}

render_content :: proc(w: ^Website) -> bool {
	for p in w.pages {
		src := preprocess(w, p) or_return
		p.content = md_block(src, w.perm)
	}
	return true
}

// Note definitions come out first so that a marker can be resolved wherever it
// sits relative to its definition. Inline rewrites run next, so that table
// cells already carry their note markup and struck text by the time a cell is
// rendered on its own.
preprocess :: proc(
	w: ^Website,
	p: ^Page,
	style := Note_Style.Margin,
) -> (
	out: string,
	ok: bool,
) {
	lines := split_source_lines(p.body, w.scratch)
	lines = collect_notes(w, p, lines) or_return
	apply_inline(w, p, lines, style) or_return
	return assemble_blocks(w, lines, w.scratch), true
}

// Joins the lines back into one source string, replacing tables and fenced
// code with the HTML that cmark will pass through untouched.
assemble_blocks :: proc(w: ^Website, lines: []Line, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)

	i := 0
	for i < len(lines) {
		if lines[i].marker {
			i += write_fenced_code(w, &b, lines, i)
			continue
		}
		if !lines[i].fence {
			if aligns, rows, _, is_table := scan_table(lines, i); is_table {
				open_html_block(&b)
				write_table(w, &b, lines[i:i + rows], aligns)
				strings.write_byte(&b, '\n')
				i += rows
				continue
			}
		}

		strings.write_string(&b, lines[i].text)
		strings.write_byte(&b, '\n')
		i += 1
	}

	return strings.to_string(b)
}

// Returns how many lines the block consumed, counting both fence markers.
@(private = "file")
write_fenced_code :: proc(w: ^Website, b: ^strings.Builder, lines: []Line, start: int) -> int {
	lang := fence_language(lines[start].text)

	end := start + 1
	for end < len(lines) && !lines[end].marker {
		end += 1
	}

	body := strings.builder_make(w.scratch)
	for line in lines[start + 1:end] {
		strings.write_string(&body, line.text)
		strings.write_byte(&body, '\n')
	}

	open_html_block(b)
	write_code_block(w, b, lang, strings.to_string(body))
	strings.write_string(b, "\n\n")

	// The closing marker is consumed too, unless the fence was never closed.
	return min(end + 1, len(lines)) - start
}

// The info string after the fence: ```odin -> "odin".
@(private = "file")
fence_language :: proc(text: string) -> string {
	t := strings.trim_left_space(text)
	t = strings.trim_left(t, "`~")
	if space := strings.index_any(t, " \t"); space >= 0 {
		t = t[:space]
	}
	return strings.trim_space(t)
}

// An HTML block cannot open in the middle of a paragraph, and the line before
// one is not always blank.
@(private = "file")
open_html_block :: proc(b: ^strings.Builder) {
	if strings.builder_len(b^) > 0 && !strings.has_suffix(strings.to_string(b^), "\n\n") {
		strings.write_byte(b, '\n')
	}
}

split_source_lines :: proc(src: string, allocator := context.allocator) -> []Line {
	raw := strings.split_lines(src, allocator)
	lines := make([]Line, len(raw), allocator)

	in_fence := false
	for text, i in raw {
		marker := is_fence_marker(text)
		lines[i] = Line{text, in_fence || marker, marker}
		if marker {
			in_fence = !in_fence
		}
	}
	return lines
}

@(private = "file")
is_fence_marker :: proc(text: string) -> bool {
	t := strings.trim_left_space(text)
	return strings.has_prefix(t, "```") || strings.has_prefix(t, "~~~")
}

// Rewrites that apply within a single line: margin note markers, then
// strikethrough.
@(private = "file")
apply_inline :: proc(w: ^Website, p: ^Page, lines: []Line, style: Note_Style) -> bool {
	for &line in lines {
		if line.fence {
			continue
		}
		line.text = replace_note_markers(w, p, line.text, style)
		line.text = replace_strikethrough(line.text, w.scratch)
	}
	return check_notes_used(p)
}
