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

## Steps

1. **Fetch the ticket.** GitHub: `gh issue view <id> --comments`. Linear: the get-issue MCP tool, with comments. What you implement against: on GitHub, the most recent `## Agent Brief` comment if one exists (the body is then context), otherwise the issue body; on Linear, the description, with comments as context. Read it in full — if it is ambiguous, contradictory, or depends on unmerged code, stop and ask rather than guessing.

2. **Branch off up-to-date `main`.** The working tree must be clean — uncommitted changes are a stop-and-ask, never a stash-and-hope. Then:

   ```sh
   git fetch origin
   git switch -c <branch> origin/main
   ```

   Branch name: `fix/<id>-<slug>` if the ticket is a bug, `feat/<id>-<slug>` otherwise — `<id>` lowercase, slug the first 4–5 meaningful words of the title in kebab-case. For Linear, keeping the identifier in the branch name is what lets Linear's GitHub integration auto-link the branch and PR to the issue. If the repo's default branch isn't `main`, substitute it throughout.

3. **Make the changes.** Follow the ticket literally, adhere to `CLAUDE.md` conventions, and read the project's domain docs first where they exist (`CONTEXT.md`, `docs/adr/`). Stay in scope — an out-of-scope cleanup becomes a follow-up issue, not part of this branch.

4. **Validate.** Run the project's validation for the area you changed: its `check`/`fix` scripts if it has them, otherwise whatever `CLAUDE.md` documents as the bar. Run any test files you added or that cover the changed code. If a check you didn't touch fails, investigate the root cause — never delete, skip, or weaken it.

5. **Commit.** Stage the files you actually changed (never `git add -A`). Conventional-style message ending with the closing reference — `Closes #<id>` for GitHub, `Closes <id>` (e.g. `Closes ABC-123`) for Linear — so the tracker auto-closes the issue on merge. One commit unless the work has natural seams.

6. **Push and open the PR.**
   - `git push -u origin <branch>`
   - `gh pr create --base main` with a body that carries the same `Closes …` reference (Linear's GitHub integration picks up the magic word from the PR body), summarises what changed, and notes anything you deviated on or want the reviewer to look at.

7. **Report.** Output the PR URL and the branch name, and note that the checkout is still on the feature branch (`git switch main` to get back). Do not merge.

## Guardrails

- Never force-push, never push to `main`, never merge.
- The branch point and PR base are always `main` (or the repo's default branch) — a ticket pointing anywhere else is a sequencing problem to surface, not an instruction to follow.
- If validation surfaces pre-existing failures unrelated to your change, mention them in the PR body but do not fix them in this PR.

## Failure recovery

- **Conflict on push** (`main` moved under you): rebase onto `origin/main`, re-run validation, then `git push --force-with-lease` — safe on your own feature branch; the force-push rule protects `main`.
