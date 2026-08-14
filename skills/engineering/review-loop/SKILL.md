---
name: review-loop
description: Fix-push-wait loop with a PR's reviewer bot — address the callouts you agree with, push, wait for re-review, repeat until only reasoned disagreements remain.
argument-hint: "issue or PR number (defaults to the current branch's PR)"
disable-model-invocation: true
---

# /review-loop — converge a PR with its reviewer bot

Given an issue or PR number (or the current branch's PR if none was given), loop with the PR's automated reviewer: read the bot's latest **pass**, fix every callout you agree with, push, wait for the bot to re-review, repeat. The loop converges when a fresh pass raises nothing new you agree with — every remaining flag sits in the **ledger** as a reasoned disagreement.

**Authorization.** Invoking `/review-loop` authorizes the commits and plain pushes to the PR's branch that the loop entails, plus one comment at the end: the exit report posted on the issue. That is the direct, intended effect of the command. It authorizes nothing beyond that: no force pushes, no merging, no replying in the bot's review threads.

## Locate the PR

- Numeric argument: treat it as an issue number first — `gh pr list --search "<num> in:body" --state open` (the `Closes #<num>` convention), cross-checked with `gh issue view <num>`. If no PR references it, treat the argument as a PR number: `gh pr view <num>`.
- No argument: the current branch's PR (`gh pr view`).
- Make sure the local checkout is on the PR's branch and up to date with its remote. A dirty working tree with unrelated changes, or an argument matching more than one PR: stop and ask.

## Read the latest pass

A **pass** is one review round from the bot — the reviewer whose account is a Bot type or carries a `[bot]` suffix. Gather all three places a pass can land:

- reviews and top-level comments: `gh pr view <pr> --json reviews,comments`
- inline review comments: `gh api repos/{owner}/{repo}/pulls/<pr>/comments`

The bot sometimes **edits** an earlier comment instead of posting a new one — and sometimes does both in the same thread. So a pass is every bot comment whose creation **or edit** date is more recent than your last push (first iteration: the bot's most recent round): compare `updated_at`/`updatedAt`, not just the creation date, and re-triage an edited comment's current text even if you processed an older version of it in a previous pass.

If the PR has no bot review yet, say so and wait for the first pass using the wait discipline below.

## Triage into the ledger

The **ledger** is the loop's memory: every callout the bot has ever raised, each marked **agree**, **disagree**, or **fixed**, with a one-line reason. Keep it current across iterations; it is also the final report.

- **Agree** when the callout names a real bug, a mismatch with the spec or ticket, or a breach of the repo's documented standards.
- **Disagree** when it is out of scope for this PR, contradicts the repo's own conventions, is factually wrong, or is taste with no rule behind it. A disagreement needs a stated reason — "seems fine as is" is not one.
- A re-raised callout keeps its ledger verdict unless the bot brings genuinely new information. The ledger exists so nothing gets re-litigated.

## Fix, verify, push

1. Fix every callout marked agree; flip each to fixed in the ledger.
2. Run the repo's checks (tests, lint, typecheck — whatever it defines) and get them green first.
3. Commit with a message saying which callouts it addresses, then plain-push. If the push is rejected because the remote moved, stop and report — someone else is on the branch.

If a pass produced no agreed callouts, there is nothing to push — go straight to the exit check.

## Wait for the next pass

The bot typically needs about 15 minutes to re-review. Wait in chunks of five minutes or less (`sleep 300`; if the harness blocks sleeping, use its wait/monitor facility), checking between chunks for bot activity newer than your push — a comment created *or edited* since it (`updated_at`).

- New pass → back to triage.
- No new pass after 30 minutes → report the current ledger and stop; don't spin forever.

## Exit

The loop is done when a fresh pass contains nothing that earns an agree — every flag is already fixed or sits in the ledger as a reasoned disagreement. Also stop after 5 iterations regardless: that is ping-pong, and a human should look.

**Exit report.** Write it once, deliver it twice: in chat, and as a comment on the GitHub issue (`gh issue comment <num> --body-file …`). If the loop started from a PR with no linked issue, post it as a top-level PR comment instead (`gh pr comment <pr>`) — never as a reply in a review thread. The report:

- which model ran the loop — name yourself, e.g. "Loop run by <model>";
- iterations run;
- each commit pushed and which callouts it fixed;
- the ledger's disagreements verbatim, so the user can answer the bot's threads themselves.

## Guardrails

- Plain pushes to the PR branch only — no force pushes, no merging, no branch surgery.
- The human owns the review conversation: never reply in the bot's threads, resolve them, approve, or request changes. The exit report comment is the only comment this skill posts.
- Stop and ask rather than guess when the PR is ambiguous or the working tree holds unrelated changes.
