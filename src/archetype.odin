package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

/*
Replaces Hugo's archetypes/default.md. The template is here rather than in a
file because there is exactly one and it is four lines long.

    ostat new blog/a-post            -> ./content/blog/a-post.md
    ostat new blog/a-post -s site    -> site/content/blog/a-post.md

The -s is why this takes an argument at all: `build` has always accepted a site
directory and `new` did not, so following the README exactly produced a stray
content tree at the repo root that no build ever looked at, reported as
success.
*/
cmd_new :: proc(args: []string) -> bool {
	rel, site_dir, ok := parse_new_args(args)
	if !ok {
		return false
	}

	path := fmt.tprintf("%s/content/%s.md", site_dir, rel)
	if os.exists(path) {
		fmt.eprintfln("ostat: %s already exists", path)
		return false
	}
	// Not make_directory_all directly: it reports .Exist rather than success,
	// so every post after the first in a section failed to be created.
	ensure_directory(filepath.dir(path)) or_return

	y, m, d := time.date(time.now())
	body := archetype_body(title_from_slug(filepath.base(rel)), y, int(m), d)

	if err := os.write_entire_file(path, body); err != nil {
		fmt.eprintfln("ostat: cannot write %s: %v", path, err)
		return false
	}

	fmt.println("created", path)
	return true
}

@(private = "file")
parse_new_args :: proc(args: []string) -> (rel, site_dir: string, ok: bool) {
	site_dir = "."

	i := 0
	for i < len(args) {
		switch args[i] {
		case "-s":
			i += 1
			if i >= len(args) {
				fmt.eprintln("ostat: -s needs a site directory")
				return
			}
			site_dir = args[i]
		case:
			if strings.has_prefix(args[i], "-") {
				fmt.eprintfln("ostat: unknown option %q", args[i])
				return
			}
			if rel != "" {
				fmt.eprintln("ostat: new takes one path")
				return
			}
			rel = strings.trim_suffix(args[i], ".md")
		}
		i += 1
	}

	if rel == "" {
		fmt.eprintln("ostat: new needs a path, like blog/a-post")
		return
	}
	// The path becomes a file path. A content file is untrusted input and a
	// slug is checked for the same reason.
	for segment in strings.split(rel, "/", context.temp_allocator) {
		if !valid_slug(segment) {
			fmt.eprintfln("ostat: %q is not a usable path segment", segment)
			return
		}
	}
	return rel, site_dir, true
}

// The file `ostat new` writes. Separate from the command so that a test can
// parse it back: what this produces has to be readable by parse_front_matter,
// and once was not.
//
// The braces are doubled because fmt reads a lone `{` as the start of a
// formatting directive. Written singly, every file this produced opened with
// `%!(MISSING CLOSE BRACE)` where the `{` belonged, and no page it created
// could be built.
archetype_body :: proc(title: string, y, m, d: int, allocator := context.temp_allocator) -> string {
	return fmt.aprintf(
		`---
{{
    "title": %q,
    "date": "%04d-%02d-%02d",
    "draft": true
}}
---

`,
		title,
		y,
		m,
		d,
		allocator = allocator,
	)
}

// "a-new-post" -> "A New Post"
title_from_slug :: proc(slug: string, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	upper := true
	for c in slug {
		switch {
		case c == '-' || c == '_':
			strings.write_rune(&b, ' ')
			upper = true
		case upper && c >= 'a' && c <= 'z':
			strings.write_rune(&b, c - 32)
			upper = false
		case:
			strings.write_rune(&b, c)
			upper = false
		}
	}
	return strings.to_string(b)
}
