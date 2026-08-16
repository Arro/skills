---
name: rtr-dispatcher
description: Dispatch one stage of the RTR pipeline based on which trigger labels have work.
---

You are the RTR pipeline dispatcher. The monitor script has already detected
which issues need work and told you in the context above. Your job: process
each one through its appropriate stage.

## How to read the monitor output

The monitor output (in your context) lists issues as `<label>:<issue-number>`.
Each label maps to a stage:

| Label | Stage | Skill to load |
|------|-------|---------------|
| `ready-for-agent` | Conquer | `rtr-conquer` |
| `ready-for-code-review` | Review | `rtr-review` |
| `changes-requested` | Fix | `rtr-fix` |
| `code-review-passed` | Ship | `rtr-ship` |
| `design-review` | Design Capture | `rtr-design-review` |
| `design-changes-requested` | Design Fix | `rtr-design-review` |

## Process

Process exactly ONE issue per run — the highest-priority issue from any stage.
Do not process multiple issues in one run. This keeps context fresh and prevents
subagent limit guardrails from firing.

1. Read the monitor output (in your context) — it lists issues as `<label>:<issue-number>`.
2. Pick the single highest-priority issue (see priority order below).
3. Load and follow the corresponding stage skill for that one issue.
4. Complete that stage's work and stop. The next tick will pick up the next issue.

The 1-minute polling interval means the next issue starts processing almost
immediately after this run finishes — there is no benefit to batching.

## Priority order

If multiple stages have work, process in this order:
1. **Ship** (code-review-passed) — get merged work out the door first
2. **Review** (ready-for-code-review) — move built work toward shipping
3. **Fix** (changes-requested) — unblock the review→fix loop
4. **Conquer** (ready-for-agent) — start new work
5. **Design Capture** (design-review) — screenshot visual changes for human review
6. **Design Fix** (design-changes-requested) — convert human design feedback into work tickets

Design stages are the lowest two priorities so code work is never delayed by a
screenshot session or spec-writing run.

## Reporting

For each issue processed, report the result. If everything succeeded, report
"OK" with a summary of what was done. If something went wrong on any issue,
report the details — this will be delivered to the user's chat.

## Constraints

- Process exactly ONE issue per run — never batch multiple issues. The 1-minute
  polling interval means the next issue starts processing immediately after.
- Always follow the stage skill's claim/recovery rules — never leave an issue
  stranded in an in-progress label.
- If a stage's skill fails to load, report the error and stop.

## See also

- `references/pipeline-architecture.md` — full architecture, monitor script
  hash-suppression pattern, cron job setup gotchas, prerequisites (Neon MCP),
  and the complete label state machine.

## Pitfall: cron job repeat

When creating the cron job for this dispatcher, you MUST set `repeat: 999999`
(or another large number). A schedule like `"1m"` defaults to a one-shot job
that fires once and stops. Without an explicit `repeat`, the entire pipeline
goes silent after the first tick.
