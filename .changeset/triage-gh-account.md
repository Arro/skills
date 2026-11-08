---
"mattpocock-skills": patch
---

`triage` now runs its `gh` commands as the GitHub account that owns the repo, the same way `grab` and `pickup` do. It ships its own copy of `gh-account.sh`, which matches the `[user]` email in the repo's `.git/config` against the logged-in `gh` accounts. On a match, each `gh` call is prefixed with that account's token rather than running `gh auth switch`. With no match, `gh` runs as it is.
