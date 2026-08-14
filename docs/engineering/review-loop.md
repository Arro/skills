## What it does

`/review-loop` parks the agent on an open PR and has it iterate with the PR's automated reviewer: read the bot's latest **pass**, fix the callouts it agrees with, push, wait for the bot to re-review, and go again. It does not treat the bot as an oracle — every callout gets a verdict with a stated reason, only the agreements get fixed, and the loop ends when a fresh pass raises nothing new worth agreeing with, not when the bot goes quiet.

## When to reach for it

You invoke this by typing `/review-loop <issue or PR number>` — the agent won't reach for it on its own. Given an issue number it finds the PR that closes it; given nothing, it uses the current branch's PR.

Reach for it when a PR is open and an automated reviewer — a Claude review action, CodeRabbit, Copilot, any bot that re-reviews on push — is producing findings you'd otherwise shuttle back and forth by hand. It stops short of merge: that's [wrapup](https://aihero.dev/skills-wrapup)'s job, after your own review.

## Prerequisites

An open PR with a reviewer bot attached — the loop has nothing to converge with otherwise — and an authenticated `gh` CLI.

## Passes and the ledger

A **pass** is one review round from the bot, and it's wider than "new comments": some bots edit an earlier comment instead of posting again, or do both in the same thread, so a pass is every bot comment created *or edited* since the last push.

The **ledger** is the loop's memory: every callout the bot has ever raised, marked agree, disagree, or fixed, each with a one-line reason. Agreement is earned — a real bug, a spec mismatch, a breach of the repo's own standards; taste with no rule behind it is a disagreement with the reason written down. A re-raised callout keeps its verdict unless the bot brings genuinely new information, so nothing gets re-litigated pass after pass.

A disagreement doesn't stay private: the moment a callout earns its verdict, the loop replies in that callout's thread with the justification, so the bot's next pass reads it — that, not silence, is what stops the re-flagging. One reply per callout; a re-raised callout already has its answer.

Convergence is judgment-shaped: the loop is done when everything still flagged sits in the ledger as a reasoned disagreement. It also gives up honestly — after five iterations (that's ping-pong; a human should look) or thirty minutes with no fresh pass. Either way the run ends with an exit report — commits pushed, the ledger verbatim with links to the in-thread replies, and which model ran the loop — posted as a comment on the issue as well as delivered in chat. The verdict on the PR stays yours: the loop never resolves threads, approves, or merges.

## It's working if

- Every commit the loop pushes names the callouts it addresses, and the repo's checks were green before each push.
- Every disagreement gets one in-thread reply carrying its reason, and the same disagreement is never argued twice across passes.
- The issue carries an exit-report comment naming the model, the commits, and the remaining disagreements.
- The loop stops itself — converged, quiet for thirty minutes, or five iterations — rather than spinning.

## Where it fits

An optional chain step in the worktree loop: [pickup](https://aihero.dev/skills-pickup) or [grab](https://aihero.dev/skills-grab) opens the PR it works on, and [wrapup](https://aihero.dev/skills-wrapup) merges once you're happy — this sits between them, burning down the bot's findings before your review. For the whole map, ask [ask-matt](https://aihero.dev/skills-ask-matt).
