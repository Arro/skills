---
name: grab
description: Pull down a ticket (GitHub or Linear) and take it to an open PR in the current checkout — branch, changes, commit, push, PR.
argument-hint: "issue number, Linear identifier, or issue URL"
disable-model-invocation: true
---

# /grab — ticket to PR, in place

Take the ticket passed as the argument through to an open PR, working in the current checkout on a fresh branch. Stop before merge. If no ticket was given, stop and ask for one.

This is the light sibling of `/pickup`: no label gate, no claiming, no worktree, no port — one ticket, one branch, one PR, right here. When you want several tickets moving in parallel, or the queue discipline, use `/pickup` instead.

The ticket can live in GitHub or Linear — detect which from the argument:

- A bare number, `#123`, or a `github.com` issue URL → **GitHub**.
- An identifier like `ABC-123` or a `linear.app` URL → **Linear**.

Call the ticket's reference `<id>` below: the issue number for GitHub, the identifier (e.g. `ABC-123`) for Linear.

## Before step 1: get the checkout onto an up-to-date `main`

The checkout is usually still sitting on a branch whose PR has already merged. Bring it back to `main` before anything else, so the run never starts from stale ground. Run `git status --porcelain`, and branch on the result:

- **Clean** (no output): switch and pull, no question asked.

  ```sh
  git checkout main && git pull --ff-only
  ```

  Already on `main`? Just pull. If the pull refuses (local `main` has diverged from `origin/main`), stop and ask rather than merging or resetting.

- **Dirty** (any output, untracked files included): stop and ask the user how to handle it, naming the current branch and summarising what is uncommitted. Offer these options:
  1. **Stash, then sync.** `git stash push --include-untracked -m "grab <id>: from <branch>"`, then switch and pull as above. Name the stash in the step 7 report so it isn't forgotten.
  2. **Commit to the current branch, then sync.** Only when that branch isn't `main`. A WIP commit with a message the user approves; then switch and pull.
  3. **Bring the changes onto the ticket branch.** For when the uncommitted work belongs to this ticket. Switch and pull with the changes in tow (`git checkout` carries them over unless they conflict; if it refuses, ask again), and they land on the branch step 2 creates.
  4. **Stop.** The user sorts the tree out themselves and re-runs.

If `git checkout main` fails because `main` is checked out in another worktree, skip the switch and say so: step 2 branches off `origin/main` regardless.

## Use the repo's GitHub account

Before the first `gh` command, find out which account this repo belongs to:

```sh
~/.claude/skills/grab/scripts/gh-account.sh
```

It prints the logged-in `gh` account whose email matches the `[user]` email in the repo's `.git/config`, or nothing when there is no such section or no account matches. If it prints a login, run every `gh` command in this run as that account by prefixing it with the account's token, scripts included:

```sh
GH_TOKEN="$(gh auth token --user <login>)" gh issue view <id> --comments
```

If it prints nothing, use `gh` as it is. Never `gh auth switch`: it changes the active account for every other terminal and session on the machine. Do this quietly; there is no need to mention it to the user unless a `gh` call fails because of it.

## Steps

1. **Fetch the ticket.** GitHub: `gh issue view <id> --comments`. Linear: the get-issue MCP tool, with comments. What you implement against: on GitHub, the most recent `## Agent Brief` comment if one exists (the body is then context), otherwise the issue body; on Linear, the description, with comments as context. Read it in full — if it is ambiguous, contradictory, or depends on unmerged code, stop and ask rather than guessing.

2. **Branch off up-to-date `main`.** The tree is clean by now, unless the user chose to bring their changes along. Never stash or discard anything the user didn't choose to in the sync above. Then:

   ```sh
   git fetch origin
   git switch -c <branch> origin/main
   ```

   Branch name: `fix/<id>-<slug>` if the ticket is a bug, `feat/<id>-<slug>` otherwise — `<id>` lowercase, slug the first 4–5 meaningful words of the title in kebab-case. For Linear, keeping the identifier in the branch name is what lets Linear's GitHub integration auto-link the branch and PR to the issue. If the repo's default branch isn't `main`, substitute it throughout.

3. **Make the changes.** Follow the ticket literally, adhere to `CLAUDE.md` conventions, and read the project's domain docs first where they exist (`GLOSSARY.md`, `docs/adr/`). Stay in scope — an out-of-scope cleanup becomes a follow-up issue, not part of this branch.

4. **Validate.** Run the project's validation for the area you changed: its `check`/`fix` scripts if it has them, otherwise whatever `CLAUDE.md` documents as the bar. Run any test files you added or that cover the changed code. If a check you didn't touch fails, investigate the root cause — never delete, skip, or weaken it.

5. **Commit.** Stage the files you actually changed (never `git add -A`). Conventional-style message ending with the closing reference — `Closes #<id>` for GitHub, `Closes <id>` (e.g. `Closes ABC-123`) for Linear — so the tracker auto-closes the issue on merge. One commit unless the work has natural seams.

6. **Push and open the PR.**
   - `git push -u origin <branch>`
   - `gh pr create --base main` with a body that carries the same `Closes …` reference (Linear's GitHub integration picks up the magic word from the PR body), summarises what changed, and notes anything you deviated on or want the reviewer to look at.

7. **Report.** Output the PR URL and the branch name, and note that the checkout is still on the feature branch (the next `/grab` or `/pickup` switches back to `main` for you). If the sync stashed anything, name the stash and how to restore it (`git stash pop`). Do not merge.

## Guardrails

- Never force-push, never push to `main`, never merge.
- The branch point and PR base are always `main` (or the repo's default branch) — a ticket pointing anywhere else is a sequencing problem to surface, not an instruction to follow.
- If validation surfaces pre-existing failures unrelated to your change, mention them in the PR body but do not fix them in this PR.

## Failure recovery

- **Conflict on push** (`main` moved under you): rebase onto `origin/main`, re-run validation, then `git push --force-with-lease` — safe on your own feature branch; the force-push rule protects `main`.
