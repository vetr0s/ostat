package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

/*
End-to-end tests against a fixture site and a committed tree of expected
output.

The generator is a pure function from (content, config, today) to a file tree:
directory walks are sorted for reproducibility and the only clock read is
overridden here. So the whole program can be pinned by comparing documents,
and this is what covers discovery, URL derivation, draft and future filtering,
the layouts, the feed document and the sitemap — none of which any unit test
reaches.

Regenerate after an intended change, and read the diff before committing it:

    ./build.sh && rm -rf tests/golden && \
      ./build/debug/ostat build tests/fixture-site -o tests/golden \
        -today 2026-01-01

The base URL is not passed: it comes from tests/fixture-site/site.json, so
the command and the test read identity from the same place.

A golden test catches regressions, not gaps: it only knows about shapes the
fixture actually contains. Adding a case to the fixture is how it learns one.
*/

FIXTURE_SITE :: "tests/fixture-site"
GOLDEN_DIR :: "tests/golden"
FIXTURE_TODAY :: "2026-01-01"

@(private = "file")
build_fixture :: proc(drafts := false, future := false) -> ^Website {
	w := test_website()
	w.opts.site_dir = FIXTURE_SITE
	w.opts.drafts = drafts
	w.opts.future = future
	w.today = FIXTURE_TODAY
	// The fixture's identity comes from its own site.json, exactly as the
	// regeneration command below reads it. Setting the config here instead
	// would leave the golden output passing while config loading was broken.
	if !load_site_config(w) {
		// Loudly, and here. Falling back to the defaults would fail every
		// golden comparison at once and say nothing about why.
		panic("tests/fixture-site/site.json failed to load")
	}
	// Same reasoning: without this the fixture's home page and head would be
	// the built-in placeholders, and the golden tree would pin those instead.
	if !load_fragments(w) {
		panic("tests/fixture-site/html failed to load")
	}
	return w
}

@(private = "file")
expect_matches_golden :: proc(t: ^testing.T, rel, got: string, loc := #caller_location) {
	path := fmt.tprintf("%s/%s", GOLDEN_DIR, rel)
	raw, err := os.read_entire_file_from_path(path, context.temp_allocator)
	if err != nil {
		testing.expectf(t, false, "no golden file at %s: %v", path, err, loc = loc)
		return
	}

	want := string(raw)
	if want == got {
		return
	}

	// Name the first line that differs; a whole-document dump is unreadable.
	want_lines := strings.split_lines(want, context.temp_allocator)
	got_lines := strings.split_lines(got, context.temp_allocator)
	for i in 0 ..< min(len(want_lines), len(got_lines)) {
		if want_lines[i] != got_lines[i] {
			testing.expectf(
				t,
				false,
				"%s differs at line %d\n  want: %s\n  got:  %s",
				rel,
				i + 1,
				want_lines[i],
				got_lines[i],
				loc = loc,
			)
			return
		}
	}
	testing.expectf(
		t,
		false,
		"%s differs in length: want %d lines, got %d",
		rel,
		len(want_lines),
		len(got_lines),
		loc = loc,
	)
}

@(test)
test_golden_pages :: proc(t: ^testing.T) {
	w := build_fixture()
	defer test_website_destroy(w)

	testing.expect(t, collect_content(w), "discovery succeeded")
	testing.expect(t, render_content(w), "markdown rendered")

	for p in w.pages {
		expect_matches_golden(t, p.out_path, build_page(w, p))
	}

	// Not in w.pages, because nothing links to it, so it needs asking for.
	not_found := not_found_page(w)
	expect_matches_golden(t, not_found.out_path, build_page(w, not_found))
}

@(test)
test_golden_feed_and_sitemap :: proc(t: ^testing.T) {
	w := build_fixture()
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")
	testing.expect(t, render_content(w), "markdown rendered")

	expect_matches_golden(t, "sitemap.xml", build_sitemap(w))

	items := w.articles[:min(FEED_ITEM_LIMIT, len(w.articles))]
	bodies := make([]string, len(items), w.scratch)
	for p, i in items {
		body, ok := feed_item_content(w, p)
		testing.expect(t, ok, "feed item rendered")
		bodies[i] = body
	}
	expect_matches_golden(t, "index.xml", build_feed(w, "/index.xml", "/", items, bodies))
}

