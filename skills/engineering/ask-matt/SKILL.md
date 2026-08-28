---
name: ask-matt
description: Ask which skill or flow fits your situation. A router over the skills in this repo.
disable-model-invocation: true
---

# Ask Matt

You don't remember every skill, so ask.

A **flow** is a path through the skills. Most paths run along one **main flow**, and two **on-ramps** merge onto it. Everything else is standalone, or a vocabulary layer that runs underneath.

## The main flow: idea → ship

The route most work travels. You have an idea and want it built.

1. **`/grill-with-docs`** — sharpen the idea by interview. Start here whenever you are **working in a working directory**: it's stateful, retaining what it learns in `CONTEXT.md` and ADRs. (No working directory? Use `/grill-me` — see Standalone. Both run the same `/grilling` primitive; `grill-with-docs` is the one that leaves a paper trail, which makes it the better of the two whenever a repo is there to leave it in.)
2. **Branch — can you settle every question in conversation?** If a question needs a runnable answer (state, business logic, a UI you have to see), detour through a prototype, bridged by **`/handoff`** in both directions (a prototype lives in its own directory, which is exactly what `/handoff` is for — see Phase boundaries):
   - **`/handoff`** out, then open a fresh session against that file,
   - **`/prototype`** to answer the question with throwaway code,
   - **`/handoff`** back what you learned, and reference it from the original idea thread.
3. **Branch — is this a multi-session build?**
   - **Yes** → **`/to-spec`** (turn the thread into a spec), then **`/to-tickets`** to split it into tracer-bullet tickets, each declaring its **blocking edges**. On a local tracker that's one file per ticket under `.scratch/<feature>/issues/`, worked blockers-first by hand; on a real tracker the edges become native blocking links, so any ticket whose blockers are done can be grabbed — kick off **`/implement`** per ticket, **`/clear`ing context between each one**. Each ticket is self-contained, so the last one's context is disposable.
   - **No** → **`/implement`** right here, in the same context window.

   Either way, **`/implement`** builds each issue by driving **`/tdd`** internally — one red-green slice at a time — then closes out by running **`/code-review`**, a two-axis review (Standards + Spec) of the diff, before committing. Reach for **`/tdd`** on its own when you just want to build a concrete behaviour test-first without a full spec, and **`/code-review`** on its own whenever you want to review a branch or PR against a fixed point.

### Context hygiene

Keep steps 1–3 in **one unbroken context window** — don't compact or clear until after `/to-tickets` — so the grilling, spec, and tickets all build on the same thinking. Each `/implement` then starts fresh, working from the ticket.

