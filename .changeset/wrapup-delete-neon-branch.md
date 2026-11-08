---
"mattpocock-skills": patch
---

`wrapup` now deletes the ticket's throwaway Neon database branch after the merge, without asking: invoking `/wrapup` is the permission. It finds the branch by the exact name the project's `docs/agents/worktrees.md` gives (usually `pickup/<num>`), never touches the default or production branch, and first points the main checkout's `.env` back at production if `/test-drive` had switched it onto the branch. Without the Neon MCP tools it finishes the wrapup and names the branch for deletion by hand. Also fixes the already-merged path, which skipped to the merge step instead of cleanup.
