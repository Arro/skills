## What it does

`pickup` takes one ready-for-agent ticket end-to-end: it claims the issue, builds the work in an isolated git worktree, and opens a PR. It stops before merge — the PR comes back to you for review, and merging belongs to [wrapup](https://aihero.dev/skills-wrapup). It is designed for fan-out: assignment on the tracker is the mutex, so several `/pickup` sessions run in parallel without claiming the same ticket or colliding on ports.

Tickets can live on GitHub or Linear; the skill detects which from the argument (`123` or a `github.com` URL vs `ABC-123` or a `linear.app` URL).

## When to reach for it

You invoke this by typing `/pickup <id>` — the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own.

Reach for it when a ticket is already agent-ready — labeled `ready-for-agent`, with a contract worth implementing against. For building tickets serially in the session you're already in, use [implement](https://aihero.dev/skills-implement) instead; `pickup` earns its overhead when you want several tickets moving at once, each in its own session and [context window](https://www.aihero.dev/ai-coding-dictionary/context-window).

## Prerequisites

- An issue tracker the session can drive: the `gh` CLI for GitHub, or the Linear [MCP](https://www.aihero.dev/ai-coding-dictionary/mcp) tools for Linear.
- On GitHub, a `ready-for-agent` label on the ticket — the claim script refuses without it.
- Optional: a `docs/agents/worktrees.md` in the project, declaring extra gitignored files to copy into a worktree and any secondary ports its services need. The skill reads it as binding when present.

## The worktree

All work happens in `$MAIN/.worktrees/<id>` — never the main checkout, which other sessions may be using. Setup is scripted: the worktree branches off `origin/main`, gets every root-level `.env*` copied in, a collision-free `PORT` assigned (stable-hashed from the ticket, bumped past anything claimed), and dependencies installed. The scripts refuse rather than half-do — an existing worktree, or a dev script that would silently ignore `PORT`, stops the run.

Two guardrails do the most work:

- **Never a stacked PR.** The branch point is always `origin/main` and the PR base is always `main`. A ticket that asks for anything else is a sequencing problem to surface, not an instruction to follow.
- **Never merge.** The run ends at an open PR, a stopped dev server, and a report carrying the PR URL, the worktree path, the assigned port — and the thread-rename block from [rename-thread](https://aihero.dev/skills-rename-thread), so the session stays findable in the sidebar.

## It's working if

- Several tickets progress at once, and no two sessions ever grab the same issue.
- Every run ends at an open PR against `main` — never a merge, never a stacked base.
- The final report gives you a PR URL, a worktree path, a port, and a copy-able rename block.
- A ticket that depends on unmerged code gets surfaced back to you instead of built anyway.

## Where it fits

A chain step in the worktree loop — `/queue` → `/pickup` → (`/test-drive`) → `/wrapup` — which is the parallel alternative to `/implement` at the tail of the main flow, picking up what [to-tickets](https://aihero.dev/skills-to-tickets) produced. [queue](https://aihero.dev/skills-queue) shows you what's available before you commit to one, because it reads the same labels this skill claims. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
