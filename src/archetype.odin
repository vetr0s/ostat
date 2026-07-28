package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

// Replaces Hugo's archetypes/default.md. The template is here rather than in a
// file because there is exactly one and it is four lines long.
cmd_new :: proc(args: []string) -> bool {
	if len(args) != 1 {
		fmt.eprintln("ostat: new takes one path, like blog/a-new-post")
		return false
	}

	rel := strings.trim_suffix(args[0], ".md")
	path := fmt.tprintf("content/%s.md", rel)

	if os.exists(path) {
		fmt.eprintfln("ostat: %s already exists", path)
		return false
	}
	if err := os.make_directory_all(filepath.dir(path)); err != nil {
		fmt.eprintfln("ostat: cannot create directory for %s: %v", path, err)
		return false
	}

	y, m, d := time.date(time.now())
	title := title_from_slug(filepath.base(rel))

	body := fmt.tprintf(
		`---
{
    "title": %q,
    "date": "%04d-%02d-%02d",
    "draft": true
}
---

`,
		title,
		y,
		int(m),
		d,
	)

	if err := os.write_entire_file(path, body); err != nil {
		fmt.eprintfln("ostat: cannot write %s: %v", path, err)
		return false
	}

	fmt.println("created", path)
	return true
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
