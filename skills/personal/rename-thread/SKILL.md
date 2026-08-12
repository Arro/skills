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

## Emit the block — in the turn's final message

The block is the entire deliverable, and the user can only act on it if they see it. Where you put it decides that, and harness realities cut both ways:

- Text written between tool calls is **not reliably shown** — Claude Code's UI collapses it into a progress chip, so a block emitted mid-turn vanishes without a trace.
- Ending the turn early just to display the block **stalls the workflow** — Codex stops the whole thread and waits on the user.

So the rule is: the block goes in the **final text message of the turn**, after all tool calls — the one message every harness renders. When the user invoked this skill directly, that's simply your next message and you're done. When another skill invoked it mid-workflow (`/pickup` does, at step 4), do **not** stop the workflow and do **not** emit mid-turn: settle on the title now, carry on with the work, and open the turn's closing report with the block, above the summary.

A run where the block never appears in the final message — dropped, buried mid-turn where the UI hid it, or replaced by a claim like "I've renamed the thread" (you cannot — `/rename` is the user's to run) — is a failed run, even if everything else went well.

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

## Also try `pbcopy`

After emitting the block, probe whether you have permission to pipe to `pbcopy` (macOS clipboard) — e.g. run it via the shell tool with the block's exact content. Don't ask the user first; just attempt it.

- If the tool call succeeds, mention in a short trailing line that the line was also copied to the clipboard.
- If it's denied (permission prompt rejected, command fails, or the tool isn't available), say nothing about it — no mention of `pbcopy`, no apology, no fallback note. Fail silently.
