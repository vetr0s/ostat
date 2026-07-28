package main

import "core:fmt"
import "core:strings"

/*
Syntax highlighting, emitting Chroma's class names so the stylesheet needs no
edits. Hugo ran Chroma with noClasses=false and style.css colours the result
with the Modus accents; cmark does no highlighting at all, so this fills the
gap rather than leaving those rules dead.

Only the seven groups the stylesheet distinguishes are produced: keyword,
type, string, number, function, builtin, and comment. That is a keyword table
and a scanner, not a parser, and it is deliberately approximate.

The chroma class goes on the <code>, not the <pre>. `.chroma { background:
none }` outranks `pre { background: … }` on specificity, so putting it on the
pre would strip the surface off every code block. Starting the block with
<pre> also matters: CommonMark ends that kind of HTML block at </pre> rather
than at a blank line, and code contains blank lines.
*/

Lang :: struct {
	names:        []string,
	keywords:     []string,
	types:        []string,
	builtins:     []string,
	line_comment: string,
	block_open:   string,
	block_close:  string,
	quotes:       string, // each byte opens a string literal
}

@(rodata)
LANGS := []Lang {
	{
		names = {"odin"},
		keywords = {
			"package", "import", "foreign", "proc", "return", "if", "else", "for", "switch",
			"case", "defer", "using", "struct", "union", "enum", "bit_set", "bit_field", "map",
			"matrix", "in", "not_in", "do", "break", "continue", "fallthrough", "when", "where",
			"or_return", "or_else", "or_break", "or_continue", "distinct", "dynamic", "cast",
			"transmute", "auto_cast", "context", "asm", "nil", "true", "false",
		},
		types = {
			"bool", "b8", "b16", "b32", "b64", "int", "i8", "i16", "i32", "i64", "i128", "uint",
			"u8", "u16", "u32", "u64", "u128", "uintptr", "f16", "f32", "f64", "rune", "string",
			"cstring", "rawptr", "typeid", "any", "byte", "complex64", "complex128",
		},
		builtins = {
			"len", "cap", "size_of", "align_of", "offset_of", "type_of", "type_info_of",
			"typeid_of", "min", "max", "abs", "clamp", "append", "delete", "make", "new", "free",
			"copy", "resize", "reserve", "clear", "raw_data", "assert", "panic", "unimplemented",
		},
		line_comment = "//",
		block_open = "/*",
		block_close = "*/",
		quotes = "\"'`",
	},
	{
		names = {"zig"},
		keywords = {
			"const", "var", "fn", "pub", "return", "if", "else", "while", "for", "switch",
			"break", "continue", "defer", "errdefer", "try", "catch", "struct", "enum", "union",
			"error", "comptime", "inline", "export", "extern", "packed", "align", "test",
			"orelse", "unreachable", "and", "or", "usingnamespace", "threadlocal", "callconv",
			"opaque", "volatile", "noalias", "asm", "suspend", "resume", "async", "await",
			"null", "undefined", "true", "false",
		},
		types = {
			"i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128",
			"usize", "f16", "f32", "f64", "f80", "f128", "bool", "void", "noreturn", "type",
			"anyerror", "anyopaque", "anytype", "comptime_int", "comptime_float", "c_int",
			"c_uint", "c_char",
		},
		builtins = {"@import", "@This", "@intCast", "@ptrCast", "@sizeOf", "@TypeOf", "@field"},
		line_comment = "//",
		quotes = "\"'",
	},
	{
		names = {"bash", "sh", "shell", "zsh"},
		keywords = {
			"if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case",
			"esac", "function", "in", "select", "return", "break", "continue", "local",
			"export", "readonly", "declare", "set", "unset", "shift", "exit", "source", "trap",
			"eval", "exec",
		},
		builtins = {
			"echo", "cd", "pwd", "printf", "read", "test", "mkdir", "rm", "cp", "mv", "ls",
			"cat", "grep", "sed", "awk", "curl", "find", "git", "make",
		},
		line_comment = "#",
		quotes = "\"'`",
	},
}

// Writes a fenced code block, highlighted when there is a lexer for its
// language and escaped-but-plain when there is not.
write_code_block :: proc(w: ^Website, b: ^strings.Builder, lang_name, code: string) {
	lang := find_lang(lang_name)

	strings.write_string(b, "<pre><code")
	switch {
	case lang == nil && lang_name == "":
		strings.write_string(b, ">")
	case lang == nil:
		fmt.sbprintf(b, ` class="language-%s">`, html_escape(lang_name, w.scratch))
	case:
		fmt.sbprintf(b, ` class="chroma language-%s">`, html_escape(lang_name, w.scratch))
	}

	if lang == nil {
		strings.write_string(b, html_escape(code, w.scratch))
	} else {
		write_tokens(w, b, lang^, code)
	}

	strings.write_string(b, "</code></pre>")
}

