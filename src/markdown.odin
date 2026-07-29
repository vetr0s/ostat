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
	fence, _ := scan_fence(lines[start].text)
	lang := fence_language(lines[start].text)

	end := start + 1
	for end < len(lines) && !lines[end].marker {
		end += 1
	}

	// The fence's own indent belongs to the list item holding it, not to the
	// code, so it comes back off before the code is rendered.
	body := strings.builder_make(w.scratch)
	for line in lines[start + 1:end] {
		strings.write_string(&body, dedent(line.text, fence.indent))
		strings.write_byte(&body, '\n')
	}

	block := strings.builder_make(w.scratch)
	write_code_block(&block, lang, strings.to_string(body), w.scratch)

	open_html_block(b)
	if fence.indent > 0 {
		write_nested_block(b, strings.to_string(block), fence.indent, w.scratch)
	} else {
		strings.write_string(b, strings.to_string(block))
	}
	strings.write_string(b, "\n\n")

	// The closing marker is consumed too, unless the fence was never closed.
	return min(end + 1, len(lines)) - start
}

/*
Writes a block that has to live inside a list item.

Every line of an HTML block must stay at the item's content column or the item
ends and the block is hoisted out to the top level, which is what used to
happen to any fence inside a list. Indenting the code to match would satisfy
the parser but show up as leading whitespace inside the <pre>.

One physical line satisfies both: there are no continuation lines to break the
item, and the newlines ride along as entities, which a browser renders inside
a <pre> without their contributing any indentation.
*/
@(private = "file")
write_nested_block :: proc(
	b: ^strings.Builder,
	block: string,
	indent: int,
	allocator := context.allocator,
) {
	for _ in 0 ..< indent {
		strings.write_byte(b, ' ')
	}
	one_line, _ := strings.replace_all(block, "\n", "&#10;", allocator)
	strings.write_string(b, one_line)
}

@(private = "file")
dedent :: proc(text: string, n: int) -> string {
	i := 0
	for i < n && i < len(text) && text[i] == ' ' {
		i += 1
	}
	return text[i:]
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

	open: Fence
	in_fence := false

	for text, i in raw {
		fence, is_fence := scan_fence(text)
		marker := false

		switch {
		case !in_fence && is_fence:
			open, in_fence, marker = fence, true, true
		case in_fence && is_fence && closes(fence, open, text):
			in_fence, marker = false, true
		}

		lines[i] = Line{text, in_fence || marker, marker}
	}
	return lines
}

// A fenced block's opening run, which its closing run has to answer.
@(private = "file")
Fence :: struct {
	char:   u8, // '`' or '~'
	length: int,
	indent: int,
}

@(private = "file")
scan_fence :: proc(text: string) -> (f: Fence, ok: bool) {
	indent := 0
	for indent < len(text) && indent < 4 && text[indent] == ' ' {
		indent += 1
	}
	if indent >= len(text) {
		return
	}

	char := text[indent]
	if char != '`' && char != '~' {
		return
	}

	length := 0
	for indent + length < len(text) && text[indent + length] == char {
		length += 1
	}
	if length < 3 {
		return
	}
	return Fence{char, length, indent}, true
}

// CommonMark: a fence closes only on the same character, a run at least as
// long, and nothing after it. Matching on the prefix alone closed a ```` block
// at the ``` example inside it — which is how one documents Markdown, and
// which left the rest of the block being rewritten as prose.
@(private = "file")
closes :: proc(f, open: Fence, text: string) -> bool {
	if f.char != open.char || f.length < open.length {
		return false
	}
	return strings.trim_space(text[f.indent + f.length:]) == ""
}

/*
Rewrites that apply within a line: margin note markers, then strikethrough.

Inline code spans are stepped over. A span opens on a run of backticks and
closes on a run of the same length, and it may continue onto a later line
within the same paragraph, so the open run is carried across the walk and
cleared at anything that ends a paragraph.

Without this, `a ~~ b` in backticks had <del> spliced into it, cmark escaped
the tags because they were inside a code span, and the reader saw the markup
as literal text where they had written tildes.
*/
@(private = "file")
apply_inline :: proc(w: ^Website, p: ^Page, lines: []Line, style: Note_Style) -> bool {
	open_ticks := 0
	for &line in lines {
		if line.fence || strings.trim_space(line.text) == "" {
			open_ticks = 0
			continue
		}
		line.text = rewrite_outside_code(w, p, line.text, style, &open_ticks)
	}
	return check_notes_used(p)
}

@(private = "file")
rewrite_outside_code :: proc(
	w: ^Website,
	p: ^Page,
	text: string,
	style: Note_Style,
	open_ticks: ^int,
) -> string {
	if open_ticks^ == 0 && !strings.contains(text, "`") {
		return rewrite_prose(w, p, text, style)
	}

	b := strings.builder_make(w.scratch)
	seg := 0

	i := 0
	for i < len(text) {
		if text[i] != '`' {
			i += 1
			continue
		}

		run := 1
		for i + run < len(text) && text[i + run] == '`' {
			run += 1
		}

		switch {
		case open_ticks^ == 0:
			// Prose up to here; the span opens and its fence goes out as-is.
			strings.write_string(&b, rewrite_prose(w, p, text[seg:i], style))
			strings.write_string(&b, text[i:i + run])
			open_ticks^ = run
			seg = i + run
		case run == open_ticks^:
			// Everything since the opening fence was code. Verbatim.
			strings.write_string(&b, text[seg:i + run])
			open_ticks^ = 0
			seg = i + run
		}
		// A run of the wrong length inside a span is just more code.
		i += run
	}

	tail := text[seg:]
	strings.write_string(&b, open_ticks^ == 0 ? rewrite_prose(w, p, tail, style) : tail)
	return strings.to_string(b)
}

@(private = "file")
rewrite_prose :: proc(w: ^Website, p: ^Page, text: string, style: Note_Style) -> string {
	return replace_strikethrough(replace_note_markers(w, p, text, style), w.scratch)
}
