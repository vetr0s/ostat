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
		if _, ok := parse_date(a.date); !ok {
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

Date :: struct {
	year, month, day:     int,
	hour, minute, second: int,
}

/*
"2026-07-12", "2026-07-12T14:30", or "2026-07-12T14:30:05".

The time is optional and midnight when absent, so a date on its own means what
it has always meant. Strict otherwise: exactly one of those three shapes, and a
real date.

Written in this order a stamp sorts lexicographically, which is what orders the
posts. A bare date sorts before any time on the same day, because "" is less
than "T", and midnight is where a bare date belongs.
*/
parse_date :: proc(s: string) -> (d: Date, ok: bool) {
	if len(s) < 10 || s[4] != '-' || s[7] != '-' {
		return
	}

	// Base 10 explicitly. With base 0 strconv reads a leading zero as octal,
	// which turns "08" and "09" into parse failures.
	d.year  = strconv.parse_int(s[0:4],  10) or_return
	d.month = strconv.parse_int(s[5:7],  10) or_return
	d.day   = strconv.parse_int(s[8:10], 10) or_return

	if d.month < 1 || d.month > 12 {
		return {}, false
	}
	if d.day < 1 || d.day > days_in_month(d.year, d.month) {
		return {}, false
	}

	if len(s) > 10 && !parse_time_of_day(s[10:], &d) {
		return {}, false
	}

	ok = true
	return
}

// "T14:30" or "T14:30:05", the tail of a stamp. Seconds are optional.
@(private = "file")
parse_time_of_day :: proc(s: string, d: ^Date) -> bool {
	if len(s) != 6 && len(s) != 9 {
		return false
	}
	if s[0] != 'T' || s[3] != ':' || (len(s) == 9 && s[6] != ':') {
		return false
	}

	ok: bool
	if d.hour, ok = strconv.parse_int(s[1:3], 10); !ok {
		return false
	}
	if d.minute, ok = strconv.parse_int(s[4:6], 10); !ok {
		return false
	}
	if len(s) == 9 {
		if d.second, ok = strconv.parse_int(s[7:9], 10); !ok {
			return false
		}
	}

	// No leap second. RSS would carry it and time.components_to_time would not.
	return d.hour < 24 && d.minute < 60 && d.second < 60
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
