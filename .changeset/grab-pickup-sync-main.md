---
"mattpocock-skills": patch
---

`grab` and `pickup` now start by putting the checkout back on an up-to-date `main` (`git checkout main && git pull --ff-only`), since it's usually still on a branch whose PR already merged. A clean tree is synced without asking; a dirty one stops and offers options (stash and sync, commit to the current branch and sync, carry the changes onto the ticket branch for `grab` or skip the sync for `pickup`, or stop).
