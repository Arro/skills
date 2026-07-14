---
name: pickup
description: Pick up a ready-for-agent issue (GitHub or Linear) in an isolated worktree and take it through to an open PR.
argument-hint: "issue number, Linear identifier, or issue URL"
disable-model-invocation: true
---

# /pickup — implement a ready-for-agent ticket end-to-end

Pick up the ticket passed as the argument, work in an isolated git worktree, and take it through to an open PR. Stop before merge. Designed so multiple `/pickup` sessions can run in parallel without colliding. If no ticket was given, stop and ask for one.

The ticket can live in GitHub or Linear — detect which from the argument:

- A bare number, `#123`, or a `github.com` issue URL → **GitHub**.
- An identifier like `ABC-123` or a `linear.app` URL → **Linear**.

Call the ticket's reference `<id>` below: the issue number for GitHub, the identifier (e.g. `ABC-123`) for Linear. Where a step's command is GitHub-specific (`gh …`), use the equivalent Linear MCP tool for a Linear ticket.

Project parameters for this workflow — any extra gitignored files to copy into a worktree — live in the project's `docs/agents/worktrees.md`; read it if it exists. Everything else project-specific — validation commands, schema/migration rules, dev-server port constraints — lives in the project's `CLAUDE.md`. Read both before you start and treat them as binding.

## Steps

1. **Fetch the issue.** For GitHub, run `gh issue view <id> --comments`; for Linear, fetch the issue (with comments) via the Linear MCP tools. Read the full body, all comments, and labels. The contract you implement against:
   - **GitHub:** if a comment titled `## Agent Brief` exists, the most recent one is the contract and the original body is context. If there is no agent brief, the issue body is the contract.
   - **Linear:** the issue description is the contract; comments are context.

2. **Check the label (GitHub only).** For a GitHub issue, confirm it carries `ready-for-agent`; if not, stop and ask. Linear issues have no label gate — skip this step.

3. **Claim the issue (mutex).** Check the issue's assignee:
   - If unassigned: assign it to yourself — `gh issue edit <id> --add-assignee @me` for GitHub, the update-issue Linear MCP tool for Linear. This is the mutex that prevents two parallel `/pickup` sessions from grabbing the same ticket.
   - If assigned to you already: continue (probably a resumed session).
   - If assigned to someone else: stop and ask — another agent or human is on it.

4. **Derive a branch name.**
   - `fix/<id>-<slug>` if the issue is labeled a bug, `feat/<id>-<slug>` otherwise.
   - `<id>` lowercase (e.g. `fix/123-…`, `feat/abc-123-…`). For Linear, keeping the identifier in the branch name is also what lets Linear's GitHub integration auto-link the branch and PR to the issue.
   - Slug = first 4–5 meaningful words of the title, kebab-case, lowercase.

   Then, as your very next output, run the `/rename-thread` skill with the title `<id> <short label>` — a short human-readable label derived from the issue title (≈3–6 words, enough to recognise the issue at a glance in the sidebar — not just the id). The skill prefixes the project's session tag and emits the copy-able rename block for the user. This matters because the session often inherits a stale title from a prior `/queue` or unrelated turn.

5. **Create an isolated worktree.** Never work in the main checkout — other `/pickup` sessions may be using it.
   - Locate the main repo root: `MAIN=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')`
   - Worktree path: `WT="$MAIN/.worktrees/<id>"` — inside the main checkout so the worktree is easy to inspect in an editor that has the repo open.
   - Make sure the container directory is ignored. Git does **not** auto-ignore a nested worktree; without this the main checkout would show the whole worktree as untracked. Use the clone-local exclude file (no commit needed in the project):
     `grep -qxF '/.worktrees/' "$MAIN/.git/info/exclude" || echo '/.worktrees/' >> "$MAIN/.git/info/exclude"`
   - If `$WT` already exists, stop and ask — it means an earlier run on this ticket didn't clean up. Don't silently reuse.
   - **Branch point is always `origin/main`. Never create a stacked PR.** If the contract, its acceptance criteria, or a "Coordination note" tells you to branch from another feature branch (e.g. `feat/<other>`), to base the PR on anything other than `main`, or to depend on code that only exists in a still-open PR — **stop and ask.** Surface it plainly: e.g. "The ticket says to branch from `feat/6` because PR #7 is still open. Stacked PRs are forbidden — that work should be sequenced (land the base ticket first, then pick this one up fresh off updated `main`). Branch from `main` instead, or hold this ticket until its dependency merges?" Do not stack to make symbols "exist" — a dependency on unmerged code means the ticket isn't ready, not that you should branch off the open branch.
   - Otherwise create it from a fresh main: `git -C "$MAIN" fetch origin && git -C "$MAIN" worktree add "$WT" -b <branch> origin/main`
   - `cd "$WT"` for the rest of the session.
   - **Copy gitignored local files** the app needs to run but that don't travel with a worktree. At minimum the env files — copy every root-level `.env*` from the main checkout except the committed `.env.example`:
     `for f in "$MAIN"/.env*; do b=$(basename "$f"); [ "$b" = ".env.example" ] && continue; cp "$f" "$WT/$b"; done`
     Without this, the dev server will fail in the worktree with missing-env errors. Also copy any other gitignored config `docs/agents/worktrees.md` lists as needed to build or run (e.g. an `ios/Config.xcconfig`).
   - Install dependencies with the project's package manager (worktrees share `.git` but not `node_modules`; pnpm's content-addressed store makes `pnpm install` fast).

