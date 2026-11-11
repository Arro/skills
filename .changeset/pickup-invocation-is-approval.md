---
"mattpocock-skills": patch
---

`pickup` now says outright that typing `/pickup <id>` is the approval for every step it prescribes (syncing `main`, claiming, creating the branch and worktree, committing, pushing, opening the PR), so the agent stops asking "May I...?" before each one. It still stops for the real decisions: a dirty checkout, a refused script, a bad contract, a stacked-PR request, an unresolvable rebase conflict.
