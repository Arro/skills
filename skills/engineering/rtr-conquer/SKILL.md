---
name: rtr-conquer
description: Process a single ready-for-agent issue — claim, build, hand off for review.
---

Process a single work item from the agent queue. This is an autonomous cron
run with no human present.

The `queue` and `pickup` skills are loaded alongside this skill — follow them
directly rather than trying to invoke them as slash commands.

## Steps

1. **Release anything that is no longer blocked.** The sweeper normally handles
   this, but do a quick check here too in case the sweeper hasn't run yet:

   ```sh
   gh issue list --state open --label blocked --json number --jq '.[].number'
   ```

   For each, count the blockers that are still open:

   ```sh
   gh api "repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by" \
     --jq '[.[] | select(.state=="open")] | length'
   ```

   If that is `0`, put it back on the pile:
   `gh issue edit <n> --remove-label blocked --add-label ready-for-agent`

2. Read the `queue` skill and follow its steps to identify the next issue with
   the `ready-for-agent` label.

3. If no issue is returned, stop — report "OK, queue empty".

4. **Confirm it is workable before claiming it.** A blocked issue must be parked,
   not attempted — claiming one only to bail out re-queues it and it gets
   retried every single run. Check both places a dependency is recorded:
   - the tracker's own links —
     `gh api "repos/{owner}/{repo}/issues/<id>/dependencies/blocked_by" --jq '[.[] | select(.state=="open")] | "#\(.number) \(.title)"'`
   - the contract's prose — a `## Blocked by` section, or a **Blocked by #N** line
     in the body. Resolve each referenced issue's state; only open ones count.

   If any blocker is open, park it and move on:
   - Comment naming the open blockers and saying it will return to the queue
     automatically once they close — but only if the newest comment on the issue
     is not already that same note. This runs on a schedule; do not re-comment
     the same thing every time.
   - `gh issue edit <id> --remove-label ready-for-agent --add-label blocked`
   - Go back to step 2 and take the next candidate. Do **not** stop — one blocked
     issue at the head of the queue must not starve everything behind it. If
     every candidate is blocked, stop and report "OK, queue fully blocked".

5. Read the `pickup` skill and follow its steps end-to-end for that issue number,
   treating the issue number from step 4 as the argument the skill expects. This
   claims the issue, works in an isolated worktree, and stops at an open PR.

   **Important path note:** the pickup skill references `~/.claude/skills/pickup/scripts/`
   for its helper scripts. In Hermes, the scripts are at
   `~/.hermes/skills/pickup/scripts/` — use that path instead. The scripts
   themselves use `BASH_SOURCE` so they work from either location.

6. The moment that claim succeeds — the issue is assigned to you and
   `ready-for-agent` is gone — mark the build as in flight:
   `gh issue edit <id> --add-label being-built`. Do this before any
   implementation work. It is what tells the rest of the flywheel (and the
   queue) that a build is running rather than abandoned, so an issue must never
   sit unlabeled while you work. If the pickup claim itself failed, stop
   instead — do not build an issue you did not claim.

7. Complete the work required by the issue, following its description and
   acceptance criteria. Read the project's `CLAUDE.md` and
   `docs/agents/worktrees.md` for binding project parameters (dev server,
   database branches, validation commands).

   **Database branches are mandatory.** The worktree's `.env` must point at a
   throwaway Neon branch, not the shared production database. Create one with
   the Neon MCP tool `mcp_Neon_create_branch` (projectId:
   `soft-feather-28170515`, branchName: `pickup/<id>`, expiresAt: now + 7 days).
   Get its connection string with `mcp_Neon_get_connection_string` and rewrite
   the `DATABASE_URL=` line in the worktree's `.env`.

8. Once satisfied that the issue is fulfilled, hand it to review:
   `gh issue edit <id> --remove-label being-built --add-label ready-for-code-review`

9. Stop — report "OK, issue #<id> ready for review".

## Reporting

On success: say only "OK, issue #<id> ready for review".
On failure: report the issue number, what went wrong, and what state the issue
is in. This will be delivered to the user's chat so they can intervene.

## Recovery

Never leave an issue stranded in `being-built`. If you stop after step 6
without reaching `ready-for-code-review`, clear the claim before reporting:

- **A dependency `pickup` surfaced that step 4 missed** (its contract check is
  stricter than a label scan): park it exactly as step 4 does —
  `gh issue edit <id> --remove-label being-built --add-label blocked`, comment
  naming the blocker, and unassign yourself.
- **No PR opened yet, for any other reason**: put it back on the pile as pickup
  instructs — `gh issue edit <id> --remove-label being-built --add-label
  ready-for-agent` — and unassign yourself, so another run can pick it up
  cleanly.
- **PR already open but the work is incomplete**: comment on the issue with what
  blocked you and what state the branch is in, then
  `gh issue edit <id> --remove-label being-built` and leave it unlabeled. Do
  not restore `ready-for-agent` — a fresh run would redo work that is already
  pushed — and do not add `ready-for-code-review`, since the work is not done.
