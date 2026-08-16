---
name: rtr-fix
description: Fix findings from one automated code review, then send back for re-review.
---

Address the findings from one automated code review, then send the issue back
for re-review. One pass only — this routine never loops within a run. This is
an autonomous cron run with no human present.

The `code-review` skill is loaded alongside this skill — follow it directly
when you need to understand the review format.

MAX_FIX_PASSES = 3. An issue body may override this with a line reading
`max-fix-passes: N`. When in doubt, the lower number wins.

You are deliberately a fresh agent with no context from the implementation
session. Your context is: the issue, the PR, and the review report. Do not try
to reconstruct or second-guess the original session's reasoning beyond what
those say.

## Steps

1. Find the oldest open issue labeled `changes-requested`:

   ```sh
   gh issue list --state open --label changes-requested \
     --json number,title,body,updatedAt --jq 'sort_by(.updatedAt) | .[0]'
   ```

   If nothing is returned, stop — report "OK, nothing to fix". Note any
   `max-fix-passes: N` line in the body.

2. Claim it, atomically, before doing any work: swap the label so no other run
   picks up the same issue.

   ```sh
   gh issue edit <id> --remove-label changes-requested --add-label making-requested-changes
   ```

   If this command fails, stop — do not fix an issue you did not successfully
   claim.

3. Locate the open PR that closes the issue
   (`gh pr list --state open --search "closes #<id>" --json number,headRefName`).
   If there is no open PR, or more than one, comment on the issue with the
   problem, drop the claim
   (`gh issue edit <id> --remove-label making-requested-changes`) to leave it
   unlabeled, and stop.

4. Enforce the cap. Count prior fix passes: the PR comments whose first line
   starts with `Automated fix pass`. If that count is already >= MAX_FIX_PASSES
   (or the issue's override), escalate instead of fixing:
   - Comment on the issue: how many review/fix cycles have run, and a short
     summary of what keeps failing (read the review reports to write this).
   - `gh issue edit <id> --remove-label making-requested-changes --add-label ready-for-human`
   - Stop — report "EXCEPTION: issue #<id> escalated to ready-for-human after <N> fix passes".

5. Read the review. The findings are the most recent PR comment containing the
   `## Standards` and `## Spec` headings (posted by the automated review run).
   That report is your work order. Also fetch the issue's contract
   (`gh issue view <id> --comments` — the most recent `## Agent Brief` comment
   if one exists, otherwise the body) so spec findings can be checked against
   what was actually asked for.

6. Get into the PR branch:
   - Prefer the existing worktree at `.worktrees/<id>`. Verify with
     `git -C .worktrees/<id> rev-parse --abbrev-ref HEAD` that it is on the
     PR's head branch and that `git status --porcelain` is clean.
   - If it is missing, create one:
     `git worktree add .worktrees/<id> <head-branch>`, then copy root-level
     `.env*` files from the main checkout (except `.env.example`) as
     `docs/agents/worktrees.md` describes. **Database branches are mandatory**
     — create a throwaway Neon branch via the `mcp_Neon_create_branch` MCP tool
     and rewrite `DATABASE_URL` in the worktree's `.env`.
   - Do all remaining work from that directory. Never work in the main checkout.

7. Address the findings, one pass:
   - Fix every hard violation and every spec finding (missing/partial
     requirements, wrong implementations, scope creep to remove).
   - Judgment-call smells: fix them where the fix is clearly right and
     contained. Where you disagree, or the fix would exceed the ticket's scope,
     do NOT change the code — instead record a one-line rationale for the
     pass-report comment in step 9. A written rationale is how this system
     avoids two agents ping-ponging the same finding forever; never silently
     skip a finding.
   - Stay in scope: touch only what the findings and the contract require. Do
     not refactor beyond the findings, do not weaken or delete failing checks.

8. Validate: the project's check/fix scripts, the tests covering what you
   changed, and a full suite run at the end. Commit the fixes to the PR branch
   (conventional message, reference `#<id>` but do NOT include another `Closes`
   line) and push. If the branch is behind origin/main, rebase onto origin/main
   and push with `--force-with-lease` — that is the only force-push permitted,
   and only to this feature branch.

9. Post the pass report as a PR comment. First line exactly:
   `Automated fix pass <N> of <MAX>` (N = the step-4 count + 1). Then: what was
   fixed per finding, and each finding intentionally left with its rationale.

10. Send it back for review:
    `gh issue edit <id> --remove-label making-requested-changes --add-label ready-for-code-review`.
    Stop — report "OK, issue #<id> fix pass <N>/<MAX> complete, sent for re-review".

## Reporting

On success: say only "OK, issue #<id> fix pass <N>/<MAX> complete".
On failure or escalation: report the issue number, what went wrong, and what
state the issue is in. This will be delivered to the user's chat.

## Constraints

Never merge, never run wrapup, never push to main. Do not create or modify any
design-review issues — that is the ship routine's job.

## Recovery

If you stop for any reason after step 2 without completing a pass, comment on the
issue with what blocked you, then clear the claim
(`gh issue edit <id> --remove-label making-requested-changes`) and leave it
unlabeled — do not restore `changes-requested` (it would retry a doomed fix
every run) and do not add `ready-for-code-review` (nothing changed, so
re-review would be a wasted cycle). Never leave an issue stranded in
`making-requested-changes`.
