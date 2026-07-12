---
name: queue
description: Show the ready-for-agent queue — what's available to pick up, what's already claimed, and any conflicts.
disable-model-invocation: true
---

# /queue — show the agent pickup queue

Report on the current state of the `ready-for-agent` queue in the current repo. Read-only. No labels modified, no issues claimed.

## Steps

1. **Available** — issues labeled `ready-for-agent`, open, unassigned:
   ```
   gh issue list --label ready-for-agent --state open --search "no:assignee" \
     --json number,title,labels,createdAt \
     --jq '.[] | "#\(.number) [\(.labels | map(.name) | join(","))] \(.title)"'
   ```
   List oldest first. These are free to pick up with `/pickup <num>`.

2. **In flight** — issues labeled `ready-for-agent`, open, with an assignee:
   ```
   gh issue list --label ready-for-agent --state open --search "assignee:*" \
     --json number,title,assignees,updatedAt \
     --jq '.[] | "#\(.number) → @\(.assignees[0].login) (updated \(.updatedAt)) — \(.title)"'
   ```
   These are claimed. Note who has each one and when it was last touched — a stale "in flight" issue may be an abandoned session worth investigating.

3. **Open PRs from agent work** — to give the user the review backlog, and to flag any stacked PR (base != `main`) since stacked PRs are forbidden and `/wrapup` will refuse to merge them:
   ```
   gh pr list --state open --json number,title,headRefName,baseRefName,createdAt \
     --jq '.[] | select(.headRefName | test("^(fix|feat)/[0-9]+-")) | "PR #\(.number) (\(.headRefName) → \(.baseRefName))\(if .baseRefName != "main" then "  ⚠ STACKED — not mergeable via /wrapup" else "" end) — \(.title)"'
   ```
   Call out any `⚠ STACKED` PR prominently in the summary — it needs retargeting to `main` (once its base lands) before it can be wrapped up.

4. **Local worktrees** — show any `<repo>-wt/*` worktrees on this machine (the sibling directory `/pickup` creates, named after the main checkout), so the user can see what's lingering after merge:
   ```
   git worktree list
   ```
   Flag any worktree whose branch has already been merged or deleted upstream — those are cleanup candidates (`git worktree remove <path>`).

5. **Summarise.** Give a 3–5 line summary at the end:
   - N available to pick up (oldest: #X)
   - N in flight (oldest update: ...)
   - N PRs awaiting review (call out any ⚠ stacked PRs by number)
   - N worktrees ready to clean up

No editing. No claiming. This command exists to give the user a clear picture before they decide what to start, review, or close out.
