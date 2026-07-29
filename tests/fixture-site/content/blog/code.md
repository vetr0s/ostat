---
{
    "title": "Code",
    "date": "2025-06-01",
    "description": "Code spans and blocks, including the shapes that used to break the build."
}
---

A regex in a span: `[^a-z]+`, and tildes in a span: `a ~~ b`. Neither is a
note or a strikethrough.

```odin
main :: proc() {
	x := 1 // a comment
}
```

Steps, with a block that has to stay inside its item:

1. First step.

   ```bash
   echo hi
   ```

2. Second step.

````text
```
A fence inside a longer fence.
```
````
