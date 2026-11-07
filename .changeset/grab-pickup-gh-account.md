---
"mattpocock-skills": patch
---

`grab` and `pickup` now run their `gh` commands as the GitHub account that owns the repo. A new `gh-account.sh` script reads the `[user]` email from the repo's `.git/config` and matches it against the logged-in `gh` accounts (noreply address, public profile email, or the account's email list when the token allows). On a match, each `gh` call is prefixed with that account's token rather than running `gh auth switch`, so the active account and any parallel sessions are left alone. With no match, `gh` runs as it is.
