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

Project parameters for this workflow — any extra gitignored files to copy into a worktree, and any secondary port names the project's services need (e.g. `INNGEST_PORT = PORT + 10000`) — live in the project's `docs/agents/worktrees.md`; read it if it exists. Everything else project-specific — validation commands, schema/migration rules — lives in the project's `CLAUDE.md`. Read both before you start and treat them as binding.

## Scripts

The mechanical parts of setup and teardown are scripted, in `~/.claude/skills/pickup/scripts/`. Use them rather than retyping their steps — they encode the guardrails (branch point, port collisions, killing only your own servers) and refuse rather than half-doing the job.

| Script | Does | Refuses when |
| --- | --- | --- |
| `claim-ticket.sh <id> [--repo o/n] [--dry-run]` | Steps 1–3 in one call: fetches the issue, gates on state and label, claims it (assign + drop the `ready-for-agent` label), prints the contract plus a suggested branch and thread label | Issue is not OPEN (3), lacks `ready-for-agent` (4), or belongs to someone else (5) |
| `setup-worktree.sh <id> <branch> [--no-install] [--skip-port-guard]` | Step 5's mechanics: worktree off `origin/main`, gitignored container, copied `.env*`, collision-free `PORT` (plus any secondary ports), dependencies installed | The worktree or branch already exists (3), or the dev script would silently ignore `PORT` (4) — creating nothing in either case |
| `stop-dev-servers.sh <worktree-path>` | Step 10's shutdown: kills listeners on the worktree's ports whose working directory is inside it | Never kills a process from outside the worktree — it says so and moves on |

They are deliberately not the whole workflow. Reading the contract, the stacked-PR judgement, anything in the project's `docs/agents/worktrees.md` (throwaway databases especially — no script touches a database), and all of steps 6–9 stay yours. `claim-ticket.sh` is GitHub-only; for Linear, do steps 1–3 with the Linear MCP tools and start at `setup-worktree.sh`.

## Steps

1. **Fetch, gate and claim the issue.** For GitHub, one call covers this step and the next two:

   ```sh
   ~/.claude/skills/pickup/scripts/claim-ticket.sh <id>
   ```

   It prints the issue header, the contract and suggested names, then assigns the issue to you and removes its `ready-for-agent` label. Any non-zero exit is a stop-and-ask. Read the contract in full before going on — a `## Blocked by` section naming unmerged issues is a sequencing problem to surface, not to work around.

   For Linear, fetch the issue with comments via the Linear MCP tools instead.

   The contract you implement against: on GitHub, the most recent `## Agent Brief` comment if one exists (the body is then context), otherwise the issue body. On Linear, the description; comments are context.

2. **Check the label (GitHub only).** `claim-ticket.sh` enforces this — it exits 4 when `ready-for-agent` is missing, and 3 when the issue isn't OPEN. Either way, stop and ask. Linear issues have no label gate.

3. **Claim the issue (mutex) and take it out of the queue.** `claim-ticket.sh` does this too, in two halves:
   - **Assign yourself** — this is what stops two parallel `/pickup` sessions grabbing the same ticket. It continues if the issue is already yours (a resumed session) and exits 5 if it belongs to someone else — stop and ask then.
   - **Remove the `ready-for-agent` label** — so the issue drops out of the queue other agents pull from. The script skips this on a resumed session (the label is already gone) and warns rather than failing if the removal doesn't stick; if you see that warning, remove the label yourself with `gh issue edit <id> --remove-label ready-for-agent` before going on.

   If you bail out before opening the PR and the ticket goes back on the pile, re-add the label so it's pickable again.

   For Linear, assign yourself with the update-issue MCP tool; there's no label to remove.

4. **Derive a branch name.**

   `claim-ticket.sh` already printed a `SUGGESTED_BRANCH`. Take it unless it reads badly, in which case build your own to the same shape:
   - `fix/<id>-<slug>` if the issue is labeled a bug, `feat/<id>-<slug>` otherwise.
   - `<id>` lowercase (e.g. `fix/123-…`, `feat/abc-123-…`). For Linear, keeping the identifier in the branch name is also what lets Linear's GitHub integration auto-link the branch and PR to the issue.
   - Slug = first 4–5 meaningful words of the title, kebab-case, lowercase.

   Don't rename the thread — the session is already titled for this ticket by the time `/pickup` runs.

