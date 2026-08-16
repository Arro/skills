---
name: rtr-ship
description: Ship a code-review-passed issue — merge its PR and bookmark visual changes.
---

Ship a single issue whose automated code review passed: merge its PR, after
bookmarking any visual changes for a later human design pass. This is an
autonomous cron run with no human present.

The `wrapup` skill is loaded alongside this skill — follow it directly. This
routine's instructions are the user's standing authorization for everything
wrapup entails: merging the PR, removing the worktree, deleting branches, and
fast-forwarding local main.

## Steps

1. Find the oldest open issue labeled `code-review-passed`:

   ```sh
   gh issue list --state open --label code-review-passed \
     --json number,title,updatedAt --jq 'sort_by(.updatedAt) | .[0]'
   ```

   If nothing is returned, stop — report "OK, nothing to ship".

2. Claim it, atomically, before doing any work: swap the label so no other run
   picks up the same issue.

   ```sh
   gh issue edit <id> --remove-label code-review-passed --add-label being-shipped
   ```

   If this command fails, stop without doing anything else. The claim label
   matters here as much as the mutex does: a ship run merges, creates issues
   and deletes branches, so an unlabeled issue must mean "this ship failed and
   needs a human", never "a ship is running right now".

3. Locate the open PR that closes the issue
   (`gh pr list --state open --search "closes #<id>" --json number,headRefName,baseRefName`)
   and confirm its base is `main`. If there is no open PR, or more than one,
   restore the label per the recovery rule below and stop with the reason.

4. Decide whether the change is visual. Start from
   `gh pr diff <pr> --name-only`, and read the actual diff hunks for any file
   you are unsure about. In this repo:
   - Visual: anything under `components/`, page/layout files under
     `app/(pipeline)/`, `globals.css` or any stylesheet, `remotion/`, React
     Three Fiber / Three.js code (scenes, lighting, materials, the model
     viewer), and image or asset changes under `public/`.
   - Not visual: `app/api/` routes, `lib/` logic, `prisma/` schema and
     migrations, `scripts/`, tests, docs, config.
   This is a judgment call, not a path checklist — a `lib/` change that alters
   what a page displays is visual; a `components/` change that only renames a
   prop is not. When genuinely unsure, treat it as visual: a spare bookmark is
   cheap, a missed design review is not.

5. If visual, bookmark it for a human — this never blocks the merge:
   - List open candidates: `gh issue list --state open --label design-review
     --json number,title,body`.
   - If one covers closely related ground (same page or section, same feature
     area, part of the same broader project), lump in: comment on that issue
     with "Related: #<id> — <one line on what changed visually and where to
     look>". If the existing title no longer covers the combined scope, you may
     broaden it (`gh issue edit <n> --title "..."`) — keep the "Design review:"
     prefix and make it honestly describe everything now lumped under it. This
     is optional, another judgment call. Do not change that issue's labels or
     create anything new.
   - Otherwise create a fresh issue titled "Design review: <page or area> —
     <short description of the visual change>", with a body linking the source
     issue and PR, describing what changed visually, and naming the route/page
     where a human should look. Label it `design-review` and nothing else — no
     `ready-for-human`, no assignee, no blocking relationship in either
     direction.

6. Merge. Read the `wrapup` skill and follow it end-to-end, treating <id> as the
   issue-number argument it expects. Its stop-and-ask conditions (red CI,
   uncommitted work in the worktree, ambiguous PR) are blockers here — there
   is no human to answer, so treat them per the recovery rule.

   **Important path note:** the wrapup skill references
   `~/.claude/skills/pickup/scripts/` for the stop-dev-servers script. In
   Hermes, the scripts are at `~/.hermes/skills/pickup/scripts/` — use that
   path instead.

7. Once the merge has landed, drop the claim:
   `gh issue edit <id> --remove-label being-shipped`. The merge closes the
   issue via its `Closes #<id>` reference; clearing the label keeps a closed
   issue from advertising a ship that is already finished.

8. Stop — report "OK, issue #<id> shipped (PR #<pr> merged)".

## Reporting

On success: say only "OK, issue #<id> shipped (PR #<pr> merged)".
On failure: report the issue number, what went wrong, and what state the issue
is in. This will be delivered to the user's chat.

## Recovery

Never leave an issue stranded in `being-shipped`. If you stop for any reason
between steps 2 and 6, remove it (`gh issue edit <id> --remove-label
being-shipped`) but do NOT restore `code-review-passed` — a red-CI issue put
back in the queue would loop on every run. Instead, comment on the issue with
what blocked the merge, leave it unlabeled, and report the blocker. The one
exception is step 3's no-PR/ambiguous-PR case, where nothing has been analyzed
yet: swap it back there
(`gh issue edit <id> --remove-label being-shipped --add-label code-review-passed`)
only if the cause is transient; if the PR is genuinely missing, comment and
leave it unlabeled instead.
