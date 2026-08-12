## What it does

`gpt-image-2` generates and edits images through the `mcp-image` [MCP](https://www.aihero.dev/ai-coding-dictionary/mcp) server, whose one tool wraps OpenAI's gpt-image-2 model. Every call costs money, so the skill generates **one image, files it, and waits for your verdict** before generating more — variations come from editing the filed image, not regenerating from scratch.

Filing is the part the skill owns: every image lands at `<output-root>/<slug>/<prefix>-<subject>-v<NN>.png`, keyed off the project's `## Project slug` block, so a project's images stay one folder with a legible version history per subject.

## When to reach for it

Type `/gpt-image-2`, or the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) reaches for it whenever the deliverable is an image file — created from a description, edited from an existing image, or blended from references.

## Prerequisites

- The `mcp-image` MCP server registered with an OpenAI API key — the skill walks you through its own `SETUP.md` if the tool is missing. The key lives in the server registration and nowhere else.
- A `## Project slug` block in the project's `CLAUDE.md`/`AGENTS.md` (slug + prefix). Missing, the skill asks and writes one.

## Prompting against the optimizer

The server runs a prompt optimizer that expands terse prompts before they reach the model — so the skill sends short prompts as-is. A hand-padded prompt gets optimized twice and comes out generic; a carefully crafted prompt that must go verbatim needs `SKIP_PROMPT_ENHANCEMENT=true` set on the server. Parameters cover the rest: quality tier, aspect ratio, size (`4K` when in-image text must be legible), input image for edits, and flags for character consistency, world knowledge, and blending.

## It's working if

- You get one image and a filed path per turn, and nothing more until you've reacted.
- A "make it warmer" follow-up edits the previous file via `inputImagePath` and bumps `v01` → `v02` — same subject stem, no from-scratch regeneration.
- The project's image folder reads as an organized series, not a scatter of timestamps.

## Where it fits

A reach-for-it-anytime standalone — the one skill in the set whose deliverable is an image, not text or code. It shares the `## Project slug` convention that [setup-matt-pocock-skills](https://aihero.dev/skills-setup-matt-pocock-skills) records. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
