## What it does

`queue` reports the current state of the `ready-for-agent` queue in the repo: what's available to pick up, what's already claimed and by whom, which agent PRs await review, and which worktrees linger on this machine. It is strictly read-only — it modifies no labels, claims no issues, and removes nothing; it exists so you can see the board before deciding what to start, review, or close out.

## When to reach for it

You invoke this by typing `/queue` — the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own.

Reach for it at the top of a working session, before a `/pickup`, or whenever you've lost track of what's in flight. To act on what it shows, use the sibling that owns the action:

| It shows | You act with |
| --- | --- |
| An available ticket | `/pickup` |
| A PR awaiting review | review it, then `/wrapup` |
| A stale worktree | `git worktree remove <path>` |

## Prerequisites

The `gh` CLI, and a repo whose tickets carry the `ready-for-agent` label — the convention [setup-matt-pocock-skills](https://aihero.dev/skills-setup-matt-pocock-skills) and [triage](https://aihero.dev/skills-triage) establish.

## What the report flags

Beyond the four lists, two callouts matter:

- **Stacked PRs** — any agent PR whose base isn't `main` is marked prominently, because stacked PRs are forbidden and `/wrapup` will refuse to merge them until they're retargeted.
- **Stale claims** — an in-flight ticket that hasn't been touched in a while may be an abandoned session worth investigating.

## It's working if

- You get a 3–5 line summary — available, in flight, awaiting review, worktrees to clean — without anything on the tracker changing.
- A stacked PR never surprises you at `/wrapup` time, because `/queue` already flagged it.

## Where it fits

The survey step of the worktree loop — `/queue` → `/pickup` → (`/test-drive`) → `/wrapup`. It reads the same `ready-for-agent` label that [triage](https://aihero.dev/skills-triage) applies and `/pickup` claims. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
