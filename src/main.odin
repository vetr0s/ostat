package main

import "base:runtime"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:strings"
import "core:time"

VERSION :: "0.2.1"

USAGE :: `ostat - a static site generator

usage:
    ostat build [site-dir]      build a site into an output directory
    ostat new <path> [-s dir]   create a page from the archetype
    ostat version               print the version

build options:
    -o <dir>          output directory (default: public)
    -drafts           include pages marked draft
    -future           include pages dated after today
    -today <date>     treat this YYYY-MM-DD as today, instead of the clock
    -base-url <url>   override the configured base URL

site-dir defaults to the current directory. It must contain content/, and may
contain static/.
`

Options :: struct {
	site_dir: string,
	out_dir:  string,
	drafts:   bool,
	future:   bool,
	base_url: string,
}

Website :: struct {
	perm_arena:    virtual.Arena,
	scratch_arena: virtual.Arena,
	perm:          runtime.Allocator,
	scratch:       runtime.Allocator,

	config:        Site_Config,
	fragments:     Fragments,
	opts:          Options,
	today:         string, // "2026-07-27", for the -future cutoff

	pages:         [dynamic]^Page,
	articles:      [dynamic]^Page, // blog posts, newest first
	sections:      map[string]^Page,
	outputs:       map[string]^Page,  // out_path -> the page that claimed it
	written:       map[string]string, // out-relative path -> what generated it
}

main :: proc() {
	if !run(os.args) {
		os.exit(1)
	}
}

run :: proc(args: []string) -> bool {
	if len(args) < 2 {
		fmt.eprint(USAGE)
		return false
	}

	switch args[1] {
	case "build":
		return cmd_build(args[2:])
	case "new":
		return cmd_new(args[2:])
	case "version":
		fmt.println("ostat", VERSION)
		return true
	case "help", "-h", "--help":
		fmt.print(USAGE)
		return true
	}

	fmt.eprintfln("ostat: unknown command %q", args[1])
	fmt.eprint(USAGE)
	return false
}

cmd_build :: proc(args: []string) -> bool {
	w: Website
	website_init(&w) or_return
	defer website_destroy(&w)

	parse_build_args(&w, args) or_return
	load_site_config(&w) or_return
	load_fragments(&w) or_return

	// After the file, not before: -base-url is an override of whatever the site
	// says, and loading site.json on top of it would put the file back in front.
	if w.opts.base_url != "" {
		if c, ok := check_base_url(w.opts.base_url); !ok {
			fmt.eprintfln("ostat: -base-url cannot contain %q", c)
			return false
		}
		w.config.base_url = w.opts.base_url
	}

	collect_content(&w) or_return
	render_content(&w) or_return
	render_all(&w) or_return

	// The synthesised home page is already in w.pages, so this counted it
	// twice and every build over-reported by one.
	fmt.printfln("built %d pages into %s", len(w.pages), w.opts.out_dir)
	return true
}

/*
The value a flag takes, or a message and false.

Checking only that another token exists is what `ostat build p -o -drafts` used
to do: it took "-drafts" as the output directory, created one, and reported
success. A flag is never a value, so a leading `-` is the mistake being made.
*/
flag_value :: proc(args: []string, i: int, flag, what: string) -> (value: string, ok: bool) {
	if i >= len(args) || strings.has_prefix(args[i], "-") {
		fmt.eprintfln("ostat: %s needs %s", flag, what)
		return "", false
	}
	return args[i], true
}

parse_build_args :: proc(w: ^Website, args: []string) -> bool {
	w.opts.out_dir = "public"

	i := 0
	for i < len(args) {
		arg := args[i]
		switch arg {
		case "-o":
			i += 1
			w.opts.out_dir = flag_value(args, i, "-o", "a directory") or_return
		case "-base-url":
			i += 1
			w.opts.base_url = flag_value(args, i, "-base-url", "a url") or_return
		case "-today":
			i += 1
			today := flag_value(args, i, "-today", "a date") or_return
			if _, _, _, ok := parse_date(today); !ok {
				fmt.eprintfln("ostat: -today: %q is not a YYYY-MM-DD date", today)
				return false
			}
			w.today = today
		case "-drafts":
			w.opts.drafts = true
		case "-future":
			w.opts.future = true
		case:
			if strings.has_prefix(arg, "-") {
				fmt.eprintfln("ostat: unknown option %q", arg)
				return false
			}
			if w.opts.site_dir != "" {
				fmt.eprintln("ostat: build takes at most one site directory")
				return false
			}
			w.opts.site_dir = arg
		}
		i += 1
	}

	if w.opts.site_dir == "" {
		w.opts.site_dir = "."
	}
	return true
}

website_init :: proc(w: ^Website) -> bool {
	if err := virtual.arena_init_growing(&w.perm_arena); err != nil {
		fmt.eprintfln("ostat: arena: %v", err)
		return false
	}
	if err := virtual.arena_init_growing(&w.scratch_arena); err != nil {
		fmt.eprintfln("ostat: arena: %v", err)
		return false
	}
	w.perm = virtual.arena_allocator(&w.perm_arena)
	w.scratch = virtual.arena_allocator(&w.scratch_arena)

	w.config = DEFAULT_SITE
	w.fragments = DEFAULT_FRAGMENTS
	w.pages = make([dynamic]^Page, w.perm)
	w.articles = make([dynamic]^Page, w.perm)
	w.sections = make(map[string]^Page, allocator = w.perm)
	w.outputs = make(map[string]^Page, allocator = w.perm)
	w.written = make(map[string]string, allocator = w.perm)

	y, m, d := time.date(time.now())
	w.today = fmt.aprintf("%04d-%02d-%02d", y, int(m), d, allocator = w.perm)
	return true
}

website_destroy :: proc(w: ^Website) {
	virtual.arena_destroy(&w.scratch_arena)
	virtual.arena_destroy(&w.perm_arena)
}
