---
name: wrapup
description: Finish a picked-up ticket — merge its PR once CI is green, then tear down the worktree and branch.
argument-hint: "issue number"
disable-model-invocation: true
---

# /wrapup — merge a reviewed PR and clean up its worktree

Close out the ticket whose issue number was passed as the argument (call it `<num>` below) after the user has reviewed its PR: merge it, then remove the worktree, delete the branch, and prune. Invoking `/wrapup` **is** the merge instruction — don't ask for a further go/no-go. Only stop for input when something is genuinely unclear (which PR is meant, red CI, uncommitted work) — never as a routine confirmation. Run this from the **main checkout** after the user is happy with the work. If no issue number was given, stop and ask for one.

## Preconditions

- **Must run from the main checkout, not a worktree.** You cannot remove a worktree you are standing inside. Determine the main root with `MAIN=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')`. If the current directory is under `$MAIN/.worktrees/` (or the legacy `<repo>-wt/` sibling directory), `cd "$MAIN"` first, then proceed.
- **Read the project's `docs/agents/worktrees.md` if it exists.** Project parameters for this workflow live there alongside the `/pickup` ones — whether the repo has CI (step 4), and any post-merge steps (step 8). Treat it as binding.

## Steps

1. **Locate the work.**
   - Worktree path: `WT="$MAIN/.worktrees/<num>"`. If that doesn't exist, also check the legacy sibling layout older `/pickup` runs used: `WT="$MAIN/../$(basename "$MAIN")-wt/<num>"`.
   - If `$WT` exists, read its branch: `BRANCH=$(git -C "$WT" branch --show-current)`.
   - If `$WT` does not exist (worktree already gone), find the branch another way: the issue's PR. Use `gh issue view <num> --json` cross-referenced with `gh pr list --search "<num> in:body" --state all` to identify the branch/PR. If you cannot confidently identify the PR, stop and ask.
   - A missing worktree with the **main checkout sitting on the ticket's branch** means `/test-drive` collapsed the worktree for local testing. That's expected — there's nothing to tear down, but step 7 must switch the main checkout back to `main` before the branch can be deleted.

2. **Find the PR and its state.** `gh pr list --head "$BRANCH" --state all --json number,state,mergeStateStatus,title,url,baseRefName`. Capture the PR number, whether it is OPEN / MERGED / CLOSED, and its **base branch** (`baseRefName`).
   - If already **MERGED**: skip to step 5 (cleanup). The merge is done; just tear down.
   - If **CLOSED** (not merged): stop and ask — the PR was abandoned; don't silently delete the work.
   - If **OPEN**: continue to the stacked-PR check, then the CI check.

3. **Stacked-PR check (OPEN PRs only).** If `baseRefName` is anything other than `main`, this is a stacked PR — **do not merge, do not tear anything down.** Stop and report: "PR #<pr> is based on `<baseRefName>`, not `main`. Stacked PRs are forbidden, so `/wrapup` won't merge it. Either retarget it to `main` once `<baseRefName>` has landed (`gh pr edit <pr> --base main`, then rebase the branch onto updated `main` and resolve any conflicts), or this is a sequencing problem to sort out first." Leave the worktree, branch, and PR exactly as they are. Only continue to the CI check once the base is `main`.

4. **CI check (OPEN PRs only).** If the project's `docs/agents/worktrees.md` declares the repo has no CI (a `## CI` section saying none), **skip this step entirely** — don't run `gh pr checks` just to rediscover that every thread. Otherwise run `gh pr checks <pr> || true` — the `|| true` matters: `gh pr checks` exits non-zero both for failing checks *and* for "no checks reported", so without it a CI-less repo produces a scary-looking failed command on every run. Read the output to tell the cases apart. This is the one thing that can block the merge:
   - All green, or "no checks reported" (the repo has no CI): proceed straight to the merge — no confirmation prompt. If the repo turned out to have no CI and its `worktrees.md` doesn't yet say so, suggest adding a `## CI` section declaring it so future wrapups skip the lookup.
   - Any check **failing or still pending**: stop and report — that's a red flag, not a routine gate. Merge over red/pending checks only on an explicit go-ahead.

   Things the old flow surfaced as a pre-merge gate now go in the final report (step 9) instead: PR title/URL, a one-line diffstat (`gh pr diff <pr> --stat`), and — if the PR includes database migration files — a callout that merging made the migration part of the canonical history, plus whether it was generated the way the project's `CLAUDE.md` requires (e.g. Prisma's `migrate dev`, never `db push`).

