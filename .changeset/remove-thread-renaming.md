---
"mattpocock-skills": patch
---

Drop thread renaming from the skills: harness sidebars now filter well enough that a hand-written thread title no longer pays for itself. `rename-thread` is removed (it was never released as a promoted skill), `pickup` no longer prints a suggested thread label or mentions renaming, and `setup-matt-pocock-skills` no longer asks for a project slug and prefix. `gpt-image-2` still asks for that `## Project slug` block itself when a project lacks one, and `pickup`'s port hashing falls back to the repo's directory name.
