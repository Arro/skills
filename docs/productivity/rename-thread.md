## What it does

`rename-thread` gives the current session a findable title. [Harnesses](https://www.aihero.dev/ai-coding-dictionary/harness) title a thread from its first message and never revisit it, so the sidebar name rarely reflects what the thread became. The [agent](https://www.aihero.dev/ai-coding-dictionary/agent) cannot fix that itself — `/rename` is a session-control command only the user can run — so the deliverable is a copy-able block, emitted in the turn's **final** message, that you paste to do the rename.

## When to reach for it

Type `/rename-thread [title]`, or let the agent reach for it when another skill needs the session renamed.

Reach for it whenever the sidebar name no longer says what the thread is for: months from now, the title is how you'll find this session again.

## The block

The title is 3–6 words naming the thread's durable task, prefixed with the project's tag (the `prefix` from the `## Project slug` block in `CLAUDE.md`/`AGENTS.md`), with ticket references in the tracker's native format (`#37` for GitHub, `ABC-123` for Linear). Delivery adapts to the harness:

| Harness | Block contains |
| --- | --- |
| Claude Code (or unknown) | the full `/rename [<tag>] <label>` command |
| Codex | the title only — you rename by clicking the thread title and pasting |

The one rule that matters: the block appears in the turn's final message, on its own fenced line so one click copies something paste-able. A run where it's buried mid-turn, dropped, or replaced by a claim that the thread "has been renamed" is a failed run. On macOS the skill also tries `pbcopy` silently — if permitted, the line is already on your clipboard.

## It's working if

- Every run ends with a fenced, one-line block you can copy without editing.
- Pasting it (or just pasting the title, on Codex) renames the thread — the agent never claims to have renamed it itself.
- Your sidebar reads as a list of tasks (`[sk] #37 fix port guard`), not a list of first messages.

## Where it fits

A reach-for-it-anytime standalone, with no fixed place in any chain — reach for it at the point a thread stops being about what its title says. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
