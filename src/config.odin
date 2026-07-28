package main

/*
Everything hugo.toml used to carry, in one struct.

This is the seam. Nothing outside this file hardcodes a site's title, URL, or
navigation, so making ostat configurable later means writing a loader that
fills a Site_Config instead of rewriting callers.
*/

Link :: struct {
	label: string,
	url:   string,
}

Site_Config :: struct {
	base_url:    string,
	title:       string,
	description: string,
	author:      string,
	locale:      string,

	// The home page's two lists. Data, not markup.
	contact:     []Link,
	elsewhere:   []Link,
}

DEFAULT_SITE :: Site_Config {
	base_url    = "https://vetr0s.dev/",
	title       = "vetr0s.dev",
	description = "Nathan Tebbs, software engineer. Writing, projects, and a page about who I am.",
	author      = "Nathan Tebbs",
	locale      = "en-us",
	contact     = {
		{"email",    "mailto:vetr0s.dev@gmail.com"},
		{"github",   "https://github.com/vetr0s"},
		{"linkedin", "https://www.linkedin.com/in/ntebbs"},
		{"resume",   "/resume.pdf"},
	},
	elsewhere   = {
		{"about",    "/about/"},
		{"blog",     "/blog/"},
		{"projects", "/projects/"},
		{"colophon", "/colophon/"},
	},
}
