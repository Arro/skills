## What it does

`test-drive` takes the branch a `/pickup` created and checks it out in the main checkout, so you can test the work hands-on without `cd`-ing into a worktree. Git refuses to check out a branch another worktree holds, so the skill removes that worktree first — deliberately: the worktrees exist for parallelization, not as the place to test. Only the checkout directory goes; the branch and its PR are untouched.

## When to reach for it

You invoke this by typing `/test-drive <id>` — the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own.

Reach for it between `/pickup` and `/wrapup`, when reading the PR isn't enough and you want to run the thing — click through the UI, poke the endpoint — from your normal working directory with your normal dev setup. If the PR reads fine as a diff, skip straight to `/wrapup`.

## What it protects

The skill stops and asks rather than losing anything:

| It finds | It does |
| --- | --- |
| Uncommitted changes in the worktree | stops — offers to commit them to the branch first |
| A dirty main checkout | stops — switching branches would carry or clobber your changes |
| No worktree for that id | touches nothing — lists what exists and asks which issue you meant |

It also stops the worktree's dev servers before removal — only processes actually running inside the worktree, never an unrelated server on the same port. The worktree's per-issue `PORT` goes with it; the main checkout's usual dev script and port apply during the test drive.

## It's working if

- The ticket's branch is on your main checkout and your usual `dev` command serves it.
- The branch and PR survive — a later `/wrapup <id>` still finds and merges them, and knows to switch the main checkout back to `main` first.
- Nothing uncommitted was ever discarded without you being asked.

## Where it fits

The optional step in the worktree loop — `/queue` → `/pickup` → **`/test-drive`** → `/wrapup` — for the tickets you want to try before you merge. `/pickup` creates what it collapses; `/wrapup` handles the aftermath either way. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
