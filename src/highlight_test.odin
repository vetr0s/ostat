package main

import "core:strings"
import "core:testing"

@(private = "file")
hl :: proc(lang, code: string) -> string {
	w := test_website()
	b := strings.builder_make(w.scratch)
	write_code_block(&b, lang, code, w.scratch)
	return strings.to_string(b)
}

@(test)
test_odin_tokens :: proc(t: ^testing.T) {
	out := hl("odin", "package main // hi\nx: int = \"s\"\nfoo(1)\n")

	testing.expect(t, strings.contains(out, `<span class="k">package</span>`), "keyword")
	testing.expect(t, strings.contains(out, `<span class="kt">int</span>`), "type")
	testing.expect(t, strings.contains(out, `<span class="c">// hi</span>`), "comment")
	testing.expect(t, strings.contains(out, `<span class="s">&quot;s&quot;</span>`), "string")
	testing.expect(t, strings.contains(out, `<span class="nf">foo</span>`), "call")
	testing.expect(t, strings.contains(out, `<span class="m">1</span>`), "number")
}

@(test)
test_odin_block_comment :: proc(t: ^testing.T) {
	out := hl("odin", "/* two\nlines */ x\n")
	testing.expect(t, strings.contains(out, `<span class="c">/* two`), "block comment opens")
	testing.expect(t, strings.contains(out, `lines */</span>`), "and closes")
}

@(test)
test_bash_tokens :: proc(t: ^testing.T) {
	out := hl("bash", "if true; then echo hi; fi  # done\n")
	testing.expect(t, strings.contains(out, `<span class="k">if</span>`), "keyword")
	testing.expect(t, strings.contains(out, `<span class="nb">echo</span>`), "builtin")
	testing.expect(t, strings.contains(out, `<span class="c"># done</span>`), "comment")
}

@(test)
test_chroma_class_sits_on_the_code_element :: proc(t: ^testing.T) {
	// `.chroma { background: none }` outranks `pre { background: … }`, so the
	// class on the pre would strip the surface off every block.
	out := hl("odin", "x\n")
	testing.expect(t, strings.has_prefix(out, "<pre><code class=\"chroma language-odin\">"))
	testing.expect(t, !strings.contains(out, `<pre class=`), "pre carries no class")
}

@(test)
test_unknown_language_is_escaped_but_plain :: proc(t: ^testing.T) {
	out := hl("text", "if <a> & \"b\"\n")
	testing.expect(t, !strings.contains(out, "<span"), "no tokens")
	testing.expect(t, !strings.contains(out, "chroma"), "no chroma class without a lexer")
	testing.expect(t, strings.contains(out, "&lt;a&gt; &amp; &quot;b&quot;"), "still escaped")
	testing.expect(t, strings.contains(out, `class="language-text"`), "language is recorded")
}

@(test)
test_fence_without_a_language :: proc(t: ^testing.T) {
	out := hl("", "plain\n")
	testing.expect(t, strings.has_prefix(out, "<pre><code>"), "no class at all")
}

@(test)
test_code_is_escaped_inside_spans :: proc(t: ^testing.T) {
	out := hl("odin", "s := \"<script>\"\n")
	testing.expect(t, !strings.contains(out, "<script>"), "no raw tag escapes into the page")
	testing.expect(t, strings.contains(out, "&lt;script&gt;"))
}

@(test)
test_unterminated_string_stops_at_the_line :: proc(t: ^testing.T) {
	// One stray quote must not colour the rest of the block.
	out := hl("odin", "a := \"oops\nb := 1\n")
	testing.expect(t, strings.contains(out, `<span class="m">1</span>`), "the next line still lexes")
}

@(test)
test_blank_line_inside_a_fence_survives :: proc(t: ^testing.T) {
	w := test_website()
	lines := split_source_lines("```odin\na\n\nb\n```\n", w.scratch)
	src := assemble_blocks(w, lines, w.scratch)

	html := md_block(src, w.scratch)
	testing.expect(t, strings.contains(html, "a\n\nb"), "the blank line is preserved")
	testing.expect(t, strings.contains(html, "</code></pre>"), "the block closed properly")
}
