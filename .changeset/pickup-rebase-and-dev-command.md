---
"mattpocock-skills": patch
---

`pickup` now checks whether `main` moved during the run before its first push. If it did, it rebases onto the new `main` automatically and re-runs validation, stopping to ask only on a conflict it can't resolve with confidence. Its final report also hands you a one-line command (`cd` into the worktree, then the project's dev command) to bring the dev server back up in a new terminal for hand testing, since the session still stops its own server.
