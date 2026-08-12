---
name: test-drive
description: Check out a picked-up ticket's branch in the main checkout for hands-on testing, tearing down its worktree first.
argument-hint: "issue number"
disable-model-invocation: true
---

# /test-drive — put a worktree's branch on the main checkout

Take the branch that `/pickup` created for the issue passed as the argument (call it `<id>` below) and check it out in the **main checkout**, so the user can test it without `cd`-ing into a worktree. Git refuses to check out a branch that another worktree holds, so this means removing the worktree first — that's expected and fine; the worktrees exist for parallelization, not as the place to test. If no issue id was given, stop and ask for one.

## Steps

1. **Locate the worktree.**
   - Main repo root: `MAIN=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')`. If the current directory is inside the worktree about to be removed, `cd "$MAIN"` first.
   - Worktree path: `WT="$MAIN/.worktrees/<id>"`. If that doesn't exist, also check the legacy sibling layout older `/pickup` runs used: `WT="$MAIN/../$(basename "$MAIN")-wt/<id>"`.
   - **If no worktree exists for `<id>`, assume the command was made in error.** Do not guess, do not check out a branch by name, do not create anything. List what actually lives in `$MAIN/.worktrees/` and ask the user to clarify which issue they meant.

2. **Read the branch.** `BRANCH=$(git -C "$WT" branch --show-current)`. If empty (detached HEAD), stop and ask — there's no branch to carry over.

3. **Safety checks.**
   - Worktree clean? `git -C "$WT" status --porcelain`. If there are uncommitted changes, stop and ask — removing the worktree would discard them. Offer to commit them to `$BRANCH` first.
   - Main checkout clean? `git -C "$MAIN" status --porcelain`. If dirty, stop and surface it — switching branches with a dirty tree carries the changes along or fails; let the user decide.
   - Note the main checkout's current branch (`git -C "$MAIN" symbolic-ref --short HEAD`) so the report can say what was switched away from.

4. **Stop the worktree's dev servers.**

   ```sh
   ~/.claude/skills/pickup/scripts/stop-dev-servers.sh "$WT"
   ```

   It kills listeners on every port in the worktree's env files, but only those whose working directory is inside `$WT` — an unrelated server on the same port is reported and left running.

5. **Tear down the worktree.** The branch survives this — only the checkout directory goes.
   - `git -C "$MAIN" worktree remove "$WT"` (use `--force` only after explicit confirmation that nothing in it matters).
   - `git -C "$MAIN" worktree prune`

6. **Check out the branch.** `git -C "$MAIN" checkout "$BRANCH"`.

7. **Report.**
   - `$BRANCH` is now checked out in `$MAIN`; name the branch that was switched away from (usually `main` — `git checkout main` gets back).
   - The worktree's per-issue `PORT` assignment lived in the worktree's `.env.local` and is gone with it — the main checkout's own dev script and usual port apply now.
   - `/wrapup <id>` still works later: it finds the PR via `gh` when the worktree is missing, and merging will clean up the branch as usual.

## Guardrails

- Never delete the branch — this skill removes only the worktree directory. The branch and its PR are untouched.
- Never `worktree remove --force` over uncommitted changes without explicit confirmation.
- If the worktree doesn't exist, touch nothing — list `.worktrees/` and ask (step 1).
- Never run the removal from inside the worktree — operate from `$MAIN`.