5. **Merge.** `gh pr merge <pr> --squash`. Squash keeps `main` history one-commit-per-ticket and matches the `Closes #<num>` convention so the issue auto-closes. Do **not** pass `--delete-branch`: run from the main checkout it also tries to delete the *local* branch, which the worktree still holds — so the command exits non-zero on every normal run even though the merge landed. The remote branch is deleted in step 7 instead, after the worktree is gone.

6. **Tear down the worktree.**
   - If `$WT` exists, check it's clean first: `git -C "$WT" status --porcelain`. If there are uncommitted changes, stop and ask — don't discard work.
   - **Stop any surviving dev server (backstop).** `/pickup` should have stopped it, but a crash or a restart during review can leave one bound. Before removing the worktree:
     ```sh
     ~/.claude/skills/pickup/scripts/stop-dev-servers.sh "$WT"
     ```
     It only kills listeners whose working directory is inside `$WT`, so an unrelated main-checkout server on the same port survives.
   - Remove it: `git -C "$MAIN" worktree remove "$WT"`. (Use `--force` only after you've confirmed there's nothing to lose, and say so.)

7. **Delete the local and remote branch, then prune.**
   - If the main checkout is currently **on** `$BRANCH` (the `/test-drive` case), go back to `main` first — git won't delete the checked-out branch. Confirm the tree is clean (`git -C "$MAIN" status --porcelain`; if dirty, stop and surface it — don't discard or carry along test-session changes), then `git -C "$MAIN" checkout main`.
   - `git -C "$MAIN" branch -D "$BRANCH"` — a squash-merged branch looks "unmerged" to git, so `-D` (not `-d`) is expected here and is safe because the PR is merged.
   - Delete the remote branch: `git -C "$MAIN" push origin --delete "$BRANCH"`. If the ref is already gone (some repos auto-delete merged branches), that's fine — note it and move on.
   - `git -C "$MAIN" worktree prune`
   - `git -C "$MAIN" fetch --prune` to drop the stale remote-tracking ref.

8. **Bring local `main` up to date.** After the squash-merge, the main checkout is one commit behind `origin/main`. Update it — but safely:
   - Confirm the main checkout is on `main`: `git -C "$MAIN" symbolic-ref --short HEAD`. If not, skip this step and note it.
   - Confirm the tree is clean: `git -C "$MAIN" status --porcelain`. If dirty, skip the pull and tell the user (don't stash their work).
   - Pull fast-forward only: `git -C "$MAIN" pull --ff-only`. This updates cleanly when possible. If it fails because local `main` has unpushed/diverged commits, **do not** merge or rebase to force it — report that local `main` has diverged and leave it for the user to reconcile (`git push` or rebase, their call).
   - If the merged PR added a database migration, the local `main` checkout's database may now be behind the migration history. Mention this so the user can apply it when they next work locally (e.g. `npx prisma migrate dev`) — don't run it yourself as part of wrapup.
   - Apply any post-merge steps the project's `docs/agents/worktrees.md` declares for `/wrapup` (e.g. regenerating a database client after a checkout switch on a test-driven branch).

9. **Verify and report.**
   - Confirm the issue closed: `gh issue view <num> --json state,closed` — `Closes #<num>` should have closed it on merge. If it's still open, close it with a comment noting the merge.
   - Report: PR title/URL and merge commit, a one-line diffstat, that the worktree and branch are gone, whether local `main` was fast-forwarded (or why it was skipped), the issue's final state, and the migration callout from step 4 if one applies.

## Guardrails

- Never merge a stacked PR. If `baseRefName` isn't `main`, refuse and leave everything in place (step 3).
- Never merge over failing or pending CI without explicit confirmation.
- Never remove a worktree with uncommitted changes without explicit confirmation.
- Never run from inside the worktree being torn down — always operate from `$MAIN`.
- If the PR can't be confidently identified, stop and ask rather than guessing.
