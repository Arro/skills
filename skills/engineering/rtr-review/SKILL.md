---
name: rtr-review
description: Review one issue with the ready-for-code-review label.
---

Review a single issue that is waiting for code review. This is an autonomous
cron run with no human present.

The `code-review` skill is loaded alongside this skill — follow it directly.

MAX_REVIEWS = 3. An issue body may override this with a line reading
`max-reviews: N`. When in doubt, the lower number wins. The cap is what stops
review/fix ping-pong: the final review is terminal, so an issue always leaves
this routine as `code-review-passed` once its budget is spent, findings or not.

## Steps

1. Find the oldest open issue labeled `ready-for-code-review`:

   ```sh
   gh issue list --state open --label ready-for-code-review \
     --json number,title,body,updatedAt --jq 'sort_by(.updatedAt) | .[0]'
   ```

   If nothing is returned, stop — report "OK, nothing to review". Note any
   `max-reviews: N` line in the body.

2. Claim it, atomically, before doing any work: swap the label so no other run
   picks up the same issue.

   ```sh
   gh issue edit <id> --remove-label ready-for-code-review --add-label being-code-reviewed
   ```

   If this command fails, stop — do not review an issue you did not successfully
   claim.

3. Locate the PR that closes the issue:

   ```sh
   gh pr list --state open --search "closes #<id>" --json number,headRefName,baseRefName
   ```

   Confirm its base is `main`. If there is no open PR, or more than one, restore
   the labels per the recovery rule below and stop with the reason.

4. Enforce the cap. Count prior review rounds on the PR: the comments containing
   both the `## Standards` and `## Spec` headings (that is the report format,
   so this counts older rounds posted before rounds were numbered).

   ```sh
   gh pr view <pr> --json comments \
     --jq '[.comments[] | select((.body | contains("## Standards")) and (.body | contains("## Spec")))] | length'
   ```

   This run is round N = that count + 1. If the count is already >= MAX_REVIEWS
   (or the issue's override), the budget is spent — do not review again:
   - Comment on the issue saying how many review rounds have run, that the cap
     was reached, and linking the most recent report.
   - `gh issue edit <id> --remove-label being-code-reviewed --add-label code-review-passed`
   - Stop — report "OK, issue #<id> passed on cap (round <N>)".

5. Get to a checkout whose HEAD is the PR branch:
   - Prefer the existing worktree at `.worktrees/<id>` — `/pickup` leaves it in
     place. Verify with `git -C .worktrees/<id> rev-parse --abbrev-ref HEAD`
     that it is on the PR's head branch, and that
     `git -C .worktrees/<id> status --porcelain` is clean.
   - If the worktree is gone, create a read-only one:
     `git worktree add .worktrees/review-<id> <head-branch>`. Remember you
     created it — you remove it in step 8.
   - Do all remaining work from that directory. Never review from the main
     checkout.

6. Run the review. Read the `code-review` skill and follow it end-to-end, with
   `main` as the fixed point. Do not ask for the fixed point — it is always
   `main`, because `/pickup` always bases its PRs there. Let the skill's own
   step 2 find the spec from the `Closes #<id>` reference in the commit
   messages; if it finds nothing, fetch the issue yourself with
   `gh issue view <id> --comments` and pass the most recent `## Agent Brief`
   comment (or the issue body if there is none) as the spec.

7. Post the skill's aggregated report as a PR comment, verbatim, under both the
   `## Standards` and `## Spec` headings. First line exactly
   `Automated code review round <N> of <MAX>`, then a line saying it was
   produced by an automated review run. If this is the final round (N == MAX)
   and either axis produced findings, say so above the report: the cap is
   reached, the issue is passing through anyway, and the findings below are for
   a human to skim before merge. Use `gh pr comment <pr> --body-file` with a
   heredoc; do not approve, request changes, or submit a formal PR review.

8. Clean up and hand off:
   - If you created `.worktrees/review-<id>` in step 5, remove it:
     `git worktree remove .worktrees/review-<id>`.
   - Remove `being-code-reviewed`, and add the terminal label:
     - `code-review-passed` if neither axis produced findings;
     - `code-review-passed` if this was the final round (N >= MAX), whatever it
       found — there is no fix cycle left to send it to;
     - otherwise `changes-requested`.
   - Stop — report "OK, issue #<id> reviewed, round <N>/<MAX>, <passed|changes-requested>".

## Reporting

On success: say only "OK, issue #<id> reviewed, round <N>/<MAX>, <result>".
On failure: report the issue number, what went wrong, and what state the issue
is in. This will be delivered to the user's chat.

## Read-only constraint

Read-only on the branch: do not commit, push, amend, rebase, merge, or edit
any file in the worktree. Do not run `wrapup` or merge the PR. Fixing what the
review finds is a human decision (or the fix routine's job).

## Recovery

If you stop for any reason after step 2, put the issue back the way you found
it before reporting the blocker:
`gh issue edit <id> --remove-label being-code-reviewed --add-label ready-for-code-review`
— so it is not stranded in `being-code-reviewed` forever.
