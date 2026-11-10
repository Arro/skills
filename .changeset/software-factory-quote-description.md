---
"mattpocock-skills": patch
---

`software-factory` now has its `description` in double quotes. The unquoted colon in "a software factory: the tasks it runs" was invalid YAML, so strict frontmatter parsers (the `skills` installer, for one) skipped the skill.
