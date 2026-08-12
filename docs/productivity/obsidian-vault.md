## What it does

`obsidian-vault` searches, creates, and organizes notes in an Obsidian vault. The vault's organizing principle is links, not folders: notes live flat at the root, related notes connect through `[[wikilinks]]`, and **index notes** — plain lists of wikilinks — do the aggregating that folders would otherwise do. Each note is written as a unit of learning, with its links to related notes at the bottom.

## When to reach for it

Type `/obsidian-vault`, or the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) reaches for it when you ask to find, create, or organize notes in Obsidian.

## Prerequisites

The vault path is hard-coded in the skill — it's a personal-setup skill, and pointing it at your own vault means editing that path in `SKILL.md`.

## The conventions it enforces

| Convention | Meaning |
| --- | --- |
| Title Case filenames | `Ralph Wiggum Index.md`, not `ralph-wiggum-index.md` |
| Flat root | no folders — organization is links and index notes |
| Links at the bottom | each note ends with its `[[wikilinks]]` to related notes |
| Index notes | aggregators named `<Topic> Index` — lists of wikilinks, nothing more |

Search runs directly over the vault files (filename, content, and backlink searches), so finding "what links here" is one grep away.

## It's working if

- New notes land at the vault root in Title Case, ending in wikilinks — never in a new folder.
- Asking for a topic surfaces its index note, and the index actually reaches the notes you remember writing.
- Backlink questions ("what references X?") get answered from the vault, not from memory.

## Where it fits

A reach-for-it-anytime standalone, outside the engineering flows entirely — it manages a knowledge vault, not a codebase. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
