package main

// Shared fixtures. The temp allocator stands in for both arenas, because
// nothing a test builds outlives the test.

test_website :: proc() -> ^Website {
	w := new(Website, context.temp_allocator)
	w.perm = context.temp_allocator
	w.scratch = context.temp_allocator
	w.config = DEFAULT_SITE
	return w
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
