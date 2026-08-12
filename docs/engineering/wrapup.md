## What it does

`wrapup` closes out a picked-up ticket after you've reviewed its PR: it merges (squash), tears down the worktree, deletes the local and remote branch, prunes, and fast-forwards your local `main`. Invoking it *is* the merge instruction — it asks for no further go/no-go, and stops only when something real blocks: failing or pending CI, a stacked PR, uncommitted work in the worktree, or a PR it can't confidently identify.

## When to reach for it

You invoke this by typing `/wrapup <id>` — the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own.

Reach for it from the main checkout, once you're happy with the PR. Don't reach for it to *decide* whether you're happy — that's your review, or a [test-drive](https://aihero.dev/skills-test-drive) first.

## Prerequisites

The `gh` CLI. Optional: a `docs/agents/worktrees.md` declaring whether the repo has CI (so wrapup skips the check instead of rediscovering "no checks" every run) and any post-merge steps; the skill treats it as binding.

## The gates

Everything is pre-authorized except three refusals:

| Gate | Behaviour |
| --- | --- |
| **Stacked PR** — base isn't `main` | refuses to merge, leaves everything in place, explains how to retarget |
| **CI red or pending** | stops and reports; merges over it only on your explicit go-ahead |
| **Uncommitted changes in the worktree** | stops — never discards work to tear down |

The teardown is thorough on purpose: squash-merge (one commit per ticket, so `Closes #<id>` fires), worktree removed after a dev-server backstop kill, branch deleted locally and remotely, worktrees pruned, local `main` fast-forwarded — or left alone with a note when the tree is dirty or `main` has diverged, because wrapup never stashes or force-reconciles your state.

## It's working if

- One `/wrapup <id>` goes from open PR to merged-and-clean with no confirmation prompts in between.
- A red check or a stacked PR stops the run instead of being merged through.
- Afterwards: the issue is closed, `git worktree list` is one shorter, the branch is gone from local and remote, and local `main` matches `origin/main`.

## Where it fits

The final step of the worktree loop — `/queue` → `/pickup` → (`/test-drive`) → **`/wrapup`**. It is the merge that [pickup](https://aihero.dev/skills-pickup) deliberately stops short of, and it knows how to clean up after a [test-drive](https://aihero.dev/skills-test-drive) collapsed the worktree early. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