@(test)
test_discovery_derives_urls_and_paths :: proc(t: ^testing.T) {
	w := build_fixture()
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")

	seen := make(map[string]string, allocator = w.scratch)
	for p in w.pages {
		seen[p.url] = p.out_path
	}

	testing.expect_value(t, seen["/"], "index.html")
	testing.expect_value(t, seen["/about/"], "about/index.html")
	testing.expect_value(t, seen["/blog/"], "blog/index.html")
	testing.expect_value(t, seen["/blog/code/"], "blog/code/index.html")
	// Front matter overrode the slug, so the file name does not appear.
	testing.expect_value(t, seen["/custom-slug/"], "custom-slug/index.html")
	testing.expect(t, "/renamed/" not_in seen, "the file name is not the URL")
}

@(test)
test_drafts_and_future_are_excluded_by_default :: proc(t: ^testing.T) {
	w := build_fixture()
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")

	for p in w.pages {
		testing.expectf(t, p.title != "A Draft", "a draft was published")
		testing.expectf(t, p.title != "From the Future", "a future post was published")
	}
	// Four: two dated to the day, two sharing a day and separated by a time.
	testing.expect_value(t, len(w.articles), 4)
}

@(test)
test_drafts_and_future_are_included_on_request :: proc(t: ^testing.T) {
	w := build_fixture(drafts = true, future = true)
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")

	titles := make(map[string]bool, allocator = w.scratch)
	for p in w.pages {
		titles[p.title] = true
	}
	testing.expect(t, titles["A Draft"], "-drafts published the draft")
	testing.expect(t, titles["From the Future"], "-future published the future post")
	testing.expect_value(t, len(w.articles), 6)
}

// The case a date alone cannot order. Two posts on one day used to come out in
// whatever order an unstable sort left them in, which was neither the order
// they were written nor the order of their file names.
@(test)
test_two_posts_on_one_day_are_ordered_by_time :: proc(t: ^testing.T) {
	w := build_fixture()
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")

	order := make([dynamic]string, w.scratch)
	for p in w.articles {
		append(&order, p.title)
	}
	// Both are 2025-06-02. The third is that day with no time, which is
	// midnight, so it belongs below them rather than between them.
	testing.expect_value(t, order[0], "Later That Day")
	testing.expect_value(t, order[1], "Earlier That Day")
	testing.expect_value(t, order[2], "Notes and Tables")
}

@(test)
test_articles_are_sorted_newest_first :: proc(t: ^testing.T) {
	w := build_fixture()
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")

	for i in 1 ..< len(w.articles) {
		testing.expectf(
			t,
			w.articles[i - 1].date >= w.articles[i].date,
			"%s came before %s",
			w.articles[i - 1].date,
			w.articles[i].date,
		)
	}
}

@(test)
test_page_fields_do_not_point_into_scratch :: proc(t: ^testing.T) {
	// A Page outlives the scratch arena. This frees scratch and writes over
	// it, so anything a Page still points at there reads as garbage. It is the
	// only way to see that class of bug, and there were two live instances of
	// it before the fixture had two separate arenas.
	w := build_fixture()
	defer test_website_destroy(w)
	testing.expect(t, collect_content(w), "discovery succeeded")

	pages := make([]^Page, len(w.pages), context.temp_allocator)
	copy(pages, w.pages[:])
	titles := make([]string, len(pages), context.temp_allocator)
	sections := make([]string, len(pages), context.temp_allocator)
	for p, i in pages {
		titles[i] = strings.clone(p.title, context.temp_allocator)
		sections[i] = strings.clone(p.section, context.temp_allocator)
	}

	test_poison_scratch(w)

	for p, i in pages {
		testing.expect_value(t, p.title, titles[i])
		testing.expect_value(t, p.section, sections[i])
		testing.expect(t, strings.has_prefix(p.url, "/"), "url survived")
		testing.expect(t, strings.has_suffix(p.out_path, ".html"), "out_path survived")
	}
}
