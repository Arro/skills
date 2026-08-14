---
"mattpocock-skills": minor
---

Add **`review-loop`**: converge an open PR with its reviewer bot. It reads the bot's latest pass — new *or edited* comments since the last push — fixes the callouts it agrees with, pushes, waits for the re-review, and repeats. A ledger keeps every callout's verdict with a reason so nothing gets re-litigated, and the loop ends when only reasoned disagreements remain (or after five iterations, or thirty quiet minutes), posting the exit report as a comment on the issue. Ships promoted in `engineering/` with a docs page and an `ask-matt` route in the worktree loop.
