---
name: rename-thread
description: Emit a copy-able `/rename` block that gives the current thread a findable title. Use when the user wants to rename or retitle this thread/session, or when another skill needs the session renamed.
argument-hint: "optional title"
---

# rename-thread — give this thread a findable title

Harnesses title a thread from its first message and never revisit it, so the sidebar name rarely reflects what the thread became. `/rename` fixes that, but it is a session-control command the agent cannot run — even the harness's rename tools refuse the current session — so the deliverable is a paste-able block the user copies.

## Choose the title

- If a title was passed (by the user or an invoking skill), use it as the label.
- Otherwise derive one: 3–6 words naming the thread's durable task — what you'd search the sidebar for months later, not the latest tangent.
- If the label references a ticket, use the tracker's native format: `#37` for a GitHub issue, but a Linear identifier as-is — `ABC-123`, never `#ABC-123`.
- In a project, prefix the session tag unless the label already starts with one: the `prefix` from the `## Project slug` block in the project's `CLAUDE.md` or `AGENTS.md`, or failing that the initials of the repo name's hyphenated words (`amber-waveform` → `aw`), as `[<tag>]`. Outside a project, no prefix.

## Emit the block — as visible text, before anything else

The block is the entire deliverable, and the user can only act on it if they see it. So print it as ordinary assistant text in your **very next message, before any further tool calls**.

This holds hardest when another skill invoked this one mid-workflow (`/pickup` does, at step 4): the temptation is to treat the rename as an internal bookkeeping step and press on with the real work. Don't. Emit the block, then resume. A run where the block was skipped, deferred to a closing summary, batched behind a pile of tool calls, or replaced by a claim like "I've renamed the thread" (you cannot — `/rename` is the user's to run) is a failed run, even if everything else went well.

One short intro line, then the content on its **own fenced code block** (not inline `` `code` ``) so GUI clients render a copy button — and nothing else on the line inside the block, so a one-click copy yields something directly paste-able.

What goes in the block depends on the harness:

- **Claude Code** (or when you can't tell): the full `/rename` command —

  📝 Rename this thread (copy the line below):

  ````
  ```
  /rename [<tag>] <label>
  ```
  ````

  e.g. the block would contain `/rename [aw] #37 forge weighted-fill logic`.

- **Codex** (the OpenAI harness — you'll know from your system prompt / `AGENTS.md`-driven setup): there is no `/rename` command; the user renames by clicking the thread title and pasting the name. Emit the **title only**, no `/rename` prefix, and adjust the intro line:

  📝 Rename this thread (click the title and paste the line below):

  ````
  ```
  [<tag>] <label>
  ```
  ````
