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
	text:  string,
	fence: bool, // inside a fenced code block, or the fence line itself
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
preprocess :: proc(w: ^Website, p: ^Page) -> (out: string, ok: bool) {
	lines := split_source_lines(p.body, w.scratch)
	lines = collect_notes(w, p, lines) or_return
	apply_inline(w, p, lines) or_return
	return build_tables(w, lines, w.scratch), true
}

split_source_lines :: proc(src: string, allocator := context.allocator) -> []Line {
	raw := strings.split_lines(src, allocator)
	lines := make([]Line, len(raw), allocator)

	in_fence := false
	for text, i in raw {
		fence := is_fence_marker(text)
		lines[i] = Line{text, in_fence || fence}
		if fence {
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
apply_inline :: proc(w: ^Website, p: ^Page, lines: []Line) -> bool {
	for &line in lines {
		if line.fence {
			continue
		}
		line.text = replace_note_markers(w, p, line.text) or_return
		line.text = replace_strikethrough(line.text, w.scratch)
	}
	return check_notes_used(p)
}