@(private = "file")
find_lang :: proc(name: string) -> ^Lang {
	if name == "" {
		return nil
	}
	for &lang in LANGS {
		for n in lang.names {
			if n == name {
				return &lang
			}
		}
	}
	return nil
}

@(private = "file")
write_tokens :: proc(w: ^Website, b: ^strings.Builder, lang: Lang, code: string) {
	i := 0
	for i < len(code) {
		if n := scan_comment(lang, code, i); n > 0 {
			write_span(w, b, "c", code[i:i + n])
			i += n
			continue
		}
		if n := scan_string(lang, code, i); n > 0 {
			write_span(w, b, "s", code[i:i + n])
			i += n
			continue
		}
		if is_digit(code[i]) {
			n := scan_number(code, i)
			write_span(w, b, "m", code[i:i + n])
			i += n
			continue
		}
		if is_ident_start(code[i]) {
			n := scan_ident(code, i)
			word := code[i:i + n]
			write_span(w, b, classify(lang, code, word, i + n), word)
			i += n
			continue
		}

		strings.write_string(b, html_escape(code[i:i + 1], w.scratch))
		i += 1
	}
}

// A word is a keyword, a type, or a builtin by table; otherwise a call if the
// next thing is an open paren, and plain text if not.
@(private = "file")
classify :: proc(lang: Lang, code, word: string, after: int) -> string {
	if contains_word(lang.keywords, word) {
		return "k"
	}
	if contains_word(lang.types, word) {
		return "kt"
	}
	if contains_word(lang.builtins, word) {
		return "nb"
	}

	j := after
	for j < len(code) && (code[j] == ' ' || code[j] == '\t') {
		j += 1
	}
	if j < len(code) && code[j] == '(' {
		return "nf"
	}
	return ""
}

@(private = "file")
write_span :: proc(w: ^Website, b: ^strings.Builder, class, text: string) {
	escaped := html_escape(text, w.scratch)
	if class == "" {
		strings.write_string(b, escaped)
		return
	}
	fmt.sbprintf(b, `<span class="%s">%s</span>`, class, escaped)
}

@(private = "file")
scan_comment :: proc(lang: Lang, code: string, start: int) -> int {
	rest := code[start:]

	if lang.line_comment != "" && strings.has_prefix(rest, lang.line_comment) {
		if end := strings.index_byte(rest, '\n'); end >= 0 {
			return end
		}
		return len(rest)
	}

	if lang.block_open != "" && strings.has_prefix(rest, lang.block_open) {
		end := strings.index(rest[len(lang.block_open):], lang.block_close)
		if end < 0 {
			return len(rest)
		}
		return len(lang.block_open) + end + len(lang.block_close)
	}
	return 0
}

@(private = "file")
scan_string :: proc(lang: Lang, code: string, start: int) -> int {
	quote := code[start]
	if strings.index_byte(lang.quotes, quote) < 0 {
		return 0
	}

	i := start + 1
	for i < len(code) {
		switch code[i] {
		case '\\':
			i += 2
			continue
		case '\n':
			// An unterminated literal ends at the line, so one stray quote
			// cannot colour the rest of the block.
			return i - start
		case quote:
			return i - start + 1
		}
		i += 1
	}
	return len(code) - start
}

@(private = "file")
scan_number :: proc(code: string, start: int) -> int {
	i := start
	for i < len(code) {
		c := code[i]
		if is_digit(c) || c == '.' || c == '_' || is_hex_letter(c) || c == 'x' || c == 'b' || c == 'o' {
			i += 1
			continue
		}
		break
	}
	return i - start
}

@(private = "file")
scan_ident :: proc(code: string, start: int) -> int {
	i := start
	for i < len(code) && (is_ident_start(code[i]) || is_digit(code[i])) {
		i += 1
	}
	return i - start
}

@(private = "file")
contains_word :: proc(words: []string, word: string) -> bool {
	for w in words {
		if w == word {
			return true
		}
	}
	return false
}

@(private = "file")
is_digit :: proc(c: u8) -> bool {
	return c >= '0' && c <= '9'
}

@(private = "file")
is_hex_letter :: proc(c: u8) -> bool {
	return (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

@(private = "file")
is_ident_start :: proc(c: u8) -> bool {
	return c == '_' || c == '@' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}
