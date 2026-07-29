package main

import "core:encoding/json"
import "core:strconv"
import "core:strings"

/*
Front matter is a `---` fence around literal JSON, the format gingerBill's
generator uses. No YAML, no TOML. core:encoding/json does the whole job.

	---
	{
	    "title": "Kitchen Sink",
	    "date": "2026-07-12",
	    "draft": true
	}
	---
*/

FENCE :: "---"

Archetype :: struct {
	title:       string,
	description: string,
	slug:        string,
	date:        string,
	draft:       bool,
}

Front_Matter_Error :: enum {
	None,
	No_Opening_Fence,
	No_Closing_Fence,
	Bad_Json,
	Missing_Title,
	Bad_Date,
	Bad_Slug,
}

// Splits a source file into its raw front matter block and the markdown after
// it. The fences themselves are not included in either half.
split_front_matter :: proc(src: string) -> (block, body: string, err: Front_Matter_Error) {
	rest := strings.trim_left_space(src)
	if !strings.has_prefix(rest, FENCE) {
		return "", "", .No_Opening_Fence
	}
	rest = rest[len(FENCE):]

	end := strings.index(rest, "\n" + FENCE)
	if end < 0 {
		return "", "", .No_Closing_Fence
	}

	block = rest[:end]
	body = rest[end + len("\n" + FENCE):]
	return
}

parse_front_matter :: proc(
	src: string,
	allocator := context.allocator,
) -> (
	a: Archetype,
	body: string,
	err: Front_Matter_Error,
) {
	block: string
	block, body = split_front_matter(src) or_return

	if json.unmarshal_string(block, &a, .JSON5, allocator) != nil {
		return {}, "", .Bad_Json
	}
	if a.title == "" {
		return {}, "", .Missing_Title
	}
	if a.date != "" {
		if _, _, _, ok := parse_date(a.date); !ok {
			return {}, "", .Bad_Date
		}
	}
	if a.slug != "" && !valid_slug(a.slug) {
		return {}, "", .Bad_Slug
	}

	body = strings.trim_left_space(body)
	return
}

/*
A slug becomes a directory name and a URL path segment, so it is checked here
rather than concatenated into a path and trusted.

A content file is the least trusted input the generator has, and "../../x" was
enough to make it create a directory outside the output tree before failing
the write. Path separators, traversal, whitespace and control characters are
all out; anything else, including non-ASCII, is a legitimate slug.
*/
valid_slug :: proc(s: string) -> bool {
	if s == "" || s == "." || strings.contains(s, "..") {
		return false
	}
	for c in s {
		if c == '/' || c == '\\' || c <= ' ' || c == 0x7f {
			return false
		}
	}
	return true
}

// "2026-07-12" -> 2026, 7, 12. Strict: exactly that shape, and a real date.
parse_date :: proc(s: string) -> (year, month, day: int, ok: bool) {
	if len(s) != 10 || s[4] != '-' || s[7] != '-' {
		return
	}

	// Base 10 explicitly. With base 0 strconv reads a leading zero as octal,
	// which turns "08" and "09" into parse failures.
	year  = strconv.parse_int(s[0:4],  10) or_return
	month = strconv.parse_int(s[5:7],  10) or_return
	day   = strconv.parse_int(s[8:10], 10) or_return

	if month < 1 || month > 12 {
		return 0, 0, 0, false
	}
	if day < 1 || day > days_in_month(year, month) {
		return 0, 0, 0, false
	}

	ok = true
	return
}

days_in_month :: proc(year, month: int) -> int {
	switch month {
	case 1, 3, 5, 7, 8, 10, 12:
		return 31
	case 4, 6, 9, 11:
		return 30
	case 2:
		leap := year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
		return 29 if leap else 28
	}
	return 0
}
