## What it does

`edit-article` improves an article draft in two passes: first structure, then prose. It treats the article's information as a directed acyclic graph — pieces of information depend on other pieces — and reorders sections so nothing is used before it's introduced. It confirms that section plan with you before touching a sentence; only then does it rewrite section by section, tightening for clarity and flow with short paragraphs.

## When to reach for it

You invoke this by typing `/edit-article` — the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own.

Reach for it when a draft exists and reads worse than its ideas deserve. For sharpening the *thinking* before a draft exists, [grill-me](https://aihero.dev/skills-grill-me) is the tool; this one edits what's already written.

## It's working if

- You're shown a section plan — and asked about it — before any rewriting starts.
- Concepts stop appearing before they're explained; the dependency order holds.
- Paragraphs come back short and single-pointed, not merged into walls of text.

## Where it fits

A reach-for-it-anytime standalone for writing work, off the engineering flows. Its neighbour is [grill-me](https://aihero.dev/skills-grill-me), because interviewing sharpens an idea while this skill sharpens its written form. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
