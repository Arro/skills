Quickstart:

```bash
npx skills add mattpocock/skills --skill=upgrade-deps
```

```bash
npx skills update upgrade-deps
```

[Source](https://github.com/mattpocock/skills/tree/main/skills/engineering/upgrade-deps)

## What it does

`upgrade-deps` brings a pnpm project up to the latest of everything, in two tiers. Minor and patch bumps are applied, verified against the repo's own checks, and committed without asking. Major versions are only ever assessed and presented — the agent researches each one and waits for your approval before touching it.

The gate on majors is the **six-month rule**: a major version younger than six months is held back no matter how good it looks, because fresh majors are where the churn and the regressions live. The eligible target may therefore be an *intermediate* major — on v4 with a month-old v6, the skill proposes the two-year-old v5.

## When to reach for it

You invoke this by typing `/upgrade-deps` — the agent won't reach for it on its own.

Reach for it when you drop back into a project you haven't dusted in a while and want its dependencies current again. It replaces the manual `ncu -t minor` / eyeball / `ncu -u` loop with pnpm-native commands plus an agent doing the eyeballing.

## Prerequisites

A pnpm project — `pnpm-lock.yaml` must exist. The skill is deliberately pnpm-native (it leans on `pnpm up`'s range-respecting sweep, `pnpm outdated`, and `pnpm view`) and stops rather than translating the workflow to npm or yarn. The working tree must be clean, so the upgrade commits contain nothing else.

## The two tiers

The **sweep** handles everything within the current majors: `pnpm up` for ranged deps, hand-bumps that preserve pin style for exact/tilde pins, `pnpm.overrides` kept in sync, then the repo's own checks (typecheck, tests, lint, build) before a single commit. Fallout the checks demand — a linter's new config opt-in, a reformat — ships in that same commit.

The **assessment** covers everything a major behind, grouped into families that must move together (`react`/`react-dom`/`@types/react`, a tool and its plugins). Each family gets a target picked by the six-month rule, its changelog read, its breaking changes grepped against your actual usage, and a verdict: safe, migration (with the work named), or risky. You pick from that table; each approved family lands as its own commit, reverted if the checks won't go green.

## It's working if

- Minor/patch bumps arrive as one commit with green checks, and you were never asked about them.
- No major version changes without you approving it from the assessment table.
- Held-back majors come with the date they become eligible, so next run knows.
- Pin styles survive: exact stays exact, `=` stays `=`, the `next-auth` beta you opted into stays put.

## Where it fits

`upgrade-deps` is periodic maintenance — run it every few weeks per project, like [improve-codebase-architecture](https://aihero.dev/skills-improve-codebase-architecture) but for the dependency tree rather than the code. It's a standalone: it feeds nothing downstream except a healthier repo, though a "migration" verdict on a big major can become an idea you take into the main flow at [grill-with-docs](https://aihero.dev/skills-grill-with-docs). When you're unsure which skill fits, [ask-matt](https://aihero.dev/skills-ask-matt) routes you.
