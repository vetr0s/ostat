package main

import "core:fmt"

// Phase 1 placeholder. Phase 3 replaces this with the real layout procs.
render_all :: proc(w: ^Website) -> bool {
	fmt.printfln("site:    %s", w.opts.site_dir)
	fmt.printfln("out:     %s", w.opts.out_dir)
	fmt.printfln("today:   %s", w.today)
	fmt.println("pages:")
	for p in w.pages {
		kind := "section" if p.is_section else "page"
		fmt.printfln("  %-8s %-28s %-12s %s", kind, p.url, p.date, p.title)
	}
	fmt.println("articles, newest first:")
	for p in w.articles {
		fmt.printfln("  %s  %s", p.date, p.url)
	}
	return true
}
