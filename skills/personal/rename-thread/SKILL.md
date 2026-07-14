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
- In a project, prefix the session tag unless the label already starts with one: the tag `docs/agents/worktrees.md` defines, or failing that the initials of the repo name's hyphenated words (`amber-waveform` → `aw`), as `[<tag>]`. Outside a project, no prefix.

## Emit the block

One short intro line, then the command on its **own fenced code block** (not inline `` `code` ``) so GUI clients render a copy button — and nothing else on the line inside the block, so a one-click copy yields a directly paste-able command:

📝 Rename this thread (copy the line below):

````
```
/rename [<tag>] <label>
```
````

e.g. the block would contain `/rename [aw] #37 forge weighted-fill logic`.