5. **Create an isolated worktree.** Never work in the main checkout — other `/pickup` sessions may be using it.

   **First, the one judgement the script can't make: branch point is always `origin/main`, and you never create a stacked PR.** If the contract, its acceptance criteria, or a "Coordination note" tells you to branch from another feature branch (e.g. `feat/<other>`), to base the PR on anything other than `main`, or to depend on code that only exists in a still-open PR — **stop and ask.** Surface it plainly: e.g. "The ticket says to branch from `feat/6` because PR #7 is still open. Stacked PRs are forbidden — that work should be sequenced (land the base ticket first, then pick this one up fresh off updated `main`). Branch from `main` instead, or hold this ticket until its dependency merges?" Do not stack to make symbols "exist" — a dependency on unmerged code means the ticket isn't ready, not that you should branch off the open branch.

   Then run, from anywhere inside the repo:

   ```sh
   ~/.claude/skills/pickup/scripts/setup-worktree.sh <id> <branch>
   ```

   It creates `$MAIN/.worktrees/<id>` off `origin/main` (nested inside the main checkout so it's easy to inspect in an editor that already has the repo open, and added to the clone-local exclude file so it doesn't show up as untracked), copies every root-level `.env*` except the committed `.env.example`, assigns a free `PORT`, and installs dependencies. It prints the path, branch and port; `cd` to that path for the rest of the session.

   It creates nothing and exits non-zero in two cases, both stop-and-ask:
   - **The worktree or branch already exists** — an earlier run didn't clean up. Don't silently reuse it.
   - **The dev script would ignore the assigned `PORT`.** Two things must both hold or the assignment is silently lost: the script expresses its port as `${PORT:-<pinned default>}` rather than a hardcoded `-p` number (a hardcoded flag always wins), and it **sources `.env.local` into its own shell invocation before that flag is expanded** — `${PORT:-3008}` is substituted by the shell `npm` spawns, long before Node exists or any dotenv loader runs, so writing `PORT` into `.env.local` alone never reaches it. The fix is a one-time change to the project's own `package.json`:
     ```
     "dev": "set -a; [ -f .env.local ] && . ./.env.local; set +a; next dev -p ${PORT:-3008}"
     ```
     That is a prerequisite commit, **not** part of this ticket's PR (guardrail: stay in scope). Surface it and let the user apply it, or open a follow-up issue. Never start a dev server on a pinned port that may belong to the main checkout. `--skip-port-guard` exists only for projects with no dev server at all.

   Port assignment, for when you need to reason about it: the preferred port is a `cksum` hash of `"<slug>-<id>"` into 3100–3999, so it's stable across runs, folds GitHub numbers and Linear identifiers in identically, and keeps issue `#15` in two repos apart. The script then bumps past anything listening, anything pinned as a `${PORT:-…}` default in `package.json`, and any port already written into a sibling worktree's env — so a stopped worktree still holds its claim. Secondary ports declared in the project's `docs/agents/worktrees.md` (e.g. `INNGEST_PORT = PORT + 10000`) are derived and written alongside. Report the assigned port(s) so the reviewer knows where the app would serve.

   **Then read the project's `docs/agents/worktrees.md` and do what it says.** The script deliberately stops at the filesystem: it never touches a database, and this is where rules about throwaway database branches live. Copy any other gitignored config that doc lists as needed to build or run (e.g. an `ios/Config.xcconfig`).

   **Browser verification** in the worktree uses `http://localhost:$PORT` directly. A `CLAUDE.md` rule mandating a reverse-proxied hostname (e.g. `https://<app>.localhost`) describes the *main checkout* — that hostname does not route to this worktree, and following it would verify the wrong server's code.

