package main

import "core:mem/virtual"

/*
Shared fixtures.

Two arenas, as a real build has. Pointing perm and scratch at one allocator
would be simpler and would hide the one bug class this separation exists to
catch: something retained on a Page that actually points into scratch. That
bug was live, in two fields, and no test could see it while the fixture had
only one arena.
*/

test_website :: proc() -> ^Website {
	w := new(Website, context.temp_allocator)

	_ = virtual.arena_init_growing(&w.perm_arena)
	_ = virtual.arena_init_growing(&w.scratch_arena)
	w.perm = virtual.arena_allocator(&w.perm_arena)
	w.scratch = virtual.arena_allocator(&w.scratch_arena)

	w.config = DEFAULT_SITE
	w.opts.out_dir = "public"
	w.pages = make([dynamic]^Page, w.perm)
	w.articles = make([dynamic]^Page, w.perm)
	w.sections = make(map[string]^Page, allocator = w.perm)
	w.today = "2026-01-01"
	return w
}

test_website_destroy :: proc(w: ^Website) {
	website_destroy(w)
}

// Scribbles over scratch so that anything still pointing into it reads as
// garbage rather than as whatever happened to survive. Use after freeing it.
test_poison_scratch :: proc(w: ^Website) {
	virtual.arena_free_all(&w.scratch_arena)
	junk := make([]byte, 256 * 1024, w.scratch)
	for &b in junk {
		b = 0xAA
	}
}

test_page :: proc(w: ^Website, body: string) -> ^Page {
	p := new(Page, w.perm)
	p.source = "test.md"
	p.title = "Test"
	p.slug = "test"
	p.section = BLOG_SECTION
	p.url = "/blog/test/"
	p.body = body
	p.notes = make([dynamic]Note, w.perm)
	return p
}
