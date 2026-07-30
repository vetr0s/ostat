package main

import "core:testing"

/*
site.json, layered over the defaults.

The merge is the whole point and is the part most likely to break silently: a
key the file omits has to keep its default, or every site.json would have to
restate the entire struct to avoid losing headings it never mentioned.
*/

CONFIG_FIXTURE :: "tests/fixture-config"
CONFIG_FIXTURE_EMPTY_TITLE :: "tests/fixture-config-empty-title"
CONFIG_FIXTURE_NONE :: "tests/fixture-config-none"

@(test)
test_site_config_absent_leaves_defaults :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)

	// A real site directory that carries content and no site.json.
	w.opts.site_dir = CONFIG_FIXTURE_NONE

	testing.expect(t, load_site_config(w), "a site without site.json should build")
	testing.expect_value(t, w.config.title, DEFAULT_SITE.title)
	testing.expect_value(t, w.config.base_url, DEFAULT_SITE.base_url)
}

@(test)
test_site_config_overrides_only_what_it_names :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)
	w.opts.site_dir = CONFIG_FIXTURE

	testing.expect(t, load_site_config(w), "the fixture config should load")

	testing.expect_value(t, w.config.title, "Configured")
	testing.expect_value(t, w.config.base_url, "https://configured.test/")
	testing.expect_value(t, w.config.brand.accent, "ured")

	// Named in neither the file nor its parent object, so both keep the default.
	testing.expect_value(t, w.config.locale, DEFAULT_SITE.locale)
	testing.expect_value(t, w.config.home.elsewhere_heading, DEFAULT_SITE.home.elsewhere_heading)

	// A slice the file does name is replaced outright, not appended to.
	testing.expect_value(t, len(w.config.contact), 1)
	testing.expect_value(t, w.config.contact[0].label, "email")
}

@(test)
test_site_config_rejects_an_empty_required_field :: proc(t: ^testing.T) {
	w := test_website()
	defer test_website_destroy(w)
	w.opts.site_dir = CONFIG_FIXTURE_EMPTY_TITLE

	// Present but empty, which unmarshals cleanly and would otherwise reach the
	// <title> of every page.
	testing.expect(t, !load_site_config(w), "an empty title should fail the build")
}
