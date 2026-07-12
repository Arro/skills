---
name: pickup
description: Pick up a ready-for-agent GitHub issue in an isolated worktree and take it through to an open PR.
argument-hint: "issue number"
disable-model-invocation: true
---

# /pickup — implement a ready-for-agent ticket end-to-end

Pick up the ticket whose issue number was passed as the argument (call it `<num>` below), work in an isolated git worktree, and take it through to an open PR. Stop before merge. Designed so multiple `/pickup` sessions can run in parallel without colliding. If no issue number was given, stop and ask for one.

Project parameters for this workflow — the session tag and any extra gitignored files to copy into a worktree — live in the project's `docs/agents/worktrees.md`; read it if it exists. Everything else project-specific — validation commands, schema/migration rules, dev-server port constraints — lives in the project's `CLAUDE.md`. Read both before you start and treat them as binding.

## Steps

1. **Fetch the issue.** Run `gh issue view <num> --comments`. Read the full body, all comments, and labels. The most recent comment titled `## Agent Brief` is the contract; the original body is context. If there is no agent brief, stop and ask whether to proceed from the body alone.

2. **Check the label.** Confirm the issue carries `ready-for-agent`. If not, stop and ask.

3. **Claim the issue (mutex).** Check the issue's assignee:
   - If unassigned: run `gh issue edit <num> --add-assignee @me`. This is the mutex that prevents two parallel `/pickup` sessions from grabbing the same ticket.
   - If assigned to you already: continue (probably a resumed session).
   - If assigned to someone else: stop and ask — another agent or human is on it.

4. **Derive a branch name.**
   - `fix/<num>-<slug>` if the issue is labeled `bug`.
   - `feat/<num>-<slug>` if labeled `enhancement`.
   - Slug = first 4–5 meaningful words of the title, kebab-case, lowercase.

   Then, as your very next output, tell the user to rename this session so the sidebar isn't misleading (it often inherits a stale title from a prior `/queue` or unrelated turn). You cannot run `/rename` yourself — it is a session-control command and is not agent-invocable — so surface it for the user to copy. Include a short human-readable label derived from the issue title (≈3–6 words, enough to recognise the issue at a glance in the sidebar — not just the number), prefixed with the project's session tag: the tag `docs/agents/worktrees.md` defines, or failing that the initials of the repo name's hyphenated words (`amber-waveform` → `aw`).

   Emit the `/rename` command on its **own fenced code block** (not inline `` `code` ``) so the GUI clients render a copy button on it. One short intro line, then the block — and nothing else on the line inside the block, so a one-click copy yields a directly paste-able command:

   📝 Rename this session (copy the line below):

   ````
   ```
   /rename [<tag>] #<num> <short label>
   ```
   ````

   e.g. the block would contain `/rename [aw] #37 forge weighted-fill logic`.

5. **Create an isolated worktree.** Never work in the main checkout — other `/pickup` sessions may be using it.
   - Locate the main repo root: `MAIN=$(git worktree list --porcelain | awk '/^worktree / {print $2; exit}')`
   - Worktree path: `WT="$MAIN/../$(basename "$MAIN")-wt/<num>"`
   - If `$WT` already exists, stop and ask — it means an earlier run on this ticket didn't clean up. Don't silently reuse.
   - **Branch point is always `origin/main`. Never create a stacked PR.** If the brief, its acceptance criteria, or a "Coordination note" tells you to branch from another feature branch (e.g. `feat/<other>`), to base the PR on anything other than `main`, or to depend on code that only exists in a still-open PR — **stop and ask.** Surface it plainly: e.g. "The brief says to branch from `feat/6` because PR #7 is still open. Stacked PRs are forbidden — that work should be sequenced (land the base ticket first, then pick this one up fresh off updated `main`). Branch from `main` instead, or hold this ticket until its dependency merges?" Do not stack to make symbols "exist" — a dependency on unmerged code means the ticket isn't ready, not that you should branch off the open branch.
   - Otherwise create it from a fresh main: `git -C "$MAIN" fetch origin && git -C "$MAIN" worktree add "$WT" -b <branch> origin/main`
   - `cd "$WT"` for the rest of the session.
   - **Copy gitignored local files** the app needs to run but that don't travel with a worktree. At minimum the env files — copy every root-level `.env*` from the main checkout except the committed `.env.example`:
     `for f in "$MAIN"/.env*; do b=$(basename "$f"); [ "$b" = ".env.example" ] && continue; cp "$f" "$WT/$b"; done`
     Without this, the dev server will fail in the worktree with missing-env errors. Also copy any other gitignored config `docs/agents/worktrees.md` lists as needed to build or run (e.g. an `ios/Config.xcconfig`).
   - Install dependencies with the project's package manager (worktrees share `.git` but not `node_modules`; pnpm's content-addressed store makes `pnpm install` fast).

6. **Implement per the brief.** Follow the acceptance criteria literally. If anything in the brief is ambiguous, contradictory, or under-specified, **stop and ask** — do not guess and do not silently make a judgment call. Adhere to all `CLAUDE.md` conventions, and read the project's domain docs first where they exist (`CONTEXT.md`, `docs/adr/`).

7. **Validate.** Run the project's validation for the area you changed: its `check`/`fix` scripts if it has them (e.g. `pnpm run check && pnpm run fix`), otherwise whatever `CLAUDE.md` documents as the bar (a clean type-check, a clean simulator build, …). Run any test files you added or that cover the changed code. If a check you didn't touch fails, investigate the root cause — do not delete, skip, or weaken it.

8. **Commit.** Stage the files you actually changed (never `git add -A`). Keep generated artifacts that belong with the change together in the commit (e.g. a schema change and its migration folder). Conventional-style message ending with `Closes #<num>` so GitHub auto-closes the issue on merge. One commit unless the work has natural seams.

9. **Push and open the PR.**
   - `git push -u origin <branch>`
   - `gh pr create --base main` with a body that links the issue (`Closes #<num>`), summarises what changed, and notes anything you deviated on or want the reviewer to look at. The PR base is **always** `main` — never another feature branch.

10. **Stop and report.** Output:
    - the PR URL
    - the worktree path (so the user knows where to clean up after merge: `git worktree remove <path>`)

    Do not merge. Do not squash, rebase, or force-push.

## Guardrails

- Never force-push. Never push to `main`. Never merge a PR.
- **Never create a stacked PR.** Always branch from `origin/main` and always open the PR with `--base main`. If the brief points you at a non-`main` branch point or PR base, that's a sequencing problem to surface (step 5), not an instruction to follow.
- Never work in the main checkout — always in the worktree created in step 5.
- Stay in scope. Out-of-scope cleanups go in a follow-up issue, not this PR. Use `mcp__ccd_session__spawn_task` or `gh issue create`.
- If you discover the brief is wrong (e.g. an acceptance criterion is impossible or conflicts with the codebase), stop and ask — do not unilaterally redefine the contract.
- If validation surfaces pre-existing failures unrelated to your change, mention them in the PR body but do not fix them in this PR.
- If you bail out mid-run after creating the worktree, leave it in place and tell the user the path so they can resume or clean up. Do not silently delete in-progress work.

## Failure recovery

- **Conflict on push** (someone else's PR merged first, your branch is behind `main`): rebase onto `origin/main`, re-run validation, force-push to your own branch only (`git push --force-with-lease`). Force-with-lease is safe on your own feature branch; the rule against force-push applies to `main`.
- **Lost the assignee race** (someone else claimed the issue between step 1 and step 3): if `gh issue edit --add-assignee @me` fails because it's now assigned to someone else, stop and report.
