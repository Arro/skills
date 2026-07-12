---
name: gpt-image-2
description: Generate or edit images with OpenAI's gpt-image-2, via the mcp-image MCP server's generate_image tool. Use whenever the deliverable is an image file — created from a text description, edited from an existing image, or blended from several references.
---

# gpt-image-2 image generation

The `mcp-image` MCP server exposes one tool, `generate_image`, backed by OpenAI's **gpt-image-2**. Images save into the server's configured `IMAGE_OUTPUT_DIR` — a per-machine choice that lives in the MCP registration, not in this file.

If `generate_image` is missing from the available tools, stop and walk the user through [SETUP.md](SETUP.md). The API key goes into the server registration and nowhere else — never into chat, this file, or a direct API call.

## Project slug

Filing keys off the project's **slug** and **prefix**, recorded as a `## Project slug` block in the project's `CLAUDE.md` or `AGENTS.md` (a project-wide identity, shared with any other skill that produces per-project output):

```markdown
## Project slug

- slug: echo-vault
- prefix: ev
```

This skill uses the slug as the project's folder under the output root, and the prefix as the first segment of every filename. If the project has no such block, ask the user to choose both — suggest a slug derived from the repo name and a prefix of its initials — write the block, then continue.

## Calling

```
generate_image(prompt: "Roscoe the puppy curled up on a Persian rug", fileName: "ev-roscoe-rug-v01")
```

Send terse prompts as-is: the server runs a prompt optimizer that expands them before they reach gpt-image-2, so a hand-padded prompt gets optimized twice and comes out generic. When a prompt is carefully crafted and must go verbatim, have the user set `SKIP_PROMPT_ENHANCEMENT=true` on the server.

### Parameters

| param | when to set it |
|---|---|
| `quality` | `fast` for drafts, `balanced` (default), `quality` for finals |
| `aspectRatio` | `16:9` YouTube, `9:16` TikTok/Shorts, `1:1` Instagram, `21:9` cinematic |
| `imageSize` | `1K` / `2K` / `4K` — use `4K` when in-image text must be legible (gpt-image-2 renders text well; lean on it) |
| `inputImagePath` | absolute path to the source image, for image-to-image edits |
| `fileName` | always set it, per Filing below |
| `purpose` | free-text intent hint (`"YouTube thumbnail"`, `"storyboard frame"`) — tunes the style |
| `maintainCharacterConsistency` | same character across a series of shots |
| `useWorldKnowledge` | historical or factual subjects (real aircraft, landmarks) |
| `blendImages` | combining multiple reference images |

## Filing

Every image ends up at `<output-root>/<slug>/<prefix>-<subject>-v<NN>.png`. The server saves flat into the output root (it strips path separators from `fileName`), so filing takes one move after each generation:

1. **Name**: pass `fileName: "<prefix>-<subject>-v<NN>"` (no extension; the server appends one). The subject is one to four slug-case words describing the content: `ev-cottage-golden-hour-v01`.
2. **Version**: a new concept starts at `v01`; an edit or variation of an existing image keeps the subject and bumps the version. List `<output-root>/<slug>/` for the subject stem first to continue its sequence.
3. **Move**: the tool result gives the saved absolute path, whose dirname is the output root. `mkdir -p` the slug folder and move the file into it.

## After each call

Every call costs money. Generate one image, report the filed path (the user opens it themselves), and wait for their verdict before generating more. For variations on a result, edit the filed image via `inputImagePath` rather than regenerating from scratch — cheaper and more consistent.
