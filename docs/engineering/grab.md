## What it does

`grab` takes one ticket to an open PR in the checkout you're already sitting in: it pulls the ticket down, branches off `main`, makes the changes, commits with a closing reference, pushes, and opens the PR. It stops before merge. It carries none of `pickup`'s machinery — no label gate, no claiming, no isolated worktree, no port assignment — which is the whole point: one ticket, one branch, one PR, in place.

Tickets can live on GitHub or Linear; the skill detects which from the argument (`123` or a `github.com` URL vs `ABC-123` or a `linear.app` URL).

## When to reach for it

You invoke this by typing `/grab <id>` — the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own.

| Situation | Use |
| --- | --- |
| One small ticket, nothing else running, PR wanted | `/grab` |
| Several tickets in parallel, each in its own session and worktree | [pickup](https://aihero.dev/skills-pickup) |
| Building serially in the session you're in, no PR ceremony | [implement](https://aihero.dev/skills-implement) |

Typing the command is the approval. `grab` does not come back to ask whether it may pull `main`, create the branch, or open the PR: those are the steps you asked for by running it. It only stops for real decisions, such as a dirty checkout or a ticket it can't follow as written.

## Prerequisites

- An issue tracker the session can drive: the `gh` CLI for GitHub, or the Linear [MCP](https://www.aihero.dev/ai-coding-dictionary/mcp) tools for Linear.
- Optional: a `[user]` email in the repo's `.git/config`. When it belongs to one of your logged-in `gh` accounts (its public profile email, a `users.noreply.github.com` address, or any of its emails if the token has the `user:email` scope), every `gh` call in the run goes out as that account. Your active `gh` account is never switched, so other terminals and parallel sessions are unaffected. With no match, `gh` runs as whatever account is active.

## Back to `main` first

Before touching the ticket, `grab` does the `git checkout main && git pull` you'd otherwise type yourself, since the checkout is usually still on a branch whose PR already merged. On a clean tree it just does it. On a dirty one it stops and offers you a choice: stash and sync, commit to the current branch and sync, bring the changes onto the ticket's branch, or stop so you can sort it out. Nothing gets stashed or committed without you picking that option.

## In place, not isolated

The defining trade is **in place**: `grab` works on a fresh branch in your main checkout, so it costs nothing to set up — and it can't run alongside anything else. There is no mutex on the ticket and no worktree keeping sessions apart, so two `grab` sessions in one repo would collide. The guardrails that survive from the heavier sibling are the ones about git, not ceremony: the branch point and PR base are always `main`, a stacked PR is a sequencing problem to surface rather than an instruction to follow, and the run always ends at an open PR — never a merge.

## Common questions

**Why doesn't it claim the ticket or check for a `ready-for-agent` label?**
Claiming exists to keep parallel sessions from grabbing the same ticket, and the label marks a queue that `/pickup` and `/queue` drain. `grab` is single-player: you hand it one ticket, so there's no race to guard against and no queue to respect. If the ticket did come off a `ready-for-agent` queue, prefer `/pickup` so the claim keeps other agents off it.

**Why did the PR open under a different GitHub account than my active one?**
Because the repo's `.git/config` says whose repo it is. If its `[user]` email matches one of your logged-in `gh` accounts, `grab` runs every `gh` command as that account, so a personal repo gets a personal PR even while your work account is active. If the account isn't being picked up, make that email public on its GitHub profile, or add the `user:email` scope to its token (`gh auth refresh -h github.com -s user:email` while it's the active account).

## It's working if

- The run ends at an open PR against `main` with a `Closes` reference, and you never had to think about worktrees or ports.
- You never type `git checkout main && git pull` before a run: a clean checkout gets synced silently, and a dirty one gets a question with options instead of a guess.
- A run on a clean checkout reaches the open PR without a single "May I...?" prompt for a step the skill prescribes.
- An ambiguous ticket, or a ticket depending on unmerged code, gets surfaced back to you instead of worked around.
- Your checkout is on the feature branch afterwards, and the report tells you so.

## Where it fits

A reach-for-it-anytime standalone: the in-place shortcut past the worktree loop. [pickup](https://aihero.dev/skills-pickup) is the sibling that earns its overhead when tickets run in parallel — claim, worktree, port; [implement](https://aihero.dev/skills-implement) is the sibling for building in the current session without the branch-and-PR wrapper. For the map over the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
