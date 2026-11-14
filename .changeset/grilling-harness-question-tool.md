---
"mattpocock-skills": patch
---

`grilling` now asks each round through the harness's structured question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex) when one exists: every question gets clickable options with the recommendation first and a free-text "Other", and as many questions as the tool allows go out in one call, so a round is answered by clicking rather than by scrolling a five-paragraph dump and typing "Q1 yes, Q2 no". The numbered `❓`/`➡️` text format stays as the fallback for harnesses without such a tool.