6. **Implement per the contract.** Follow the acceptance criteria literally. If anything in the contract is ambiguous, contradictory, or under-specified, **stop and ask** — do not guess and do not silently make a judgment call. Adhere to all `CLAUDE.md` conventions, and read the project's domain docs first where they exist (`CONTEXT.md`, `docs/adr/`).

7. **Validate.** Run the project's validation for the area you changed: its `check`/`fix` scripts if it has them (e.g. `pnpm run check && pnpm run fix`), otherwise whatever `CLAUDE.md` documents as the bar (a clean type-check, a clean simulator build, …). Run any test files you added or that cover the changed code. If a check you didn't touch fails, investigate the root cause — do not delete, skip, or weaken it.

8. **Commit.** Stage the files you actually changed (never `git add -A`). Keep generated artifacts that belong with the change together in the commit (e.g. a schema change and its migration folder). Conventional-style message ending with the closing reference — `Closes #<id>` for GitHub, `Closes <id>` (e.g. `Closes ABC-123`) for Linear — so the tracker auto-closes the issue on merge. One commit unless the work has natural seams.

9. **Push and open the PR.**
   - `git push -u origin <branch>`
   - `gh pr create --base main` with a body that links the issue (same `Closes …` reference as the commit — Linear's GitHub integration picks up the magic word from the PR body), summarises what changed, and notes anything you deviated on or want the reviewer to look at. The PR base is **always** `main` — never another feature branch.

10. **Stop and report.** Output:
    - the PR URL
    - the worktree path (so the user knows where to clean up after merge: `git worktree remove <path>`)

    Do not merge. Do not squash, rebase, or force-push.

## Guardrails

- Never force-push. Never push to `main`. Never merge a PR.
- Never run `git clean` in the main checkout. Worktrees live gitignored under `$MAIN/.worktrees/`, so `git clean -fdx` from `$MAIN` would destroy every in-flight worktree, not just build artifacts.
- **Never create a stacked PR.** Always branch from `origin/main` and always open the PR with `--base main`. If the ticket points you at a non-`main` branch point or PR base, that's a sequencing problem to surface (step 5), not an instruction to follow.
- Never work in the main checkout — always in the worktree created in step 5.
- Stay in scope. Out-of-scope cleanups go in a follow-up issue, not this PR. Use `mcp__ccd_session__spawn_task` or `gh issue create`.
- If you discover the contract is wrong (e.g. an acceptance criterion is impossible or conflicts with the codebase), stop and ask — do not unilaterally redefine it.
- If validation surfaces pre-existing failures unrelated to your change, mention them in the PR body but do not fix them in this PR.
- If you bail out mid-run after creating the worktree, leave it in place and tell the user the path so they can resume or clean up. Do not silently delete in-progress work.

## Failure recovery

- **Conflict on push** (someone else's PR merged first, your branch is behind `main`): rebase onto `origin/main`, re-run validation, force-push to your own branch only (`git push --force-with-lease`). Force-with-lease is safe on your own feature branch; the rule against force-push applies to `main`.
- **Lost the assignee race** (someone else claimed the issue between step 1 and step 3): if the assign call fails or the issue is now assigned to someone else, stop and report.
