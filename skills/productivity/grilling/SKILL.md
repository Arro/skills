---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round, then wait for the user's answers before the next round.

## Asking a round

Ask through the harness's structured question tool whenever one exists (Claude Code's `AskUserQuestion`, Codex's `request_user_input`, or the equivalent in the harness you are running in). The user then clicks an answer per question instead of reading a wall of text and typing "Q1 yes, Q2 no" back. Each question in the round becomes one entry in the call:

- A short title, a body that carries the context needed to decide, and two to four options with a one-line description each.
- Your recommended answer is the first option, with `(Recommended)` in its label.
- A free-text option is always present. Most tools add an "Other" entry themselves; when the one you are using does not, add an option named `Other` whose description invites the user's own answer.

Put as many questions in one call as the tool allows (Claude Code's takes four), so the user works through the round in one sitting rather than waiting on you between questions. A round larger than the cap goes out in consecutive calls, each sent as soon as the previous one returns.

When the harness has no such tool, fall back to text, one block per question:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

In either form, word each question so "yes" accepts your recommended answer.

## Working the tree

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent with a fresh context window to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