The limit on this is the **[smart zone](https://www.aihero.dev/ai-coding-dictionary/smart-zone)**: the window (~150k tokens on state-of-the-art models) within which the model still reasons sharply. If a session approaches it before `/to-tickets`, don't push on degraded — `/compact` at the nearest phase boundary and carry on (see Phase boundaries).

## The worktree loop: tickets in parallel

An alternative tail for the main flow. Where step 3 runs `/implement` per ticket serially in your own window, this loop **fans out**: each `ready-for-agent` ticket gets its own session and its own isolated git worktree, so several run at once without colliding, and the PRs come back to you for review.

1. **`/queue`** — survey before starting: what's available to pick up, what's already claimed, which PRs await review (flagging any forbidden stacked PR), which worktrees linger. Read-only.
2. **`/pickup <id>`** — claim one ticket (GitHub or Linear; assignment is the **mutex**), build it in a worktree with its own `PORT`, and take it through to an open PR. It stops before merge, and runs `/implement` for the build itself — same loop as the serial flow, wrapped in a worktree and a PR.
3. **`/review-loop <id>`** — optional, when a reviewer bot watches the repo's PRs: converge the open PR with it. Fix the bot callouts you agree with, push, wait for the re-review, repeat — until every remaining flag is a reasoned disagreement in the **ledger** — each answered in its PR thread so the bot's next pass reads it — with the ledger posted back to the issue as the exit report. Works on any open PR, so it serves `/grab` too.
4. **`/test-drive <id>`** — optional: put the ticket's branch on the main checkout for hands-on testing. The worktree goes; the branch and PR stay.
5. **`/wrapup <id>`** — after your review: merge the PR once CI is green, then tear down the worktree and branch and fast-forward `main`.

For **one ticket you'd rather run in place**, skip the loop and use **`/grab <id>`** — the light sibling of `/pickup`: no queue, no claim, no worktree, no port. It pulls the ticket down (GitHub or Linear), branches off `main` in the current checkout, makes the changes, and takes them to an open PR. Reach for it when the ticket is small and nothing else is running; the moment you want tickets in parallel, it's `/pickup`.

## On-ramps

A starting situation that generates work, then merges onto the main flow.

- **Bugs and requests piling up** → **`/triage`**. It moves issues through triage roles and produces agent-ready issues, which **`/implement`** later picks up.

  Triage is only for issues **you didn't create** — bug reports, incoming feature requests, anything that arrives raw. Tickets that `/to-tickets` produced are already agent-ready, so **don't triage them**.

- **Something's broken** → **`/diagnosing-bugs`**. For the hard ones: the bug that resists a first glance, the intermittent flake, the regression that crept in between two known-good states. It refuses to theorise until it has a **tight feedback loop** — one command that already goes red on *this* bug — then fixes with a regression test. Its post-mortem hands off to **`/improve-codebase-architecture`** when the real finding is that there's no good seam to lock the bug down.

- **A huge, foggy effort — a greenfield project or a huge feature build, too big for one session** → **`/wayfinder`**, the most cognitively demanding flow here. When the way from here to the destination isn't visible yet, it charts a **shared map** of **decision tickets** on the issue tracker and resolves them one at a time — producing **decisions, not deliverables** — until the fog is pushed back and the way is clear. Where **`/grill-with-docs`** sharpens an idea you can hold in one session, wayfinder is for the idea you can't — and it's slower and denser, so save it for exactly that, never a well-scoped feature.

  When the map clears, **it hands off, it doesn't build**: merge onto the main flow at **`/to-spec`**, which collapses the map's linked decisions into a buildable plan, then `/to-tickets` and `/implement` as usual. Looping the map straight into `/implement` skips that collapse and throws the linked detail away — go straight to `/implement` only when the effort turned out genuinely small.

## Codebase health

Not feature work — upkeep.

- **`/improve-codebase-architecture`** — run whenever you have a spare moment to keep the codebase good for agents to operate in. It surfaces **deepening opportunities**; picking one _generates an idea_ you can take into the main flow at `/grill-with-docs`. It's the survey that finds the candidates; **`/codebase-design`** (below) is the bench you design the chosen one on.
- **`/upgrade-deps`** — the same upkeep instinct pointed at the dependency tree of a pnpm project. Minor/patch bumps are applied and committed automatically; majors are assessed against a **six-month rule** (a major younger than six months is held back) and only applied with your approval, each as its own commit. A "migration" verdict on a big major can become an idea for the main flow at `/grill-with-docs`.

## Vocabulary underneath

Two model-invoked references that run *beneath* the other skills — each the single source of truth for its vocabulary. Reach for them directly when the **words**, not the process, are the problem; or let the skills above pull them in.

- **`/domain-modeling`** — sharpen the project's *domain* language: challenge a fuzzy term, resolve an overloaded word ("account" doing three jobs), record a hard-to-reverse decision as an ADR. It's the active discipline `/grill-with-docs` drives to keep `CONTEXT.md` a clean glossary.
- **`/codebase-design`** — the deep-module vocabulary (module, interface, depth, seam, adapter, leverage, locality) for designing a module's *shape*: a lot of behaviour behind a small interface at a clean seam. `/tdd` and `/improve-codebase-architecture` both speak it.

## Phase boundaries

A **phase** is a chunk of work inside a session — the grilling, the implementation, the QA. At the **boundary** between two of them you have five options, and picking between them is the fuzziest decision in this whole map:

- **Continue** — stay put. Costs nothing, loses nothing.
- **`/clear`** — empty the window, when nothing here matters to what's next.
- **`/handoff`** — write a portable markdown file. Narrow: only for a **new harness**, a **new directory**, a **colleague**, or forking a side task **mid-phase**. What it buys is portability.
- **Subagent** — send a tightly-scoped task to its own window and get a report back.
- **`/compact`** — compress this context and seed a fresh session with it. The **default**, at the bottom of the tree rather than the first reach.

Read [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) for the ordered tree — the five questions, the reasoning behind each branch, and why the primary-source cost makes **Continue** the one to rule out first. Make the decision **at** a boundary; mid-phase, continue or split the rest into subagents.

## Standalone

Off the main flow entirely.

- **`/grill-me`** — the same relentless interview as `/grill-with-docs`, but **stateless**: it saves nothing locally and builds no `CONTEXT.md`. Reach for it when you are **not working in a working directory** — sharpening a plan, a design, a piece of writing, anything with no repo under it. If you are in a working directory, use `/grill-with-docs` instead: it runs the same interview and leaves a paper trail, so it is strictly the better one.
- **`/grilling`** — the interview primitive itself: rounds, the frontier, facts are the agent's job and decisions are yours. `/grill-me` and `/grill-with-docs` are the two named ways in, and `/triage`, `/wayfinder` and `/improve-codebase-architecture` all run it internally. Reach for it directly only when you want the interview with no wrapper around it.
- **`/resolving-merge-conflicts`** — work an in-progress merge or rebase conflict hunk by hunk, resolving by **intent** traced to each side's primary source rather than by picking lines, then finish the operation. It never runs `--abort`. Standalone and off every flow: reach for it when you are already mid-conflict.
- **`/content-inventory`** — when a page or component needs a **redesign**, not another patch. Vibe-coded features accumulate design — each built in the style of the last — and showing a design session the existing UI anchors it to those choices. This produces the anchor-free alternative: the complete list of what the scope must contain (data, actions, inputs, states, navigation, feedback), traced from the code with every design decision stripped, ready to paste into a fresh design session. Pairs with `/prototype`: the inventory says what must be present; the prototype explores what it could look like.
- **`/prototype`** — a small, throwaway program that answers one design question: does this state model feel right, or what should this UI look like. Throwaway is a constraint on how the code is written, not a promise to destroy it: the answer folds into the real code, and the prototype itself is kept as a **primary source** on a `prototype/<name>` branch out of main, pointed at from the implementation issue. It's the detour in step 2 of the main flow, but reach for it any time a design question is hard to settle on paper.
- **`/research`** — delegate reading legwork to a **background agent**: it investigates a question against **primary sources**, then leaves a cited Markdown file in the repo. Keep working while it reads. The file it produces is something to take *into* the main flow at `/grill-with-docs` — research feeds the thinking, it doesn't replace it.
- **`/to-questionnaire`** — when the thing blocking you isn't in your head or the codebase but in **someone else's**, this writes them a questionnaire to fill in. It's the inverse of `/grill-me`: instead of interviewing you about the subject, it interviews you about the **send** — who it's going to, what you need back — and aims the questions at the gap. What comes back is material for `/grill-with-docs` or `/to-spec`.
- **`/wizard`** — for the steps only a **human** can take: provisioning infrastructure, setting up credentials or CI secrets, clicking through an unfamiliar third-party dashboard, running a one-off migration or cutover. It generates an interactive bash script that opens each URL, captures each value, and writes it into `.env` and GitHub secrets — so the procedure stops being something you re-explain to an agent every time. Model-invoked, so the agent reaches for it the moment it hits a wall only you can pass. If the agent could just do it itself, it should; this is for where a human is genuinely in the loop.
- **`/wait-what`** — the corrective for a message that didn't land. Use it mid-conversation, inside any other skill, and the agent re-pitches what it just said with the context you were missing, in plain English, using the `CONTEXT.md` vocabulary. It works after the fact; `/grill-with-docs` is the upfront cure, because a shared language agreed early is what stops the jargon arriving at all.
- **`/teach`** — learn a concept over multiple sessions, using the current directory as a stateful workspace.
- **`/writing-for-agents`** — reference for writing documents agents consume: skills, AGENTS.md, pointed-at docs.
- **`/rename-thread`** — give the current thread a findable title. The agent can't run `/rename` itself, so the deliverable is a copy-able block in the turn's final message. Reach for it when the sidebar name no longer says what the thread became.
- **`/gpt-image-2`** — when the deliverable is an image file: generate, edit, or blend with OpenAI's gpt-image-2 through the `mcp-image` MCP server, filed per project by slug and prefix. One image per call, then wait for the verdict — every call costs money.
- **`/obsidian-vault`** — search, create, and organize notes in the Obsidian vault: wikilinks, index notes, Title Case, links over folders.
- **`/edit-article`** — improve an article draft: restructure sections so information dependencies read in order, then tighten prose section by section, confirming each with you.

## Precondition

**`/setup-matt-pocock-skills`** — run before your first engineering flow to configure the issue tracker, triage labels, doc layout, and project slug the other skills assume. Custom issue trackers also work.