6. **Implement per the contract — run the `/implement` skill.** The contract is its spec: pass it the acceptance criteria and let it drive the build (`/tdd` at pre-agreed seams, type-checking and single test files as it goes, the full suite and a `/code-review` pass at the end). Two things override its defaults here: all work happens in the step-5 worktree, never the main checkout, and the commit is step 8 below rather than `/implement`'s own — the message needs the closing reference, so leave it uncommitted for that step.

   Follow the acceptance criteria literally. If anything in the contract is ambiguous, contradictory, or under-specified, **stop and ask** — do not guess and do not silently make a judgment call. Adhere to all `CLAUDE.md` conventions, and read the project's domain docs first where they exist (`CONTEXT.md`, `docs/adr/`).

7. **Validate.** On top of what `/implement` already ran, run the project's validation for the area you changed: its `check`/`fix` scripts if it has them (e.g. `pnpm run check && pnpm run fix`), otherwise whatever `CLAUDE.md` documents as the bar (a clean type-check, a clean simulator build, …). Run any test files you added or that cover the changed code. If a check you didn't touch fails, investigate the root cause — do not delete, skip, or weaken it.

8. **Commit.** Stage the files you actually changed (never `git add -A`). Keep generated artifacts that belong with the change together in the commit (e.g. a schema change and its migration folder). Conventional-style message ending with the closing reference — `Closes #<id>` for GitHub, `Closes <id>` (e.g. `Closes ABC-123`) for Linear — so the tracker auto-closes the issue on merge. One commit unless the work has natural seams.

9. **Push and open the PR.**
   - `git push -u origin <branch>`
   - `gh pr create --base main` with a body that links the issue (same `Closes …` reference as the commit — Linear's GitHub integration picks up the magic word from the PR body), summarises what changed, and notes anything you deviated on or want the reviewer to look at. The PR base is **always** `main` — never another feature branch.

10. **Stop the dev server, then report.**
    - **Stop the worktree's dev servers** so nothing lingers past the thread:
      ```sh
      ~/.claude/skills/pickup/scripts/stop-dev-servers.sh "$WT"
      ```
      It kills listeners on every port in the worktree's env files, but only those whose working directory is inside the worktree — an unrelated main-checkout server on the same port is reported and left alone.
    - Output the PR URL, the worktree path (so the user knows where to clean up after merge: `git worktree remove <path>`), and the assigned `PORT`.

    Do not merge. Do not squash, rebase, or force-push.

## Guardrails

- Never force-push. Never push to `main`. Never merge a PR.
- Never run `git clean` in the main checkout. Worktrees live gitignored under `$MAIN/.worktrees/`, so `git clean -fdx` from `$MAIN` would destroy every in-flight worktree, not just build artifacts.
- **Never create a stacked PR.** Always branch from `origin/main` and always open the PR with `--base main`. If the ticket points you at a non-`main` branch point or PR base, that's a sequencing problem to surface (step 5), not an instruction to follow.
- Never work in the main checkout — always in the worktree created in step 5.
- Stay in scope. Out-of-scope cleanups go in a follow-up issue, not this PR. Use `mcp__ccd_session__spawn_task` or `gh issue create`.
- If you discover the contract is wrong (e.g. an acceptance criterion is impossible or conflicts with the codebase), stop and ask — do not unilaterally redefine it.
- If validation surfaces pre-existing failures unrelated to your change, mention them in the PR body but do not fix them in this PR.
- If you bail out mid-run after creating the worktree, leave it in place and tell the user the path so they can resume or clean up. Do not silently delete in-progress work — but still stop any dev server you started (the step-10 shutdown), so a left-behind worktree never means a left-behind server.
- Never leave a dev server running when the session ends. On success or bail-out, stop whatever is listening on the worktree's `PORT` (verifying its working directory is inside the worktree first).

## Failure recovery

- **Conflict on push** (someone else's PR merged first, your branch is behind `main`): rebase onto `origin/main`, re-run validation, force-push to your own branch only (`git push --force-with-lease`). Force-with-lease is safe on your own feature branch; the rule against force-push applies to `main`.
- **Lost the assignee race** (someone else claimed the issue between step 1 and step 3): if the assign call fails or the issue is now assigned to someone else, stop and report.
