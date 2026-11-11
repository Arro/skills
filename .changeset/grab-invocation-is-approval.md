---
"mattpocock-skills": patch
---

`grab` now says outright that typing `/grab <id>` is the approval for every step it prescribes (syncing `main`, creating the branch, committing, pushing, opening the PR), matching `pickup`, so the agent stops asking "May I...?" before each one. It still stops for the real decisions: a dirty checkout, a pull that refuses, a ticket it can't follow as written.
